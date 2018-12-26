class Encoding::RLE
end

class Encoding::Huffman
  @encoding_map : Hash(UInt8, Tuple(Int32, Int32))
  @decoding_map : Hash(Tuple(Int32, Int32), UInt8)

  def initialize(bits, huffval)
    huffsize = generate_size_table(bits)
    huffcode = generate_code_table(huffsize)
    map = order_codes(huffsize, huffcode, huffval)
    @encoding_map = map
    @decoding_map = map.invert
  end

  def decode(code, size)
    @decoding_map[{code, size}]?
  end

  def encode(byte)
    @encoding_map[byte]
  end

  private def generate_size_table(bits)
    huffsize = [] of Int32

    16.times do |i|
      1.upto(bits[i]) do
        huffsize <<  i + 1
      end
    end

    huffsize << 0
    huffsize
  end

  private def generate_code_table(huffsize)
    huffcode = [] of Int32

    k = 0
    code = 0
    size = huffsize[0]

    loop do
      loop do
        huffcode << code
        code += 1
        k += 1
        break if huffsize[k] != size
      end
      break if huffsize[k] == 0
      loop do
        code <<= 1
        size += 1
        break if huffsize[k] == size
      end
    end

    huffcode
  end

  private def order_codes(huffsize, huffcode, huffval)
    map = {} of UInt8 => Tuple(Int32, Int32)
    huffval.each_with_index do |v, i|
      map[v.to_u8] = {huffcode[i], huffsize[i]}
    end
    map
  end

end
