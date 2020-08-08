// Selsyn test suite: Full end-to-end PMU runtime pipeline integration test.

import math
import ..src.engine show PmuEngine
import ..src.protocol.data_frame show DataFrame PmuDataBlock PhasorFormat
import ..src.protocol.crc16 show CrcCcitt

main:
  pmu := PmuEngine
    --id-code=101
    --station-name="TEST_PIPELINE_SUB"
    --nominal-frequency=60.0
    --samples-per-cycle=64
    --reporting-rate=50

  v-peak := 120.0 * (math.sqrt 2.0)
  i-peak := 5.0 * (math.sqrt 2.0)
  dt := 1.0 / pmu.sampling-rate

  // Ingest 250 ms (960 samples = 15 cycles) to allow PLL and filters to prime
  total-steps := (pmu.sampling-rate * 0.25).round.to-int
  latest-df /DataFrame? := null
  for step := 0; step < total-steps; step++:
    t := step.to-float * dt
    th-a := 2.0 * math.PI * 60.0 * t
    th-b := th-a - (2.0 * math.PI / 3.0)
    th-c := th-a + (2.0 * math.PI / 3.0)

    va := v-peak * (math.cos th-a)
    vb := v-peak * (math.cos th-b)
    vc := v-peak * (math.cos th-c)

    ia := i-peak * (math.cos th-a)
    ib := i-peak * (math.cos th-b)
    ic := i-peak * (math.cos th-c)

    df := pmu.process-sample [va, vb, vc, ia, ib, ic]
    if df:
      latest-df = df

  if not latest-df:
    throw "Failed to generate any DataFrame during ingestion"

  // 1. Verify DATA frame encoding and CRC-CCITT
  bytes := latest-df.encode --phasor-format=PhasorFormat.RECTANGULAR
  if not (CrcCcitt.verify bytes):
    throw "Pipeline generated invalid CRC on DATA frame"

  // 2. Verify decoded phasor magnitudes
  block := latest-df.blocks[0]
  va-mag := block.phasors[0].magnitude
  if (va-mag - 120.0).abs > 1.0:
    throw "Steady-state Va magnitude error: expected ~120.0 V, got $va-mag"

  // 3. Verify Modbus telemetry map was updated
  reg-freq := pmu.modbus-map.read-input-register 0
  if (reg-freq - 6000).abs > 10:
    throw "Modbus frequency register mismatch: expected ~6000, got $reg-freq"

  print "test_integration_pipeline: ALL TESTS PASSED."
