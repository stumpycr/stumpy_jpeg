require "matrix"

class Transformation::DCT
  @matrix : Matrix(Float64)
  @t_matrix : Matrix(Float64)

  def initialize(size : Int32)
    @matrix = Matrix.new(size, size) do |l, p, q|
      if p == 0
        1 / Math.sqrt(size.to_f)
      else
        Math.sqrt(2 / size.to_f) * Math.cos(Math::PI*(2*q + 1)*p / (2*size))
      end
    end
    @t_matrix = @matrix.transpose
  end

  def transform(a : Matrix)
    @matrix * a * @t_matrix
  end

  def inverse_transform(b : Matrix)
    @t_matrix * b * @matrix
  end
end
