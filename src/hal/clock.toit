// Selsyn: IEEE C37.118 Synchrophasor Measurement and Grid Stability Controller
// High-Precision GPS PPS Synchronized Timekeeper and FRACSEC Generator.

/**
GPS Pulse-Per-Second (PPS) disciplined timekeeper for IEEE C37.118 compliance.
Maintains UTC Second of Century (SOC) and 24-bit fraction-of-second tags.
*/
class PpsTimekeeper:
  soc                /int := 0   // Seconds since 1970-01-01 00:00:00 UTC
  time-base          /int := 1000000  // 1 microsecond resolution
  gps-locked         /bool := true
  time-quality-code  /int := 0   // 0 = Locked < 100ns, 1-15 = degraded
  leap-sec-pending   /bool := false
  leap-sec-occurred  /bool := false

  // Sub-second microsecond accumulator
  microsecond-offset /int := 0

  constructor --initial-soc/int=1731000000 --time-base/int=1000000:
    this.soc = initial-soc
    this.time-base = time-base

  /**
  GPS Pulse-Per-Second (PPS) hardware interrupt callback.
  Pins timekeeper precisely to the top of the next second.
  */
  on-pps-pulse -> none:
    soc++
    microsecond-offset = 0
    gps-locked = true
    time-quality-code = 0

  /**
  Advance internal time by $delta-us microseconds from high-resolution hardware timer.
  */
  tick-microseconds delta-us/int -> none:
    microsecond-offset += delta-us
    while microsecond-offset >= 1000000:
      microsecond-offset -= 1000000
      soc++

  /**
  Generate IEEE C37.118 32-bit FRACSEC word:
    Bit 31: Leap second direction (0 = add, 1 = delete)
    Bit 30: Leap second occurred
    Bit 29: Leap second pending
    Bit 27-24: Time quality code (0x0 - 0xF)
    Bit 23-0: Fraction of second (24-bit count: microsecond_offset * 2^24 / 1,000,000)
  */
  fracsec -> int:
    flags := 0
    if leap-sec-occurred: flags |= (1 << 30)
    if leap-sec-pending:  flags |= (1 << 29)
    if not gps-locked:
      // Degraded clock status
      flags |= (0x0B << 24)
    else:
      flags |= ((time-quality-code & 0x0F) << 24)

    // Convert microseconds to 24-bit fraction count
    // frac_count = us * 16777216 / 1000000
    frac-count := ((microsecond-offset.to-float * 16777216.0) / 1000000.0).round.to-int & 0x00FFFFFF

    return flags | frac-count
