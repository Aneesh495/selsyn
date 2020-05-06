// Selsyn test suite: IEEE C37.118 Header and Command frame handling.

import ..src.protocol.header_frame show HeaderFrame
import ..src.protocol.command_frame show CommandFrame
import ..src.protocol.crc16 show CrcCcitt

main:
  id := 101
  soc := 1731000000
  fracsec := 0

  // 1. Test Header Frame encode & decode
  meta-text := "SELSYN PMU STATION ALPHA - FIRMWARE 1.0.0"
  hdr := HeaderFrame
    --id-code=id
    --soc=soc
    --fracsec=fracsec
    --header-data=meta-text

  hdr-bytes := hdr.encode
  if not (CrcCcitt.verify hdr-bytes):
    throw "Header frame failed CRC verification"

  d-hdr := HeaderFrame.decode hdr-bytes
  if d-hdr.header-data != meta-text:
    throw "Header text mismatch: expected '$meta-text', got '$(d-hdr.header-data)'"

  // 2. Test Command Frame encode & decode
  cmd-start := CommandFrame
    --id-code=id
    --soc=soc
    --fracsec=fracsec
    --command-word=CommandFrame.CMD-START-TRANSMISSION

  cmd-bytes := cmd-start.encode
  if not (CrcCcitt.verify cmd-bytes):
    throw "Command frame failed CRC verification"

  d-cmd := CommandFrame.decode cmd-bytes
  if d-cmd.command-word != CommandFrame.CMD-START-TRANSMISSION:
    throw "Command word mismatch: expected 0x0002, got 0x$(%x d-cmd.command-word)"

  // 3. Test CFG-2 Request Command
  cmd-cfg := CommandFrame
    --id-code=id
    --soc=soc
    --fracsec=fracsec
    --command-word=CommandFrame.CMD-SEND-CFG2

  cmd-cfg-bytes := cmd-cfg.encode
  d-cmd-cfg := CommandFrame.decode cmd-cfg-bytes
  if d-cmd-cfg.command-word != CommandFrame.CMD-SEND-CFG2:
    throw "CFG request command mismatch"

  print "test_command_and_header: ALL TESTS PASSED."
