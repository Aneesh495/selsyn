// Selsyn: IEEE C37.118 Synchrophasor Measurement and Grid Stability Controller
// Main executable entrypoint and diagnostics dashboard.

import math
import .engine show PmuEngine
import .protocol.data_frame show PhasorFormat
import .protocol.command_frame show CommandFrame

main args/List:
  print "================================================================="
  print "  SELSYN: Real-Time IEEE C37.118 Synchrophasor Measurement Unit"
  print "  Grid Frequency Stability Controller and Fault Classifier"
  print "================================================================="

  pmu := PmuEngine
    --id-code=101
    --station-name="SELSYN_SUB_ALPHA"
    --nominal-frequency=60.0
    --samples-per-cycle=64
    --reporting-rate=50

  print "PMU Engine initialized:"
  print "  Station: $(pmu.station-name)"
  print "  Base Frequency: $(pmu.nominal-frequency) Hz"
  print "  Sampling Rate: $(pmu.sampling-rate) Hz (64 samples/cycle)"
  print "  Reporting Rate: $(pmu.reporting-rate) frames/sec"

  // Enable data streaming simulation
  start-cmd := CommandFrame
    --id-code=101
    --soc=1731000000
    --fracsec=0
    --command-word=CommandFrame.CMD-START-TRANSMISSION

  pmu.streamer.handle-command start-cmd.encode null

  print "\nRunning 2-second real-time grid telemetry simulation..."
  total-steps := (pmu.sampling-rate * 2.0).round.to-int

  v-peak := 120.0 * (math.sqrt 2.0)
  i-peak := 5.0 * (math.sqrt 2.0)
  dt := 1.0 / pmu.sampling-rate

  reports-count := 0
  for step := 0; step < total-steps; step++:
    t := step.to-float * dt

    // Normal balanced three-phase 60 Hz signals
    theta-a := 2.0 * math.PI * 60.0 * t
    theta-b := theta-a - (2.0 * math.PI / 3.0)
    theta-c := theta-a + (2.0 * math.PI / 3.0)

    va := v-peak * (math.cos theta-a)
    vb := v-peak * (math.cos theta-b)
    vc := v-peak * (math.cos theta-c)

    ia := i-peak * (math.cos theta-a)
    ib := i-peak * (math.cos theta-b)
    ic := i-peak * (math.cos theta-c)

    // Introduce single-phase ground fault transient at t = 1.0s
    if t >= 1.0 and t < 1.15:
      va = 12.0 * (math.cos theta-a)  // 90% voltage collapse on Phase A
      ia = 45.0 * (math.cos theta-a)  // 9x current surge

    df := pmu.process-sample [va, vb, vc, ia, ib, ic]
    if df:
      reports-count++
      if (reports-count % 25) == 0:
        b := df.blocks[0]
        p-va := b.phasors[0]
        print "  [T=$(%4.2f t)s] Freq: $(%5.2f b.frequency) Hz | ROCOF: $(%5.2f b.rocof) Hz/s | Va: $(%5.1f p-va.magnitude) V | Status: $(%04x b.stat)"

  print "\nSimulation Complete."
  print "  Total Samples Ingested: $total-steps"
  print "  Total IEEE C37.118 DATA Frames Generated: $reports-count"
  print "  Fault Trigger State: $(pmu.tripped ? "TRIPPED" : "NORMAL")"
  print "  p50 Latency: $(%4.2f pmu.metrics.p50) ms | p99 Latency: $(%4.2f pmu.metrics.p99) ms"
  print "================================================================="
