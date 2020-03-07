// Selsyn: IEEE C37.118 Synchrophasor Measurement and Grid Stability Controller
// Recursive Discrete Fourier Transform (RDFT) and Full-Cycle DFT Engine.

import math
import .complex show Complex

/**
Recursive Discrete Fourier Transform (RDFT) engine for real-time synchrophasor estimation.
Computes fundamental frequency phasor (RMS magnitude and phase angle) with O(1) sample updates.
Includes pre-computed trigonometric twiddle tables and periodic drift correction.
*/
class RecursiveDft:
  samples-per-cycle /int
  nominal-frequency /float
  sampling-rate     /float

  // Twiddle factor lookup tables (cosine and -sine) for fundamental bin k = 1
  cos-table /List := []
  sin-table /List := []

  // Ring buffer holding the past $samples_per_cycle raw waveform samples
  history /List := []
  history-idx /int := 0
  sample-count /int := 0

  // Running phasor accumulator (unscaled)
  accum-real /float := 0.0
  accum-imag /float := 0.0

  // Scaling factor: sqrt(2) / N for true RMS output
  scale-factor /float := 0.0

  // Drift reset interval (samples) to prevent infinite accumulation of numerical roundoff
  reset-interval /int := 0

  /**
  Initialize recursive DFT engine.
  $samples-per-cycle: Number of samples in one nominal grid cycle (e.g. 64 or 80).
  $nominal-frequency: Power grid base frequency in Hz (typically 50.0 or 60.0).
  */
  constructor --samples-per-cycle/int=64 --nominal-frequency/float=60.0:
    this.samples-per-cycle = samples-per-cycle
    this.nominal-frequency = nominal-frequency
    this.sampling-rate = nominal-frequency * samples-per-cycle.to-float
    this.scale-factor = (math.sqrt 2.0) / samples-per-cycle.to-float
    this.reset-interval = samples-per-cycle * 8  // Reset every 8 cycles

    this.cos-table = List samples-per-cycle 0.0
    this.sin-table = List samples-per-cycle 0.0
    this.history = List samples-per-cycle 0.0

    // Precompute twiddle factors for e^(-j * 2*pi*n / N)
    for n := 0; n < samples-per-cycle; n++:
      angle := 2.0 * math.PI * n.to-float / samples-per-cycle.to-float
      cos-table[n] = math.cos angle
      sin-table[n] = -(math.sin angle)

  /** Reset internal accumulator and waveform history. */
  reset -> none:
    history-idx = 0
    sample-count = 0
    accum-real = 0.0
    accum-imag = 0.0
    for i := 0; i < samples-per-cycle; i++:
      history[i] = 0.0

  /**
  Process a single new incoming waveform sample x[n].
  Updates running phasor accumulator in O(1) time and returns the updated Complex RMS phasor.
  */
  process sample/float -> Complex:
    old-sample := history[history-idx]
    history[history-idx] = sample

    twiddle-idx := sample-count % samples-per-cycle
    cos-val := cos-table[twiddle-idx]
    sin-val := sin-table[twiddle-idx]

    delta := sample - old-sample
    accum-real += delta * cos-val
    accum-imag += delta * sin-val

    history-idx = (history-idx + 1) % samples-per-cycle
    sample-count++

    // Periodic numerical drift correction
    if (sample-count % reset-interval) == 0:
      recalculate-accumulator

    // Rotate phasor to report phase relative to the current sampling instant
    // X_reported = (accum_real + j*accum_imag) * e^(j * 2*pi*n / N) * scale
    rot-cos := cos-val
    rot-sin := -sin-val  // e^(+j * theta)
    r := (accum-real * rot-cos) - (accum-imag * rot-sin)
    i := (accum-real * rot-sin) + (accum-imag * rot-cos)

    return Complex (r * scale-factor) (i * scale-factor)

  /** Recalculate accumulator from full history buffer to eliminate roundoff error. */
  recalculate-accumulator -> none:
    accum-real = 0.0
    accum-imag = 0.0
    for k := 0; k < samples-per-cycle; k++:
      idx := (history-idx + k) % samples-per-cycle
      s := history[idx]
      n := (sample-count - samples-per-cycle + k) % samples-per-cycle
      if n < 0: n += samples-per-cycle
      accum-real += s * cos-table[n]
      accum-imag += s * sin-table[n]

  /**
  Static batch DFT on an entire window of N samples.
  Returns the RMS fundamental phasor.
  */
  static batch-dft samples/List -> Complex:
    n := samples.size
    if n == 0:
      return Complex.zero
    scale := (math.sqrt 2.0) / n.to-float
    sum-r := 0.0
    sum-i := 0.0
    for k := 0; k < n; k++:
      angle := 2.0 * math.PI * k.to-float / n.to-float
      cos-val := math.cos angle
      sin-val := -(math.sin angle)
      s := samples[k]
      sum-r += s * cos-val
      sum-i += s * sin-val
    return Complex (sum-r * scale) (sum-i * scale)
