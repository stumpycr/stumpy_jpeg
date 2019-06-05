module StumpyJPEG
  class Segment::SOS < Segment
    getter number_of_components : Int32
    getter selectors : Array(Component::Selector)
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

    def to_s(io : IO)
      super io
      io.write_bytes(length.to_u16, IO::ByteFormat::BigEndian)
      io.write_byte(number_of_components.to_u8)
      components.each do |component|
        io << component
      end
      io.write_byte(spectral_start.to_u8)
      io.write_byte(spectral_end.to_u8)
      io.write_byte(((approx_high << 4) | approx_low).to_8)
    end

    def self.from_io(io)
      length = io.read_bytes(UInt16, IO::ByteFormat::BigEndian)
      number_of_components = io.read_byte.not_nil!.to_i
      selectors = Array(Component::Selector).new(number_of_components) do
        io.read_bytes(Component::Selector, IO::ByteFormat::BigEndian)
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
