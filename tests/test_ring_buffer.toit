// Selsyn test suite: Circular waveform ring buffer.

import ..src.storage.ring_buffer show WaveformRingBuffer

main:
  cap := 8
  rb := WaveformRingBuffer cap

  // 1. Initial push
  rb.push 10.0
  rb.push 20.0
  rb.push 30.0
  if rb.count != 3:
    throw "Expected count 3, got $(rb.count)"
  if (rb.get 0) != 10.0 or (rb.get 2) != 30.0:
    throw "Indexing mismatch"
  if rb.last != 30.0:
    throw "Expected last 30.0, got $(rb.last)"

  // 2. Wrap-around test: push 12 elements (0 to 11)
  rb.reset
  for i := 0; i < 12; i++:
    rb.push i.to-float

  if rb.count != cap:
    throw "Count should cap at capacity ($cap), got $(rb.count)"
  // The buffer should contain [4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0]
  if (rb.get 0) != 4.0:
    throw "Oldest sample mismatch: expected 4.0, got $(rb.get 0)"
  if rb.last != 11.0:
    throw "Newest sample mismatch: expected 11.0, got $(rb.last)"

  // 3. Snapshot extraction
  snap := rb.snapshot 4
  if snap.size != 4:
    throw "Snapshot size mismatch"
  if snap[0] != 8.0 or snap[1] != 9.0 or snap[2] != 10.0 or snap[3] != 11.0:
    throw "Snapshot contents mismatch: $snap"

  // 4. Freeze test
  rb.freeze
  rb.push 999.0
  if rb.last != 11.0:
    throw "Frozen buffer allowed modification"

  print "test_ring_buffer: ALL TESTS PASSED."
