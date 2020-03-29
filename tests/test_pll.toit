// Selsyn test suite: DSOGI-PLL grid synchronization.

import math
import ..src.dsp.pll show DsogiPll

main:
  fs := 3840.0
  dt := 1.0 / fs
  pll := DsogiPll --nominal-freq=60.0 --sampling-rate=fs

  // 1. Test balanced 60.0 Hz grid waveform
  total-steps := (fs * 0.4).to-int  // 400 ms simulation
  for step := 0; step < total-steps; step++:
    t := step.to-float * dt
    theta := 2.0 * math.PI * 60.0 * t
    v-a := 100.0 * (math.cos theta)
    v-b := 100.0 * (math.sin theta)
    pll.process v-a v-b

  f-est := pll.estimated-freq
  if (f-est - 60.0).abs > 0.05:
    throw "Balanced 60 Hz PLL lock error: expected 60.0, got $f-est"

  // 2. Test frequency step to 60.5 Hz (+500 mHz)
  for step := 0; step < total-steps; step++:
    t := step.to-float * dt
    theta := 2.0 * math.PI * 60.5 * t
    v-a := 100.0 * (math.cos theta)
    v-b := 100.0 * (math.sin theta)
    pll.process v-a v-b

  f-step := pll.estimated-freq
  if (f-step - 60.5).abs > 0.1:
    throw "Frequency step tracking error: expected 60.5, got $f-step"

  // 3. Test single-phase unbalanced input (v_beta = 0)
  pll.reset
  for step := 0; step < total-steps; step++:
    t := step.to-float * dt
    theta := 2.0 * math.PI * 60.0 * t
    v-a := 100.0 * (math.cos theta)
    v-b := 0.0  // Complete loss of phase B/beta
    pll.process v-a v-b

  f-unbal := pll.estimated-freq
  if (f-unbal - 60.0).abs > 0.35:
    throw "Unbalanced single-phase PLL lock error: expected ~60.0, got $f-unbal"

  print "test_pll: ALL TESTS PASSED."
