require 'cinch'
require './lib/memegen'
require 'typhoeus'
require 'oj'
require 'active_support/core_ext/array/conversions'
require 'yaml/store'

$store = YAML::Store.new File.join(File.dirname(__FILE__), 'config.yml')
$channels = $store.transaction { $store['channels'].uniq }

CLIENT_ID = $store.transaction { $store['imgur']['client_id'] }
COMMAND_PREFIX = $store.transaction { $store['command_prefix'] }
$memes = Dir.glob("#{File.join(File.dirname(__FILE__), "memes")}/*.jpg").reduce({}) do |images, path|
  name = path.split('/').last.sub(/\.jpg$/,'')
  images.merge(name => path )
end

def upload(filepath)
  # Check to see we haven't exceeded rate limits, based on the last request's data
  if @last && ((@last.headers['X-RateLimit-ClientRemaining'].to_i <= 50) || (@last.headers['X-RateLimit-UserRemaining'].to_i <= 5))
    credits_response = Typhoeus.get(
      'https://api.imgur.com/3/credits',
      headers: {
        Authorization: "Client-ID #{CLIENT_ID}"
      }
    )
    credits = Oj.load(credits_response.body)
    # Return false unless our limits have reset to normal
    return false unless credits['data']['UserRemaining'].to_i == credits['data']['UserLimit'].to_i || credits['data']['ClientRemaining'].to_i == credits['data']['ClientLimit'].to_i
  end

  response = Typhoeus.post(
    'https://api.imgur.com/3/image',
    body: {
      image: File.open(filepath, 'r')
    },
    headers: {
      Authorization: "Client-ID #{CLIENT_ID}"
    }
  )
  if response.code == 200
    @last = response

    Oj.load(response.body)['data']['link']
  else
    false
  end
end

bot = Cinch::Bot.new do 
  configure do |c|
    c.server = $store.transaction { $store['irc']['server'] }
    c.port = $store.transaction { $store['irc'].fetch('port', 6667) }
    c.realname = 'lemaymay'
    c.ssl.use = $store.transaction { $store['irc'].fetch('ssl', false) }
    c.nick = $store.transaction { $store['irc']['nick'] }
    c.modes = $store.transaction { $store['irc'].fetch('modes', []) }
    if $store.transaction { $store['irc'].fetch('sasl', false) }
      c.sasl.username = $store.transaction { $store['irc']['sasl']['username'] }
      c.sasl.password = $store.transaction { $store['irc']['sasl']['password'] }
    end
    c.channels = $channels
  end
  on :message, /^#{COMMAND_PREFIX}meme (?:m\:(\w+) )?(.*?);(.*)/i do |m, meme, top, bottom|
    if meme
      path = $memes[meme]
    else
      path = $memes[$memes.keys.sample]
    end
    if path.nil?
      warn "Couldn't find meme \"#{meme}\""
      m.reply "IDK what meme \"#{meme}\" is, try #{COMMAND_PREFIX}memes for a list", true
      break
    end
    top.gsub!(/[\x02\x0f\x16\x1f\x12]|\x03(\d{1,2}(,\d{1,2})?)?/, '')
    top.gsub!(/[\x00-\x1f]/, '')
    bottom.gsub!(/[\x02\x0f\x16\x1f\x12]|\x03(\d{1,2}(,\d{1,2})?)?/, '')
    bottom.gsub!(/[\x00-\x1f]/, '')
    file = Meme.generate(path, top.strip, bottom.strip, "#{$store.transaction { $store['watermark_prefix'] }}/#{m.channel.to_s}")
    url = upload(file)
    if url == false
      m.reply "Couldn't make that meme", true
    else
      m.reply url, true
    end
  end

  on :message, /^#{COMMAND_PREFIX}memes/ do |m|
    memes = $memes.keys
    m.reply memes.to_sentence, true
    m.reply "Usage: !meme [m:<memename>] <top>;<bottom>", true
  end

  on :invite do |m|
    bot.join m.channel
    $channels << m.channel.to_s
    $store.transaction { $store['channels'] = $channels.uniq}
  end
  on :kick do |m|
    if m.params[1] == m.bot.to_s
      $channels.delete m.channel.to_s
      $store.transaction {$store['channels']= $channels.uniq}
    end
  end

  on :ctcp, /version/i do |m|
    m.ctcp_reply('http://github.com/paradox460/memebot')
  end
end

bot.start
