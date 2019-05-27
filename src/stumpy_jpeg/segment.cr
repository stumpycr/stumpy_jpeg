require "./component"
require "./quantization"
require "./huffman"
require "./markers"

module StumpyJPEG

  abstract class Segment
    getter marker : UInt8

    def initialize(@marker)
    end

    def to_s(io : IO)
      io.write_byte(Markers::START)
      io.write_byte(marker)
    end
  end

  class SOI < Segment
    def initialize
      super Markers::SOI
    end
  end

  class EOI < Segment
    def initialize
      super Markers::EOI
    end
  end

  class DHT < Segment
    getter tables : Array(Huffman::Table)

    def initialize(@tables)
      super Markers::DHT
    end

    def length
      tables.reduce(2) do |acc, table|
        acc += table.bytesize
      end
    end

    def to_s(io : IO)
      super io
      io.write_bytes(length.to_u16, IO::ByteFormat::BigEndian)
      tables.each do |table|
        # TODO
      end
    end

    def self.from_io(io : IO)
      length = io.read_bytes(UInt16, IO::ByteFormat::BigEndian)
      bytes_read = 2

      tables = [] of Huffman::Table
      while bytes_read < length
        dht = Huffman::Table.from_io(io)
        bytes_read += dht.bytesize
        tables << dht
      end

      DHT.new(tables)
    end
  end

  class DQT < Segment
    getter tables : Array(Quantization::Table)

    def initialize(@tables)
      super Markers::DQT
    end

    def length
      tables.reduce(2) do |acc, table|
        acc += table.bytesize
      end
    end

    def to_s(io : IO)
      super io
      io.write_bytes(length.to_u16, IO::ByteFormat::BigEndian)
      # TODO: Write tables
    end

    def self.from_io(io : IO)
      length = io.read_bytes(UInt16, IO::ByteFormat::BigEndian)
      bytes_read = 2

      tables = [] of Quantization::Table
      while bytes_read < length
        dqt = Quantization::Table.from_io(io)
        bytes_read += dqt.bytesize
        tables << dqt
      end

      self.new(tables)
    end
  end

  class DRI < Segment
    getter interval : Int32

    def initialize(@interval)
      super Markers::DRI
    end

    def length
      4
    end

    def to_s(io : IO)
      super io
      io.write_bytes(length.to_u16, IO::ByteFormat::BigEndian)
      io.write_bytes(interval.to_u16, IO::ByteFormat::BigEndian)
    end

    def self.from_io(io : IO)
      io.read_bytes(UInt16, IO::ByteFormat::BigEndian)
      interval = io.read_bytes(UInt16, IO::ByteFormat::BigEndian).to_i

      self.new(interval)
    end
  end

  class SOF < Segment
    getter bit_precision : Int32
    getter height : Int32
    getter width : Int32
    getter number_of_components : Int32
    getter components : Array(Component)

    def initialize(type, @bit_precision, @height, @width, @number_of_components, @components)
      super (Markers::SOF + type)
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

      components = Array(Component).new(number_of_components) do |i|
        Component.from_io(io)
      end

      self.new(0, bit_precision, height, width, number_of_components, components)
    end
  end

  class SOS < Segment
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

  class APP < Segment
    getter bytes : Bytes

    def initialize(n, @bytes)
      super (Markers::APP + n)
    end

    def self.build_jfif_header
      io = IO::Memory.new
      io.write("JFIF".to_slice)
      io.write_byte(0_u8)
      io.write_byte(1_u8)
      io.write_byte(2_u8)
      io.write_byte(0_u8)
      io.write_bytes(1_u16, IO::ByteFormat::BigEndian)
      io.write_bytes(1_u16, IO::ByteFormat::BigEndian)
      io.write_byte(0_u8)
      io.write_byte(0_u8)
      io.rewind

      bytes = Bytes.new(14 + 3 * 0 * 0)
      io.read(bytes)

      self.new(bytes, 0)
    end

    def jfif?
      data = IO::Memory.new(bytes)
      data.gets('\0', chomp: true) == "JFIF"
    end

    def length
      2 + bytes.size
    end

    def to_s(io : IO)
      super io
      io.write_bytes(length.to_u16, IO::ByteFormat::BigEndian)
      io.write(bytes)
    end

    def self.from_io(io : IO)
      length = io.read_bytes(UInt16, IO::ByteFormat::BigEndian)
      bytes_read = 2

      bytes = Bytes.new(length - bytes_read)
      io.read(bytes)

      self.new(0, bytes)
    end
  end

  class COM < Segment
    getter text : String

    def initialize(@text)
      super Markers::COM
    end

    def length
      3 + text.bytesize
    end

    def to_s(io : IO)
      super io
      io.write_bytes(length.to_u16, IO::ByteFormat::BigEndian)
      io.write(text.to_slice)
      io.write_byte(0_u8)
    end

    def self.from_io(io)
      length = io.read_bytes(UInt16, IO::ByteFormat::BigEndian)
      text = io.gets(length - 2).not_nil!.chomp('\0')
      self.new(text)
    end
  end
end