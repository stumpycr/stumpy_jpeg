require "./spec_helper"

describe StumpyCore::Canvas do
  it "returns blocks of size" do
    canvas = StumpyCore::Canvas.new(8, 8)
    blocks = canvas.blocks_of(4)

    expected = StumpyCore::Canvas.new(4, 4)

    blocks.size.should eq(4)
    blocks.first.should eq(expected)
  end

  it "returns blocks filling missing with repetitions" do
    canvas = StumpyCore::Canvas.new(3, 3)
    blocks = canvas.blocks_of(4)

    expected = StumpyCore::Canvas.new(4, 4)

    blocks.size.should eq(1)
    blocks.first.should eq(expected)
  end

  it "yields blocks one at a time" do
    canvas = StumpyCore::Canvas.new(8, 8)

    yielded = 0
    canvas.blocks_of(4) do |block|
      yielded += 1
      block.class.should eq(StumpyCore::Canvas)
    end

    yielded.should eq(4)
  end
end
