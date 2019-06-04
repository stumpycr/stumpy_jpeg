require "./component"
require "./quantization"
require "./huffman"
require "./markers"

module StumpyJPEG

  abstract class Segment
    getter marker : UInt8

    def initialize(@marker)
    end

    def to_io(io : IO, format : IO::ByteFormat = IO::ByteFormat::SystemEndian)
      raise "ByteFormat must be BigEndian" if format != IO::ByteFormat::BigEndian
      format.encode(Markers::START, io)
      format.encode(marker, io)
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
  end
end
