// Selsyn test suite: Virtual Synchronous Generator (VSG) swing equation dynamics.

import math
import ..src.control.vsg show VirtualSynchronousGenerator

main:
  vsg := VirtualSynchronousGenerator
    --inertia-h=4.0
    --damping-d=20.0
    --nominal-freq=60.0
    --p-rated=100.0

  dt := 0.005  // 5 ms step

  // 1. Test steady-state equilibrium (P_m == P_e)
  for step := 0; step < 100; step++:
    f := vsg.step 50.0 50.0 dt
    if (f - 60.0).abs > 1e-4:
      throw "Equilibrium frequency should be 60.0 Hz, got $f"

  // 2. Test sudden load surge (P_e jumps from 50 to 70 kW)
  // Rotor should decelerate naturally (synthetic inertia release)
  f-latest := 60.0
  for step := 0; step < 200; step++:
    f-latest = vsg.step 50.0 70.0 dt

  // Expected frequency decline
  if f-latest >= 60.0:
    throw "Load surge should cause rotor deceleration: got $f-latest"

  // Expected steady-state frequency dip:
  // Delta_P_pu = (50 - 70) / 100 = -0.20
  // D * Delta_omega_pu = -0.20 -> Delta_omega_pu = -0.20 / 20 = -0.01 (-1%)
  // f_expected = 60.0 * (1 - 0.01) = 59.40 Hz
  if (f-latest - 59.40).abs > 0.05:
    throw "Steady-state frequency dip mismatch: expected ~59.40 Hz, got $f-latest"

  print "test_vsg: ALL TESTS PASSED."
