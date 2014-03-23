require 'fileutils'
require 'RMagick'

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
      image = canvas.first

      draw = Magick::Draw.new
      draw.font = File.join(File.dirname(__FILE__), '..', 'fonts', 'Impact.ttf')
      draw.font_weight = Magick::BoldWeight

      pointsize = image.columns / 5.0
      stroke_width = pointsize / 30.0

      # Draw watermark
      unless watermark.nil?
        watermark_draw = draw.dup
        watermark_draw.annotate(canvas, 0, 0, 0, 0, watermark) do
          self.font = 'Helvetica'
          self.fill = 'white'
          self.stroke_antialias(true)
          self.font_weight = 100
          self.gravity = Magick::SouthEastGravity
          self.pointsize = 10
          self.undercolor = 'hsla(0,0,0,.5)'
        end
      end

      # Draw top
      unless top.empty?
        scale, spacing, text = scale_text(top)
        bottom_draw = draw.dup
        bottom_draw.annotate(canvas, 0, 0, 0, 0, text) do
          self.interline_spacing = -(pointsize / spacing)
          self.stroke_antialias(true)
          self.stroke = 'black'
          self.fill = 'white'
          self.gravity = Magick::NorthGravity
          self.stroke_width = stroke_width * scale
          self.pointsize = pointsize * scale
        end
      end

      # Draw bottom
      unless bottom.empty?
        scale, spacing, text = scale_text(bottom)
        bottom_draw = draw.dup
        bottom_draw.annotate(canvas, 0, 0, 0, 0, text) do
          self.interline_spacing = -(pointsize / spacing)
          self.stroke_antialias(true)
          self.stroke = 'black'
          self.fill = 'white'
          self.gravity = Magick::SouthGravity
          self.stroke_width = stroke_width * scale
          self.pointsize = pointsize * scale
        end
      end

      output_path = "/tmp/meme-#{Time.now.to_i}.jpg"
      canvas.write(output_path)
      output_path
    end

    private

    def word_wrap(text, col = 80)
      text.gsub(/(.{1,#{col}})( +|$\n?)|(.{1,#{col}})/, "\\1\\3\n")
    end

    def scale_text(text)
      text = text.dup
      if text.length < 10
        scale = 1.0
        spacing = 5
      elsif text.length < 20
        text = word_wrap(text, 10)
        scale = 0.7
        spacing = 5
      elsif text.length < 25
        text = word_wrap(text, 18)
        scale = 0.5
        spacing = 7
      else
        text = word_wrap(text, 28)
        scale = 0.3
        spacing = 10
      end
      [scale, spacing, text.strip]
    end
  end
end
