require "matrix"

module StumpyJPEG
  module Transformation
    C = [1.0, 0.9807852804032304, 0.9238795325112867, 0.8314696123025452, 0.7071067811865476, 0.55557023301960230, 0.38268343236508984, 0.19509032201612833]
    A = [0.0, 0.7071067811865476, 0.5411961001461969, 0.7071067811865476, 1.3065629648763766, 0.38268343236508984, 0.9238795325112867]

    def self.fast_inverse_transform(coefficients : Matrix, quantization_table : Quantization::Table)
      fast_inverse_transform(coefficients.to_a, quantization_table)
    end

    def self.fast_inverse_transform(coefficients : Array, quantization_table : Quantization::Table)
      tmp = StaticArray(Float64, 64).new(0.0)
      output = Matrix.new(8, 8, 0)
      
      rng = 0...64
      rng.step(8) do |index|
        a0 = coefficients[index]     * quantization_table.scaled_elements[index]
        a1 = coefficients[index + 4] * quantization_table.scaled_elements[index + 4]
        a2 = coefficients[index + 2] * quantization_table.scaled_elements[index + 2]
        a3 = coefficients[index + 6] * quantization_table.scaled_elements[index + 6]
        a4 = coefficients[index + 1] * quantization_table.scaled_elements[index + 1]
        a5 = coefficients[index + 5] * quantization_table.scaled_elements[index + 5]
        a6 = coefficients[index + 3] * quantization_table.scaled_elements[index + 3]
        a7 = coefficients[index + 7] * quantization_table.scaled_elements[index + 7]
  
        b0 = a0
        b1 = a1
        b2 = a2 - a3
        b3 = a2 + a3
        b4 = a4 - a7
        b5 = a5 + a6
        b6 = a5 - a6
        b7 = a4 + a7
  
        c0 = b0
        c1 = b1
        c2 = b2
        c3 = b3
        c4 = A[2] * b4
        c5 = b7 - b5
        c6 = A[4] * b6
        c7 = b5 + b7
  
        d0 = c0
        d1 = c1
        d2 = c2
        d3 = c3
        d4 = c4 + c6
        d5 = c5
        d6 = c4 - c6
        d7 = c7
  
        e0 = d0 + d1
        e1 = d0 - d1
        e2 = d2 * C[4]
        e3 = d3
        e4 = d4 * C[4]
        e5 = d5 * C[4]
        e6 = d6
        e7 = d7
  
        f0 = e0
        f1 = e1
        f2 = e2
        f3 = e3
        f4 = e4
        f5 = e5
        f6 = e4 + e6
        f7 = e7
  
        g0 = f0
        g1 = f1
        g2 = f2
        g3 = f2 + f3
        g4 = f4
        g5 = f4 + f5
        g6 = f5 + f6
        g7 = f6 + f7
  
        h0 = g0 + g3
        h1 = g1 + g2
        h2 = g1 - g2
        h3 = g0 - g3
        h4 = g4
        h5 = g5
        h6 = g6
        h7 = g7

        tmp[index]     = (h0 + h7)
        tmp[index + 1] = (h1 + h6)
        tmp[index + 2] = (h2 + h5)
        tmp[index + 3] = (h3 + h4)
        tmp[index + 4] = (h3 - h4)
        tmp[index + 5] = (h2 - h5)
        tmp[index + 6] = (h1 - h6)
        tmp[index + 7] = (h0 - h7)
      end
      
      rng = 0...8
      rng.each do |index|
        a0 = tmp[index]
        a1 = tmp[index + 32]
        a2 = tmp[index + 16]
        a3 = tmp[index + 48]
        a4 = tmp[index + 8]
        a5 = tmp[index + 40]
        a6 = tmp[index + 24]
        a7 = tmp[index + 56]
    
        b0 = a0
        b1 = a1
        b2 = a2 - a3
        b3 = a2 + a3
        b4 = a4 - a7
        b5 = a5 + a6
        b6 = a5 - a6
        b7 = a4 + a7
  
        c0 = b0
        c1 = b1
        c2 = b2
        c3 = b3
        c4 = A[2] * b4
        c5 = b7 - b5
        c6 = A[4] * b6
        c7 = b5 + b7
  
        d0 = c0
        d1 = c1
        d2 = c2
        d3 = c3
        d4 = c4 + c6
        d5 = c5
        d6 = c4 - c6
        d7 = c7
  
        e0 = d0 + d1
        e1 = d0 - d1
        e2 = d2 * C[4]
        e3 = d3
        e4 = d4 * C[4]
        e5 = d5 * C[4]
        e6 = d6
        e7 = d7
  
        f0 = e0
        f1 = e1
        f2 = e2
        f3 = e3
        f4 = e4
        f5 = e5
        f6 = e4 + e6
        f7 = e7
  
        g0 = f0
        g1 = f1
        g2 = f2
        g3 = f2 + f3
        g4 = f4
        g5 = f4 + f5
        g6 = f5 + f6
        g7 = f6 + f7
  
        h0 = g0 + g3
        h1 = g1 + g2
        h2 = g1 - g2
        h3 = g0 - g3
        h4 = g4
        h5 = g5
        h6 = g6
        h7 = g7
        
        output[index]      = (h0 + h7).round.to_i
        output[index + 8]  = (h1 + h6).round.to_i
        output[index + 16] = (h2 + h5).round.to_i
        output[index + 24] = (h3 + h4).round.to_i
        output[index + 32] = (h3 - h4).round.to_i
        output[index + 40] = (h2 - h5).round.to_i
        output[index + 48] = (h1 - h6).round.to_i
        output[index + 56] = (h0 - h7).round.to_i
      end

      output
    end
  end  
end
