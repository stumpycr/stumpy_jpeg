require "stumpy_core"
require "matrix"

module StumpyCore

  struct RGBA
    def self.from_ycbcr(values)
      y, cb, cr = values
      from_ycbcr(y, cb, cr)
    end

    def self.from_ycbcr(y, cb, cr)
      r =  1.402   * (cr - 128) + y;
      g = -0.34414 * (cb - 128) + y - 0.71414 * (cr - 128);
      b =  1.772   * (cb - 128) + y;
      from_rgb8(r.round.clamp(0, 255).to_i, g.clamp(0, 255).round.to_i, b.clamp(0, 255).round.to_i)
    end

    def to_ycbcr
      r, g, b = to_rgb8
      y =   0.299  * r + 0.587  * g + 0.114  * b
      cb = -0.1687 * r - 0.3313 * g + 0.5    * b + 128
      cr =  0.5    * r - 0.4187 * g - 0.0813 * b + 128
      {y.round.to_u8, cb.round.to_u8, cr.round.to_u8}
    end
  end

  class Canvas

    def self.compose_ycbcr(matrices)
      width = matrices.first.column_count
      height = matrices.first.row_count

      self.new(width, height) do |w, h|
        y  = matrices[0]?.try {|m| (m[w, h] + 128).clamp(0, 255) } || 0
        cb = matrices[1]?.try {|m| (m[w, h] + 128).clamp(0, 255) } || 128
        cr = matrices[2]?.try {|m| (m[w, h] + 128).clamp(0, 255) } || 128
        RGBA.from_ycbcr(y, cb, cr)
      end
    end

    def decompose_ycbcr(grayscale = false)
      matrices = [] of Matrix(Int32)
      matrices << Matrix.new(@height, @width, 0)
      if !grayscale
        matrices << Matrix.new(@height, @width, 0)
        matrices << Matrix.new(@height, @width, 0)
      end
      map do |color, x, y|
        y, cb, cr = color.to_ycbcr
        matrices[0][y, x] = y
        if !grayscale
          matrices[1][y, x] = cb
          matrices[2][y, x] = cr
        end
        color
      end
      matrices
    end

    def blocks_of(size : Int32)
      blocks = [] of Canvas
      blocks_of(size) do |block|
        blocks << block
      end
      blocks
    end

    def blocks_of(size : Int32, &block)
      (0...@height).step(size) do |y|
        (0...@width).step(size) do |x|
          canvas = Canvas.new(size, size)

          size.times do |n|
            size.times do |m|
              ix = x + n
              iy = y + m
              if pix = safe_get(ix, iy)
                canvas.safe_set(n, m, pix)
              elsif ix >= @width
                last_pix = safe_get(@width - 1, iy) || canvas.get(n - 1, m)
                canvas.safe_set(n, m, last_pix)
              else
                last_pix = safe_get(ix, @height - 1) || canvas.get(n, m - 1)
                canvas.safe_set(n, m, last_pix)
              end
            end
          end

          yield canvas
        end
      end
    end

    def section(width, height, x, y)

      width.times do |w|
        height.times do |cy|
          if pix = safe_get(ix, iy)
            canvas.safe_set(n, m, pix)
          elsif ix >= @width
            last_pix = safe_get(@width - 1, iy) || canvas.get(n - 1, m)
            canvas.safe_set(n, m, last_pix)
          else
            last_pix = safe_get(ix, @height - 1) || canvas.get(n, m - 1)
            canvas.safe_set(n, m, last_pix)
          end
        end
      end

    end

  end

end
