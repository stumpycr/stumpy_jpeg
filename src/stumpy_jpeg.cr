require "./canvas_ext"
require "./transform"
require "./quantization"
require "./huffman"
require "./bitio"

require "./standards"

require "./markers"
require "./decoder"

# TODO: Write documentation for `StumpyJPEG`
module StumpyJPEG
  VERSION = "0.1.0"

  def self.write(canvas : StumpyCore::Canvas, file : String)
    File.open(file) do |io|
      write(canvas, io)
    end
  end

  # TODO: Finish this
  def self.write(canvas : StumpyCore::Canvas, io : IO)
    # TODO: Move these to params? Calculate quality somewhere else, use h/v values instead?
    chroma_subsampling = {4, 2, 0}
    block_size = 8
    quality = 1

    # Calculate sampling
    # TODO: Change this
    j, a, b = chroma_subsampling
    valid_a = [1, 2, 4]
    valid_b = [0, 1, 2, 4]
    raise "Unsupported chroma subsampling" if j != 4 || !valid_a.includes?(a) || !valid_b.includes?(b)
    luma_h = 1
    luma_v = 1
    chroma_h = j / a
    chroma_v = 2 / ((a > 0).to_unsafe + (b > 0).to_unsafe)

    lqt = (Quantization::LUMA * quality).map {|e| e.round }
    cqt = (Quantization::CHROMA * quality).map {|e| e.round }
    dct = Transformation::DCT.new(block_size)



  end

  def self.read(file : String)
    File.open(file) do |io|
      read(io)
    end
  end

  def self.read(io : IO)
    decoder = Decoder.new
    decoder.decode(io)
  end
end
