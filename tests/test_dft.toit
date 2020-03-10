// Selsyn test suite: Recursive and Batch DFT.

import math
import ..src.dsp.complex show Complex
import ..src.dsp.dft show RecursiveDft

main:
  samples-per-cycle := 64
  freq := 60.0
  v-rms := 120.0
  v-peak := v-rms * (math.sqrt 2.0)

  // 1. Test Static Batch DFT on pure fundamental cosine
  samples := List samples-per-cycle 0.0
  for n := 0; n < samples-per-cycle; n++:
    theta := 2.0 * math.PI * n.to-float / samples-per-cycle.to-float
    samples[n] = v-peak * (math.cos theta)

  p-batch := RecursiveDft.batch-dft samples
  if (p-batch.magnitude - v-rms).abs > 1e-4:
    throw "Batch DFT RMS mismatch: expected $v-rms, got $(p-batch.magnitude)"
  if p-batch.phase.abs > 1e-4:
    throw "Batch DFT phase mismatch: expected 0.0, got $(p-batch.phase)"

  // 2. Test Batch DFT with +45 deg phase offset (pi/4 radians)
  phase-offset := math.PI / 4.0
  for n := 0; n < samples-per-cycle; n++:
    theta := (2.0 * math.PI * n.to-float / samples-per-cycle.to-float) + phase-offset
    samples[n] = v-peak * (math.cos theta)

  p-offset := RecursiveDft.batch-dft samples
  if (p-offset.magnitude - v-rms).abs > 1e-4:
    throw "Offset RMS mismatch: expected $v-rms, got $(p-offset.magnitude)"
  if (p-offset.phase - phase-offset).abs > 1e-4:
    throw "Offset phase mismatch: expected $phase-offset, got $(p-offset.phase)"

  // 3. Test Recursive DFT sample-by-sample streaming
  rdft := RecursiveDft --samples-per-cycle=samples-per-cycle --nominal-frequency=freq
  latest-p := Complex.zero

  // Stream 3 cycles of sinusoidal samples
  total-samples := samples-per-cycle * 3
  for n := 0; n < total-samples; n++:
    theta := 2.0 * math.PI * n.to-float / samples-per-cycle.to-float
    sample := v-peak * (math.cos theta)
    latest-p = rdft.process sample

  // After 3 cycles, filter is primed and steady-state
  if (latest-p.magnitude - v-rms).abs > 1e-3:
    throw "RDFT steady-state magnitude mismatch: expected $v-rms, got $(latest-p.magnitude)"

  // 4. Test Harmonic Rejection: Inject 3rd harmonic (180 Hz) and 5th harmonic (300 Hz)
  rdft.reset
  v3-peak := 20.0 * (math.sqrt 2.0)  // 20 V 3rd harmonic
  v5-peak := 10.0 * (math.sqrt 2.0)  // 10 V 5th harmonic

  for n := 0; n < total-samples; n++:
    theta1 := 2.0 * math.PI * n.to-float / samples-per-cycle.to-float
    theta3 := 3.0 * theta1
    theta5 := 5.0 * theta1
    sample := (v-peak * (math.cos theta1)) + (v3-peak * (math.cos theta3)) + (v5-peak * (math.cos theta5))
    latest-p = rdft.process sample

  // Verify that harmonics are filtered out by full-cycle DFT
  if (latest-p.magnitude - v-rms).abs > 1e-3:
    throw "Harmonic rejection failure: expected $v-rms, got $(latest-p.magnitude)"

  print "test_dft: ALL TESTS PASSED."
