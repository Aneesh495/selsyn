// Selsyn test suite: IEEE C37.118 DATA frame encode and decode.

import ..src.dsp.complex show Complex
import ..src.protocol.data_frame show DataFrame PmuDataBlock PhasorFormat
import ..src.protocol.crc16 show CrcCcitt

main:
  id := 101
  soc := 1731000000
  fracsec := 0x00001234  // GPS locked, fraction count

  va := Complex 120.0 0.0
  vb := Complex -60.0 -103.923048
  vc := Complex -60.0 103.923048
  vn := Complex.zero

  block := PmuDataBlock
    --stat=0x0000
    --phasors=[va, vb, vc, vn]
    --frequency=59.98
    --rocof=-0.05
    --analogs=[25.4, 1.05]
    --digitals=[0x0001]

  frame := DataFrame
    --id-code=id
    --soc=soc
    --fracsec=fracsec
    --blocks=[block]

  // 1. Encode to binary
  bytes := frame.encode --phasor-format=PhasorFormat.RECTANGULAR
  if bytes.size != frame.frame-size:
    throw "Encoded frame size mismatch: expected $(frame.frame-size), got $(bytes.size)"

  // 2. Verify CRC
  if not (CrcCcitt.verify bytes):
    throw "DATA frame failed CRC check"

  // 3. Decode frame back
  decoded := DataFrame.decode bytes
    --phasor-count=4
    --analog-count=2
    --digital-count=1
    --phasor-format=PhasorFormat.RECTANGULAR

  if decoded.id-code != id:
    throw "IDCODE mismatch: expected $id, got $(decoded.id-code)"
  if decoded.soc != soc:
    throw "SOC mismatch: expected $soc, got $(decoded.soc)"
  if decoded.fracsec != fracsec:
    throw "FRACSEC mismatch: expected $fracsec, got $(decoded.fracsec)"

  d-block /PmuDataBlock := decoded.blocks[0]
  if (d-block.frequency - 59.98).abs > 1e-4:
    throw "Decoded frequency mismatch: expected 59.98, got $(d-block.frequency)"
  if (d-block.rocof - (-0.05)).abs > 1e-4:
    throw "Decoded ROCOF mismatch: expected -0.05, got $(d-block.rocof)"

  d-va /Complex := d-block.phasors[0]
  if (d-va.real - 120.0).abs > 1e-4 or d-va.imag.abs > 1e-4:
    throw "Decoded Va mismatch: expected 120.0 + j0.0, got $d-va"

  d-analog := d-block.analogs[0]
  if (d-analog - 25.4).abs > 1e-4:
    throw "Decoded analog mismatch: expected 25.4, got $d-analog"

  d-dig := d-block.digitals[0]
  if d-dig != 0x0001:
    throw "Decoded digital status mismatch: expected 0x0001, got $d-dig"

  print "test_data_frame: ALL TESTS PASSED."
