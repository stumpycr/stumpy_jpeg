require "./spec_helper"

describe StumpyJPEG::Huffman::Table do
  bits = [0x00, 0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
  huffval = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B]

  h_table = StumpyJPEG::Huffman::Table.new(0, 0, bits, huffval)

  it "returns a code, size pair when encoding a given byte" do
    h_table.encode(0x00_u8).should eq({0, 2})
    h_table.encode(0x01_u8).should eq({2, 3})
  end

  it "returns a byte when decoding a given code, size pair" do
    h_table.decode(0, 2).should eq(0x00_u8)
    h_table.decode(2, 3).should eq(0x01_u8)
    h_table.decode(0, 1).should eq(nil)
  end
end
