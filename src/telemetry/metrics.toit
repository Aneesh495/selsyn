// Selsyn: IEEE C37.118 Synchrophasor Measurement and Grid Stability Controller
// Performance Metrics, Latency Percentiles, and Jitter Tracking.

import math

/**
Real-time latency, jitter, and frame throughput statistical tracker.
Uses a circular reservoir to compute rolling p50, p95, and p99 streaming metrics.
*/
class StreamMetrics:
  capacity          /int
  latency-reservoir /List := []
  reservoir-idx     /int := 0
  sample-count      /int := 0

  total-frames-sent /int := 0
  total-dropped     /int := 0

  // Inter-arrival jitter tracking (microseconds)
  last-timestamp-us /int := 0
  jitter-us         /float := 0.0

  constructor --capacity/int=1000:
    this.capacity = capacity
    this.latency-reservoir = List capacity 0.0

  /** Reset all statistical accumulators. */
  reset -> none:
    reservoir-idx = 0
    sample-count = 0
    total-frames-sent = 0
    total-dropped = 0
    last-timestamp-us = 0
    jitter-us = 0.0
    for i := 0; i < capacity; i++:
      latency-reservoir[i] = 0.0

  /**
  Record latency of a processed or streamed frame in milliseconds.
  */
  record-latency latency-ms/float -> none:
    latency-reservoir[reservoir-idx] = latency-ms
    reservoir-idx = (reservoir-idx + 1) % capacity
    if sample-count < capacity:
      sample-count++
    total-frames-sent++

  /**
  Record inter-arrival timestamp (in microseconds) to calculate network jitter.
  Uses exponentially weighted moving average (EWMA) per RFC 3550:
    D = |(R_j - R_i) - (S_j - S_i)|
    Jitter = Jitter + (D - Jitter) / 16
  */
  record-inter-arrival timestamp-us/int expected-interval-us/int -> float:
    if last-timestamp-us != 0:
      delta := timestamp-us - last-timestamp-us
      diff := (delta - expected-interval-us).abs.to-float
      jitter-us += (diff - jitter-us) / 16.0
    last-timestamp-us = timestamp-us
    return jitter-us

  /**
  Calculate percentile latency (e.g. 50.0 for p50, 95.0 for p95, 99.0 for p99).
  */
  percentile p/float -> float:
    if sample-count == 0:
      return 0.0
    if p <= 0.0: return 0.0

    // Copy active samples and sort
    active := List sample-count: latency-reservoir[it]
    active.sort

    rank := (p / 100.0 * (sample-count - 1).to-float).round.to-int
    if rank < 0: rank = 0
    if rank >= sample-count: rank = sample-count - 1
    return active[rank]

  p50 -> float: return percentile 50.0
  p95 -> float: return percentile 95.0
  p99 -> float: return percentile 99.0
