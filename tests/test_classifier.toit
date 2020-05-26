// Selsyn test suite: Real-time symmetrical fault classification.

import math
import ..src.dsp.complex show Complex
import ..src.symmetrical.classifier show FaultClassifier FaultType FaultRecord

main:
  classifier := FaultClassifier --nominal-voltage=120.0 --nominal-current=5.0

  // Nominal balanced voltages and currents
  va-nom := Complex.polar 120.0 0.0
  vb-nom := Complex.polar 120.0 (-2.0 * math.PI / 3.0)
  vc-nom := Complex.polar 120.0 (2.0 * math.PI / 3.0)

  ia-nom := Complex.polar 5.0 0.0
  ib-nom := Complex.polar 5.0 (-2.0 * math.PI / 3.0)
  ic-nom := Complex.polar 5.0 (2.0 * math.PI / 3.0)

  // 1. Normal state
  rec-norm := classifier.classify va-nom vb-nom vc-nom ia-nom ib-nom ic-nom
  if rec-norm.type != FaultType.NONE or rec-norm.trip:
    throw "Normal state misclassified as $(FaultType.to-string rec-norm.type)"

  // 2. Three-Phase Symmetrical Fault: voltages collapse to 30V, currents surge to 30A
  va-3p := Complex.polar 30.0 0.0
  vb-3p := Complex.polar 30.0 (-2.0 * math.PI / 3.0)
  vc-3p := Complex.polar 30.0 (2.0 * math.PI / 3.0)
  ia-3p := Complex.polar 30.0 0.0
  ib-3p := Complex.polar 30.0 (-2.0 * math.PI / 3.0)
  ic-3p := Complex.polar 30.0 (2.0 * math.PI / 3.0)

  rec-3p := classifier.classify va-3p vb-3p vc-3p ia-3p ib-3p ic-3p
  if rec-3p.type != FaultType.THREE-PHASE or not rec-3p.trip:
    throw "Three-phase fault misclassified as $(FaultType.to-string rec-3p.type)"

  // 3. Single Line-to-Ground on Phase A (Va sags to 10V, Ia surges to 35A)
  va-slg := Complex.polar 10.0 0.0
  ia-slg := Complex.polar 35.0 0.0
  rec-slg := classifier.classify va-slg vb-nom vc-nom ia-slg ib-nom ic-nom
  if rec-slg.type != FaultType.SLG-A or not rec-slg.trip:
    throw "SLG-A fault misclassified as $(FaultType.to-string rec-slg.type)"

  // 4. Line-to-Line fault between Phase B and Phase C
  vb-ll := Complex.polar 50.0 (-math.PI / 2.0)
  vc-ll := Complex.polar 50.0 (-math.PI / 2.0)
  ib-ll := Complex.polar 25.0 (-math.PI / 2.0)
  ic-ll := Complex.polar 25.0 (math.PI / 2.0)  // equal and opposite current, zero ground current

  rec-ll := classifier.classify va-nom vb-ll vc-ll ia-nom ib-ll ic-ll
  if rec-ll.type != FaultType.LL-BC or not rec-ll.trip:
    throw "LL-BC fault misclassified as $(FaultType.to-string rec-ll.type)"

  // 5. Double Line-to-Ground on Phase A and Phase B
  va-dlg := Complex.polar 15.0 0.0
  vb-dlg := Complex.polar 15.0 (-2.0 * math.PI / 3.0)
  ia-dlg := Complex.polar 28.0 0.0
  ib-dlg := Complex.polar 28.0 (-2.0 * math.PI / 3.0)

  rec-dlg := classifier.classify va-dlg vb-dlg vc-nom ia-dlg ib-dlg ic-nom
  if rec-dlg.type != FaultType.DLG-AB or not rec-dlg.trip:
    throw "DLG-AB fault misclassified as $(FaultType.to-string rec-dlg.type)"

  print "test_classifier: ALL TESTS PASSED."
