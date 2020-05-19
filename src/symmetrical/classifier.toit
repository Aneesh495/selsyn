// Selsyn: IEEE C37.118 Synchrophasor Measurement and Grid Stability Controller
// Real-Time Symmetrical-Components Fault Classification State Machine.

import ..dsp.complex show Complex
import .fortescue show SymmetricalComponents

/**
Standard transmission and distribution grid fault taxonomy.
*/
class FaultType:
  static NONE        /int ::= 0
  static SLG-A       /int ::= 1
  static SLG-B       /int ::= 2
  static SLG-C       /int ::= 3
  static LL-AB       /int ::= 4
  static LL-BC       /int ::= 5
  static LL-CA       /int ::= 6
  static DLG-AB      /int ::= 7
  static DLG-BC      /int ::= 8
  static DLG-CA      /int ::= 9
  static THREE-PHASE /int ::= 10

  static to-string type/int -> string:
    if type == NONE:        return "NORMAL"
    if type == SLG-A:       return "SLG_AG"
    if type == SLG-B:       return "SLG_BG"
    if type == SLG-C:       return "SLG_CG"
    if type == LL-AB:       return "LL_AB"
    if type == LL-BC:       return "LL_BC"
    if type == LL-CA:       return "LL_CA"
    if type == DLG-AB:      return "DLG_ABG"
    if type == DLG-BC:      return "DLG_BCG"
    if type == DLG-CA:      return "DLG_CAG"
    if type == THREE-PHASE: return "THREE_PHASE_BALANCED"
    return "UNKNOWN"

/**
Fault event record returned by the classifier.
*/
class FaultRecord:
  type      /int := FaultType.NONE
  trip      /bool := false
  v0-mag    /float := 0.0
  v1-mag    /float := 0.0
  v2-mag    /float := 0.0
  i0-mag    /float := 0.0
  i2-mag    /float := 0.0

  constructor .type .trip .v0-mag .v1-mag .v2-mag .i0-mag .i2-mag:

/**
Sub-cycle fault detector and phase selector using sequence networks.
*/
class FaultClassifier:
  nominal-voltage /float
  nominal-current /float

  // Pickup thresholds (in per-unit of nominal)
  v0-trip-threshold /float := 0.20  // 20% zero-sequence voltage
  v2-trip-threshold /float := 0.15  // 15% negative-sequence indicates unbalance
  v1-sag-threshold  /float := 0.70  // 30% drop in positive-sequence voltage
  i-overcurrent-pu  /float := 1.80  // 1.8x nominal current instantaneous pickup
  i0-ground-pu      /float := 0.20  // 20% residual ground current

  constructor
      --nominal-voltage/float=120.0
      --nominal-current/float=5.0:
    this.nominal-voltage = nominal-voltage
    this.nominal-current = nominal-current

  /**
  Classify grid condition based on three-phase voltage and current phasors.
  */
  classify
      va/Complex vb/Complex vc/Complex
      ia/Complex ib/Complex ic/Complex -> FaultRecord:
    v-sym := SymmetricalComponents.decompose va vb vc
    i-sym := SymmetricalComponents.decompose ia ib ic

    v0 := v-sym.zero.magnitude
    v1 := v-sym.positive.magnitude
    v2 := v-sym.negative.magnitude

    i0 := i-sym.zero.magnitude
    i1 := i-sym.positive.magnitude
    i2 := i-sym.negative.magnitude

    v0-pu := v0 / nominal-voltage
    v1-pu := v1 / nominal-voltage
    v2-pu := v2 / nominal-voltage

    i0-pu := i0 / nominal-current
    i2-pu := i2 / nominal-current

    ia-pu := ia.magnitude / nominal-current
    ib-pu := ib.magnitude / nominal-current
    ic-pu := ic.magnitude / nominal-current

    has-unbalance    := (v2-pu > v2-trip-threshold) or (i2-pu > 0.25)
    has-severe-sag   := v1-pu < v1-sag-threshold
    has-overcurrent  := (ia-pu > i-overcurrent-pu) or (ib-pu > i-overcurrent-pu) or (ic-pu > i-overcurrent-pu)

    // Standard numerical relay I0 / I2 ratio discriminator for ground involvement
    has-ground-fault := false
    if i2 > 0.1:
      // If negative-sequence is present, check ground involvement ratio I0 / I2
      ratio := i0 / i2
      has-ground-fault = (ratio > 0.25) and (i0-pu > i0-ground-pu)
    else:
      // Direct ground current pickup when I2 is minimal
      has-ground-fault = i0-pu > i0-ground-pu

    fault-type := FaultType.NONE
    trip := false

    if has-severe-sag and not has-unbalance and not has-ground-fault:
      // Three-phase symmetrical fault
      fault-type = FaultType.THREE-PHASE
      trip = true

    else if has-ground-fault and not has-unbalance:
      // Single line to ground with dominant zero-sequence
      fault-type = select-slg-phase va.magnitude vb.magnitude vc.magnitude
      trip = true

    else if has-ground-fault and has-unbalance:
      // Both zero and negative sequence present: distinguish SLG vs DLG
      low-v-count := count-collapsed-phases va.magnitude vb.magnitude vc.magnitude
      if low-v-count >= 2:
        fault-type = select-dlg-phases va.magnitude vb.magnitude vc.magnitude
      else:
        fault-type = select-slg-phase va.magnitude vb.magnitude vc.magnitude
      trip = true

    else if has-unbalance and not has-ground-fault:
      // Line-to-line fault without ground path
      fault-type = select-ll-phases va.magnitude vb.magnitude vc.magnitude
      trip = true

    return FaultRecord fault-type trip v0 v1 v2 i0 i2

  /** Select faulted phase for Single Line-to-Ground fault (lowest voltage). */
  select-slg-phase va/float vb/float vc/float -> int:
    if va <= vb and va <= vc: return FaultType.SLG-A
    if vb <= va and vb <= vc: return FaultType.SLG-B
    return FaultType.SLG-C

  /** Select faulted pair for Line-to-Line fault (two lowest voltages). */
  select-ll-phases va/float vb/float vc/float -> int:
    // Highest voltage is the healthy phase
    if va >= vb and va >= vc: return FaultType.LL-BC  // Phase A is healthy
    if vb >= va and vb >= vc: return FaultType.LL-CA  // Phase B is healthy
    return FaultType.LL-AB                           // Phase C is healthy

  /** Select faulted phases for Double Line-to-Ground fault. */
  select-dlg-phases va/float vb/float vc/float -> int:
    // The healthy phase retains highest voltage
    if va >= vb and va >= vc: return FaultType.DLG-BC
    if vb >= va and vb >= vc: return FaultType.DLG-CA
    return FaultType.DLG-AB

  /** Count how many phase voltages have sagged below 80% nominal. */
  count-collapsed-phases va/float vb/float vc/float -> int:
    threshold := nominal-voltage * 0.80
    count := 0
    if va < threshold: count++
    if vb < threshold: count++
    if vc < threshold: count++
    return count
