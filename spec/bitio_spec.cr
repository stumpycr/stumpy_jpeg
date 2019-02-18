require "./spec_helper"

describe StumpyJPEG::BitReader do
  it "reads a single bit from an io" do
    io = IO::Memory.new("Hello")

    br = StumpyJPEG::BitReader.new(io)
    br.read_bit.should eq(0)
    br.read_bit.should eq(1)
    br.read_bit.should eq(0)
    br.read_bit.should eq(0)
    br.read_bit.should eq(1)
  end

  it "reads multiple bits from an io" do
    io = IO::Memory.new("Hello")

    br = StumpyJPEG::BitReader.new(io)
    br.read_bits(3).should eq(2)
    br.read_bits(1).should eq(0)
    br.read_bits(3).should eq(4)
  end

  it "reads past the first byte from an io" do
    io = IO::Memory.new("Hello")

    br = StumpyJPEG::BitReader.new(io)
    br.read_bits(7)

    br.read_bits(3).should eq(1)
    br.read_bits(3).should eq(4)
  end
end

describe StumpyJPEG::BitWriter do
  it "writes a single bit into an io" do
    io = IO::Memory.new

    bw = StumpyJPEG::BitWriter.new(io)
    bw.write_bit(1)
    bw.write_bit(1)
    bw.write_bit(1)
    bw.write_bit(1)
    bw.write_bit(1)
    bw.write_bit(1)
    bw.write_bit(1)
    bw.write_bit(1)

    io.rewind
    io.read_byte.should eq(255_u8)
  end

  it "writes multiple bits into an io" do
    io = IO::Memory.new

    bw = StumpyJPEG::BitWriter.new(io)
    bw.write_bits(7, 8)

    io.rewind
    io.read_byte.should eq(7_u8)
  end

  it "writes past the first byte into an io" do
    io = IO::Memory.new

    bw = StumpyJPEG::BitWriter.new(io)
    bw.write_bits(7, 7)
    bw.write_bits(128, 9)

    io.rewind
    io.read_byte.should eq(14_u8)
    io.read_byte.should eq(128_u8)
  end
end
