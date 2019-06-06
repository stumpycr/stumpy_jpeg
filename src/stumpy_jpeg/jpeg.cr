module StumpyJPEG
  class JPEG
    SUPPORTED_MODES = {0, 1, 2, 9, 10}.map {|n| Markers::SOF + n}
    PROGRESSIVE_MODES = {2, 10}.map {|n| Markers::SOF + n}

    getter canvas : Canvas
    getter comment : String?
    getter components : Hash(Int32, Component)
    getter restart_interval : Int32
    getter entropy_dc_tables : StaticArray(Huffman::Table, 4)
    getter entropy_ac_tables : StaticArray(Huffman::Table, 4)
    getter quantization_tables : StaticArray(Quantization::Table, 4)

    getter app : Segment::APP?
    getter progressive : Bool

    getter frame : Segment::SOF?

    getter mcu_cols : Int32
    getter mcu_rows : Int32

    def initialize
      @canvas = Canvas.new(0,0)
      @components = {} of Int32 => Component
      @restart_interval = 0
      @entropy_dc_tables = uninitialized Huffman::Table[4]
      @entropy_ac_tables = uninitialized Huffman::Table[4]
      @quantization_tables = uninitialized Quantization::Table[4]
      @progressive = false
      @mcu_rows = 0
      @mcu_cols = 0
      @canvas_outdated = false
    end

    def update_canvas
      frame = @frame
      return false if !@canvas_outdated || !frame

      component_matrices = components.map do |id, component|
        component.idct_transform(quantization_tables[component.dqt_table_id])
        if component.sampling_h == 1 && component.sampling_v == 1
          component.upsample_one_to_one
        else
          component.upsample
        end
        Matrix.new(frame.height, frame.width) do |l, r, c|
          du_x, sample_x = c.divmod(8)
          du_y, sample_y = r.divmod(8)
          du = component.upsampled_data[{du_x, du_y}]
          du[sample_y, sample_x]
        end
      end

      color_model = ColorModel.from_number_of_components(frame.number_of_components)
      @canvas = color_model.compose_canvas(component_matrices)
      @canvas_outdated = false
      return true
    end

    private def parse_dqt(io)
      dqt = Segment::DQT.from_io(io)
      dqt.tables.each do |table|
        @quantization_tables[table.table_id] = table
      end
    end

    private def parse_dht(io)
      dht = Segment::DHT.from_io(io)
      dht.tables.each do |table|
        @entropy_dc_tables[table.table_id] = table if table.table_class == 0
        @entropy_ac_tables[table.table_id] = table if table.table_class == 1
      end
    end

    private def parse_dac(io)
      raise "Arithmetic encoding not currently supported"
    end

    private def parse_dri(io)
      dri = Segment::DRI.from_io(io)
      @restart_interval = dri.interval
    end

    private def parse_com(io)
      comment = Segment::COM.from_io(io)
      @comment = comment.text
    end

    private def parse_app(marker, io)
      app = Segment::APP.from_io(io)
      @app = app
    end

    private def parse_sof(marker, io)
      raise "Unsupported decoding mode" if !SUPPORTED_MODES.includes?(marker)
      @progressive = PROGRESSIVE_MODES.includes?(marker)

      frame = Segment::SOF.from_io(io)
      max_h = frame.components.max_of { |comp| comp.h }
      max_v = frame.components.max_of { |comp| comp.v }
      frame.components.each do |definition|
        component = Component.new(definition, max_h, max_v, frame.width, frame.height)
        @components[component.component_id] = component
      end
      @mcu_rows = (frame.height + 8 * max_v - 1) // (8 * max_v)
      @mcu_cols = (frame.width + 8 * max_h - 1) // (8 * max_h)
      @frame = frame
    end

    private def parse_sos(io)
      sos = Segment::SOS.from_io(io)
      parse_scan(sos, io)
    end

    private def parse_scan(sos, io)
      c = components[sos.selectors.first.component_id]
      mcu_x = (sos.selectors.size > 1) ? mcu_cols : c.non_interleaved_mcu_cols
      mcu_y = (sos.selectors.size > 1) ? mcu_rows : c.non_interleaved_mcu_rows

      if progressive
        parse_progressive_scan(sos, io, mcu_x, mcu_y)
      else
        parse_sequential_scan(sos, io, mcu_x, mcu_y)
      end
      @canvas_outdated = true
    end

    private def parse_progressive_scan(sos, io, mcu_x, mcu_y)
      sss = sos.spectral_start
      sse = sos.spectral_end
      sah = sos.approx_high
      sal = sos.approx_low

      if sss == 0
        raise "Invalid spectral selection for dc scan" if sse != 0
        parse_progressive_dc_scan(sos, io, mcu_x, mcu_y, sah, sal)
      else
        raise "Invalid spectral selection for ac scan" if sse < sss
        parse_progressive_ac_scan(sos, io, mcu_x, mcu_y, sss, sse, sah, sal)
      end
    end

    private def parse_progressive_dc_scan(sos, io, mcu_x, mcu_y, sa_high, sa_low)
      restart_count = 0
      decoded_mcus = 0

      first_scan = sa_high == 0

      reader = BitReader.new(io)

      mcu_y.times do |mcu_row|
        mcu_x.times do |mcu_col|

          if restart_interval > 0 && decoded_mcus == restart_interval
            restart(reader, restart_count)
            restart_count += 1
            decoded_mcus = 0
          end

          sos.selectors.each do |s|
            component = components[s.component_id]
            dc_table = entropy_dc_tables[s.dc_table_id]

            component.v.times do |c_y|
              du_row = mcu_row * component.v + c_y
              component.h.times do |c_x|
                du_col = mcu_col * component.h + c_x
                if first_scan
                  component.decode_progressive_dc_first(reader, dc_table, sa_low, du_row, du_col)
                else
                  component.decode_progressive_dc_refine(reader, sa_low, du_row, du_col)
                end
              end
            end
          end

          decoded_mcus += 1
        end
      end
    end

    private def parse_progressive_ac_scan(sos, io, mcu_x, mcu_y, s_start, s_end, sa_high, sa_low)
      raise "Invalid number of components in progressive ac scan" if sos.selectors.size > 1

      restart_count = 0
      decoded_mcus = 0

      first_scan = sa_high == 0

      reader = BitReader.new(io)

      mcu_y.times do |mcu_row|
        mcu_x.times do |mcu_col|

          if restart_interval > 0 && decoded_mcus == restart_interval
            restart(reader, restart_count)
            restart_count += 1
            decoded_mcus = 0
          end

          sos.selectors.each do |s|
            component = components[s.component_id]
            ac_table = entropy_ac_tables[s.ac_table_id]

            if first_scan
              component.decode_progressive_ac_first(reader, ac_table, s_start, s_end, sa_low, mcu_row, mcu_col)
            else
              component.decode_progressive_ac_refine(reader, ac_table, s_start, s_end, sa_low, mcu_row, mcu_col)
            end
          end

          decoded_mcus += 1
        end
      end
    end

    private def parse_sequential_scan(sos, io, mcu_x, mcu_y)
      restart_count = 0
      decoded_mcus = 0

      reader = BitReader.new(io)

      mcu_y.times do |mcu_row|
        mcu_x.times do |mcu_col|

          if restart_interval > 0 && decoded_mcus == restart_interval
            restart(reader, restart_count)
            restart_count += 1
            decoded_mcus = 0
          end

          sos.selectors.each do |s|
            component = components[s.component_id]
            dc_table = entropy_dc_tables[s.dc_table_id]
            ac_table = entropy_ac_tables[s.ac_table_id]

            component.v.times do |c_y|
              du_row = mcu_row * component.v + c_y
              component.h.times do |c_x|
                du_col = mcu_col * component.h + c_x
                component.decode_sequential(reader, dc_table, ac_table, du_row, du_col)
              end
            end
          end

          decoded_mcus += 1
        end
      end
    end

    private def restart(reader, restart_count)
      marker = reader.read_restart_marker
      expected_marker = Markers::RST + restart_count
      raise "Expected correct restart marker" if expected_marker != marker
      components.each do |id, c|
        c.reset_last_dc_value
        c.reset_end_of_band
      end
    end

    def parse_segment(marker, io)
      case marker
      when Markers::DQT then parse_dqt(io)
      when Markers::DHT then parse_dht(io)
      when Markers::DAC then parse_dac(io)
      when Markers::DRI then parse_dri(io)
      when Markers::COM then parse_com(io)
      when Markers::SOS then parse_sos(io)
      else
        case
        when Markers::APPN.includes?(marker) then parse_app(marker, io)
        when Markers::SOFN.includes?(marker) then parse_sof(marker, io)
        else
          raise "Unsupported marker #{marker} at #{io.pos}"
        end
      end
    end

  end
end
