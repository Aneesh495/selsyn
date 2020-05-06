// Selsyn: IEEE C37.118 Synchrophasor Measurement and Grid Stability Controller
// IEEE C37.118 Header Frame (HDR) Model.

import io show BIG-ENDIAN
import .crc16 show CrcCcitt
import .frame show Frame

/**
IEEE C37.118 Header Frame (HDR).
Carries descriptive ASCII human-readable text regarding PMU hardware, firmware revision,
substation location, and calibration parameters.
*/
class HeaderFrame extends Frame:
  header-data /string

  constructor
      --id-code/int
      --soc/int
      --fracsec/int
      --header-data/string:
    this.header-data = header-data
    total-size := 14 + header-data.size + 2  // Header (14) + Text + CRC (2)
    sync := (Frame.SYNC-BYTE << 8) | Frame.TYPE-HEADER | Frame.VERSION-1
    super sync total-size id-code soc fracsec

  /** Encode Header frame to binary ByteArray with valid CRC. */
  encode -> ByteArray:
    buffer := ByteArray frame-size
    serialize-header buffer 0

    text-bytes := header-data.to-byte-array
    for i := 0; i < text-bytes.size; i++:
      buffer[14 + i] = text-bytes[i]

    CrcCcitt.append-crc buffer
    return buffer

  /** Decode binary ByteArray into HeaderFrame. */
  static decode bytes/ByteArray -> HeaderFrame:
    if not (CrcCcitt.verify bytes):
      throw "CRC failure on Header Frame"
    base := Frame.parse-header bytes
    if base.frame-type != Frame.TYPE-HEADER:
      throw "Invalid frame type: expected HEADER (0x10), got $(%x base.frame-type)"

    text-len := base.frame-size - 16
    text-bytes := bytes[14..(14 + text-len)]
    return HeaderFrame
      --id-code=base.id-code
      --soc=base.soc
      --fracsec=base.fracsec
      --header-data=text-bytes.to-string
