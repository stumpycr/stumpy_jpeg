module StumpyJPEG
  class Segment::SOF < Segment
    getter bit_precision : Int32
    getter height : Int32
    getter width : Int32
    getter number_of_components : Int32
    getter components : Array(Component)

    def initialize(n, @bit_precision, @height, @width, @number_of_components, @components)
      super (Markers::SOF + n)
    end

    def length
      8 + 3 * number_of_components
    end

    def to_io(io : IO, format : IO::ByteFormat = IO::ByteFormat::SystemEndian)
      super(io, format)
      format.encode(length.to_u16, io)
      format.encode(bit_precision.to_u8, io)
      format.encode(height.to_u16, io)
      format.encode(width.to_u16, io)
      format.encode(number_of_components.to_u8, io)
      components.each do |component|
        io.write_bytes(component, format)
      end
    end

    def self.from_io(io : IO)
      length = io.read_bytes(UInt16, IO::ByteFormat::BigEndian)

      bit_precision = io.read_byte.not_nil!.to_i
      height = io.read_bytes(UInt16, IO::ByteFormat::BigEndian).to_i
      width = io.read_bytes(UInt16, IO::ByteFormat::BigEndian).to_i
      number_of_components = io.read_byte.not_nil!.to_i

      components = Array(Component).new(number_of_components) do |i|
        Component.from_io(io)
      end

      self.new(0, bit_precision, height, width, number_of_components, components)
    end
  end
end
