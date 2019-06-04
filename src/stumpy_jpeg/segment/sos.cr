module StumpyJPEG
  class Segment::SOS < Segment
    getter number_of_components : Int32
    getter selectors : Array(ComponentSelector)
    getter spectral_start : Int32
    getter spectral_end : Int32
    getter approx_high : Int32
    getter approx_low : Int32

    def initialize(@number_of_components, @selectors, @spectral_start, @spectral_end, @approx_high, @approx_low)
      super Markers::SOS
    end

    def length
      6 + 2 * number_of_components
    end

    def to_io(io : IO, format : IO::ByteFormat = IO::ByteFormat::SystemEndian)
      super(io, format)
      format.encode(length.to_u16, io)
      format.encode(number_of_components.to_u8, io)
      selectors.each do |selector|
        io.write_bytes(selector, format)
      end
      format.encode(spectral_start.to_u8, io)
      format.encode(spectral_end.to_u8, io)
      format.encode(((approx_high << 4) | approx_low).to_8, io)
    end

    def self.from_io(io)
      length = io.read_bytes(UInt16, IO::ByteFormat::BigEndian)
      number_of_components = io.read_byte.not_nil!.to_i
      selectors = [] of ComponentSelector
      number_of_components.times do
        selectors << ComponentSelector.from_io(io)
      end
      spectral_start = io.read_byte.not_nil!.to_i
      spectral_end = io.read_byte.not_nil!.to_i
      approx = io.read_byte.not_nil!.to_i
      approx_high = approx >> 4
      approx_low = approx & 0x0F

      self.new(number_of_components, selectors, spectral_start, spectral_end, approx_high, approx_low)
    end
  end
end
