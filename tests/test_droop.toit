// Selsyn test suite: Active and reactive droop controllers and inverter dispatch.

import math
import ..src.control.droop show DroopController InverterPriority

main:
  droop := DroopController
    --nominal-freq=60.0
    --nominal-voltage=120.0
    --p-rated=100.0
    --q-rated=60.0
    --s-max=110.0
    --droop-p=0.05
    --droop-q=0.03

  // 1. Test nominal grid condition
  p-nom := droop.compute-active-power 60.0
  q-nom := droop.compute-reactive-power 120.0
  if p-nom != 0.0:
    throw "Nominal active power should be 0.0, got $p-nom"
  if q-nom != 0.0:
    throw "Nominal reactive power should be 0.0, got $q-nom"

  // 2. Test frequency deadband (+/- 36 mHz)
  p-deadband := droop.compute-active-power 60.030
  if p-deadband != 0.0:
    throw "Frequency within deadband must not trigger power output: got $p-deadband"

  // 3. Test under-frequency response (f = 59.80 Hz -> -200 mHz)
  p-under := droop.compute-active-power 59.80
  if p-under <= 0.0:
    throw "Under-frequency must increase active power injection: got $p-under"

  // 4. Test voltage sag response (V = 110.0 V)
  q-sag := droop.compute-reactive-power 110.0
  if q-sag <= 0.0:
    throw "Voltage sag must inject capacitive reactive power: got $q-sag"

  // 5. Test Four-Quadrant Apparent Power Capacity Enforcement (P^2 + Q^2 <= S_max^2)
  res := droop.dispatch 58.50 90.0  // Huge simultaneous frequency drop and voltage sag
  p-disp /float := res["P"]
  q-disp /float := res["Q"]

  s-mag := math.sqrt ((p-disp * p-disp) + (q-disp * q-disp))
  if (s-mag - 110.0) > 1e-3:
    throw "Dispatched apparent power $s-mag exceeded inverter limit S_max (110.0)"

  print "test_droop: ALL TESTS PASSED."
