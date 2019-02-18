module StumpyJPEG
  class Datastream
    def initialize(@io : IO)
      @buffer_marker = nil.as(UInt8?)
    end

    def read
      raise "Not a JPEG file" if @io.read_byte != Markers::START || @io.read_byte != Markers::SOI

      while marker = read_marker
        break if marker == Markers::EOI
        yield marker, @io
      end
    end

    def read_marker
      if marker = @buffer_marker
        @buffer_marker = nil
        marker
      else
        read_marker_start
        read_marker_byte  
      end
    end

    private def read_marker_start
      start = @io.read_byte
      raise IO::EOFError.new if !start
      raise "Expected a marker but got #{start}" if start != Markers::START
    end

    private def read_marker_byte
      byte = @io.read_byte
      raise IO::EOFError.new if !byte
      byte
    end

  end
end