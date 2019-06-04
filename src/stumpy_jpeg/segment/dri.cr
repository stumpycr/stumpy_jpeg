module StumpyJPEG
  class Segment::DRI < Segment
    getter interval : Int32

    def initialize(@interval)
      super Markers::DRI
    end

    def length
      4
    end

    def to_io(io : IO, format : IO::ByteFormat = IO::ByteFormat::SystemEndian)
      super(io, format)
      format.encode(length.to_u16, io)
      format.encode(interval.to_u16, io)
    end

    def self.from_io(io : IO)
      io.read_bytes(UInt16, IO::ByteFormat::BigEndian)
      interval = io.read_bytes(UInt16, IO::ByteFormat::BigEndian).to_i

      self.new(interval)
    end
  end
end
