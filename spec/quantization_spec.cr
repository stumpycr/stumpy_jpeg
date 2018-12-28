require "./spec_helper"

describe StumpyJPEG::Quantization::Table do

  elems = Matrix.new(8, 8) { |i| i + 1 }
  dqt = StumpyJPEG::Quantization::Table.new(0, 0, elems)

  it "quantizes correctly" do
    matrix = Matrix.new(8, 8) { |i| i + 1 }
    expected = Matrix.new(8, 8) { 1 }

    dqt.quantize(matrix).should eq(expected)
  end

  it "dequantizes correctly" do
    matrix = Matrix.new(8, 8) { 1 }
    expected = Matrix.new(8, 8) { |i| i + 1 }

    dqt.dequantize(matrix).should eq(expected)
  end

end
