require 'fileutils'
temp_memes = Dir.glob('/tmp/meme*.jpg')
FileUtils.rm(temp_memes)
