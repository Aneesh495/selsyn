// Selsyn: IEEE C37.118 Synchrophasor Measurement and Grid Stability Controller
// Central PMU Runtime Engine.

import math
import .dsp.complex show Complex
import .dsp.dft show RecursiveDft
import .dsp.pll show DsogiPll
import .dsp.rocof show RocofFilter
import .symmetrical.fortescue show SymmetricalComponents
import .symmetrical.unbalance show UnbalanceMetrics
import .symmetrical.classifier show FaultClassifier FaultType FaultRecord
import .control.droop show DroopController
import .control.islanding show IslandingDetector
import .control.vsg show VirtualSynchronousGenerator
import .storage.fault_recorder show TransientFaultRecorder
import .storage.comtrade show ComtradeWriter
import .protocol.data_frame show DataFrame PmuDataBlock PhasorFormat
import .protocol.config_frame show ConfigFrame PmuConfig PhasorUnit
import .protocol.header_frame show HeaderFrame
import .protocol.streamer show SynchrophasorStreamer
import .modbus.register_map show ModbusRegisterMap
import .modbus.modbus_tcp show ModbusTcpServer
import .telemetry.metrics show StreamMetrics
import .hal.clock show PpsTimekeeper

/**
Central PMU engine running on the embedded microcontroller.
Coordinates DSP signal processing, symmetrical protection, stability control,
transient recording, and IEEE C37.118 streaming.
*/
class PmuEngine:
  id-code            /int
  station-name       /string
  nominal-frequency  /float
  sampling-rate      /float
  samples-per-cycle  /int
  reporting-rate     /int  // Frames per second (e.g. 50)

  // Subsystems
  timekeeper         /PpsTimekeeper
  rdft-va            /RecursiveDft
  rdft-vb            /RecursiveDft
  rdft-vc            /RecursiveDft
  rdft-ia            /RecursiveDft
  rdft-ib            /RecursiveDft
  rdft-ic            /RecursiveDft

  pll                /DsogiPll
  rocof-filter       /RocofFilter
  classifier         /FaultClassifier
  droop              /DroopController
  islanding          /IslandingDetector
  vsg                /VirtualSynchronousGenerator
  recorder           /TransientFaultRecorder
  comtrade-writer    /ComtradeWriter

  modbus-map         /ModbusRegisterMap
  modbus-server      /ModbusTcpServer
  metrics            /StreamMetrics

  config-frame       /ConfigFrame
  header-frame       /HeaderFrame
  streamer           /SynchrophasorStreamer

  // Operational states
  current-freq       /float := 60.0
  current-rocof      /float := 0.0
  latest-v-sym       /SymmetricalComponents? := null
  latest-i-sym       /SymmetricalComponents? := null
  latest-fault       /FaultRecord? := null
  is-islanded        /bool := false
  tripped            /bool := false

  sample-step-count  /int := 0
  report-interval    /int := 0

  constructor
      --id-code/int=101
      --station-name/string="SELSYN_STATION_ALPHA"
      --nominal-frequency/float=60.0
      --samples-per-cycle/int=64
      --reporting-rate/int=50:
    this.id-code = id-code
    this.station-name = station-name
    this.nominal-frequency = nominal-frequency
    this.samples-per-cycle = samples-per-cycle
    this.reporting-rate = reporting-rate
    this.sampling-rate = nominal-frequency * samples-per-cycle.to-float
    this.report-interval = (sampling-rate / reporting-rate.to-float).round.to-int

    // Initialize subsystems
    this.timekeeper = PpsTimekeeper
    this.rdft-va = RecursiveDft --samples-per-cycle=samples-per-cycle --nominal-frequency=nominal-frequency
    this.rdft-vb = RecursiveDft --samples-per-cycle=samples-per-cycle --nominal-frequency=nominal-frequency
    this.rdft-vc = RecursiveDft --samples-per-cycle=samples-per-cycle --nominal-frequency=nominal-frequency
    this.rdft-ia = RecursiveDft --samples-per-cycle=samples-per-cycle --nominal-frequency=nominal-frequency
    this.rdft-ib = RecursiveDft --samples-per-cycle=samples-per-cycle --nominal-frequency=nominal-frequency
    this.rdft-ic = RecursiveDft --samples-per-cycle=samples-per-cycle --nominal-frequency=nominal-frequency

    this.pll = DsogiPll --nominal-freq=nominal-frequency --sampling-rate=sampling-rate
    this.rocof-filter = RocofFilter --reporting-rate=reporting-rate.to-float
    this.classifier = FaultClassifier
    this.droop = DroopController --nominal-freq=nominal-frequency
    this.islanding = IslandingDetector --nominal-freq=nominal-frequency
    this.vsg = VirtualSynchronousGenerator --nominal-freq=nominal-frequency
    this.recorder = TransientFaultRecorder --sampling-rate=sampling-rate
    this.comtrade-writer = ComtradeWriter --station-name=station-name --device-id="PMU_$(id-code)"

    this.modbus-map = ModbusRegisterMap
    this.modbus-server = ModbusTcpServer modbus-map
    this.metrics = StreamMetrics

    // Setup IEEE C37.118 Configuration
    pu-v := PhasorUnit --is-current=false
    pu-i := PhasorUnit --is-current=true
    pmu-cfg := PmuConfig
      --station-name=station-name
      --id-code=id-code
      --channel-names=["VA", "VB", "VC", "IA", "IB", "IC"]
      --phasor-units=[pu-v, pu-v, pu-v, pu-i, pu-i, pu-i]
      --nominal-frequency=nominal-frequency

    this.config-frame = ConfigFrame
      --id-code=id-code
      --soc=1731000000
      --fracsec=0
      --pmu-configs=[pmu-cfg]
      --data-rate=reporting-rate

    this.header-frame = HeaderFrame
      --id-code=id-code
      --soc=1731000000
      --fracsec=0
      --header-data="SELSYN EMBEDDED SYNCHROPHASOR PMU VERSION 1.0"

    this.streamer = SynchrophasorStreamer
      --id-code=id-code
      --config-frame=config-frame
      --header-frame=header-frame

  /**
  Ingest a single 6-channel instantaneous sample point:
  [v_a, v_b, v_c, i_a, i_b, i_c].
  Returns a DataFrame if this sample coincided with a reporting interval, null otherwise.
  */
  process-sample samples/List -> DataFrame?:
    va-raw := samples[0]
    vb-raw := samples[1]
    vc-raw := samples[2]
    ia-raw := samples[3]
    ib-raw := samples[4]
    ic-raw := samples[5]

    // 1. Advance timekeeper by sampling period (microseconds)
    dt-us := (1000000.0 / sampling-rate).round.to-int
    timekeeper.tick-microseconds dt-us

    // 2. Buffer into transient fault recorder
    rec-done := recorder.process samples
    if rec-done:
      // Transient oscillogram capture ready for persistence
      print "Event oscillogram frozen: $(recorder.latest-snapshot.trigger-reason)"

    // 3. Update recursive DFT phasor estimators (O(1) update)
    va-p := rdft-va.process va-raw
    vb-p := rdft-vb.process vb-raw
    vc-p := rdft-vc.process vc-raw
    ia-p := rdft-ia.process ia-raw
    ib-p := rdft-ib.process ib-raw
    ic-p := rdft-ic.process ic-raw

    // 4. Update DSOGI-PLL grid frequency tracker
    current-freq = pll.process va-raw vb-raw

    sample-step-count++

    // Check reporting rate cadence
    if (sample-step-count % report-interval) == 0:
      return generate-report va-p vb-p vc-p ia-p ib-p ic-p

    return null

  /** Generate periodic synchrophasor report at reporting rate. */
  generate-report
      va-p/Complex vb-p/Complex vc-p/Complex
      ia-p/Complex ib-p/Complex ic-p/Complex -> DataFrame:
    // Update ROCOF filter
    current-rocof = rocof-filter.process current-freq

    // Decompose into symmetrical components
    v-sym := SymmetricalComponents.decompose va-p vb-p vc-p
    i-sym := SymmetricalComponents.decompose ia-p ib-p ic-p
    latest-v-sym = v-sym
    latest-i-sym = i-sym

    // Classify fault conditions
    fault-rec := classifier.classify va-p vb-p vc-p ia-p ib-p ic-p
    latest-fault = fault-rec
    if fault-rec.trip and not tripped:
      tripped = true
      recorder.trigger (FaultType.to-string fault-rec.type)

    // Check anti-islanding protection
    is-island-trip := islanding.process current-freq current-rocof va-p.magnitude va-p.phase
    if is-island-trip and not is-islanded:
      is-islanded = true
      tripped = true
      recorder.trigger "ISLANDING_TRIP_$(islanding.trip-reason)"

    // Dispatch droop active/reactive power setpoints
    droop.dispatch current-freq va-p.magnitude

    // Update Modbus-TCP telemetry registers
    vuf := UnbalanceMetrics.vuf v-sym
    modbus-map.update-telemetry
      --freq=current-freq
      --rocof=current-rocof
      --va-mag=va-p.magnitude
      --vb-mag=vb-p.magnitude
      --vc-mag=vc-p.magnitude
      --ia-mag=ia-p.magnitude
      --ib-mag=ib-p.magnitude
      --ic-mag=ic-p.magnitude
      --p-kw=0.0
      --q-kvar=0.0
      --v0=v-sym.zero.magnitude
      --v1=v-sym.positive.magnitude
      --v2=v-sym.negative.magnitude
      --vuf=vuf
      --fault-code=fault-rec.type
      --tripped=tripped
      --islanded=is-islanded

    // Construct IEEE C37.118 DATA frame
    stat := 0x0000
    if not timekeeper.gps-locked: stat |= 0x4000
    if tripped: stat |= 0x1000

    block := PmuDataBlock
      --stat=stat
      --phasors=[va-p, vb-p, vc-p, ia-p, ib-p, ic-p]
      --frequency=current-freq
      --rocof=current-rocof

    frame := DataFrame
      --id-code=id-code
      --soc=timekeeper.soc
      --fracsec=timekeeper.fracsec
      --blocks=[block]

    metrics.record-latency 0.15
    return frame
