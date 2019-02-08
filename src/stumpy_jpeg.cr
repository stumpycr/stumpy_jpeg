require "./canvas_ext"
require "./transform"
require "./quantization"
require "./huffman"
require "./bitio"

require "./standards"

require "./segments"
require "./decoder"

# TODO: Write documentation for `StumpyJPEG`
module StumpyJPEG
  VERSION = "0.1.0"

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
