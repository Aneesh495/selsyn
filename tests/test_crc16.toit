// Selsyn test suite: IEEE C37.118 CRC-CCITT verification.

import ..src.protocol.crc16 show CrcCcitt

main:
  // 1. Standard test vector: "123456789" -> 0x29B1
  test-bytes := "123456789".to-byte-array
  crc := CrcCcitt.calculate test-bytes
  if crc != 0x29B1:
    throw "Standard test vector CRC mismatch: expected 0x29B1, got 0x$(%x crc)"

  // 2. Empty byte array
  empty := ByteArray 0
  crc-empty := CrcCcitt.calculate empty
  if crc-empty != 0xFFFF:
    throw "Empty CRC mismatch: expected 0xFFFF, got 0x$(%x crc-empty)"

  // 3. Append and verify CRC on a frame buffer
  frame := ByteArray 16: 0xAA
  CrcCcitt.append-crc frame
  if not (CrcCcitt.verify frame):
    throw "Failed to verify appended CRC on valid frame"

  // 4. Corrupt a byte and verify detection
  frame[5] ^= 0x01
  if CrcCcitt.verify frame:
    throw "CRC failed to detect corrupted byte in frame"

  print "test_crc16: ALL TESTS PASSED."
