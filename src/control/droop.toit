// Selsyn: IEEE C37.118 Synchrophasor Measurement and Grid Stability Controller
// Active Power-Frequency (P-f) and Reactive Power-Voltage (Q-V) Droop Control (IEEE 1547).

import math

/**
Inverter priority mode during apparent power saturation.
*/
class InverterPriority:
  static ACTIVE-PRIORITY   /int ::= 0  // Prioritize P over Q
  static REACTIVE-PRIORITY /int ::= 1  // Prioritize Q for grid voltage support

/**
Droop controller governing smart inverter and battery energy storage (BESS) response.
*/
class DroopController:
  nominal-freq    /float  // 50.0 or 60.0 Hz
  nominal-voltage /float  // 120.0 or 230.0 V
  p-rated         /float  // Rated active power (Watts or kW)
  q-rated         /float  // Rated reactive power (Vars or kVar)
  s-max           /float  // Inverter apparent power capacity (VA)

  // Droop slopes: R_p = Delta_f / Delta_P (e.g. 0.05 = 5% droop)
  droop-p-percent /float := 0.05
  droop-q-percent /float := 0.03

  // Deadbands (NERC / IEEE 1547 standard)
  freq-deadband   /float := 0.036  // +/- 36 mHz deadband
  volt-deadband   /float := 0.020  // +/- 2% voltage deadband

  // Setpoint baseline targets
  p-ref /float := 0.0
  q-ref /float := 0.0

  priority /int := InverterPriority.REACTIVE-PRIORITY

  constructor
      --nominal-freq/float=60.0
      --nominal-voltage/float=120.0
      --p-rated/float=100.0
      --q-rated/float=60.0
      --s-max/float=110.0
      --droop-p/float=0.05
      --droop-q/float=0.03:
    this.nominal-freq = nominal-freq
    this.nominal-voltage = nominal-voltage
    this.p-rated = p-rated
    this.q-rated = q-rated
    this.s-max = s-max
    this.droop-p-percent = droop-p
    this.droop-q-percent = droop-q

  /**
  Calculate active power target P_target given measured grid frequency $f-meas.
  */
  compute-active-power f-meas/float -> float:
    delta-f := f-meas - nominal-freq

    // Deadband check
    if delta-f.abs <= freq-deadband:
      return p-ref

    effective-delta-f := delta-f > 0.0 ? (delta-f - freq-deadband) : (delta-f + freq-deadband)

    // Droop response: Delta_P = -Delta_f / (droop_p * f_nom) * P_rated
    droop-scale := droop-p-percent * nominal-freq
    p-delta := -1.0 * (effective-delta-f / droop-scale) * p-rated

    p-target := p-ref + p-delta
    // Saturation clamp [-P_rated, P_rated]
    if p-target > p-rated: p-target = p-rated
    if p-target < -p-rated: p-target = -p-rated
    return p-target

  /**
  Calculate reactive power target Q_target given measured RMS voltage $v-meas.
  */
  compute-reactive-power v-meas/float -> float:
    v-pu := v-meas / nominal-voltage
    delta-v := v-pu - 1.0

    // Deadband check
    if delta-v.abs <= volt-deadband:
      return q-ref

    effective-delta-v := delta-v > 0.0 ? (delta-v - volt-deadband) : (delta-v + volt-deadband)

    // Droop response: Delta_Q = -Delta_V / droop_q * Q_rated
    q-delta := -1.0 * (effective-delta-v / droop-q-percent) * q-rated

    q-target := q-ref + q-delta
    // Saturation clamp [-Q_rated, Q_rated]
    if q-target > q-rated: q-target = q-rated
    if q-target < -q-rated: q-target = -q-rated
    return q-target

  /**
  Coordinated P-Q setpoint calculation enforcing four-quadrant inverter capacity:
    P^2 + Q^2 <= S_max^2.
  Returns a Map with keys "P" and "Q".
  */
  dispatch f-meas/float v-meas/float -> Map:
    p-cmd := compute-active-power f-meas
    q-cmd := compute-reactive-power v-meas

    s-apparent := math.sqrt ((p-cmd * p-cmd) + (q-cmd * q-cmd))

    if s-apparent > s-max:
      if priority == InverterPriority.REACTIVE-PRIORITY:
        // Prioritize reactive power Q for grid voltage stabilization
        q-clamped := q-cmd
        if q-clamped.abs > s-max:
          q-clamped = q-clamped > 0.0 ? s-max : -s-max
        max-p := math.sqrt ((s-max * s-max) - (q-clamped * q-clamped))
        p-clamped := p-cmd > 0.0 ? (min p-cmd max-p) : (max p-cmd -max-p)
        return {"P": p-clamped, "Q": q-clamped}
      else:
        // Prioritize active power P
        p-clamped := p-cmd
        if p-clamped.abs > s-max:
          p-clamped = p-clamped > 0.0 ? s-max : -s-max
        max-q := math.sqrt ((s-max * s-max) - (p-clamped * p-clamped))
        q-clamped := q-cmd > 0.0 ? (min q-cmd max-q) : (max q-cmd -max-q)
        return {"P": p-clamped, "Q": q-clamped}

    return {"P": p-cmd, "Q": q-cmd}
