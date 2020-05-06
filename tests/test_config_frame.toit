// Selsyn test suite: IEEE C37.118 Configuration Frame (CFG-2) encoding.

import ..src.protocol.config_frame show ConfigFrame PmuConfig PhasorUnit
import ..src.protocol.frame show Frame
import ..src.protocol.crc16 show CrcCcitt

main:
  id := 101
  soc := 1731000000
  fracsec := 0x00000000

  pu-va := PhasorUnit --is-current=false --scale-factor=1.0
  pu-vb := PhasorUnit --is-current=false --scale-factor=1.0
  pu-vc := PhasorUnit --is-current=false --scale-factor=1.0
  pu-ia := PhasorUnit --is-current=true  --scale-factor=1.0

  pmu-cfg := PmuConfig
    --station-name="SUBSTATION_ALPHA"
    --id-code=id
    --data-format=0x000F  // float rectangular
    --channel-names=["VA", "VB", "VC", "IA", "AMBIENT_TEMP"]
    --phasor-units=[pu-va, pu-vb, pu-vc, pu-ia]
    --analog-units=[1.0]
    --digital-masks=[0x00000000]
    --nominal-frequency=60.0

  cfg-frame := ConfigFrame
    --id-code=id
    --soc=soc
    --fracsec=fracsec
    --is-cfg2=true
    --time-base=1000000
    --pmu-configs=[pmu-cfg]
    --data-rate=50
    --cfg-count=1

  // 1. Encode configuration frame
  bytes := cfg-frame.encode
  if bytes.size != cfg-frame.frame-size:
    throw "Config frame size mismatch: expected $(cfg-frame.frame-size), got $(bytes.size)"

  // 2. Verify CRC-CCITT checksum
  if not (CrcCcitt.verify bytes):
    throw "Config frame failed CRC check"

  // 3. Verify sync word (CFG-2: 0xAA31)
  sync := (bytes[0] << 8) | bytes[1]
  if sync != 0xAA31:
    throw "Config frame sync mismatch: expected 0xAA31, got 0x$(%x sync)"

  // 4. Verify base header parsing
  parsed := Frame.parse-header bytes
  if parsed.frame-type != Frame.TYPE-CFG2:
    throw "Parsed type mismatch: expected CFG-2 (0x30), got 0x$(%x parsed.frame-type)"
  if parsed.id-code != id:
    throw "Parsed ID mismatch: expected $id, got $(parsed.id-code)"

  print "test_config_frame: ALL TESTS PASSED."
