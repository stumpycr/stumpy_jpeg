require "matrix"
require "./standards"

module StumpyJPEG

  class Component
    getter definition : Definition

    getter sampling_h : Int32
    getter sampling_v : Int32

    getter non_interleaved_mcu_rows : Int32
    getter non_interleaved_mcu_cols : Int32

    getter data_units : Hash(Tuple(Int32, Int32), Matrix(Int32))
    getter upsampled_data : Hash(Tuple(Int32, Int32), Matrix(Int32))
    getter raw_coefficients : Hash(Tuple(Int32, Int32), Array(Int32))

    getter last_dc_value : Int32 = 0
    getter end_of_band_run : Int32 = 0

    delegate component_id, to: @definition
    delegate dqt_table_id, to: @definition
    delegate h, to: @definition
    delegate v, to: @definition

    def initialize(@definition, max_h, max_v, image_width, image_height)
      @sampling_h = max_h // h
      @sampling_v = max_v // v

      @raw_coefficients = {} of Tuple(Int32, Int32) => Array(Int32)
      @data_units = {} of Tuple(Int32, Int32) => Matrix(Int32)
      @upsampled_data = {} of Tuple(Int32, Int32) => Matrix(Int32)

      cols, rows = non_interleaved_mcu_dimensions(image_width, image_height)

      @non_interleaved_mcu_cols = cols
      @non_interleaved_mcu_rows = rows
    end

    private def non_interleaved_mcu_dimensions(image_width, image_height)
      pixels_x = 8 * sampling_h
      pixels_y = 8 * sampling_v
      cols = (image_width + pixels_x - 1) // pixels_x
      rows = (image_height + pixels_y - 1) // pixels_y
      {cols, rows}
    end

    def idct_transform(dqt)
      raw_coefficients.each do |coords, coef|
        data_units[coords] = Transformation.fast_inverse_transform(coef, dqt)
      end
    end

    def upsample_one_to_one
      data_units.each do |coords, du|
        upsampled_data[coords] = du
      end
    end

    def upsample
      h_size = 8 // sampling_h
      v_size = 8 // sampling_v

      data_units.each do |coords, du|
        du_x, du_y = coords

        new_du_x = du_x * sampling_h
        new_du_y = du_y * sampling_v

        sampling_v.times do |y|
          sampling_h.times do |x|
            new_coords = {new_du_x + x, new_du_y + y}

            new_du = Matrix.new(8, 8) do |l, r, c|
              du[r // sampling_v + v_size * y, c // sampling_h + h_size * x]
            end

            upsampled_data[new_coords] = new_du
          end
        end
      end
    end

    def decode_sequential(bit_reader, dc_table, ac_table, du_row, du_col)
      coef = Array.new(64, 0)
      decode_sequential_dc(bit_reader, dc_table, coef)
      decode_sequential_ac(bit_reader, ac_table, coef)
      raw_coefficients[{du_col, du_row}] = coef
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
      coef = raw_coefficients[{du_col, du_row}]? || Array.new(64, 0)
      magnitude = dc_table.decode_from_io(bit_reader)
      @last_dc_value += read_n_extend(bit_reader, magnitude)
      coef[ZIGZAG[0]] = @last_dc_value << approx
      raw_coefficients[{du_col, du_row}] = coef
    end

    def decode_progressive_dc_refine(bit_reader, approx, du_row, du_col)
      coef = raw_coefficients[{du_col, du_row}]
      bit = bit_reader.read_bits(1)
      coef[ZIGZAG[0]] = coef[ZIGZAG[0]] | (bit << approx)
    end

    def decode_progressive_ac_first(bit_reader, ac_table, s_start, s_end, approx, du_row, du_col)
      coef = raw_coefficients[{du_col, du_row}]

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
      coef = raw_coefficients[{du_col, du_row}]

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
      vt = 1 << (-1 + magnitude)
      return bits + 1 + (-1 << magnitude) if bits < vt
      return bits
    end

    def reset_last_dc_value
      @last_dc_value = 0
    end

    def reset_end_of_band
      @end_of_band_run = 0
    end
  end

  class Component::Definition
    SUPPORTED_SAMPLING_VALUES = {1, 2, 4}

    getter component_id : Int32
    getter dqt_table_id : Int32
    getter h : Int32
    getter v : Int32

    def initialize(@component_id, @h, @v, @dqt_table_id)
      raise "Unsupported horizontal sampling: #{h}" if !SUPPORTED_SAMPLING_VALUES.includes?(h)
      raise "Unsupported vertical sampling: #{v}" if !SUPPORTED_SAMPLING_VALUES.includes?(v)
    end

    def to_io(io : IO, format : IO::ByteFormat = IO::ByteFormat::SystemEndian)
      raise "ByteFormat must be BigEndian" if format != IO::ByteFormat::BigEndian

      frequency = (h << 4) | v

      format.encode(component_id.to_u8, io)
      format.encode(frequency.to_u8, io)
      format.encode(dqt_table_id.to_u8, io)
    end

    def self.from_io(io : IO, format : IO::ByteFormat = IO::ByteFormat::SystemEndian)
      raise "ByteFormat must be BigEndian" if format != IO::ByteFormat::BigEndian

      component_id = format.decode(UInt8, io).to_i
      frequency = format.decode(UInt8, io).to_i
      dqt_table_id = format.decode(UInt8, io).to_i

      h = frequency >> 4
      v = frequency & 0x0F

      self.new(component_id, h, v, dqt_table_id)
    end
  end

  class Component::Selector
    getter component_id : Int32
    getter dc_table_id : Int32
    getter ac_table_id : Int32

    def initialize(@component_id, @dc_table_id, @ac_table_id)
    end

    def to_s(io : IO)
      io.write_byte(component_id)
      io.write_byte(((dc_table_id << 4) | ac_table_id).to_u8)
    end

    def self.from_io(io : IO, format : IO::ByteFormat = IO::ByteFormat::SystemEndian)
      raise "ByteFormat must be BigEndian" if format != IO::ByteFormat::BigEndian

      component_id = format.decode(UInt8, io).to_i
      table_ids = format.decode(UInt8, io).to_i

      dc_table_id = table_ids >> 4
      ac_table_id = table_ids & 0x0F

      self.new(component_id, dc_table_id, ac_table_id)
    end
  end
end
