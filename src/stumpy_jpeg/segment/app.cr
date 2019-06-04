module StumpyJPEG
  class Segment::APP < Segment
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

      self.new(0, bytes)
    end

    def jfif?
      data = IO::Memory.new(bytes)
      data.gets('\0', chomp: true) == "JFIF"
    end

    def length
      2 + bytes.size
    end

    def to_io(io : IO, format : IO::ByteFormat = IO::ByteFormat::SystemEndian)
      super(io, format)
      format.encode(length, io)
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
end
