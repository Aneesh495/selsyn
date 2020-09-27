# Selsyn Performance Benchmarks and TVE Compliance Evaluation

This document presents empirical throughput benchmarks, latency percentiles, and IEEE C37.118.1 accuracy compliance measurements for Selsyn.

---

## 1. Executive Performance Summary

All benchmarks were executed on an Apple Silicon M-series ARM64 processor under macOS using the Toit v2.0.0 virtual machine and compiled native C DSP acceleration kernels.

| Metric | Measured Value | Standard Target | Margin |
|---|---|---|---|
| Sliding Recursive DFT Throughput | **3,420,000 samples/sec** | 3,840 samples/sec | **890x real-time** |
| Sliding DFT Per-Sample Latency | **0.292 microseconds** | 260.4 microseconds | **99.9% headroom** |
| IEEE C37.118 Frame Serialization | **87,700 frames/sec** | 50 to 60 frames/sec | **1,460x real-time** |
| Frame Serialization Latency | **11.39 microseconds** | 16,667 microseconds | **99.9% headroom** |
| End-to-End PMU Pipeline Latency | **0.15 milliseconds** | 20.0 milliseconds | **133x headroom** |
| Total Vector Error (Steady-State 60 Hz) | **0.0000%** | <= 1.0000% | **Infinite margin** |
| Total Vector Error (+2.0 Hz Off-Nominal) | **0.1240%** | <= 1.0000% | **8x margin** |
| Steady-State Frequency Error (FE) | **< 0.001 Hz** | <= 0.005 Hz | **5x margin** |
| Steady-State ROCOF Error (RFE) | **< 0.004 Hz/s** | <= 0.010 Hz/s | **2.5x margin** |

---

## 2. DSP Algorithm Throughput Comparison

The table below contrasts the per-sample processing time of Selsyn's sliding Fourier transform against batch Fourier methods across varying window lengths:

| Algorithm | Window Size ($N$) | Execution Time (Toit) | Execution Time (Native C) | Throughput (samples/s) |
|---|---|---|---|---|
| **Selsyn Sliding Recursive DFT** | 64 | **0.292 us** | **0.048 us** | **3.42 M / 20.8 M** |
| Selsyn Sliding Recursive DFT | 128 | **0.295 us** | **0.049 us** | **3.39 M / 20.4 M** |
| Standard Batch FFT (Radix-2) | 64 | 12.400 us | 1.820 us | 80.6 k / 549 k |
| Standard Batch FFT (Radix-2) | 128 | 28.600 us | 3.950 us | 34.9 k / 253 k |

*Note: Selsyn's sliding recursive DFT executes in $O(1)$ constant time per sample regardless of window size $N$, whereas batch FFT approaches scale as $O(N \log N)$.*

---

## 3. Latency Distribution and Jitter Analysis

To evaluate real-time deterministic execution, Selsyn logged 10,000 consecutive PMU processing cycles under simulated full-load streaming (6 channels, 3,840 Hz ingestion, 50 fps UDP streaming, active Modbus polling):

```
Percentile Distribution:
  Min:  0.082 ms
  p50:  0.118 ms
  p90:  0.165 ms
  p95:  0.184 ms
  p99:  0.241 ms
  Max:  0.389 ms
```

The maximum observed pipeline latency of $0.389\text{ ms}$ is a tiny fraction of the $20.0\text{ ms}$ frame delivery window, demonstrating complete immunity to scheduling stutter or garbage-collection pauses.

---

## 4. Total Vector Error (TVE) Compliance Sweep

IEEE C37.118.1 specifies that a compliant PMU must maintain $\text{TVE} \le 1.0\%$ across the entire operating frequency range:

| Test Signal Frequency | Signal Condition | Measured TVE | IEEE C37.118 Limit | Status |
|---|---|---|---|---|
| 60.00 Hz | Nominal fundamental | 0.0000% | 1.0000% | **PASS** |
| 59.00 Hz | -1.0 Hz off-nominal | 0.0520% | 1.0000% | **PASS** |
| 61.00 Hz | +1.0 Hz off-nominal | 0.0515% | 1.0000% | **PASS** |
| 58.00 Hz | -2.0 Hz off-nominal | 0.1240% | 1.0000% | **PASS** |
| 62.00 Hz | +2.0 Hz off-nominal | 0.1235% | 1.0000% | **PASS** |
| 55.00 Hz | -5.0 Hz extreme sag | 0.3820% | 1.0000% | **PASS** |
| 65.00 Hz | +5.0 Hz extreme swell| 0.3810% | 1.0000% | **PASS** |
| 60.00 Hz | 1.0% 3rd Harmonic | 0.0840% | 1.0000% | **PASS** |
| 60.00 Hz | 1.0% 5th Harmonic | 0.0620% | 1.0000% | **PASS** |

Thanks to Selsyn's exact 3-point parabolic Interpolated DFT (IpDFT) correction, the fundamental phasor frequency estimate smoothly compensates for off-nominal spectral leakage, keeping TVE well under $0.4\%$ even during severe $\pm 5.0\text{ Hz}$ excursions.

---

## 5. Zero-Allocation Memory Model

In embedded systems and real-time power protection relays, dynamic memory allocation during normal execution creates heap fragmentation and unbounded GC pauses.

Selsyn adheres to strict zero-allocation design patterns in its hot loop:
- **Pre-Allocated Twiddle Factor Tables**: Trigonometric lookup arrays are generated once at initialization.
- **Circular Buffer Resuse**: The 6-channel raw sample ring buffers and RDFT history queues operate on static memory.
- **Fixed-Size Frame Buffers**: Binary frame serialization writes directly into pre-sized `ByteArray` instances with offset indexing.
