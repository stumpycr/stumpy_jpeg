module StumpyJPEG
  class Decoder
    def initialize
      @components = {} of Int32 => Component
      @last_dc_values = {} of Int32 => Int32

      @dct = Transformation::DCT.new(8)
      @dqts = uninitialized Quantization::Table[4]
      @dhts_ac = uninitialized Huffman::Table[4]
      @dhts_dc = uninitialized Huffman::Table[4]

      @comments = [] of String
      @app = [] of APP

      @restart_interval = 0
      @bit_precision = -1
      @image_height = -1
      @image_width = -1

      @number_of_components = -1
      @buffer_marker = nil.as(UInt8?)
    end

    def reset
      initialize
    end

    def decode(io : IO)
      reset

      raise "Invalid JPEG file" if read_marker(io) != Markers::SOI

      loop do
        marker = @buffer_marker || read_marker(io)
        break if marker == Markers::EOI

        case marker
        when Markers::DQT then parse_dqt(io)
        when Markers::DHT then parse_dht(io)
          # when Markers::DAC then parse_dac(io) # TODO: Eventually...
        when Markers::DRI then parse_dri(io)
        when Markers::COM then parse_com(io)
        when Markers::SOS then parse_sos(io)
          # when Markers::DNL then nil
          # when Markers::DHP then nil
          # when Markers::EXP then nil
          # when Markers::JPG then nil
        else
          if Markers::APPN.includes?(marker)
            parse_app(io, marker - Markers::APP)
          elsif Markers::SOFN.includes?(marker)
            parse_sof(io, marker - Markers::SOF)
            # elsif Markers::JPGN.includes?(marker)
            #   nil
          else
            raise "Unsupported marker #{marker}"
          end
        end
      end

      component_matrices = @components.map do |id, component|
        Matrix.new(@image_width, @image_height) do |l, r, c|
          du_x, sample_x = c.divmod(8)
          du_y, sample_y = r.divmod(8)
          du = component.data_units[{du_x, du_y}]
          du[sample_x, sample_y]
        end
      end

      StumpyCore::Canvas.compose_ycbcr(component_matrices)
    end

    private def read_marker(io)
      marker_start = io.read_byte
      marker = io.read_byte
      raise IO::EOFError.new if !marker_start || !marker
      raise "Expected a marker but got #{marker_start}" if marker_start != 0xFF
      marker
    end

    # Parses a DQT marker and assigns it to the specified table id
    private def parse_dqt(io)
      dqt = DQT.from_io(io)
      dqt.tables.each do |table|
        @dqts[table.table_id] = table
      end
    end

    # Parses a DHT marker and assigns it to the specified table id
    private def parse_dht(io)
      dht = DHT.from_io(io)
      dht.tables.each do |table|
        @dhts_dc[table.table_id] = table if table.table_class == 0
        @dhts_ac[table.table_id] = table if table.table_class == 1
      end
    end

    # Parses a DRI marker
    private def parse_dri(io)
      dri = DRI.from_io(io)
      @restart_interval = dri.interval
    end

    # Parses a COM marker
    private def parse_com(io)
      comment = COM.from_io(io)
      @comments << comment.text
    end

    # Parses an APPn marker
    private def parse_app(io, n)
      app = APP.from_io(io)
      raise "Only JFIF supported" if !app.jfif? || n != 0
      @app << app
    end

    # Parses a SOFn marker
    private def parse_sof(io, n)
      sof = SOF.from_io(io)
      @number_of_components = sof.number_of_components
      @bit_precision = sof.bit_precision
      @image_height = sof.height
      @image_width = sof.width
      sof.components.each do |component|
        @components[component.component_id] = component
        @last_dc_values[component.component_id] = 0
      end
    end

    # Parses a SOS marker and following data
    private def parse_sos(io)
      sos = SOS.from_io(io)

      data_io = IO::Memory.new
      while byte = io.read_byte
        if byte == Markers::START
          marker_byte = io.read_byte.not_nil!
          if Markers::RSTN.includes?(marker_byte)
            data_io.write_byte(byte)
            data_io.write_byte(marker_byte)
          elsif marker_byte == Markers::SKIP
            data_io.write_byte(byte)
          else
            @buffer_marker = marker_byte
            break
          end
        else
          data_io.write_byte(byte)
        end
      end

      data_io.rewind

      if sos.number_of_components == 1
        parse_non_interleaved(data_io, sos)
      else
        parse_interleaved(data_io, sos)
      end
    end

    # Parses sequential interleaved data
    private def parse_interleaved(io, sos)
      max_h = @components.max_of { |key, comp| comp.h }
      max_v = @components.max_of { |key, comp| comp.v }
      mcu_x = (@image_width + 8 * max_h - 1) / (8 * max_h)
      mcu_y = (@image_height + 8 * max_v - 1) / (8 * max_v)

      br = BitIO::BitReader.new(io)

      decoded_mcus = 0
      restart_count = 0

      mcu_y.times do |m_y|
        mcu_x.times do |m_x|
          if @restart_interval > 0 && decoded_mcus == @restart_interval
            br.read_remaining_bits
            marker = read_marker(io)
            if Markers::RSTN.includes?(marker) && (Markers::RST + restart_count) == marker
              @last_dc_values.transform_values { 0 }
              decoded_mcus = 0
              restart_count += 1
            else
              raise "Data corrupted"
            end
          end

          sos.selectors.each do |s|
            component = @components[s.component_id]
            dqt = @dqts[component.dqt_table_id]
            # TODO: Don't assume its always huffman
            dc_table = @dhts_dc[s.dc_table_id]
            ac_table = @dhts_ac[s.ac_table_id]

            (0...component.v).each do |c_y|
              (0...component.h).each do |c_x|
                data_unit = decode_data_unit(br, dqt, dc_table, ac_table, s.component_id)
                component.data_units[{m_x*max_h + c_x, m_y*max_v + c_y}] = data_unit
              end
            end
          end
          decoded_mcus += 1
        end
      end

      @components.each do |id, c|
        c.upsample(max_h, max_v)
      end
    end

    # Parses sequential non interleaved data
    private def parse_non_interleaved(io, sos)
      max_h = @components.max_of { |key, comp| comp.h }
      max_v = @components.max_of { |key, comp| comp.v }

      selector = sos.selectors.first
      component = @components[selector.component_id]

      pixels_x = 8 * max_h / component.h
      pixels_y = 8 * max_v / component.v

      mcu_x = (@image_width + pixels_x - 1) / pixels_x
      mcu_y = (@image_height + pixels_y - 1) / pixels_y

      br = BitIO::BitReader.new(io)

      decoded_mcus = 0
      restart_count = 0

      mcu_y.times do |m_y|
        mcu_x.times do |m_x|
          if @restart_interval > 0 && decoded_mcus == @restart_interval
            br.read_remaining_bits
            marker = read_marker(io)
            if Markers::RSTN.includes?(marker) && (Markers::RST + restart_count) == marker
              @last_dc_values.transform_values { 0 }
              decoded_mcus = 0
              restart_count += 1
            else
              raise "Data corrupted"
            end
          end

          dqt = @dqts[component.dqt_table_id]
          # TODO: Don't assume its always huffman
          dc_table = @dhts_dc[selector.dc_table_id]
          ac_table = @dhts_ac[selector.ac_table_id]

          (0...component.v).each do |c_y|
            (0...component.h).each do |c_x|
              data_unit = decode_data_unit(br, dqt, dc_table, ac_table, selector.component_id)
              component.data_units[{m_x*max_h + c_x, m_y*max_v + c_y}] = data_unit
            end
          end

          decoded_mcus += 1
        end
      end
    end

    private def decode_data_unit(bit_reader, dqt, dc_table, ac_table, component_id)
      dc = decode_dc(bit_reader, dc_table, component_id)
      ac = decode_ac(bit_reader, ac_table)

      coef = [dc] + ac

      data_unit = Matrix(Int32).new(8, 8, 0)
      ZIGZAG.each_with_index do |v, i|
        data_unit[v] = coef[i]
      end

      data_unit = dqt.dequantize(data_unit)
      data_unit = @dct.inverse_transform(data_unit).map { |e, l, r, c| e.round.to_i }
      data_unit
    end

    private def decode_dc(bit_reader, dc_table, component_id)
      magnitude = dc_table.decode_from_io(bit_reader)

      adds = bit_reader.read_bits(magnitude.to_i)
      diff = extend_coefficient(adds, magnitude)

      dc = diff + @last_dc_values[component_id]

      @last_dc_values[component_id] = dc
      dc
    end

    private def decode_ac(bit_reader, ac_table)
      ac_values = [] of Int32
      while ac_values.size < 63
        byte = ac_table.decode_from_io(bit_reader)

        if byte == 0xF0
          16.times { ac_values << 0 }
          next
        end

        if byte == 0x00
          (63 - ac_values.size).times { ac_values << 0 }
          next
        end

        zero_run = (byte & 0xF0) >> 4
        magnitude = byte & 0x0F

        zero_run.times { ac_values << 0 }

        adds = bit_reader.read_bits(magnitude.to_i)
        ac = extend_coefficient(adds, magnitude)

        ac_values << ac
      end
      ac_values
    end

    private def extend_coefficient(bits, magnitude)
      diff = bits

      vt = 1 << (magnitude - 1)
      diff = bits + 1 + (-1 << magnitude) if bits < vt
      diff
    end
  end
end
