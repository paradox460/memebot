A messy bot for making memes in IRC channels

# Installation

1. You need ruby 2.0 or newer. I coded against 2.1. You also need rmagick AND graphics magick
2. Clone the git repo
3. run `bundle install` to get the dependencies. This may fail on rmagick. If it does, google till you figure it out. Its simple, I promise
3. Rename `config.example.yml` to `config.yml`
4. Fill out `config.yml`. You will need an Imgur api key
5. Start the bot via `ruby bot.rb`

# Usage
The bot is fairly simple to use via IRC, providing only two commands:

+ `!memes` lists the memes the bot knows about, the filenames, sans extension, of jpgs in the memes folder
+ `!meme [m:memename] <toptext>;<bottomtext>` creates a meme. `m:memename` specifies the meme to use, semicolon is *required* and separates top and bottom meme text.

# Caveats
This bot was written in a single nights coding session. As such its ugly as hell and probably full of bugs. As with everything else under the MIT license, use at your own risk.

Additionally, if you run this on a server that doesn't reboot very often, chances are your `/tmp` folder will fill up with meme images.

Since people tend to use `/tmp` for lots of useful things, such as sockets and other stuff, I've provided a script, `tmpclean.rb` you can run periodically to clean memes out of your `/tmp`. I recommend adding this to a nightly cron-job.

# License
```
Copyright (c) 2014 Jeff Sandberg

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
