// Selsyn test suite: Fortescue Symmetrical Components decomposition and synthesis.

import math
import ..src.dsp.complex show Complex
import ..src.symmetrical.fortescue show SymmetricalComponents

main:
  // 1. Test perfectly balanced three-phase system
  va := Complex.polar 120.0 0.0
  vb := Complex.polar 120.0 (-2.0 * math.PI / 3.0)  // -120 deg
  vc := Complex.polar 120.0 (2.0 * math.PI / 3.0)   // +120 deg

  sym := SymmetricalComponents.decompose va vb vc

  // V0 and V2 must be zero for balanced positive-sequence system
  if sym.zero.magnitude > 1e-4:
    throw "Balanced system V0 should be 0.0, got $(sym.zero.magnitude)"
  if sym.negative.magnitude > 1e-4:
    throw "Balanced system V2 should be 0.0, got $(sym.negative.magnitude)"
  if (sym.positive.magnitude - 120.0).abs > 1e-4:
    throw "Balanced system V1 mismatch: expected 120.0, got $(sym.positive.magnitude)"

  // 2. Test Single-Phase Ground Fault on Phase A (Va = 0)
  va-fault := Complex.zero
  sym-fault := SymmetricalComponents.decompose va-fault vb vc
  // In a single-phase fault with Va = 0: |V0| = |V2| = 120/3 = 40.0 V
  if (sym-fault.zero.magnitude - 40.0).abs > 1e-4:
    throw "SLG fault V0 mismatch: expected 40.0, got $(sym-fault.zero.magnitude)"
  if (sym-fault.negative.magnitude - 40.0).abs > 1e-4:
    throw "SLG fault V2 mismatch: expected 40.0, got $(sym-fault.negative.magnitude)"

  // 3. Test Synthesis roundtrip (Reconstruction)
  synth := sym-fault.synthesize
  re-va /Complex := synth[0]
  re-vb /Complex := synth[1]
  re-vc /Complex := synth[2]

  if re-va.magnitude > 1e-4:
    throw "Reconstructed Va mismatch: expected 0.0, got $(re-va.magnitude)"
  if (re-vb.magnitude - 120.0).abs > 1e-4:
    throw "Reconstructed Vb mismatch: expected 120.0, got $(re-vb.magnitude)"
  if (re-vc.magnitude - 120.0).abs > 1e-4:
    throw "Reconstructed Vc mismatch: expected 120.0, got $(re-vc.magnitude)"

  print "test_fortescue: ALL TESTS PASSED."
