// Selsyn test suite: Hardware Abstraction Layer (ADC calibration and PPS clock).

import ..src.hal.adc_channel show AdcChannel AdcCalibration
import ..src.hal.clock show PpsTimekeeper

main:
  // 1. Test ADC calibration scaling
  // E.g. 12-bit ADC (0..4095), offset = 2048, gain = 0.1 V/count
  cal := AdcCalibration --offset=2048.0 --gain=0.1
  ch := AdcChannel "VA" --pin=34 --calibration=cal

  val-zero := ch.read-scaled 2048
  if val-zero.abs > 1e-4:
    throw "ADC mid-scale offset mismatch: expected 0.0, got $val-zero"

  val-pos := ch.read-scaled 3048  // +1000 counts * 0.1 = +100.0 V
  if (val-pos - 100.0).abs > 1e-4:
    throw "ADC gain scaling mismatch: expected 100.0, got $val-pos"

  // 2. Test PPS Timekeeper
  initial-soc := 1731000000
  timekeeper := PpsTimekeeper --initial-soc=initial-soc

  // At top of second: fraction should be 0
  frac0 := timekeeper.fracsec
  if (frac0 & 0x00FFFFFF) != 0:
    throw "Fraction at top of second must be zero, got $(frac0 & 0x00FFFFFF)"

  // Advance by 500,000 us (0.5 second)
  timekeeper.tick-microseconds 500000
  frac-half := timekeeper.fracsec & 0x00FFFFFF
  // 0.5 * 2^24 = 8,388,608
  if (frac-half - 8388608).abs > 2:
    throw "Half-second fraction mismatch: expected 8388608, got $frac-half"

  // Advance by another 500,000 us -> rollover into next SOC
  timekeeper.tick-microseconds 500000
  if timekeeper.soc != (initial-soc + 1):
    throw "SOC rollover failed: expected $(initial-soc + 1), got $(timekeeper.soc)"
  if timekeeper.microsecond-offset != 0:
    throw "Microsecond offset should wrap to 0"

  // 3. Test PPS hardware interrupt pulse
  timekeeper.tick-microseconds 250000
  timekeeper.on-pps-pulse
  if timekeeper.soc != (initial-soc + 2):
    throw "PPS pulse failed to increment SOC"
  if timekeeper.microsecond-offset != 0:
    throw "PPS pulse failed to align microsecond offset to zero"

  print "test_hal: ALL TESTS PASSED."
