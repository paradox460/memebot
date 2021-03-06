require 'fileutils'
require 'RMagick'
require 'word_wrapper'

# Class for handling memes
class Meme
  class << self
      # Creates the meme using the image specified, and returns the temporary url
      # @param  path [String] The image path to use for the meme
      # @param  top [String] The text that appears on the top of the meme
      # @param  bottom [String] The text that appears on the bottom of the meme
      #
      # @return [String] The temporary meme file URL
    def generate(path, top, bottom, watermark = nil)
      top = (top || '').upcase
      bottom = (bottom || '').upcase

      canvas = Magick::ImageList.new(path)

      caption_meme(top, Magick::NorthGravity, canvas) unless top.empty?
      caption_meme(bottom, Magick::SouthGravity, canvas) unless bottom.empty?

      # Draw watermark
      unless watermark.nil?
        watermark_draw = Magick::Draw.new
        watermark_draw.annotate(canvas, 0, 0, 0, 0, " #{watermark}") do
          self.font = 'Helvetica'
          self.fill = 'white'
          self.text_antialias(false)
          self.font_weight = 100
          self.gravity = Magick::SouthEastGravity
          self.pointsize = 10
          self.undercolor = 'hsla(0,0,0,.5)'
        end
      end

      output_path = "/tmp/meme-#{Time.now.to_i}.jpg"
      canvas.write(output_path)
      output_path
    end

    private

    def caption_meme(text, gravity, canvas)
      
      text.gsub!('\\', '\\\\\\')

      # 28 is the biggest pointsize memes dont look like shit on
      min_pointsize = 28
      max_pointsize = 128
      current_pointsize = min_pointsize
      current_stroke = current_pointsize / 30.0

      max_width = canvas.columns - 20
      max_height = (canvas.rows / 2) - 20

      draw = Magick::Draw.new
      draw.font = File.join(File.dirname(__FILE__), '..', 'fonts', 'Impact.ttf')
      draw.font_weight = Magick::BoldWeight
      metrics = nil

      # Non-ragged word-wrap
      text.word_wrap!(24)

      # Calculate out the largest pointsize that will fit
      loop do
        draw.pointsize = current_pointsize
        last_metrics = metrics
        metrics = draw.get_multiline_type_metrics(text)

        if metrics.width + current_stroke > max_width ||
          metrics.height + current_stroke > max_height ||
          current_pointsize > max_pointsize
          if current_pointsize > min_pointsize
            current_pointsize -= 1
            current_stroke = current_pointsize / 30.0
            metrics = last_metrics
          end
          break
        else
          current_pointsize += 1
          current_stroke = current_pointsize / 30.0
        end
      end
      draw.annotate(canvas, canvas.columns, canvas.rows - 10, 0, 0, text) do
        self.interline_spacing = -( current_pointsize / 5)
        self.stroke_antialias(true)
        self.stroke = 'black'
        self.fill = 'white'
        self.gravity = gravity
        self.stroke_width = current_stroke
        self.pointsize = current_pointsize
      end
    end
  end
end

class String
  def word_wrap!(col)
    text = self
    text = WordWrapper::MinimumRaggedness.new(24, text).wrap
    text = text.split("\n").map do |line|
      line.length > col ? line.gsub(/(.{1,#{col}})( +|$\n?)|(.{1,#{col}})/, "\\1\\3\n").strip : line
    end * "\n"
    self.replace text.strip
  end
end
