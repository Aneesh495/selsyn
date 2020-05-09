// Selsyn test suite: Synchrophasor streamer session and command handling.

import net
import ..src.protocol.streamer show SynchrophasorStreamer
import ..src.protocol.config_frame show ConfigFrame PmuConfig PhasorUnit
import ..src.protocol.header_frame show HeaderFrame
import ..src.protocol.command_frame show CommandFrame
import ..src.protocol.crc16 show CrcCcitt

main:
  id := 101
  soc := 1731000000

  pmu-cfg := PmuConfig
    --station-name="TEST_STATION"
    --id-code=id
    --channel-names=["VA", "VB", "VC"]
    --phasor-units=[PhasorUnit, PhasorUnit, PhasorUnit]
    --nominal-frequency=60.0

  cfg := ConfigFrame
    --id-code=id
    --soc=soc
    --fracsec=0
    --pmu-configs=[pmu-cfg]

  hdr := HeaderFrame
    --id-code=id
    --soc=soc
    --fracsec=0
    --header-data="TEST HDR METADATA"

  streamer := SynchrophasorStreamer
    --id-code=id
    --config-frame=cfg
    --header-frame=hdr

  client-addr := net.SocketAddress (net.IpAddress.parse "127.0.0.1") 4712

  // 1. Test CFG-2 Request Command
  cmd-cfg := CommandFrame
    --id-code=id
    --soc=soc
    --fracsec=0
    --command-word=CommandFrame.CMD-SEND-CFG2
  resp-cfg := streamer.handle-command cmd-cfg.encode client-addr
  if resp-cfg.size != 1:
    throw "Expected 1 response for CFG2 request, got $(resp-cfg.size)"
  if not (CrcCcitt.verify resp-cfg[0]):
    throw "Streamer CFG2 response failed CRC check"

  // 2. Test HDR Request Command
  cmd-hdr := CommandFrame
    --id-code=id
    --soc=soc
    --fracsec=0
    --command-word=CommandFrame.CMD-SEND-HDR
  resp-hdr := streamer.handle-command cmd-hdr.encode client-addr
  if resp-hdr.size != 1:
    throw "Expected 1 response for HDR request"

  // 3. Test Start Transmission
  cmd-start := CommandFrame
    --id-code=id
    --soc=soc
    --fracsec=0
    --command-word=CommandFrame.CMD-START-TRANSMISSION
  streamer.handle-command cmd-start.encode client-addr
  if not streamer.is-streaming:
    throw "Streamer failed to start transmission"
  if streamer.subscribers.size != 1:
    throw "Client was not added to subscribers"

  // 4. Test Stop Transmission
  cmd-stop := CommandFrame
    --id-code=id
    --soc=soc
    --fracsec=0
    --command-word=CommandFrame.CMD-STOP-TRANSMISSION
  streamer.handle-command cmd-stop.encode client-addr
  if streamer.is-streaming:
    throw "Streamer failed to stop transmission"

  print "test_streamer: ALL TESTS PASSED."
