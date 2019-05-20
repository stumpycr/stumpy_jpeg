require "./spec_helper"

describe StumpyJPEG do
  # TODO: Write tests

  it "writes a file" do
    false.should eq(false)
  end

  it "reads a file" do
    canvas = StumpyJPEG.read("spec/images/4x4.jpg")

    expected = StumpyCore::Canvas.new(4, 4)
    expected.set(0, 0, StumpyCore::RGBA.from_hex("#000000"))
    expected.set(1, 0, StumpyCore::RGBA.from_hex("#a44e4d"))
    expected.set(2, 0, StumpyCore::RGBA.from_hex("#000000"))
    expected.set(3, 0, StumpyCore::RGBA.from_hex("#a44e4d"))
    expected.set(0, 1, StumpyCore::RGBA.from_hex("#426fee"))
    expected.set(1, 1, StumpyCore::RGBA.from_hex("#000000"))
    expected.set(2, 1, StumpyCore::RGBA.from_hex("#6fc21c"))
    expected.set(3, 1, StumpyCore::RGBA.from_hex("#000000"))
    expected.set(0, 2, StumpyCore::RGBA.from_hex("#426fee"))
    expected.set(1, 2, StumpyCore::RGBA.from_hex("#000002"))
    expected.set(2, 2, StumpyCore::RGBA.from_hex("#6fc21c"))
    expected.set(3, 2, StumpyCore::RGBA.from_hex("#000000"))
    expected.set(0, 3, StumpyCore::RGBA.from_hex("#000000"))
    expected.set(1, 3, StumpyCore::RGBA.from_hex("#a44e4d"))
    expected.set(2, 3, StumpyCore::RGBA.from_hex("#000000"))
    expected.set(3, 3, StumpyCore::RGBA.from_hex("#a44e4d"))

    canvas.should eq(expected)
  end

  it "reads a grayscale file" do
    canvas = StumpyJPEG.read("spec/images/4x4_gray.jpg")

    expected = StumpyCore::Canvas.new(4, 4)
    expected.set(0, 0, StumpyCore::RGBA.from_hex("#000000"))
    expected.set(1, 0, StumpyCore::RGBA.from_hex("#606060"))
    expected.set(2, 0, StumpyCore::RGBA.from_hex("#000000"))
    expected.set(3, 0, StumpyCore::RGBA.from_hex("#606060"))
    expected.set(0, 1, StumpyCore::RGBA.from_hex("#6f6f6f"))
    expected.set(1, 1, StumpyCore::RGBA.from_hex("#000000"))
    expected.set(2, 1, StumpyCore::RGBA.from_hex("#a4a4a4"))
    expected.set(3, 1, StumpyCore::RGBA.from_hex("#000000"))
    expected.set(0, 2, StumpyCore::RGBA.from_hex("#6f6f6f"))
    expected.set(1, 2, StumpyCore::RGBA.from_hex("#000000"))
    expected.set(2, 2, StumpyCore::RGBA.from_hex("#a4a4a4"))
    expected.set(3, 2, StumpyCore::RGBA.from_hex("#000000"))
    expected.set(0, 3, StumpyCore::RGBA.from_hex("#000000"))
    expected.set(1, 3, StumpyCore::RGBA.from_hex("#606060"))
    expected.set(2, 3, StumpyCore::RGBA.from_hex("#000000"))
    expected.set(3, 3, StumpyCore::RGBA.from_hex("#606060"))

    canvas.should eq(expected)
  end

  it "decodes large images" do
    canvas = StumpyJPEG.read("spec/images/stones.jpeg")
  end
    
  it "decodes images with restart markers" do
    canvas = StumpyJPEG.read("spec/images/alpaca.jpg")
  end
end
