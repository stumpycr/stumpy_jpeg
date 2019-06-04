module StumpyJPEG
  class Segment::DHT < Segment
    getter tables : Array(Huffman::Table)

    def initialize(@tables)
      super Markers::DHT
    end

    def length
      tables.reduce(2) do |acc, table|
        acc += table.bytesize
      end
    end

    def to_io(io : IO, format : IO::ByteFormat = IO::ByteFormat::SystemEndian)
      super(io, format)
      format.encode(length.to_u16, io)
      tables.each do |table|
        io.write_bytes(table, format)
      end
    end

    def self.from_io(io : IO)
      length = io.read_bytes(UInt16, IO::ByteFormat::BigEndian)
      bytes_read = 2

      tables = [] of Huffman::Table
      while bytes_read < length
        dht = Huffman::Table.from_io(io)
        bytes_read += dht.bytesize
        tables << dht
      end

      self.new(tables)
    end
  end
end
