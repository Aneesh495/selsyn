// Selsyn test suite: Interpolated DFT (IpDFT) off-nominal frequency tracking.

import math
import ..src.dsp.complex show Complex
import ..src.dsp.interpolated_dft show InterpolatedDft

main:
  nom-freq := 60.0
  fs := 3840.0
  n-samples := 128
  v-rms := 120.0
  v-peak := v-rms * (math.sqrt 2.0)

  ipdft := InterpolatedDft
    --nominal-frequency=nom-freq
    --sampling-rate=fs
    --window-size=n-samples

  // 1. Test nominal 60.0 Hz signal
  samples-60 := List n-samples 0.0
  for n := 0; n < n-samples; n++:
    t := n.to-float / fs
    samples-60[n] = v-peak * (math.cos (2.0 * math.PI * nom-freq * t))

  res-60 := ipdft.estimate samples-60
  f-est-60 /float := res-60["frequency"]
  p-est-60 /Complex := res-60["phasor"]

  if (f-est-60 - 60.0).abs > 0.05:
    throw "Nominal frequency estimate error: expected 60.0, got $f-est-60"
  if (p-est-60.magnitude - v-rms).abs > 1.0:
    throw "Nominal magnitude estimate error: expected $v-rms, got $(p-est-60.magnitude)"

  // 2. Test off-nominal 60.2 Hz grid frequency (+200 mHz deviation)
  f-off := 60.2
  samples-off := List n-samples 0.0
  for n := 0; n < n-samples; n++:
    t := n.to-float / fs
    samples-off[n] = v-peak * (math.cos (2.0 * math.PI * f-off * t))

  res-off := ipdft.estimate samples-off
  f-est-off /float := res-off["frequency"]
  p-est-off /Complex := res-off["phasor"]

  if (f-est-off - f-off).abs > 0.08:
    throw "Off-nominal frequency estimate error: expected $f-off, got $f-est-off"
  if (p-est-off.magnitude - v-rms).abs > 2.0:
    throw "Off-nominal magnitude estimate error: expected $v-rms, got $(p-est-off.magnitude)"

  print "test_interpolated_dft: ALL TESTS PASSED."
