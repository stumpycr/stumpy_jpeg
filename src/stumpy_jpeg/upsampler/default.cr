module StumpyJPEG
  module Upsampler::Default
    def self.upsample(data_units, h, v, max_h, max_v)
      h_sampling = max_h // h
      v_sampling = max_v // v

      h_size = 8 // h_sampling
      v_size = 8 // v_sampling

      data_units.reduce({} of Tuple(Int32, Int32) => Matrix(Int32)) do |memo, (coords, du)|
        du_x, du_y = coords

        new_du_x = du_x * h_sampling
        new_du_y = du_y * v_sampling

        v_sampling.times do |y|
          h_sampling.times do |x|
            new_coords = {new_du_x + x, new_du_y + y}

            new_du = Matrix.new(8, 8) do |l, r, c|
              du[r // v_sampling + v_size * y, c // h_sampling + h_size * x]
            end

            memo[new_coords] = new_du
          end
        end
        memo
      end
    end
  end
end
