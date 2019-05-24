module StumpyJPEG
  module ColorModel::CMYK
    extend ColorModel

    def self.number_of_components
      4
    end

    def self.decompose_canvas(canvas : Canvas)
      matrices = [] of Matrix
      matrices << Matrix.new(canvas.height, canvas.width, 0)
      matrices << Matrix.new(canvas.height, canvas.width, 0)
      matrices << Matrix.new(canvas.height, canvas.width, 0)
      matrices << Matrix.new(canvas.height, canvas.width, 0)
      canvas.map do |pix, c, r|
        r, g, b, a = pix.to_relative

        cc = 1 - r
        mc = 1 - g
        yc = 1 - b

        kr = Math.min(cc, mc, yc)
        kc = 1 - k

        c = (cc - kr) * kc * 255
        m = (mc - kr) * kc * 255
        y = (yc - kr) * kc * 255
        k = kr * 255

        matrices[0][r, c] = c.clamp(0, 255).round.to_i - 128
        matrices[1][r, c] = m.clamp(0, 255).round.to_i - 128
        matrices[2][r, c] = y.clamp(0, 255).round.to_i - 128
        matrices[3][r, c] = k.clamp(0, 255).round.to_i - 128
        pix
      end
      matrices
    end

    def self.compose_canvas(matrices)
      raise "CMYK requires 4 components" if matrices.size != 4

      image_height = matrices[0].row_count
      image_width = matrices[0].column_count

      Canvas.new(image_width, image_height) do |w, h|
        c = (matrices[0][h, w] + 128).clamp(0, 255)
        m = (matrices[1][h, w] + 128).clamp(0, 255)
        y = (matrices[2][h, w] + 128).clamp(0, 255)
        k = (matrices[3][h, w] + 128).clamp(0, 255)

        kc = (255 - k) / 255
        r = (255 - c) * kc
        g = (255 - m) * kc
        b = (255 - y) * kc
        RGBA.from_rgb8(r.clamp(0, 255).round.to_i, g.clamp(0, 255).round.to_i, b.clamp(0, 255).round.to_i)
      end
    end
  end
end