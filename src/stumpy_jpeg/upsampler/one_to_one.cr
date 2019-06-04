module StumpyJPEG
  module Upsampler::OneToOne
    def self.upsample(data_units)
      data_units.reduce({} of Tuple(Int32, Int32) => Matrix(Int32)) do |memo, (coords, du)|
        memo[coords] = du
        memo
      end
    end
  end
end
