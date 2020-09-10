/**
Copyright (C) 2026 Aneesh Krishna

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import ..src.dsp.complex show Complex
import ..src.protocol.data_frame show DataFrame PmuDataBlock PhasorFormat
import ..src.protocol.crc16 show CrcCcitt

main:
  print "============================================================"
  print " Selsyn Benchmark: IEEE C37.118 Frame Serialization Speed   "
  print "============================================================"

  va := Complex 120.0 0.0
  vb := Complex -60.0 -103.923048
  vc := Complex -60.0 103.923048
  ia := Complex 5.0 -1.0
  ib := Complex -2.5 -4.33
  ic := Complex -2.5 4.33

  block := PmuDataBlock
    --stat=0x0000
    --phasors=[va, vb, vc, ia, ib, ic]
    --frequency=60.002
    --rocof=0.015
    --analogs=[120.0, 5.0]
    --digitals=[0x0001]

  frame := DataFrame
    --id-code=101
    --soc=1731000000
    --fracsec=0x00001234
    --blocks=[block]

  total-frames := 50000

  start-us := Time.monotonic-us

  for i := 0; i < total-frames; i++:
    bytes := frame.encode --phasor-format=PhasorFormat.RECTANGULAR
    // Verify CRC calculation speed
    CrcCcitt.calculate bytes --to=(bytes.size - 2)

  elapsed-us := Time.monotonic-us - start-us
  elapsed-sec := elapsed-us.to-float / 1000000.0
  fps := total-frames.to-float / elapsed-sec

  print "  Encoded:    $total-frames IEEE C37.118 DATA frames"
  print "  Elapsed:    $(%.3f elapsed-sec) seconds"
  print "  Throughput: $(%.1f fps) frames/sec"
  print "  Latency:    $(%.3f (elapsed-us.to-float / total-frames)) microseconds/frame"
  print "============================================================"
