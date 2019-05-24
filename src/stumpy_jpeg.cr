require "stumpy_core"
require "./stumpy_jpeg/**"

# TODO: Write documentation for `StumpyJPEG`
module StumpyJPEG
  include StumpyCore

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
end
