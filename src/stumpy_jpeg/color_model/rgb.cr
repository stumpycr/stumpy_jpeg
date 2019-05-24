module StumpyJPEG
  module ColorModel::RGB
    extend ColorModel

    def self.number_of_components
      3
    end

    def self.decompose_canvas(canvas : Canvas)
      matrices = [] of Matrix
      matrices << Matrix.new(canvas.height, canvas.width, 0)
      matrices << Matrix.new(canvas.height, canvas.width, 0)
      matrices << Matrix.new(canvas.height, canvas.width, 0)
      canvas.map! do |pix, c, r|
        r, g, b = pix.to_rgb8
        matrices[0][r, c] = r.to_i - 128
        matrices[1][r, c] = g.to_i - 128
        matrices[2][r, c] = b.to_i - 128
        pix
      end
      matrices
    end

    def self.compose_canvas(matrices)
      raise "RGB requires 3 components" if matrices.size != 3

      image_height = matrices[0].row_count
      image_width = matrices[0].column_count

      Canvas.new(image_width, image_height) do |w, h|
        r = (matrices[0][h, w] + 128).clamp(0, 255).to_i
        g = (matrices[1][h, w] + 128).clamp(0, 255).to_i
        b = (matrices[2][h, w] + 128).clamp(0, 255).to_i
        RGBA.from_rgb8(r, g, b)
      end
    end
  end
end