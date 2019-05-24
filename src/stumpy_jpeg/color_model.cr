module StumpyJPEG
  module ColorModel

    # Returns the number of components used for this ColorModel
    abstract def number_of_components

    # Composes a Canvas using each matrix as a component
    abstract def compose_canvas(matrices : Array(Matrix))

    # Decomposes a Canvas into component matrices
    abstract def decompose_canvas(canvas : Canvas)

    # Returns a ColorModel corresponding to n components
    def self.from_number_of_components(n, transform_flag = 1)
      case n
      when 1 then Grayscale
      when 3 then (transform_flag == 1) ? YCbCr : RGB
      when 4 then (transform_flag == 2) ? YCCK : CMYK
      else
        raise "Unsupported ColorModel defined"
      end
    end
  end
end