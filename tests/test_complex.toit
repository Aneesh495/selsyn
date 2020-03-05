// Selsyn test suite: Complex numbers and phasor operations.

import math
import ..src.dsp.complex show Complex

main:
  // Test basic arithmetic
  c1 := Complex 3.0 4.0
  if c1.magnitude != 5.0:
    throw "Expected magnitude 5.0, got $(c1.magnitude)"
  if c1.magnitude-squared != 25.0:
    throw "Expected magnitude-squared 25.0, got $(c1.magnitude-squared)"

  c2 := Complex 1.0 -2.0
  sum := c1 + c2
  if sum.real != 4.0 or sum.imag != 2.0:
    throw "Addition failure: expected 4.0 + j2.0, got $(sum)"

  diff := c1 - c2
  if diff.real != 2.0 or diff.imag != 6.0:
    throw "Subtraction failure: expected 2.0 + j6.0, got $(diff)"

  prod := c1 * c2
  // (3 + 4j)(1 - 2j) = 3 - 6j + 4j - 8(-1) = 11 - 2j
  if prod.real != 11.0 or prod.imag != -2.0:
    throw "Multiplication failure: expected 11.0 - j2.0, got $(prod)"

  quot := prod / c2
  if (quot.real - c1.real).abs > 1e-9 or (quot.imag - c1.imag).abs > 1e-9:
    throw "Division failure: expected $(c1), got $(quot)"

  // Test conjugate
  conj := c1.conjugate
  if conj.real != 3.0 or conj.imag != -4.0:
    throw "Conjugate failure: expected 3.0 - j4.0, got $(conj)"

  // Test polar constructor
  mag := 120.0
  angle := math.PI / 4.0
  polar-c := Complex.polar mag angle
  if (polar-c.magnitude - mag).abs > 1e-9:
    throw "Polar magnitude mismatch: expected $(mag), got $(polar-c.magnitude)"
  if (polar-c.phase - angle).abs > 1e-9:
    throw "Polar phase mismatch: expected $(angle), got $(polar-c.phase)"

  // Test rotation by 90 degrees (pi/2 radians)
  rot-90 := c1.rotate (math.PI / 2.0)
  // (3 + 4j)*j = -4 + 3j
  if (rot-90.real - (-4.0)).abs > 1e-9 or (rot-90.imag - 3.0).abs > 1e-9:
    throw "Rotation failure: expected -4.0 + j3.0, got $(rot-90)"

  // Test TVE (Total Vector Error)
  c-ref := Complex 100.0 0.0
  c-est := Complex 100.0 1.0  // small error
  tve := c-est.tve c-ref
  if (tve - 0.01).abs > 1e-6:
    throw "TVE calculation incorrect: expected 0.01, got $(tve)"

  c-perfect := Complex 100.0 0.0
  if (c-perfect.tve c-ref) != 0.0:
    throw "TVE for identical vectors should be 0.0"

  print "test_complex: ALL TESTS PASSED."
