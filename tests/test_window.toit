// Selsyn test suite: Windowing functions and normalization.

import ..src.dsp.window show Window

main:
  n := 64

  // Test Rectangular Window
  rect := Window.generate Window.RECTANGULAR n
  if rect.size != n:
    throw "Rectangular size mismatch: expected $n, got $(rect.size)"
  rect.do: | w |
    if w != 1.0:
      throw "Rectangular weight must be 1.0, got $w"

  cg-rect := Window.coherent-gain rect
  if cg-rect != n.to-float:
    throw "Rectangular coherent gain mismatch: expected $n, got $cg-rect"

  enbw-rect := Window.enbw rect
  if (enbw-rect - 1.0).abs > 1e-9:
    throw "Rectangular ENBW mismatch: expected 1.0, got $enbw-rect"

  // Test Hann Window
  hann := Window.generate Window.HANN n
  if hann[0].abs > 1e-9 or hann[n - 1].abs > 1e-9:
    throw "Hann window edges must be zero"
  // Symmetry check
  for i := 0; i < n / 2; i++:
    if (hann[i] - hann[n - 1 - i]).abs > 1e-9:
      throw "Hann window asymmetry at index $i"

  // Test Hamming Window
  hamming := Window.generate Window.HAMMING n
  if (hamming[0] - 0.08).abs > 1e-6:
    throw "Hamming edge mismatch: expected ~0.08, got $(hamming[0])"
  for i := 0; i < n / 2; i++:
    if (hamming[i] - hamming[n - 1 - i]).abs > 1e-9:
      throw "Hamming window asymmetry at index $i"

  // Test Blackman Window
  blackman := Window.generate Window.BLACKMAN n
  if blackman[0].abs > 1e-6:
    throw "Blackman edge mismatch: expected ~0.0, got $(blackman[0])"

  // Test Flat-Top Window
  flattop := Window.generate Window.FLAT_TOP n
  if flattop.size != n:
    throw "Flat-top size mismatch"

  // Test Normalization
  norm-hann := Window.normalize hann
  cg-norm := Window.coherent-gain norm-hann
  if (cg-norm - 1.0).abs > 1e-9:
    throw "Normalized coherent gain must be 1.0, got $cg-norm"

  print "test_window: ALL TESTS PASSED."
