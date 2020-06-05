// Selsyn test suite: Fault loop impedance and distance relay reach.

import math
import ..src.dsp.complex show Complex
import ..src.symmetrical.impedance show DistanceRelay

main:
  relay := DistanceRelay
    --line-r1=0.03
    --line-x1=0.30
    --line-length-km=100.0

  // 1. Apparent impedance for Phase-to-Phase fault at 40 km:
  // Z_apparent = 40 km * (0.03 + j0.30) = 1.2 + j12.0 Ohms
  z-40km := Complex 1.2 12.0
  dist-40km := relay.estimate-fault-distance z-40km
  if (dist-40km - 40.0).abs > 0.05:
    throw "Fault distance estimation error: expected 40.0 km, got $dist-40km"

  // 2. Zone 1 reach test (Zone 1 reach = 80 km = 24.0 Ohms reactance)
  if not (relay.is-zone-1-trip z-40km):
    throw "Fault at 40 km should trip Zone 1"

  // Fault at 90 km (X = 27.0 Ohms > 24.0 Ohms)
  z-90km := Complex 2.7 27.0
  if relay.is-zone-1-trip z-90km:
    throw "Fault at 90 km should NOT trip Zone 1 (outside 80% reach)"

  // 3. Phase-to-phase loop calculation
  va := Complex 100.0 0.0
  vb := Complex 0.0 0.0
  ia := Complex 10.0 0.0
  ib := Complex 0.0 0.0

  z-ll := relay.apparent-impedance-ll va vb ia ib
  if (z-ll.real - 10.0).abs > 1e-4 or z-ll.imag.abs > 1e-4:
    throw "Apparent impedance LL mismatch: expected 10.0 + j0.0, got $z-ll"

  print "test_impedance: ALL TESTS PASSED."
