module StumpyJPEG
  module Huffman
    class Table
      getter table_class : Int32
      getter table_id : Int32
      getter bits : Array(Int32)
      getter huffval : Array(Int32)
      @encoding_map : Hash(UInt8, Tuple(Int32, Int32))
      @decoding_map : Hash(Tuple(Int32, Int32), UInt8)

      def initialize(@table_class, @table_id, @bits, @huffval)
        huffsize = generate_size_table(bits)
        huffcode = generate_code_table(huffsize)
        map = order_codes(huffsize, huffcode, huffval)
        @encoding_map = map
        @decoding_map = map.invert
      end

      def decode(code, size)
        @decoding_map[{code, size}]?
      end

      def decode_from_io(bit_reader)
        size = 0
        code = 0
        byte = 0_u8
        loop do
          size += 1
          code <<= 1
          code |= bit_reader.read_bits(1)
          if v = decode(code, size)
            byte = v
            break
          end
        end
        byte
      end

      def encode(byte)
        @encoding_map[byte]
      end

      def bytesize
        17 + @encoding_map.size
      end

      def to_io(io : IO, format : IO::ByteFormat = IO::ByteFormat::SystemEndian)
        raise "ByteFormat must be BigEndian" if format != IO::ByteFormat::BigEndian
        format.encode(((table_class << 4) | table_id).to_u8, io)
        bits.each do |bit|
          format.encode(bit.to_u8, io)
        end
        huffval.each do |huff|
          format.encode(huff.to_u8, io)
        end
      end

      def self.from_io(io)
        table = io.read_byte.not_nil!.to_i
        table_class = table >> 4
        table_id = table & 0x0F

        bits = Array(Int32).new(16) do
          io.read_byte.not_nil!.to_i
        end

        huffval = Array(Int32).new(bits.sum) do
          io.read_byte.not_nil!.to_i
        end

        self.new(table_class, table_id, bits, huffval)
      end

      private def generate_size_table(bits)
        huffsize = [] of Int32

        16.times do |i|
          1.upto(bits[i]) do
            huffsize << i + 1
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

      private def order_codes(huffsize, huffcode, huffvals)
        map = Hash(UInt8, Tuple(Int32, Int32)).new(huffvals.size) { raise IndexError.new }
        huffvals.each_with_index do |v, i|
          c = huffcode[i]
          s = huffsize[i]
          map[v.to_u8] = {c, s}
        end
        map
      end
    end
  end
end
