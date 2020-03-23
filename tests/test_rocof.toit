// Selsyn test suite: Rate of Change of Frequency (ROCOF) filter.

import ..src.dsp.rocof show RocofFilter

main:
  rate := 50.0  // 50 fps
  dt := 1.0 / rate
  filter := RocofFilter --window-size=7 --reporting-rate=rate --max-rocof=15.0

  // 1. Test steady-state frequency (zero slope)
  for i := 0; i < 20; i++:
    val := filter.process 60.0
    if i >= 7 and val.abs > 1e-4:
      throw "Steady-state ROCOF should be zero, got $val"

  // 2. Test linear frequency ramp (+2.0 Hz/s)
  filter.reset
  slope := 2.0
  latest-rocof := 0.0
  for i := 0; i < 30; i++:
    t := i.to-float * dt
    f := 60.0 + (slope * t)
    latest-rocof = filter.process f

  // Verify steady-state slope estimation
  if (latest-rocof - slope).abs > 0.02:
    throw "Positive ramp ROCOF error: expected $slope, got $latest-rocof"

  // 3. Test negative ramp (-1.5 Hz/s)
  filter.reset
  neg-slope := -1.5
  for i := 0; i < 30; i++:
    t := i.to-float * dt
    f := 60.0 + (neg-slope * t)
    latest-rocof = filter.process f

  if (latest-rocof - neg-slope).abs > 0.02:
    throw "Negative ramp ROCOF error: expected $neg-slope, got $latest-rocof"

  // 4. Test spike outlier rejection
  filter.reset
  for i := 0; i < 7; i++:
    filter.process 60.0
  // Huge impossible frequency step (e.g. 75 Hz)
  spike-rocof := filter.process 75.0
  if spike-rocof.abs > 15.0:
    throw "Outlier spike was not clamped: got $spike-rocof"

  print "test_rocof: ALL TESTS PASSED."
