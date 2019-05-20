module StumpyJPEG
  class Datastream
    def initialize(@io : IO)
    end

    def read
      read_start_of_image
      while marker = read_marker
        break if marker == Markers::EOI
        yield marker, @io
      end
    end

    def read_marker
      read_marker_start
      read_marker_byte  
    end

    private def read_marker_start
      start = @io.read_byte
      raise IO::EOFError.new if !start
      raise "Expected a marker but got #{start} at #{@io.pos}" if start != Markers::START
    end

    private def read_marker_byte
      byte = @io.read_byte
      raise IO::EOFError.new if !byte
      byte
    end

    private def read_start_of_image
      raise "Not a JPEG file" if @io.read_byte != Markers::START || @io.read_byte != Markers::SOI
    end
  end
end