module StumpyJPEG
  class Segment::SOF < Segment
    getter bit_precision : Int32
    getter height : Int32
    getter width : Int32
    getter number_of_components : Int32
    getter components : Array(Component::Definition)

    def initialize(n, @bit_precision, @height, @width, @number_of_components, @components)
      super (Markers::SOF + n)
    end

    def length
      8 + 3 * number_of_components
    end

    def to_s(io : IO)
      super io
      io.write_bytes(length.to_u16, IO::ByteFormat::BigEndian)
      io.write_byte(bit_precision.to_u8)
      io.write_bytes(height.to_u16, IO::ByteFormat::BigEndian)
      io.write_bytes(width.to_u16, IO::ByteFormat::BigEndian)
      io.write_byte(number_of_components.to_u8)
      components.each do |component|
        io << component
      end
    end

    def self.from_io(io : IO)
      length = io.read_bytes(UInt16, IO::ByteFormat::BigEndian)

      bit_precision = io.read_byte.not_nil!.to_i
      height = io.read_bytes(UInt16, IO::ByteFormat::BigEndian).to_i
      width = io.read_bytes(UInt16, IO::ByteFormat::BigEndian).to_i
      number_of_components = io.read_byte.not_nil!.to_i

      components = Array(Component::Definition).new(number_of_components) do |i|
        io.read_bytes(Component::Definition, IO::ByteFormat::BigEndian)
      end

      self.new(0, bit_precision, height, width, number_of_components, components)
    end
  end
end
