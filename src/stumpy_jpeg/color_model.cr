module StumpyJPEG
  module ColorModel

    # Returns the number of components used for this ColorModel
    abstract def number_of_components

    # Composes a Canvas using each matrix as a component
    abstract def compose_canvas(matrices : Array(Matrix))

    # Decomposes a Canvas into component matrices
    abstract def decompose_canvas(canvas : Canvas)

    # Returns a ColorModel corresponding to n components
    def self.from_number_of_components(n)
      case n
      when 1 then Grayscale
      when 3 then YCbCr
      else
        raise "Unsupported ColorModel defined"
      end
    end
  end
end
