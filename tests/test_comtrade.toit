// Selsyn test suite: IEEE C37.111 COMTRADE file emission.

import ..src.storage.fault_recorder show OscillogramSnapshot
import ..src.storage.comtrade show ComtradeWriter

main:
  writer := ComtradeWriter --station-name="TEST_SUB" --device-id="PMU_99"

  ch-names := ["VA", "VB", "IA"]
  ch-data := [
    [120.0, 119.5, 118.0, 10.0, 10.0],
    [-60.0, -59.8, -59.0, -60.0, -60.0],
    [5.0, 5.0, 5.1, 45.0, 48.0]
  ]

  snap := OscillogramSnapshot
    "TRIP_OVERCURRENT"
    3
    3840.0
    ch-names
    ch-data

  // 1. Generate CFG configuration
  cfg-str := writer.generate-cfg snap
  if not (cfg-str.contains "TEST_SUB,PMU_99,1999"):
    throw "CFG station header mismatch"
  if not (cfg-str.contains "3,3A,0D"):
    throw "CFG channel counts mismatch"
  if not (cfg-str.contains "ASCII"):
    throw "CFG format indicator mismatch"

  // 2. Generate DAT data
  dat-str := writer.generate-dat snap
  lines := dat-str.split "\r\n"
  if lines[0] != "1,0,120.0,-60.0,5.0":
    throw "First DAT row mismatch: got '$(lines[0])'"

  print "test_comtrade: ALL TESTS PASSED."
