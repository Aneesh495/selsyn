// Selsyn: IEEE C37.118 Synchrophasor Measurement and Grid Stability Controller
// Transient Fault Oscillography Event Recorder (DFR).

import .ring_buffer show WaveformRingBuffer

/**
Recording state of the transient fault event recorder.
*/
class RecorderState:
  static IDLE                 /int ::= 0  // Monitoring, circular pre-fault buffering
  static CAPTURING-POST-FAULT /int ::= 1  // Fault triggered, collecting post-fault samples
  static COMPLETED            /int ::= 2  // Snapshot frozen and ready for COMTRADE export

/**
Captured multi-channel oscillography event data snapshot.
*/
class OscillogramSnapshot:
  trigger-reason    /string
  trigger-sample-idx /int
  sampling-rate     /float
  channel-names     /List := []  // List of channel name strings
  channel-data      /List := []  // List of List of floats (each channel's complete sample history)

  constructor
      .trigger-reason
      .trigger-sample-idx
      .sampling-rate
      .channel-names
      .channel-data:

/**
Multi-channel transient fault event recorder.
*/
class TransientFaultRecorder:
  sampling-rate       /float
  pre-fault-samples   /int
  post-fault-samples  /int
  total-samples       /int
  channel-names       /List := []

  // Ring buffers for each physical channel
  channel-buffers     /List := []

  state               /int := RecorderState.IDLE
  post-fault-counter  /int := 0
  trigger-reason      /string := "NONE"
  trigger-sample-idx  /int := 0
  current-sample-idx  /int := 0

  latest-snapshot     /OscillogramSnapshot? := null

  constructor
      --sampling-rate/float=3840.0
      --pre-fault-samples/int=640    // 10 cycles at 64 samples/cycle
      --post-fault-samples/int=1920  // 30 cycles
      --channel-names/List=["VA", "VB", "VC", "IA", "IB", "IC"]:
    this.sampling-rate = sampling-rate
    this.pre-fault-samples = pre-fault-samples
    this.post-fault-samples = post-fault-samples
    this.total-samples = pre-fault-samples + post-fault-samples
    this.channel-names = channel-names

    this.channel-buffers = []
    channel-names.do:
      channel-buffers.add (WaveformRingBuffer total-samples)

  /** Reset recorder back to idle monitoring. */
  reset -> none:
    state = RecorderState.IDLE
    post-fault-counter = 0
    trigger-reason = "NONE"
    trigger-sample-idx = 0
    current-sample-idx = 0
    latest-snapshot = null
    channel-buffers.do: | buf/WaveformRingBuffer |
      buf.reset

  /**
  Ingest a multi-channel sample vector [v_a, v_b, v_c, i_a, i_b, i_c].
  Returns true on the exact step when a recording has completed and is ready.
  */
  process sample-vector/List -> bool:
    if sample-vector.size != channel-names.size:
      throw "Sample vector size $(sample-vector.size) does not match channel count $(channel-names.size)"

    if state == RecorderState.COMPLETED:
      return false  // Locked until reset

    // Push samples into per-channel ring buffers
    for i := 0; i < channel-names.size; i++:
      buf /WaveformRingBuffer := channel-buffers[i]
      buf.push sample-vector[i]

    current-sample-idx++

    if state == RecorderState.CAPTURING-POST-FAULT:
      post-fault-counter++
      if post-fault-counter >= post-fault-samples:
        // Finalize recording
        finalize-snapshot
        state = RecorderState.COMPLETED
        return true

    return false

  /**
  Trigger an event capture manually or from the protection trip classifier.
  */
  trigger reason/string -> none:
    if state == RecorderState.IDLE:
      state = RecorderState.CAPTURING-POST-FAULT
      trigger-reason = reason
      trigger-sample-idx = current-sample-idx
      post-fault-counter = 0

  /** Extract snapshot from all channel ring buffers. */
  finalize-snapshot -> none:
    data := []
    channel-buffers.do: | buf/WaveformRingBuffer |
      buf.freeze
      snap-size := min total-samples buf.count
      data.add (buf.snapshot snap-size)

    latest-snapshot = OscillogramSnapshot
      trigger-reason
      trigger-sample-idx
      sampling-rate
      channel-names
      data
