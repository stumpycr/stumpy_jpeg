class StumpyJPEG::BitReader
  @rack : UInt8
  @mask : UInt8

  def initialize(@io : IO)
    @rack = 0_u8
    @mask = 0x80_u8
  end

  def read_bit
    if @mask == 0x80
      return nil if !prepare_next_byte
    end
    val = @rack & @mask
    @mask >>= 1
    @mask = 0x80 if @mask == 0

    return (val > 0) ? 1 : 0
  end

  def read_bits(count : Int)
    val = 0
    count.times do
      val <<= 1

      bit = read_bit
      raise IO::EOFError.new if !bit

      val |= bit
    end
    val
  end

  def read_remaining_bits
    val = 0
    while @mask != 0x80
      val <<= 1

      bit = read_bit
      raise IO::EOFError.new if !bit

      val |= bit
    end
    val
  end

  def skip_remaining_bits
    @mask = 0x80
  end

  def read_restart_marker
    skip_remaining_bits
    if (byte = @io.read_byte) && (marker = @io.read_byte)
      raise "Expecting restart marker" if byte != Markers::START
      marker
    else
      raise IO::EOFError.new
    end
  end

  private def prepare_next_byte
    if byte = @io.read_byte
      if byte == Markers::START
        raise "Unexpected marker found inside entropy encoded data" if @io.read_byte != Markers::SKIP
      end
      @rack = byte
    end
  end
end

class StumpyJPEG::BitWriter
  @rack : UInt8
  @mask : UInt8

  def initialize(@io : IO)
    @rack = 0_u8
    @mask = 0x80_u8
  end

  def write_bit(bit : Int32)
    @rack |= @mask if bit > 0
    @mask >>= 1

    if @mask == 0
      @io.write_byte(@rack)

      @rack = 0_u8
      @mask = 0x80_u8
    end
  end

  def write_bits(number : Int32, bit_count : Int32)
    mask = 1 << (bit_count - 1)
    while mask != 0
      write_bit(mask & number)
      mask >>= 1
    end
  end

  def flush(padding_bit : Int32 = 1)
    while mask != 0
      write_bit(padding_bit)
    end
  end
end
