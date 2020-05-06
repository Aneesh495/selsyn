// Selsyn: IEEE C37.118 Synchrophasor Measurement and Grid Stability Controller
// IEEE C37.118 Command Frame (CMD) Model and Dispatcher.

import io show BIG-ENDIAN
import .crc16 show CrcCcitt
import .frame show Frame

/**
IEEE C37.118 Northbound Command Frame (CMD).
Sent by Phasor Data Concentrators (PDC) to control PMU data streaming and request schemas.
*/
class CommandFrame extends Frame:
  static CMD-STOP-TRANSMISSION  /int ::= 0x0001
  static CMD-START-TRANSMISSION /int ::= 0x0002
  static CMD-SEND-HDR           /int ::= 0x0003
  static CMD-SEND-CFG1          /int ::= 0x0004
  static CMD-SEND-CFG2          /int ::= 0x0005
  static CMD-SEND-CFG3          /int ::= 0x0006
  static CMD-EXTENDED           /int ::= 0x0008

  command-word /int := 0
  extended-data /ByteArray := ByteArray 0

  constructor
      --id-code/int
      --soc/int
      --fracsec/int
      --command-word/int
      --extended-data/ByteArray=(ByteArray 0):
    this.command-word = command-word
    this.extended-data = extended-data
    total-size := 14 + 2 + extended-data.size + 2  // Header (14) + CMD (2) + Ext + CRC (2)
    sync := (Frame.SYNC-BYTE << 8) | Frame.TYPE-CMD | Frame.VERSION-1
    super sync total-size id-code soc fracsec

  /** Encode command frame to binary ByteArray with valid CRC. */
  encode -> ByteArray:
    buffer := ByteArray frame-size
    serialize-header buffer 0

    BIG-ENDIAN.put-uint16 buffer 14 command-word
    for i := 0; i < extended-data.size; i++:
      buffer[16 + i] = extended-data[i]

    CrcCcitt.append-crc buffer
    return buffer

  /** Decode binary ByteArray into CommandFrame. */
  static decode bytes/ByteArray -> CommandFrame:
    if not (CrcCcitt.verify bytes):
      throw "CRC failure on Command Frame"
    base := Frame.parse-header bytes
    if base.frame-type != Frame.TYPE-CMD:
      throw "Invalid frame type: expected CMD (0x40), got $(%x base.frame-type)"

    cmd := BIG-ENDIAN.uint16 bytes 14
    ext-len := base.frame-size - 18
    ext := (ext-len > 0) ? bytes[16..(16 + ext-len)] : (ByteArray 0)

    return CommandFrame
      --id-code=base.id-code
      --soc=base.soc
      --fracsec=base.fracsec
      --command-word=cmd
      --extended-data=ext
