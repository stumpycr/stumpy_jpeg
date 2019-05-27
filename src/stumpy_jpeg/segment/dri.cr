module StumpyJPEG
  class Segment::DRI < Segment
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
end
