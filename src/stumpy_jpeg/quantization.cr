require "matrix"
require "./standards"

module StumpyJPEG
  module Quantization
    class Table
      getter precision : Int32
      getter table_id : Int32
      getter elements : Array(Int32)

      def initialize(@precision, @table_id, matrix : Matrix(Int32))
        @elements = matrix.to_a
      end

      def initialize(@precision, @table_id, @elements)
      end

      def bytesize
        @precision == 0 ? 65 : 129
      end

      def quantize(matrix)
        matrix.map do |e, i, r, c|
          (e.to_f / elements[i]).round.to_i
        end
      end

      def dequantize(matrix)
        matrix.map do |e, i, r, c|
          (e * elements[i]).round.to_i
        end
      end

      def to_s(io : IO)
        io.write_byte(((precision << 4) | table_id).to_u8)
        elements.each do |elem|
          if precision == 0
            io.write_byte(elem.to_u8)
          else
            io.write_bytes(elem.to_u16, IO::ByteFormat::BigEndian)
          end
        end
      end

      def self.from_io(io)
        table = io.read_byte.not_nil!.to_i
        precision = table >> 4
        table_id = table & 0x0F

        elements = Array(Int32).new(64, 0)
        ZIGZAG.each_with_index do |v, i|
          if precision == 0
            elements[v] = io.read_byte.not_nil!.to_i
          else
            elements[v] = io.read_bytes(UInt16, IO::ByteFormat::BigEndian).to_i
          end
        end
        self.new(precision, table_id, elements)
      end
    end
  end
end
