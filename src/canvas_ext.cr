require "stumpy_core"

class StumpyCore::Canvas
  
  def blocks_of(size : Int32)
    blocks = [] of StumpyCore::Canvas
    blocks_of(size) do |block|
      blocks << block
    end
    blocks
  end

  def blocks_of(size : Int32, &block)
    (0...@height).step(size) do |y|
      (0...@width).step(size) do |x|
        canvas = StumpyCore::Canvas.new(size, size)

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

end
