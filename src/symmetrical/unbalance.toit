// Selsyn: IEEE C37.118 Synchrophasor Measurement and Grid Stability Controller
// Voltage and Current Unbalance Factor (VUF, CUF, PVUR) Calculator.

import .fortescue show SymmetricalComponents
import ..dsp.complex show Complex

/**
Power quality unbalance metrics conforming to IEC 61000-4-30, IEEE 1159, and NEMA MG-1.
*/
class UnbalanceMetrics:
  /**
  Calculate True Voltage Unbalance Factor (VUF) per IEC 61000-4-30:
    VUF = |V2| / |V1| * 100 (%)
  Returns unbalance percentage (e.g. 1.5%).
  */
  static vuf sym/SymmetricalComponents -> float:
    v1-mag := sym.positive.magnitude
    if v1-mag == 0.0:
      return 100.0  // Complete collapse of positive sequence
    return (sym.negative.magnitude / v1-mag) * 100.0

  /**
  Calculate Zero-Sequence Voltage Unbalance Factor (ZUF):
    ZUF = |V0| / |V1| * 100 (%)
  */
  static zuf sym/SymmetricalComponents -> float:
    v1-mag := sym.positive.magnitude
    if v1-mag == 0.0:
      return 100.0
    return (sym.zero.magnitude / v1-mag) * 100.0

  /**
  Calculate NEMA Phase Voltage Unbalance Rate (PVUR):
    PVUR = max(|V_avg - V_phase|) / V_avg * 100 (%)
  */
  static pvur va/Complex vb/Complex vc/Complex -> float:
    ma := va.magnitude
    mb := vb.magnitude
    mc := vc.magnitude
    v-avg := (ma + mb + mc) / 3.0
    if v-avg == 0.0:
      return 100.0

    dev-a := (ma - v-avg).abs
    dev-b := (mb - v-avg).abs
    dev-c := (mc - v-avg).abs

    max-dev := dev-a
    if dev-b > max-dev: max-dev = dev-b
    if dev-c > max-dev: max-dev = dev-c

    return (max-dev / v-avg) * 100.0

  /**
  Check whether grid voltage violates standard utility unbalance limits.
  $warning: typically 2.0% (IEC standard limit)
  $trip: typically 3.0%
  Returns:
    0: Normal
    1: Warning
    2: Critical alarm or trip
  */
  static evaluate-severity vuf-val/float --warning/float=2.0 --trip/float=3.0 -> int:
    if vuf-val >= trip:
      return 2
    else if vuf-val >= warning:
      return 1
    return 0
