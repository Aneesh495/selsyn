// Selsyn: IEEE C37.118 Synchrophasor Measurement and Grid Stability Controller
// Zero-Allocation Circular Point-on-Wave Waveform Ring Buffer.

/**
High-performance circular waveform ring buffer.
Holds rolling history of raw ADC instantaneous samples without dynamic allocations.
*/
class WaveformRingBuffer:
  capacity /int
  buffer   /List := []
  head     /int := 0
  count    /int := 0
  frozen   /bool := false

  constructor .capacity:
    if capacity <= 0:
      throw "Ring buffer capacity must be positive"
    this.buffer = List capacity 0.0

  /** Reset the buffer to empty un-frozen state. */
  reset -> none:
    head = 0
    count = 0
    frozen = false
    for i := 0; i < capacity; i++:
      buffer[i] = 0.0

  /** Push a single float sample into the ring buffer. */
  push sample/float -> none:
    if frozen:
      return  // Buffer locked for event capture snapshot

    buffer[head] = sample
    head = (head + 1) % capacity
    if count < capacity:
      count++

  /**
  Read a sample at relative offset $offset from the oldest available sample.
  0 = oldest sample, (count - 1) = newest sample.
  */
  get offset/int -> float:
    if offset < 0 or offset >= count:
      throw "Index out of bounds: $offset (count: $count)"
    start-idx := count < capacity ? 0 : head
    idx := (start-idx + offset) % capacity
    return buffer[idx]

  /**
  Read the most recent sample (newest pushed).
  */
  last -> float:
    if count == 0:
      throw "Ring buffer is empty"
    idx := head == 0 ? (capacity - 1) : (head - 1)
    return buffer[idx]

  /**
  Extract a continuous sub-array snapshot of the last $window_size samples.
  */
  snapshot window-size/int -> List:
    if window-size > count:
      throw "Requested snapshot size $window-size exceeds buffered count $count"
    out := List window-size 0.0
    start-offset := count - window-size
    for i := 0; i < window-size; i++:
      out[i] = get (start-offset + i)
    return out

  /** Freeze buffer to prevent overwriting during fault snapshot extraction. */
  freeze -> none:
    frozen = true

  /** Unfreeze buffer to resume circular ingestion. */
  unfreeze -> none:
    frozen = false
