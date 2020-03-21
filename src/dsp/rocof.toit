// Selsyn: IEEE C37.118 Synchrophasor Measurement and Grid Stability Controller
// Rate of Change of Frequency (ROCOF, df/dt) Savitzky-Golay polynomial filter.

/**
Rate of Change of Frequency (ROCOF) filter per IEEE C37.118.
Uses a Savitzky-Golay / moving-least-squares 1st-order differentiator
over an odd-length historical frequency window to suppress noise while maintaining fast transient response.
*/
class RocofFilter:
  window-size  /int
  delta-t      /float
  buffer       /List := []
  buf-idx      /int := 0
  filled       /bool := false
  coeffs       /List := []
  coeff-denom  /float := 0.0

  // Maximum physical limit on ROCOF (Hz/s) for outlier spike clipping
  max-rocof    /float := 15.0

  /**
  Initialize ROCOF filter.
  $window-size: Odd integer (e.g. 5, 7, or 9 points).
  $reporting-rate: Frequency of updates in Hz (e.g. 50.0 fps -> delta_t = 0.02s).
  $max-rocof: Threshold in Hz/s to reject unphysical phase step jumps.
  */
  constructor --window-size/int=7 --reporting-rate/float=50.0 --max-rocof/float=15.0:
    if (window-size % 2) == 0 or window-size < 3:
      throw "ROCOF filter window size must be an odd integer >= 3"
    this.window-size = window-size
    this.delta-t = 1.0 / reporting-rate
    this.max-rocof = max-rocof
    this.buffer = List window-size 0.0

    // Compute Savitzky-Golay 1st-derivative linear regression weights
    // For odd M = 2K + 1: c_k = k, denom = delta_t * sum(k^2)
    k-half := window-size / 2
    this.coeffs = List window-size 0.0
    sum-k-sq := 0.0
    for k := -k-half; k <= k-half; k++:
      idx := k + k-half
      coeffs[idx] = k.to-float
      sum-k-sq += (k.to-float * k.to-float)
    this.coeff-denom = sum-k-sq * delta-t

  /** Reset internal filter state. */
  reset -> none:
    buf-idx = 0
    filled = false
    for i := 0; i < window-size; i++:
      buffer[i] = 0.0

  /**
  Feed a new frequency measurement f[n] (in Hz).
  Returns estimated df/dt in Hz/s.
  */
  process freq/float -> float:
    buffer[buf-idx] = freq
    buf-idx = (buf-idx + 1) % window-size
    if buf-idx == 0:
      filled = true

    if not filled:
      return 0.0  // Filter ramping up

    // Compute Savitzky-Golay derivative over the window
    sum := 0.0
    for i := 0; i < window-size; i++:
      // Oldest sample is at buf_idx, newest is at (buf_idx - 1)
      hist-idx := (buf-idx + i) % window-size
      sum += buffer[hist-idx] * coeffs[i]

    rocof := sum / coeff-denom

    // Outlier rejection / clamp
    if rocof > max-rocof:
      rocof = max-rocof
    else if rocof < -max-rocof:
      rocof = -max-rocof

    return rocof
