require "matrix"
require "./standards"

module StumpyJPEG

  class Component
    getter component_id : Int32
    getter h : Int32
    getter v : Int32
    getter dqt_table_id : Int32

    getter last_dc_value : Int32
    getter end_of_band_run : Int32

    getter coefficients : Hash(Tuple(Int32, Int32), Array(Int32))
    getter data_units : Hash(Tuple(Int32, Int32), Matrix(Int32))
    getter upsampled_data : Hash(Tuple(Int32, Int32), Matrix(Int32))

    def initialize(@component_id, @h, @v, @dqt_table_id)
      @last_dc_value = 0
      @end_of_band_run = 0
      @coefficients = {} of Tuple(Int32, Int32) => Array(Int32)
      @data_units = {} of Tuple(Int32, Int32) => Matrix(Int32)
      @upsampled_data = {} of Tuple(Int32, Int32) => Matrix(Int32)
    end

    def idct_transform(dqt)
      coefficients.each do |coords, coef|
        data_units[coords] = Transformation.fast_inverse_transform(coef, dqt)
      end
    end

    def upsample(max_h, max_v)
      if h == max_h && v == max_v
        data_units.each do |coords, du|
          upsampled_data[coords] = du
        end
      else
        h_sampling = max_h // h
        v_sampling = max_v // v

        h_size = 8 // h_sampling
        v_size = 8 // v_sampling
        
        data_units.each do |coords, du|
          du_x, du_y = coords

          new_du_x = du_x * h_sampling
          new_du_y = du_y * v_sampling
          
          v_sampling.times do |y|
            h_sampling.times do |x|
              new_coords = {new_du_x + x, new_du_y + y}

              new_du = Matrix.new(8, 8) do |l, r, c|
                du[r // v_sampling + v_size * y, c // h_sampling + h_size * x]
              end

              upsampled_data[new_coords] = new_du
            end
          end
        end
      end
    end

    def decode_sequential(bit_reader, dc_table, ac_table, du_row, du_col)
      coef = Array.new(64, 0)
      decode_sequential_dc(bit_reader, dc_table, coef)
      decode_sequential_ac(bit_reader, ac_table, coef)
      coefficients[{du_col, du_row}] = coef
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

    def decode_progressive_dc_first(bit_reader, dc_table, approx, du_row, du_col)
      coef = coefficients[{du_col, du_row}]? || Array.new(64, 0)
      magnitude = dc_table.decode_from_io(bit_reader)
      @last_dc_value += read_n_extend(bit_reader, magnitude)
      coef[ZIGZAG[0]] = @last_dc_value << approx
      coefficients[{du_col, du_row}] = coef
    end

    def decode_progressive_dc_refine(bit_reader, approx, du_row, du_col)
      coef = coefficients[{du_col, du_row}]
      bit = bit_reader.read_bits(1)
      coef[ZIGZAG[0]] = coef[ZIGZAG[0]] | (bit << approx)
    end

    def decode_progressive_ac_first(bit_reader, ac_table, s_start, s_end, approx, du_row, du_col)
      coef = coefficients[{du_col, du_row}]

      if @end_of_band_run > 0
        @end_of_band_run -= 1
        return
      end

      i = s_start
      while i <= s_end
        byte = ac_table.decode_from_io(bit_reader)
        
        hi = byte >> 4
        lo = byte & 0x0F

        if lo == 0
          if hi == 0xF
            i += 16
          else
            @end_of_band_run = (1 << hi) - 1
            @end_of_band_run += bit_reader.read_bits(hi) if hi > 0
            break
          end
        else
          i += hi

          break if i > s_end

          coef[ZIGZAG[i]] = read_n_extend(bit_reader, lo) << approx
          i += 1
        end
      end
    end

    def decode_progressive_ac_refine(bit_reader, ac_table, s_start, s_end, approx, du_row, du_col)
      coef = coefficients[{du_col, du_row}]

      if @end_of_band_run > 0
        refine_ac_non_zeroes(bit_reader, coef, s_start, s_end, 64, approx)
        @end_of_band_run -= 1
        return
      end
      
      i = s_start
      while i <= s_end
        byte = ac_table.decode_from_io(bit_reader)

        hi = byte >> 4
        lo = byte & 0x0F

        zero_run = hi
        new_val = 0
        
        case lo
        when 0
          if hi == 0x0F
          else
            @end_of_band_run = (1 << hi) - 1
            @end_of_band_run += bit_reader.read_bits(hi) if hi > 0
            zero_run = 64
          end
        when 1
          if bit_reader.read_bits(1) != 0
            new_val = (1 << approx)
          else
            new_val = (-1 << approx)
          end
        else
          raise "Invalid huffman encoded value for ac scan"
        end

        i = refine_ac_non_zeroes(bit_reader, coef, i, s_end, zero_run, approx)
        coef[ZIGZAG[i]] = new_val if new_val != 0
        i += 1
      end
    end
    
    private def refine_ac_non_zeroes(bit_reader, coef, start, stop, zero_run, approx)
      (start..stop).each do |i|
        pos = ZIGZAG[i]
        if coef[pos] != 0
          refine_ac_value(bit_reader, coef, pos, approx)
        else
          return i if zero_run == 0
          zero_run -= 1
        end
      end
      return stop
    end

    private def refine_ac_value(bit_reader, coef, pos, approx)
      case
      when coef[pos] > 0
        bit = bit_reader.read_bits(1)
        if bit != 0
          coef[pos] += (1 << approx)
        end
      when coef[pos] < 0
        bit = bit_reader.read_bits(1)
        if bit != 0
          coef[pos] += (-1 << approx)
        end
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

    def reset_end_of_band
      @end_of_band_run = 0
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