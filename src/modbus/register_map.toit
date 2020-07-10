// Selsyn: IEEE C37.118 Synchrophasor Measurement and Grid Stability Controller
// Industrial SCADA Modbus Register Mapping and Memory Model.

/**
Modbus memory model mapping physical grid telemetry into standardized 16-bit registers.
*/
class ModbusRegisterMap:
  // Discrete inputs (bits)
  breaker-closed     /bool := true
  islanding-alarm    /bool := false
  fault-trip-alarm   /bool := false
  gps-locked         /bool := true

  // Analog telemetry registers (scaled integers)
  frequency-x100     /int := 6000  // 60.00 Hz
  rocof-x100         /int := 0     // 0.00 Hz/s
  va-rms-x10         /int := 1200  // 120.0 V
  vb-rms-x10         /int := 1200
  vc-rms-x10         /int := 1200
  ia-rms-x100        /int := 500   // 5.00 A
  ib-rms-x100        /int := 500
  ic-rms-x100        /int := 500
  p-active-x10       /int := 0     // kW
  q-reactive-x10     /int := 0     // kVar
  power-factor-x1000 /int := 1000  // 1.000 PF
  v0-mag-x10         /int := 0     // V0 sequence
  v1-mag-x10         /int := 1200  // V1 sequence
  v2-mag-x10         /int := 0     // V2 sequence
  vuf-x100           /int := 0     // VUF (%)
  fault-type-code    /int := 0

  /**
  Update telemetry registers from active PMU engine measurements.
  */
  update-telemetry
      --freq/float
      --rocof/float
      --va-mag/float
      --vb-mag/float
      --vc-mag/float
      --ia-mag/float
      --ib-mag/float
      --ic-mag/float
      --p-kw/float
      --q-kvar/float
      --v0/float
      --v1/float
      --v2/float
      --vuf/float
      --fault-code/int
      --tripped/bool
      --islanded/bool -> none:
    frequency-x100 = (freq * 100.0).round.to-int
    rocof-x100 = (rocof * 100.0).round.to-int
    va-rms-x10 = (va-mag * 10.0).round.to-int
    vb-rms-x10 = (vb-mag * 10.0).round.to-int
    vc-rms-x10 = (vc-mag * 10.0).round.to-int
    ia-rms-x100 = (ia-mag * 100.0).round.to-int
    ib-rms-x100 = (ib-mag * 100.0).round.to-int
    ic-rms-x100 = (ic-mag * 100.0).round.to-int
    p-active-x10 = (p-kw * 10.0).round.to-int
    q-reactive-x10 = (q-kvar * 10.0).round.to-int
    v0-mag-x10 = (v0 * 10.0).round.to-int
    v1-mag-x10 = (v1 * 10.0).round.to-int
    v2-mag-x10 = (v2 * 10.0).round.to-int
    vuf-x100 = (vuf * 100.0).round.to-int
    fault-type-code = fault-code
    fault-trip-alarm = tripped
    islanding-alarm = islanded
    if tripped or islanded:
      breaker-closed = false

  /** Read 16-bit input register at address $addr (0-indexed). */
  read-input-register addr/int -> int:
    if addr == 0:  return frequency-x100
    if addr == 1:  return rocof-x100 & 0xFFFF
    if addr == 2:  return va-rms-x10
    if addr == 3:  return vb-rms-x10
    if addr == 4:  return vc-rms-x10
    if addr == 5:  return ia-rms-x100
    if addr == 6:  return ib-rms-x100
    if addr == 7:  return ic-rms-x100
    if addr == 8:  return p-active-x10 & 0xFFFF
    if addr == 9:  return q-reactive-x10 & 0xFFFF
    if addr == 10: return power-factor-x1000
    if addr == 11: return v0-mag-x10
    if addr == 12: return v1-mag-x10
    if addr == 13: return v2-mag-x10
    if addr == 14: return vuf-x100
    if addr == 15: return fault-type-code
    throw "Illegal data address: $addr"

  /** Read discrete input bit at address $addr. */
  read-discrete-input addr/int -> bool:
    if addr == 0: return breaker-closed
    if addr == 1: return islanding-alarm
    if addr == 2: return fault-trip-alarm
    if addr == 3: return gps-locked
    throw "Illegal discrete input address: $addr"
