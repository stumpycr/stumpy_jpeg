require "matrix"
require "./standards"

module StumpyJPEG

  class Component
    getter component_id : Int32
    getter h : Int32
    getter v : Int32
    getter dqt_table_id : Int32

    getter last_dc_value : Int32

    getter data_units : Hash(Tuple(Int32, Int32), Matrix(Int32))
    getter upsampled_data : Hash(Tuple(Int32, Int32), Matrix(Int32))

    def initialize(@component_id, @h, @v, @dqt_table_id)
      @last_dc_value = 0
      @data_units = {} of Tuple(Int32, Int32) => Matrix(Int32)
      @upsampled_data = {} of Tuple(Int32, Int32) => Matrix(Int32)
    end

    def upsample(max_h, max_v)
      keys = data_units.each do |coords, du|
        du_x, du_y = coords

        (0...max_v).each do |y|
          (0...max_h).each do |x|
            dupe_coords = {du_x + x, du_y + y}
            upsampled_data[dupe_coords] = du
          end
        end
      end
    end

    def decode_sequential(bit_reader, dc_table, ac_table, dqt)
      coef = Array.new(64, 0)
      decode_sequential_dc(bit_reader, dc_table, coef)
      decode_sequential_ac(bit_reader, ac_table, coef)
      Transformation.fast_inverse_transform(coef, dqt)
    end

    def decode_sequential_dc(bit_reader, dc_table, coef)
      magnitude = dc_table.decode_from_io(bit_reader)
      @last_dc_value += read_n_extend(bit_reader, magnitude)
      coef[ZIGZAG[0]] = @last_dc_value
    end

    def decode_sequential_ac(bit_reader, ac_table, coef)
      i = 1
      while i < 64
        byte = ac_table.decode_from_io(bit_reader)

        case
        when byte == 0x00 then break
        when byte == 0xF0
          i += 16
          next
        end

        zero_run = (byte & 0xF0) >> 4
        magnitude = byte & 0x0F

        i += zero_run
        coef[ZIGZAG[i]] = read_n_extend(bit_reader, magnitude)
        i += 1
      end
    end
    
    private def read_n_extend(bit_reader, magnitude)
      adds = bit_reader.read_bits(magnitude)
      extend_coefficient(adds, magnitude)
    end

    private def extend_coefficient(bits, magnitude)
      vt = 1 << (magnitude - 1)
      return bits + 1 + (-1 << magnitude) if bits < vt
      return bits
    end

    def reset_last_dc_value
      @last_dc_value = 0
    end

    def to_s(io : IO)
      io.write_byte(component_id)
      io.write_byte(((h << 4) | v).to_u8)
      io.write_byte(dqt_table_id)
    end

    def self.from_io(io)
      component_id = io.read_byte.not_nil!.to_i

      freq = io.read_byte.not_nil!.to_i
      h = freq >> 4
      v = freq & 0x0F

      dqt_table_id = io.read_byte.not_nil!.to_i

      self.new(component_id, h, v, dqt_table_id)
    end
  end

  class ComponentSelector
    getter component_id : Int32
    getter dc_table_id : Int32
    getter ac_table_id : Int32

    def initialize(@component_id, @dc_table_id, @ac_table_id)
    end

    def to_s(io : IO)
      io.write_byte(component_id)
      io.write_byte(((dc_table_id << 4) | ac_table_id).to_u8)
    end

    def self.from_io(io)
      component_id = io.read_byte.not_nil!.to_i

      ids = io.read_byte.not_nil!.to_i
      dc_table_id = ids >> 4
      ac_table_id = ids & 0x0F

      self.new(component_id, dc_table_id, ac_table_id)
    end
  end
end