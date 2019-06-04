require "stumpy_core"
require "./stumpy_jpeg/**"

# TODO: Write documentation for `StumpyJPEG`
module StumpyJPEG
  include StumpyCore

  WRITE_SUPPORTED_COLORMODELS = {
    ColorModel::YCbCr,
    ColorModel::Grayscale
  }

  def self.read(file : String)
    File.open(file) do |io|
      read(io)
    end
  end

  def self.read(file : String)
    File.open(file) do |io|
      read(io) do |canvas|
        yield canvas
      end
    end
  end

  def self.read(io : IO)
    jpeg = JPEG.new
    Datastream.new(io).read do |marker, stream|
      jpeg.parse_segment(marker, stream)
    end
    jpeg.update_canvas
    jpeg.canvas
  end

  def self.read(io : IO)
    jpeg = JPEG.new
    Datastream.new(io).read do |marker, io|
      jpeg.parse_segment(marker, io)
      if jpeg.update_canvas
        yield jpeg.canvas
      end
    end
    jpeg.canvas
  end

  def self.write(canvas : Canvas, file : String, *, color_model : ColorModel = ColorModel::YCbCr, comment : String? = nil)
    File.open(file, "wb") do |io|
      write(canvas, io, color_model: color_model, comment: comment)
    end
  end

  def self.write(canvas : Canvas, io : IO, *, color_model : ColorModel = ColorModel::YCbCr, comment : String? = nil)
    raise "Unsupported color model" if !WRITE_SUPPORTED_COLORMODELS.includes?(color_model)

    format = IO::ByteFormat::BigEndian

    image_height = canvas.height
    image_width = canvas.width

    matrices = color_model.decompose_canvas(canvas)
    matrices.map! do |matrix|
      rows = (matrix.row_count + 7) // 8
      cols = (matrix.column_count + 7) // 8
      Matrix.new(rows, cols) do |l, r, c|
        x = (c >= cols) ? cols - 1 : c
        y = (r >= rows) ? rows - 1 : c
        matrix[y, x]
      end
    end

    dqts = [] of Quantization::Table
    dqts << Quantization::Table.new(0, 0, Quantization::LUMA.to_a)
    dqts << Quantization::Table.new(0, 1, Quantization::CHROMA.to_a) if matrices.size > 1

    dhts = [] of Huffman::Table
    dhts << Huffman::Table.new(0, 0, Huffman::LUMA_DC_BITS, Huffman::LUMA_DC_HUFFVAL)
    dhts << Huffman::Table.new(1, 0, Huffman::LUMA_AC_BITS, Huffman::LUMA_AC_HUFFVAL)
    dhts << Huffman::Table.new(0, 1, Huffman::CHROMA_DC_BITS, Huffman::CHROMA_DC_HUFFVAL)
    dhts << Huffman::Table.new(1, 1, Huffman::CHROMA_AC_BITS, Huffman::CHROMA_AC_HUFFVAL)

    components = matrices.map_with_index do |m, i|
      dqt_id = (i > 0) ? 1 : 0
      component = Component.new(i, 1, 1, dqt_id)
    end

    io.write_bytes(Segment::SOI.new, format)
    io.write_bytes(Segment::APP.build_jfif_header, format)
    io.write_bytes(Segment::COM.new(comment), format) if comment
    io.write_bytes(Segment::DQT.new(dqts), format)
    io.write_bytes(Segment::DHT.new(dhts), format)
    io.write_bytes(Segment::SOF.new(0, 8, image_height, image_width, matrices.size, components), format)
#    sos.each do |s|
#
#    end
    io.write_bytes(Segment::EOI.new, format)
  end
end
