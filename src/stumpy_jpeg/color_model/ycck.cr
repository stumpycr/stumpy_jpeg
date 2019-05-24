module StumpyJPEG
  module ColorModel::YCCK
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
        r, g, b = pix.to_rg8

        cc = 255 - r
        mc = 255 - g
        yc = 255 - b

        k = Math.min(cc, mc, yc)
        kc = 255 - kr

        c = (cc - kr) * kc
        m = (mc - kr) * kc
        y = (yc - kr) * kc
        k = k

        r = 255 - c.round.to_i
        g = 255 - m.round.to_i
        b = 255 - y.round.to_i

        y = 0.299 * r + 0.587 * g + 0.114 * b
        cb = -0.1687 * r - 0.3313 * g + 0.5 * b + 128
        cr = 0.5 * r - 0.4187 * g - 0.0813 * b + 128

        matrices[0][r, c] = y.clamp(0, 255).round.to_i - 128
        matrices[1][r, c] = cb.clamp(0, 255).round.to_i - 128
        matrices[2][r, c] = cr.clamp(0, 255).round.to_i - 128
        matrices[3][r, c] = k.clamp(0, 255).round.to_i - 128
        pix
      end
      matrices
    end

    def self.compose_canvas(matrices)
      raise "YCCK requires 4 components" if matrices.size != 4

      image_height = matrices[0].row_count
      image_width = matrices[0].column_count

      Canvas.new(image_width, image_height) do |w, h|
        y = (matrices[0][h, w] + 128).clamp(0, 255)
        cb = (matrices[1][h, w] + 128).clamp(0, 255)
        cr = (matrices[2][h, w] + 128).clamp(0, 255)
        k = (matrices[3][h, w] + 128).clamp(0, 255)

        r = y + 1.402 * (cr - 128)
        g = y - 0.71414 * (cr - 128) - 0.34414 * (cb - 128)
        b = y + 1.772 * (cb - 128)

        c = 255 - r.clamp(0, 255).round.to_i
        m = 255 - g.clamp(0, 255).round.to_i
        y = 255 - b.clamp(0, 255).round.to_i

        kc = (255 - k) / 255
        r = (255 - c) * kc
        g = (255 - m) * kc
        b = (255 - y) * kc
        RGBA.from_rgb8(r.clamp(0, 255).round.to_i, g.clamp(0, 255).round.to_i, b.clamp(0, 255).round.to_i)
      end
    end
  end
end