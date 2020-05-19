// Selsyn test suite: Unbalance factors (VUF, ZUF, PVUR) evaluation.

import math
import ..src.dsp.complex show Complex
import ..src.symmetrical.fortescue show SymmetricalComponents
import ..src.symmetrical.unbalance show UnbalanceMetrics

main:
  // 1. Balanced system: VUF should be 0.0%
  va := Complex.polar 120.0 0.0
  vb := Complex.polar 120.0 (-2.0 * math.PI / 3.0)
  vc := Complex.polar 120.0 (2.0 * math.PI / 3.0)

  sym-bal := SymmetricalComponents.decompose va vb vc
  vuf-bal := UnbalanceMetrics.vuf sym-bal
  if vuf-bal > 1e-4:
    throw "Balanced VUF should be 0.0, got $vuf-bal"

  sev-bal := UnbalanceMetrics.evaluate-severity vuf-bal
  if sev-bal != 0:
    throw "Expected normal severity 0, got $sev-bal"

  // 2. Unbalanced system (e.g. single-phase voltage sag: Va = 100V, Vb=120V, Vc=120V)
  va-sag := Complex.polar 100.0 0.0
  sym-sag := SymmetricalComponents.decompose va-sag vb vc
  vuf-sag := UnbalanceMetrics.vuf sym-sag
  zuf-sag := UnbalanceMetrics.zuf sym-sag

  if vuf-sag <= 0.0 or zuf-sag <= 0.0:
    throw "Sag unbalance factors should be positive"

  // 3. Threshold severity classification
  if (UnbalanceMetrics.evaluate-severity 1.5) != 0:
    throw "1.5% should be Normal (0)"
  if (UnbalanceMetrics.evaluate-severity 2.4) != 1:
    throw "2.4% should be Warning (1)"
  if (UnbalanceMetrics.evaluate-severity 3.8) != 2:
    throw "3.8% should be Critical Trip (2)"

  // 4. Test NEMA PVUR
  pvur := UnbalanceMetrics.pvur va-sag vb vc
  if pvur <= 0.0 or pvur > 20.0:
    throw "PVUR calculation out of bounds: $pvur"

  print "test_unbalance: ALL TESTS PASSED."
