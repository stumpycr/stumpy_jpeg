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
