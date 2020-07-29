// Selsyn test suite: Telemetry metrics and latency percentiles.

import ..src.telemetry.metrics show StreamMetrics

main:
  metrics := StreamMetrics --capacity=200

  // 1. Feed 100 uniformly spaced latencies (1.0 to 100.0 ms)
  for i := 1; i <= 100; i++:
    metrics.record-latency i.to-float

  p50 := metrics.p50
  p95 := metrics.p95
  p99 := metrics.p99

  if (p50 - 50.0).abs > 1.5:
    throw "p50 latency mismatch: expected ~50.0, got $p50"
  if (p95 - 95.0).abs > 1.5:
    throw "p95 latency mismatch: expected ~95.0, got $p95"
  if (p99 - 99.0).abs > 1.5:
    throw "p99 latency mismatch: expected ~99.0, got $p99"

  // 2. Inter-arrival jitter tracking (expected 20,000 us for 50 fps)
  metrics.reset
  expected-interval := 20000

  // 10 perfect arrival intervals
  for i := 0; i < 10; i++:
    t := 1000000 + (i * expected-interval)
    metrics.record-inter-arrival t expected-interval

  if metrics.jitter-us > 1.0:
    throw "Jitter for perfect periodic arrivals should be ~0, got $(metrics.jitter-us)"

  // Inject 200 us jitter pulses
  t-curr := 1200000
  for i := 0; i < 10; i++:
    t-curr += expected-interval + (i % 2 == 0 ? 200 : -200)
    metrics.record-inter-arrival t-curr expected-interval

  if metrics.jitter-us < 10.0:
    throw "Jitter should detect inter-arrival variance: got $(metrics.jitter-us)"

  print "test_metrics: ALL TESTS PASSED."
