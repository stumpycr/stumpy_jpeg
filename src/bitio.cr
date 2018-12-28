class BitIO::BitReader
  @rack : UInt8
  @mask : UInt8

  def initialize(@io : IO)
    @rack = 0_u8
    @mask = 0x80_u8
  end

  def read_bit
    if @mask == 0x80
      byte = @io.read_byte
      return nil if !byte

      @rack = byte
    end
    val = @rack & @mask
    @mask >>= 1
    @mask = 0x80 if @mask == 0

    return (val > 0) ? 1 : 0
  end

  def read_bits(count : Int32)
    val = 0
    count.times do
      val <<= 1

      bit = read_bit
      raise "End of file reached" if !bit

      val |= bit
    end
    val
  end
end

class BitIO::BitWriter
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

  def flush(padding_bit : Int32 = 0)
    while mask != 0
      write_bit(padding_bit)
    end
  end
end
