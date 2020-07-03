// Selsyn test suite: Transient fault event recorder.

import ..src.storage.fault_recorder show TransientFaultRecorder RecorderState OscillogramSnapshot

main:
  pre-samples := 10
  post-samples := 20
  total-samples := pre-samples + post-samples

  recorder := TransientFaultRecorder
    --sampling-rate=3840.0
    --pre-fault-samples=pre-samples
    --post-fault-samples=post-samples
    --channel-names=["VA", "VB", "IA"]

  // 1. Ingest 15 baseline samples in idle state
  for i := 0; i < 15; i++:
    is-done := recorder.process [120.0, -60.0, 5.0]
    if is-done or recorder.state != RecorderState.IDLE:
      throw "Recorder should be idle during pre-fault monitoring"

  // 2. Trigger fault
  recorder.trigger "SLG_AG_OVERCURRENT"
  if recorder.state != RecorderState.CAPTURING-POST-FAULT:
    throw "Recorder failed to transition to CAPTURING_POST_FAULT"

  // 3. Ingest post-fault samples until completion
  completed-step := -1
  for i := 0; i < post-samples; i++:
    // Fault condition: Va drops to 10V, Ia surges to 50A
    finished := recorder.process [10.0, -60.0, 50.0]
    if finished:
      completed-step = i

  if completed-step != (post-samples - 1):
    throw "Expected recording to finish on final post-fault sample ($post-samples), got step $completed-step"

  if recorder.state != RecorderState.COMPLETED:
    throw "Recorder should be in COMPLETED state"

  // 4. Verify frozen snapshot
  snap := recorder.latest-snapshot
  if not snap:
    throw "Missing latest snapshot after completion"
  if snap.trigger-reason != "SLG_AG_OVERCURRENT":
    throw "Snapshot trigger reason mismatch: $(snap.trigger-reason)"
  if snap.channel-names.size != 3 or snap.channel-data.size != 3:
    throw "Snapshot channel count mismatch"

  ch0-data := snap.channel-data[0]
  if ch0-data.size != total-samples:
    throw "Channel 0 sample count mismatch: expected $total-samples, got $(ch0-data.size)"

  // Pre-fault sample should be 120.0, post-fault sample should be 10.0
  if ch0-data[0] != 120.0:
    throw "Pre-fault sample mismatch: expected 120.0, got $(ch0-data[0])"
  if ch0-data[total-samples - 1] != 10.0:
    throw "Post-fault sample mismatch: expected 10.0, got $(ch0-data[total-samples - 1])"

  print "test_fault_recorder: ALL TESTS PASSED."
