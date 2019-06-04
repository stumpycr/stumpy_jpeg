module StumpyJPEG
  module Upsampler
    def self.upsample(data_units, h, v, max_h, max_v)
      if h == max_h && v == max_v
        OneToOne.upsample(data_units)
      else
        Default.upsample(data_units, h, v, max_h, max_v)
      end
    end
  end
end
