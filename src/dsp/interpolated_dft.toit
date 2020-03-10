// Selsyn: IEEE C37.118 Synchrophasor Measurement and Grid Stability Controller
// Interpolated Discrete Fourier Transform (IpDFT) for off-nominal frequency correction.

import math
import .complex show Complex

/**
Interpolated Discrete Fourier Transform (IpDFT) engine.
Compensates for spectral leakage when power grid frequency deviates from nominal (50/60 Hz).
Estimates fractional bin offset delta using 3-point Hann interpolation to yield true frequency,
corrected magnitude, and phase.
*/
class InterpolatedDft:
  nominal-frequency /float
  sampling-rate     /float
  window-size       /int
  bin-resolution    /float

  /**
  Initialize IpDFT processor.
  $nominal-frequency: Nominal base grid frequency (e.g. 60.0 Hz).
  $sampling-rate: Waveform sampling rate in Hz (e.g. 3840.0 Hz).
  $window-size: Window length in samples (e.g. 128 for 2-cycle observation).
  */
  constructor
      --nominal-frequency/float=60.0
      --sampling-rate/float=3840.0
      --window-size/int=128:
    this.nominal-frequency = nominal-frequency
    this.sampling-rate = sampling-rate
    this.window-size = window-size
    this.bin-resolution = sampling-rate / window-size.to-float

  /**
  Estimate off-nominal frequency, corrected magnitude, and phase from a Hann-windowed signal.
  $samples: Raw input samples of length $window_size.
  Returns a Map containing:
    "frequency": estimated grid frequency in Hz
    "phasor": corrected Complex RMS phasor
    "delta": fractional bin deviation
  */
  estimate samples/List -> Map:
    if samples.size != window-size:
      throw "Input samples size $(samples.size) does not match window size $window-size"

    // 1. Apply Hann window: w[n] = 0.5 * (1 - cos(2*pi*n / (N-1)))
    denom := (window-size - 1).to-float
    w-samples := List window-size 0.0
    for n := 0; n < window-size; n++:
      c := math.cos (2.0 * math.PI * n.to-float / denom)
      w := 0.5 * (1.0 - c)
      w-samples[n] = samples[n] * w

    // 2. Identify nominal fundamental bin k0
    k0 := (nominal-frequency / bin-resolution).round.to-int

    // 3. Compute DFT bins for k0 - 1, k0, and k0 + 1
    x-prev := compute-bin w-samples (k0 - 1)
    x-main := compute-bin w-samples k0
    x-next := compute-bin w-samples (k0 + 1)

    y1 := x-prev.magnitude
    y2 := x-main.magnitude
    y3 := x-next.magnitude

    // 4. Parabolic / 3-point Hann interpolation for fractional bin shift delta
    delta := 0.0
    denom-val := (2.0 * y2) - y1 - y3
    if denom-val.abs > 1e-9:
      delta = 0.5 * (y3 - y1) / denom-val
      // Guardrails on delta
      if delta > 0.5: delta = 0.5
      if delta < -0.5: delta = -0.5

    // 5. Calculate actual frequency: f = (k0 + delta) * bin_resolution
    est-freq := (k0.to-float + delta) * bin-resolution

    // 6. Window coherent gain compensation for Hann window (S1 = 0.5 * N)
    // and scaling to RMS: sqrt(2) / S1 = 2 * sqrt(2) / N
    rms-scale := (2.0 * (math.sqrt 2.0)) / window-size.to-float

    // Hann scallop amplitude correction
    amp-correction := 1.0
    if delta.abs > 1e-5:
      pi-delta := math.PI * delta
      sin-val := math.sin pi-delta
      if sin-val.abs > 1e-9:
        amp-correction = (pi-delta / sin-val) * (1.0 - (delta * delta))

    corr-mag := y2 * amp-correction * rms-scale

    // 7. Correct phase angle: phi = angle(X_main) - pi * delta
    corr-phase := x-main.phase - (math.PI * delta)

    // Normalize phase to [-pi, pi]
    while corr-phase > math.PI:
      corr-phase -= 2.0 * math.PI
    while corr-phase < -math.PI:
      corr-phase += 2.0 * math.PI

    corr-phasor := Complex.polar corr-mag corr-phase

    return {
      "frequency": est-freq,
      "phasor": corr-phasor,
      "delta": delta
    }

  /** Compute single DFT bin k for windowed samples. */
  compute-bin samples/List k/int -> Complex:
    n := samples.size
    sum-r := 0.0
    sum-i := 0.0
    two-pi-k-over-n := 2.0 * math.PI * k.to-float / n.to-float
    for m := 0; m < n; m++:
      theta := two-pi-k-over-n * m.to-float
      s := samples[m]
      sum-r += s * (math.cos theta)
      sum-i -= s * (math.sin theta)
    return Complex sum-r sum-i
