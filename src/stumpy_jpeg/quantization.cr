require "matrix"
require "./standards"

module StumpyJPEG
  module Quantization

    # Scaling factors for quantization
    # From "Compressed Image File Formats: JPEG, PNG, GIF, XBM, BMP" (1999)
    # 
    # S(i, j) = 0.125 * F(i) * F(j)
    # 
    # F(0) = 1
    # F(x) =  1 / (Math.sqrt(2) * Math.cos(x * Math::PI / 16.0))
    SCALING_FACTORS = [
      0.125,               0.09011997775086848, 0.09567085809127245, 0.10630376184590705, 0.125,               0.1590948225716042,  0.23096988312782163, 0.4530637231764438, 
     	0.09011997775086848, 0.06497288311853625, 0.06897484482073575, 0.07664074121909412, 0.09011997775086848, 0.11470097496345072, 0.16652000582879983, 0.326640741219094, 
     	0.09567085809127245, 0.06897484482073575, 0.07322330470336312, 0.08136137691302557, 0.09567085809127245, 0.12176590554643292, 0.17677669529663684, 0.34675996133053677, 
     	0.10630376184590705, 0.07664074121909412, 0.08136137691302557, 0.09040391826073059, 0.10630376184590705, 0.1352990250365492,  0.19642373959677548, 0.3852990250365491, 
     	0.125,               0.09011997775086848, 0.09567085809127245, 0.10630376184590705, 0.125,               0.1590948225716042,  0.23096988312782163, 0.4530637231764438, 
     	0.1590948225716042,  0.11470097496345072, 0.12176590554643292, 0.1352990250365492,  0.1590948225716042,  0.2024893005527218,  0.29396890060483954, 0.5766407412190938, 
     	0.23096988312782163, 0.16652000582879983, 0.17677669529663684, 0.19642373959677548, 0.23096988312782163, 0.29396890060483954, 0.42677669529663664, 0.8371526015321517, 
      0.4530637231764438,  0.326640741219094,   0.34675996133053677, 0.3852990250365491,  0.4530637231764438,  0.5766407412190938,  0.8371526015321517,  1.6421338980680102 
    ]

    class Table
      getter precision : Int32
      getter table_id : Int32
      getter elements : Array(Int32)
      getter scaled_elements : Array(Float64)

      def initialize(@precision, @table_id, @elements)
        @scaled_elements = SCALING_FACTORS.map_with_index do |sf, i|
          elements[i] * sf
        end
      end

      def bytesize
        @precision == 0 ? 65 : 129
      end

      def self.from_io(io)
        table = io.read_byte.not_nil!.to_i
        precision = table >> 4
        table_id = table & 0x0F

        elements = Array.new(64, 0)
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
