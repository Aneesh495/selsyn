// Selsyn test suite: Passive anti-islanding protection (IEEE 1547).

import math
import ..src.control.islanding show IslandingDetector

main:
  det := IslandingDetector --nominal-freq=60.0 --nominal-voltage=120.0

  // 1. Normal grid operation: no trip
  trip-normal := det.process 60.0 0.05 120.0 0.0
  if trip-normal:
    throw "Normal grid condition should not trip islanding"

  // 2. Under-frequency trip (56.0 Hz < 57.0 Hz)
  det.reset
  trip-uf := det.process 56.0 0.10 120.0 0.0
  if not trip-uf or det.trip-reason != "UNDER_FREQUENCY":
    throw "Expected UNDER_FREQUENCY trip, got $(det.trip-reason)"

  // 3. Under-voltage trip (90.0 V < 105.6 V)
  det.reset
  trip-uv := det.process 60.0 0.0 90.0 0.0
  if not trip-uv or det.trip-reason != "UNDER_VOLTAGE":
    throw "Expected UNDER_VOLTAGE trip, got $(det.trip-reason)"

  // 4. Voltage Vector Shift trip (phase jumps by 15 degrees = 0.26 rad)
  det.reset
  det.process 60.0 0.0 120.0 0.0  // Prime first sample
  trip-vvs := det.process 60.0 0.0 120.0 0.26
  if not trip-vvs or det.trip-reason != "VOLTAGE_VECTOR_SHIFT":
    throw "Expected VOLTAGE_VECTOR_SHIFT trip, got $(det.trip-reason)"

  // 5. Sustained High ROCOF trip (+1.8 Hz/s sustained for 2 cycles)
  det.reset
  trip1 := det.process 60.0 1.8 120.0 0.0
  if trip1:
    throw "Single high ROCOF report should not trip prematurely before sustain limit"
  trip2 := det.process 60.0 1.8 120.0 0.0
  if not trip2 or det.trip-reason != "SUSTAINED_HIGH_ROCOF":
    throw "Expected SUSTAINED_HIGH_ROCOF trip, got $(det.trip-reason)"

  print "test_islanding: ALL TESTS PASSED."
