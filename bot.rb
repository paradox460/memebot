require 'cinch'
require_relative 'lib/memegen'
require 'typhoeus'
require 'oj'
require 'active_support/core_ext/array/conversions'
require 'yaml/store'
require 'damerau-levenshtein'

$store = YAML::Store.new File.join(File.dirname(__FILE__), 'config.yml')
$channels = $store.transaction { $store['channels'].uniq }

CLIENT_ID = $store.transaction { $store['imgur']['client_id'] }
COMMAND_PREFIX = $store.transaction { $store['command_prefix'] }
$memes = Dir.glob("#{File.join(File.dirname(__FILE__), "memes")}/*.jpg").reduce({}) do |images, path|
  name = path.split('/').last.sub(/\.jpg$/,'')
  images.merge(name => path )
end

$dl = DamerauLevenshtein

def upload(filepath)
  # Check to see we haven't exceeded rate limits, based on the last request's data
  if @last && ((@last.headers['X-RateLimit-ClientRemaining'].to_i <= 50) || (@last.headers['X-RateLimit-UserRemaining'].to_i <= 5))
    credits_response = Typhoeus.get(
      'https://api.imgur.com/3/credits',
      headers: {
        Authorization: "Client-ID #{CLIENT_ID}"
      },
      nosignal: true
    )
    credits = Oj.load(credits_response.body)
    # Return false unless our limits have reset to normal
    return [false, {user_remaining: credits['data']['UserRemaining'], client_remaining: credits['data']['ClientRemaining']}] unless credits['data']['UserRemaining'].to_i == credits['data']['UserLimit'].to_i || credits['data']['ClientRemaining'].to_i == credits['data']['ClientLimit'].to_i
  end

  response = Typhoeus.post(
    'https://api.imgur.com/3/image',
    body: {
      image: File.open(filepath, 'r')
    },
    headers: {
      Authorization: "Client-ID #{CLIENT_ID}"
    },
    nosignal: true
  )
  if response.code == 200
    @last = response

    [ Oj.load(response.body)['data']['link'], nil]
  else
    [ false, { code: response.code } ]
  end
end

def best_meme(query, max_difference = 0.5)
  distances = $memes.keys.map do |x|
    longest = [query.length, x.length].max
    damlev = $dl.distance(query, x, 1)
    normalized_damlev = damlev / longest.to_f
    [x, damlev, normalized_damlev]
  end
  if distances.min_by { |x| x[2] }[2] >= max_difference
    nil
  else
    return distances.sort_by { |x| x[2] }.first
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
  on :message, /^\s*#{COMMAND_PREFIX}meme (?:m\:(\w+) )?(.*?);(.*)/io do |m, meme, top, bottom|
    if meme
      path = $memes[meme]
    else
      path = $memes[$memes.keys.sample]
    end
    # If no meme by that name exists…
    if path.nil?
      guess = best_meme(meme)
      if guess.nil?
        m.reply "IDK what meme \"#{meme}\" is, try #{COMMAND_PREFIX}memes for a list", true
        break
      else
        m.reply "Assuming you meant \"#{guess[0]}\", generating meme", true
        path = $memes[guess[0]]
      end
    end
    top.gsub!(/[\x02\x0f\x16\x1f\x12]|\x03(\d{1,2}(,\d{1,2})?)?/, '')
    top.gsub!(/[\x00-\x1f]/, '')
    bottom.gsub!(/[\x02\x0f\x16\x1f\x12]|\x03(\d{1,2}(,\d{1,2})?)?/, '')
    bottom.gsub!(/[\x00-\x1f]/, '')
    file = Meme.generate(path, top.strip, bottom.strip, "#{$store.transaction { $store['watermark_prefix'] }}/#{m.channel.to_s}")
    url, error_hash = upload(file)
    if url == false
      warn "Upload error: #{error_hash}"
      m.reply "Couldn't make that meme (#{error_hash})", true
    else
      m.reply url, true
    end
  end

  on :message, /^\s*#{COMMAND_PREFIX}memes/io do |m|
    memes = $memes.keys
    m.reply memes.sort.to_sentence, true
    m.reply "Usage: #{COMMAND_PREFIX}meme [m:<memename>] <top>;<bottom>", true
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
