module StumpyJPEG
  module ColorModel::Grayscale
    extend ColorModel

    def self.number_of_components
      1
    end

    def self.decompose_canvas(canvas : Canvas)
      matrices = [] of Matrix
      matrices << Matrix.new(canvas.height, canvas.width) do |i, r, c|
        r, g, b = canvas[c, r].to_rgb8
        y = 0.299 * r + 0.587 * g + 0.114 * b
        y.clamp(0, 255).round.to_i - 128
      end
      matrices
    end

    def self.compose_canvas(matrices)
      raise "Grayscale requires 1 component" if matrices.size != 1

      image_height = matrices[0].row_count
      image_width = matrices[0].column_count

      Canvas.new(image_width, image_height) do |w, h|
        y = (matrices[0][h, w] + 128).clamp(0, 255).to_i
        RGBA.from_rgb8(y, y, y)
      end
    end
  end
end
