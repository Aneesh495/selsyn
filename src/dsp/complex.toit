// Selsyn: IEEE C37.118 Synchrophasor Measurement and Grid Stability Controller
// Complex number arithmetic and phasor representation.

import math

/**
A double-precision complex number representing a phasor or frequency-domain bin.
Supports Cartesian (real, imag) and polar (magnitude, phase) operations.
*/
class Complex:
  real /float := 0.0
  imag /float := 0.0

  /** Standard constructor from real and imaginary parts. */
  constructor .real .imag:

  /** Zero complex number (0 + j0). */
  constructor.zero:
    real = 0.0
    imag = 0.0

  /** Construct a phasor from polar coordinates (magnitude and phase in radians). */
  constructor.polar magnitude/float phase/float:
    real = magnitude * (math.cos phase)
    imag = magnitude * (math.sin phase)

  /** Euler exponential: e^(j * theta) = cos(theta) + j * sin(theta). */
  constructor.exp theta/float:
    real = math.cos theta
    imag = math.sin theta

  /** Phasor addition: (a + jb) + (c + jd) = (a + c) + j(b + d). */
  operator + other/Complex -> Complex:
    return Complex (real + other.real) (imag + other.imag)

  /** Phasor subtraction: (a + jb) - (c + jd) = (a - c) + j(b - d). */
  operator - other/Complex -> Complex:
    return Complex (real - other.real) (imag - other.imag)

  /** Phasor multiplication: (a + jb) * (c + jd) = (ac - bd) + j(ad + bc). */
  operator * other/Complex -> Complex:
    r := (real * other.real) - (imag * other.imag)
    i := (real * other.imag) + (imag * other.real)
    return Complex r i

  /** Scale phasor by a real scalar factor. */
  scale factor/float -> Complex:
    return Complex (real * factor) (imag * factor)

  /** Phasor division: (a + jb) / (c + jd). */
  operator / other/Complex -> Complex:
    denom := (other.real * other.real) + (other.imag * other.imag)
    if denom == 0.0:
      throw "Division by zero in Complex phasor arithmetic"
    r := ((real * other.real) + (imag * other.imag)) / denom
    i := ((imag * other.real) - (real * other.imag)) / denom
    return Complex r i

  /** Complex conjugate: (a + jb)* = a - jb. */
  conjugate -> Complex:
    return Complex real (-imag)

  /** Squared magnitude: |Z|^2 = a^2 + b^2. */
  magnitude-squared -> float:
    return (real * real) + (imag * imag)

  /** Euclidean magnitude: |Z| = sqrt(a^2 + b^2). */
  magnitude -> float:
    return math.sqrt magnitude-squared

  /** Phase angle in radians [-pi, pi]. */
  phase -> float:
    return math.atan2 imag real

  /** Phase angle in degrees [-180, 180]. */
  phase-degrees -> float:
    return (phase * 180.0) / math.PI

  /** Rotate phasor by an angle in radians. */
  rotate angle-rad/float -> Complex:
    rot := Complex.exp angle-rad
    return this * rot

  /**
  Calculate Total Vector Error (TVE) per IEEE C37.118.1:
    TVE = sqrt( (real_est - real_true)^2 + (imag_est - imag_true)^2 ) / |true|
  Returns fractional TVE (e.g. 0.01 = 1%).
  */
  tve reference/Complex -> float:
    ref-mag-sq := reference.magnitude-squared
    if ref-mag-sq == 0.0:
      throw "Cannot compute TVE with zero reference magnitude"
    diff-r := real - reference.real
    diff-i := imag - reference.imag
    err-sq := (diff-r * diff-r) + (diff-i * diff-i)
    return math.sqrt (err-sq / ref-mag-sq)

  /** String representation in standard engineering format. */
  to-string -> string:
    if imag >= 0.0:
      return "$real + j$imag"
    return "$real - j$(-imag)"
