// Selsyn: IEEE C37.118 Synchrophasor Measurement and Grid Stability Controller
// Positive-Sequence Loop Impedance and Fault Distance Estimation (ANSI 21).

import math
import ..dsp.complex show Complex

/**
Calculates apparent fault loop impedance and quadrilateral / mho distance relay reach.
*/
class DistanceRelay:
  line-r1 /float  // Positive sequence line resistance (Ohms/km)
  line-x1 /float  // Positive sequence line reactance (Ohms/km)
  line-length-km /float

  // Zero-sequence compensation factor k0 = (Z0 - Z1) / (3 * Z1)
  k0 /Complex

  constructor
      --line-r1/float=0.03
      --line-x1/float=0.30
      --line-length-km/float=100.0
      --k0/Complex=(Complex 0.65 0.0):
    this.line-r1 = line-r1
    this.line-x1 = line-x1
    this.line-length-km = line-length-km
    this.k0 = k0

  /**
  Calculate Phase-to-Phase apparent fault loop impedance:
    Z_LL = (Va - Vb) / (Ia - Ib)
  */
  apparent-impedance-ll va/Complex vb/Complex ia/Complex ib/Complex -> Complex:
    v-diff := va - vb
    i-diff := ia - ib
    if i-diff.magnitude < 1e-4:
      return Complex 1e6 1e6  // Infinite impedance (open circuit)
    return v-diff / i-diff

  /**
  Calculate Phase-to-Ground apparent fault loop impedance:
    Z_LG = Va / (Ia + k0 * 3*I0)
  */
  apparent-impedance-lg va/Complex ia/Complex i0/Complex -> Complex:
    i0-scaled := i0.scale 3.0
    i-comp := ia + (k0 * i0-scaled)
    if i-comp.magnitude < 1e-4:
      return Complex 1e6 1e6
    return va / i-comp

  /**
  Estimate distance to fault along the transmission line in kilometers.
  Uses positive-sequence reactance: d = X_apparent / X1_per_km.
  */
  estimate-fault-distance z-apparent/Complex -> float:
    x-app := z-apparent.imag
    if x-app <= 0.0:
      return 0.0
    dist-km := x-app / line-x1
    if dist-km > line-length-km:
      dist-km = line-length-km
    return dist-km

  /**
  Evaluate Zone 1 (instantaneous reach: 80% line length) quadrilateral characteristic.
  Returns true if apparent impedance falls inside Zone 1 boundaries.
  */
  is-zone-1-trip z-apparent/Complex -> bool:
    r := z-apparent.real
    x := z-apparent.imag
    reach-x1 := line-x1 * line-length-km * 0.80  // 80% of line reactance
    r-max := line-r1 * line-length-km * 1.50     // Quadrilateral resistive reach

    // Quadrilateral boundary check
    return (x >= 0.0) and (x <= reach-x1) and (r >= -2.0) and (r <= r-max)
