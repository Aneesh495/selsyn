// Selsyn: IEEE C37.118 Synchrophasor Measurement and Grid Stability Controller
// Windowing functions for spectral leakage suppression and harmonic attenuation.

import math

/**
Windowing functions for finite-length observation windows.
Provides coefficient generators and coherent gain normalization factors.
*/
class Window:
  static RECTANGULAR /int ::= 0
  static HANN        /int ::= 1
  static HAMMING     /int ::= 2
  static BLACKMAN    /int ::= 3
  static FLAT_TOP    /int ::= 4

  /** Generate window weights of length $size for the given window $type. */
  static generate type/int size/int -> List:
    if size <= 0:
      throw "Window size must be positive"
    if size == 1:
      return [1.0]

    weights := List size 0.0
    denom := (size - 1).to-float

    if type == RECTANGULAR:
      for i := 0; i < size; i++:
        weights[i] = 1.0

    else if type == HANN:
      for i := 0; i < size; i++:
        c := math.cos (2.0 * math.PI * i / denom)
        weights[i] = 0.5 * (1.0 - c)

    else if type == HAMMING:
      for i := 0; i < size; i++:
        c := math.cos (2.0 * math.PI * i / denom)
        weights[i] = 0.54 - (0.46 * c)

    else if type == BLACKMAN:
      for i := 0; i < size; i++:
        term1 := 0.50 * (math.cos (2.0 * math.PI * i / denom))
        term2 := 0.08 * (math.cos (4.0 * math.PI * i / denom))
        weights[i] = 0.42 - term1 + term2

    else if type == FLAT_TOP:
      // Standard ISO/IEEE flat-top coefficients for precision amplitude calibration
      a0 := 0.21557895
      a1 := 0.41663158
      a2 := 0.277263158
      a3 := 0.083578947
      a4 := 0.006947368
      for i := 0; i < size; i++:
        term1 := a1 * (math.cos (2.0 * math.PI * i / denom))
        term2 := a2 * (math.cos (4.0 * math.PI * i / denom))
        term3 := a3 * (math.cos (6.0 * math.PI * i / denom))
        term4 := a4 * (math.cos (8.0 * math.PI * i / denom))
        weights[i] = a0 - term1 + term2 - term3 + term4

    else:
      throw "Unknown window type: $type"

    return weights

  /** Calculate coherent gain (sum of window weights): S1 = sum(w[n]). */
  static coherent-gain weights/List -> float:
    sum := 0.0
    weights.do: | w | sum += w
    return sum

  /** Calculate energy gain (sum of squared window weights): S2 = sum(w[n]^2). */
  static energy-gain weights/List -> float:
    sum := 0.0
    weights.do: | w | sum += (w * w)
    return sum

  /** Calculate Equivalent Noise Bandwidth (ENBW): N * S2 / (S1^2). */
  static enbw weights/List -> float:
    s1 := coherent-gain weights
    s2 := energy-gain weights
    if s1 == 0.0:
      throw "Coherent gain is zero"
    return (weights.size.to-float * s2) / (s1 * s1)

  /** Normalize window weights so that coherent gain S1 equals 1.0. */
  static normalize weights/List -> List:
    s1 := coherent-gain weights
    if s1 == 0.0:
      throw "Cannot normalize window with zero coherent gain"
    normalized := List weights.size 0.0
    for i := 0; i < weights.size; i++:
      normalized[i] = weights[i] / s1
    return normalized
