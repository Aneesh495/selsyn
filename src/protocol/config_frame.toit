// Selsyn: IEEE C37.118 Synchrophasor Measurement and Grid Stability Controller
// IEEE C37.118 CFG-1 and CFG-2 Configuration Frame Models.

import io show BIG-ENDIAN
import .crc16 show CrcCcitt
import .frame show Frame

/**
PMU channel unit descriptor.
*/
class PhasorUnit:
  is-current   /bool := false  // false = voltage, true = current
  scale-factor /float := 1.0

  constructor --is-current/bool=false --scale-factor/float=1.0:
    this.is-current = is-current
    this.scale-factor = scale-factor

/**
Configuration specification for a single PMU within a stream.
*/
class PmuConfig:
  station-name /string
  id-code      /int
  data-format  /int := 0x000F  // Default: float freq, float analog, float phasor, rectangular
  channel-names /List := []    // List of 16-character string channel names
  phasor-units  /List := []    // List of PhasorUnit
  analog-units  /List := []    // List of float scaling factors
  digital-masks /List := []    // List of int 32-bit normal/trigger mask words
  nominal-frequency /float := 60.0

  constructor
      --station-name/string
      --id-code/int
      --data-format/int=0x000F
      --channel-names/List=[]
      --phasor-units/List=[]
      --analog-units/List=[]
      --digital-masks/List=[]
      --nominal-frequency/float=60.0:
    this.station-name = pad-string station-name 16
    this.id-code = id-code
    this.data-format = data-format
    this.channel-names = channel-names.map: | name/string | pad-string name 16
    this.phasor-units = phasor-units
    this.analog-units = analog-units
    this.digital-masks = digital-masks
    this.nominal-frequency = nominal-frequency

  static pad-string s/string target-len/int -> string:
    if s.size >= target-len:
      return s[0..target-len]
    pad-len := target-len - s.size
    pad-bytes := ByteArray pad-len: 0x20  // ASCII space
    return s + pad-bytes.to-string

/**
IEEE C37.118 Configuration Frame (CFG-1 or CFG-2).
*/
class ConfigFrame extends Frame:
  time-base   /int := 1000000  // Microsecond tick resolution
  pmu-configs /List := []      // List of PmuConfig
  data-rate   /int := 50       // Frames per second
  cfg-count   /int := 1

  constructor
      --id-code/int
      --soc/int
      --fracsec/int
      --is-cfg2/bool=true
      --time-base/int=1000000
      --pmu-configs/List
      --data-rate/int=50
      --cfg-count/int=1:
    this.time-base = time-base
    this.pmu-configs = pmu-configs
    this.data-rate = data-rate
    this.cfg-count = cfg-count

    // Calculate total frame size
    // Base Header (14) + TIME_BASE (4) + NUM_PMU (2)
    payload-size := 6
    pmu-configs.do: | cfg/PmuConfig |
      // STN (16) + IDCODE (2) + FORMAT (2) + PHNMR (2) + ANNMR (2) + DGNMR (2) = 26 bytes
      p-size := 26
      // Channel names: (PHNMR + ANNMR + 16*DGNMR) * 16 bytes
      total-channels := cfg.phasor-units.size + cfg.analog-units.size + (cfg.digital-masks.size * 16)
      p-size += total-channels * 16
      // Conversion factors: PHUNIT (4 * PHNMR) + ANUNIT (4 * ANNMR) + DIGUNIT (4 * DGNMR)
      p-size += (cfg.phasor-units.size * 4) + (cfg.analog-units.size * 4) + (cfg.digital-masks.size * 4)
      // FNOM (2) + CFGCNT (2)
      p-size += 4
      payload-size += p-size

    // DATA_RATE (2) + CRC (2)
    total-size := 14 + payload-size + 2 + 2

    type-nibble := is-cfg2 ? Frame.TYPE-CFG2 : Frame.TYPE-CFG1
    sync := (Frame.SYNC-BYTE << 8) | type-nibble | Frame.VERSION-1
    super sync total-size id-code soc fracsec

  /**
  Serialize configuration frame to binary ByteArray with valid CRC.
  */
  encode -> ByteArray:
    buffer := ByteArray frame-size
    serialize-header buffer 0

    offset := 14
    BIG-ENDIAN.put-uint32 buffer offset time-base
    BIG-ENDIAN.put-uint16 buffer (offset + 4) pmu-configs.size
    offset += 6

    pmu-configs.do: | cfg/PmuConfig |
      // 1. Station name (16 bytes ASCII)
      stn-bytes := cfg.station-name.to-byte-array
      for i := 0; i < 16; i++:
        buffer[offset + i] = (i < stn-bytes.size) ? stn-bytes[i] : 0x20
      offset += 16

      // 2. IDCODE, FORMAT, PHNMR, ANNMR, DGNMR
      BIG-ENDIAN.put-uint16 buffer offset cfg.id-code
      BIG-ENDIAN.put-uint16 buffer (offset + 2) cfg.data-format
      BIG-ENDIAN.put-uint16 buffer (offset + 4) cfg.phasor-units.size
      BIG-ENDIAN.put-uint16 buffer (offset + 6) cfg.analog-units.size
      BIG-ENDIAN.put-uint16 buffer (offset + 8) cfg.digital-masks.size
      offset += 10

      // 3. Channel names (16 bytes each)
      cfg.channel-names.do: | ch-name/string |
        c-bytes := ch-name.to-byte-array
        for i := 0; i < 16; i++:
          buffer[offset + i] = (i < c-bytes.size) ? c-bytes[i] : 0x20
        offset += 16

      // 4. Phasor conversion factors (4 bytes each)
      cfg.phasor-units.do: | pu/PhasorUnit |
        // Bit 31: 0 for voltage, 1 for current. Lower 24 bits: integer scaling factor
        flag := pu.is-current ? 1 : 0
        raw-val := (flag << 31) | 0x00000001
        BIG-ENDIAN.put-uint32 buffer offset raw-val
        offset += 4

      // 5. Analog conversion factors (4 bytes each)
      cfg.analog-units.do: | au/float |
        BIG-ENDIAN.put-uint32 buffer offset 0x00000001
        offset += 4

      // 6. Digital channel masks (4 bytes each)
      cfg.digital-masks.do: | dm/int |
        BIG-ENDIAN.put-uint32 buffer offset dm
        offset += 4

      // 7. Nominal line frequency (0 = 60 Hz, 1 = 50 Hz) and CFGCNT
      fnom-code := (cfg.nominal-frequency == 50.0) ? 1 : 0
      BIG-ENDIAN.put-uint16 buffer offset fnom-code
      BIG-ENDIAN.put-uint16 buffer (offset + 2) cfg-count
      offset += 4

    // 8. DATA_RATE
    BIG-ENDIAN.put-int16 buffer offset data-rate
    offset += 2

    // 9. Append CRC-CCITT
    CrcCcitt.append-crc buffer
    return buffer
