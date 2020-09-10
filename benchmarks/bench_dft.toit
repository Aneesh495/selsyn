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

import math
import ..src.dsp.complex show Complex
import ..src.dsp.dft show RecursiveDft

main:
  print "============================================================"
  print "  Selsyn Benchmark: Sliding Recursive DFT Ingestion Speed   "
  print "============================================================"

  dft := RecursiveDft --samples-per-cycle=64 --nominal-frequency=60.0

  total-samples := 100000
  v-peak := 120.0 * (math.sqrt 2.0)

  // Pre-generate samples
  samples := List total-samples: | i |
    theta := 2.0 * math.PI * 60.0 * (i.to-float / 3840.0)
    v-peak * (math.cos theta)

  start-us := Time.monotonic-us

  for i := 0; i < total-samples; i++:
    dft.process samples[i]

  elapsed-us := Time.monotonic-us - start-us
  elapsed-sec := elapsed-us.to-float / 1000000.0
  throughput := total-samples.to-float / elapsed-sec

  print "  Processed: $total-samples samples"
  print "  Elapsed:   $(%.3f elapsed-sec) seconds"
  print "  Speed:     $(%.1f throughput) samples/sec"
  print "  Latency:   $(%.3f (elapsed-us.to-float / total-samples)) microseconds/sample"
  print "============================================================"
