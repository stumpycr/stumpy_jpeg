require "matrix"

class Transformation::DCT
  C = (0..7).map { |n| Math.cos(Math::PI*n/16.0) }
  A = [0.0, C[4], C[2] - C[6], C[4], C[2] + C[6], C[6], C[2]]
  S = [1.0/(2*Math.sqrt(2))] + (1..7).map { |n| 1.0/(4*C[n]) }

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

  def fast_transform(a : Matrix)
    rows = a.rows.map do |row|
      fast_transform_vector(row)
    end
    
    tmp = Matrix.rows(rows)
    
    columns = tmp.columns.map do |column|
      fast_transform_vector(column)
    end

    Matrix.columns(columns)
  end

  def inverse_transform(b : Matrix)
    @t_matrix * b * @matrix
  end

  def fast_inverse_transform(b : Matrix)
    rows = b.rows.map do |row|
      fast_inverse_transform_vector(row)
    end
    
    tmp = Matrix.rows(rows)
    
    columns = tmp.columns.map do |column|
      fast_inverse_transform_vector(column)
    end

    Matrix.columns(columns)
  end

  private def fast_transform_vector(vector)
    s10 = vector[0] + vector[7]
    s11 = vector[1] + vector[6]
    s12 = vector[2] + vector[5]
    s13 = vector[3] + vector[4]
    s14 = vector[3] - vector[4]
    s15 = vector[2] - vector[5]
    s16 = vector[1] - vector[6]
    s17 = vector[0] - vector[7]

    s20 = s10 + s13
    s21 = s11 + s12
    s22 = s11 - s12
    s23 = s10 - s13
    s24 = - s14 - s15
    s25 = s15 + s16
    s26 = s16 + s17

    s30 = s20 + s21
    s31 = s20 - s21
    s32 = s22 + s23

    ps4 = (s24 + s26) * A[5]
    
    s42 = s32 * A[1]
    s44 = - s24 * A[2] - ps4
    s45 = s25 * A[3]
    s46 = s26 * A[4] - ps4

    s52 = s42 + s23
    s53 = s23 - s42
    s55 = s45 + s17
    s57 = s17 - s45

    s64 = s44 + s57
    s65 = s55 + s46
    s66 = s55 - s46
    s67 = s57 - s44

    [
      s30 * S[0],
      s65 * S[1],
      s52 * S[2],
      s67 * S[3],
      s31 * S[4],
      s64 * S[5],
      s53 * S[6],
      s66 * S[7]
    ]
  end

  private def fast_inverse_transform_vector(vector)    
    s60 = vector[0] / S[0]
    s61 = vector[4] / S[4]
    s82 = vector[2] / S[2]
    s83 = vector[6] / S[6]
    s94 = vector[5] / S[5]
    s95 = vector[1] / S[1]
    s96 = vector[7] / S[7]
    s97 = vector[3] / S[3]

    s74 = s94 - s97
    s85 = s95 + s96
    s76 = s95 - s96
    s87 = s94 + s97

    s72 = s82 - s83
    s63 = s82 + s83
    s75 = s85 - s87
    s57 = s85 + s87

    ps4 = (s74 + s76) * 2 * A[6]

    s62 = s72 * 2 * A[1]
    s64 = ps4 - s74 * 2 * A[4]
    s45 = s75 * 2 * A[3]
    s66 = s76 * 2 * A[2] - ps4
  
    s30 = s60 + s61
    s31 = s60 - s61
    s32 = s62 - s63
    s33 = s63
    s34 = s66
    s56 = s64

    s46 = s56 - s57
    s27 = s57

    s25 = s45 - s46
    s26 = s46

    s20 = s30 + s33
    s21 = s31 + s32
    s22 = s31 - s32
    s23 = s30 - s33
    s24 = - s34 - s25
    
    [
      (s20 + s27) / 8.0,
      (s21 + s26) / 8.0,
      (s22 + s25) / 8.0,
      (s23 + s24) / 8.0,
      (s23 - s24) / 8.0,
      (s22 - s25) / 8.0,
      (s21 - s26) / 8.0,
      (s20 - s27) / 8.0
    ]
  end
end
