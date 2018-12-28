require "matrix"

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
        bw = BitIO::BitWriter.new(io)
        bw.write_bits(precision, 4)
        bw.write_bits(table_id, 4)

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

        elements = Array(Int32).new(64) do
          if precision == 0
            io.read_byte.not_nil!.to_i
          else
            io.read_bytes(UInt16, IO::ByteFormat::BigEndian).to_i
          end
        end

        self.new(precision, table_id, elements)
      end

    end

  end

end