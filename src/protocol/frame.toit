// Selsyn: IEEE C37.118 Synchrophasor Measurement and Grid Stability Controller
// IEEE C37.118 Base Frame Representation and Time Synchronization Tags.

import io show BIG-ENDIAN
import .crc16 show CrcCcitt

/**
Base representation for IEEE C37.118 binary frames.
Provides common header parsing, time-tag extraction, and integrity verification.
*/
class Frame:
  // Frame type synchronization masks
  static TYPE-DATA   /int ::= 0x00
  static TYPE-HEADER /int ::= 0x10
  static TYPE-CFG1   /int ::= 0x20
  static TYPE-CFG2   /int ::= 0x30
  static TYPE-CMD    /int ::= 0x40
  static TYPE-CFG3   /int ::= 0x50

  static SYNC-BYTE   /int ::= 0xAA
  static VERSION-1   /int ::= 0x01
  static VERSION-2   /int ::= 0x02

  sync-word   /int := 0
  frame-size  /int := 0
  id-code     /int := 0
  soc         /int := 0
  fracsec     /int := 0

  constructor .sync-word .frame-size .id-code .soc .fracsec:

  /** Extract frame type nibble from sync word. */
  frame-type -> int:
    return sync-word & 0x70

  /** Extract protocol version number from sync word. */
  version -> int:
    return sync-word & 0x0F

  /** Time quality indicator code (0 = GPS lock < 100ns, 1-15 = degraded). */
  time-quality -> int:
    return (fracsec >> 24) & 0x0F

  /** Sub-second fraction count (24-bit integer). */
  fraction-of-second -> int:
    return fracsec & 0x00FFFFFF

  /** Check whether leap second is pending. */
  leap-second-pending -> bool:
    return ((fracsec >> 24) & 0x20) != 0

  /**
  Serialize common 14-byte IEEE C37.118 frame header into $buffer starting at $offset.
  */
  serialize-header buffer/ByteArray offset/int -> none:
    BIG-ENDIAN.put-uint16 buffer offset sync-word
    BIG-ENDIAN.put-uint16 buffer (offset + 2) frame-size
    BIG-ENDIAN.put-uint16 buffer (offset + 4) id-code
    BIG-ENDIAN.put-uint32 buffer (offset + 6) soc
    BIG-ENDIAN.put-uint32 buffer (offset + 10) fracsec

  /**
  Parse common header fields from a raw frame byte array.
  */
  static parse-header bytes/ByteArray -> Frame:
    if bytes.size < 14:
      throw "Frame buffer underflow: minimum 14 bytes required for IEEE C37.118 header"
    if bytes[0] != SYNC-BYTE:
      throw "Invalid sync byte: expected 0xAA, got $(%x bytes[0])"

    sync := BIG-ENDIAN.uint16 bytes 0
    size := BIG-ENDIAN.uint16 bytes 2
    id := BIG-ENDIAN.uint16 bytes 4
    soc-val := BIG-ENDIAN.uint32 bytes 6
    fracsec-val := BIG-ENDIAN.uint32 bytes 10

    if size > bytes.size:
      throw "Incomplete frame: specified framesize $size exceeds buffer $(bytes.size)"

    return Frame sync size id soc-val fracsec-val
