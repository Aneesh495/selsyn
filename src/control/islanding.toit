// Selsyn: IEEE C37.118 Synchrophasor Measurement and Grid Stability Controller
// Passive Anti-Islanding Detection (IEEE 1547) via ROCOF and Voltage Vector Shift (VVS).

import math

/**
Islanding trip status indicator.
*/
class IslandingState:
  static GRID-CONNECTED /int ::= 0
  static ISLAND-DETECTED /int ::= 1
  static TRIPPED         /int ::= 2

/**
Multi-criteria passive anti-islanding protection engine.
*/
class IslandingDetector:
  nominal-freq    /float
  nominal-voltage /float

  // Protective trip thresholds (IEEE 1547)
  freq-min        /float := 57.0   // Under-frequency trip (Hz)
  freq-max        /float := 62.0   // Over-frequency trip (Hz)
  volt-min-pu     /float := 0.88   // 88% under-voltage
  volt-max-pu     /float := 1.12   // 112% over-voltage
  rocof-threshold /float := 1.20   // ROCOF threshold (Hz/s)
  vvs-threshold   /float := 0.105  // Voltage Vector Shift threshold: ~6 degrees (0.105 rad)

  // State memory
  prev-phase-rad  /float := 0.0
  first-sample    /bool := true
  rocof-sustain-count /int := 0
  sustain-limit   /int := 2        // 2 consecutive reports over ROCOF threshold

  state           /int := IslandingState.GRID-CONNECTED
  trip-reason     /string := "NONE"

  constructor --nominal-freq/float=60.0 --nominal-voltage/float=120.0:
    this.nominal-freq = nominal-freq
    this.nominal-voltage = nominal-voltage

  /** Reset internal detector states. */
  reset -> none:
    prev-phase-rad = 0.0
    first-sample = true
    rocof-sustain-count = 0
    state = IslandingState.GRID-CONNECTED
    trip-reason = "NONE"

  /**
  Evaluate grid state given current measurements:
  $freq: Current frequency in Hz.
  $rocof: Current Rate of Change of Frequency in Hz/s.
  $voltage-rms: True RMS voltage.
  $phase-rad: Current phasor phase angle in radians [-pi, pi].
  Returns true if islanding trip is triggered.
  */
  process freq/float rocof/float voltage-rms/float phase-rad/float -> bool:
    // 1. Under/Over Frequency Check
    if freq < freq-min:
      trip-reason = "UNDER_FREQUENCY"
      state = IslandingState.TRIPPED
      return true
    if freq > freq-max:
      trip-reason = "OVER_FREQUENCY"
      state = IslandingState.TRIPPED
      return true

    // 2. Under/Over Voltage Check
    v-pu := voltage-rms / nominal-voltage
    if v-pu < volt-min-pu:
      trip-reason = "UNDER_VOLTAGE"
      state = IslandingState.TRIPPED
      return true
    if v-pu > volt-max-pu:
      trip-reason = "OVER_VOLTAGE"
      state = IslandingState.TRIPPED
      return true

    // 3. Voltage Vector Shift (VVS) Check
    if not first-sample:
      phase-diff := (phase-rad - prev-phase-rad).abs
      // Handle +/- pi wrap-around
      if phase-diff > math.PI:
        phase-diff = (2.0 * math.PI) - phase-diff

      if phase-diff > vvs-threshold:
        trip-reason = "VOLTAGE_VECTOR_SHIFT"
        state = IslandingState.TRIPPED
        return true
    else:
      first-sample = false

    prev-phase-rad = phase-rad

    // 4. Sustained ROCOF Check
    if rocof.abs > rocof-threshold:
      rocof-sustain-count++
      if rocof-sustain-count >= sustain-limit:
        trip-reason = "SUSTAINED_HIGH_ROCOF"
        state = IslandingState.TRIPPED
        return true
    else:
      rocof-sustain-count = 0

    return false
