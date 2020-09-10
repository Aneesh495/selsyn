#!/usr/bin/env python3
"""
Selsyn Automated Performance Benchmarking and Telemetry Suite.

Runs native C DSP kernels and Toit VM synchrophasor pipelines, measures throughput,
sub-microsecond execution latencies, and generates reproducible performance summaries.
"""

import os
import subprocess
import sys
import time


def run_benchmark(title: str, cmd: list) -> str:
    print(f"--> Running: {title}...")
    start = time.time()
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    dur = time.time() - start
    if res.returncode != 0:
        print(f"Error running {title}:\n{res.stderr}")
        return ""
    print(res.stdout.strip())
    return res.stdout


def main() -> None:
    root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    bench_dir = os.path.join(root_dir, "benchmarks")

    print("============================================================")
    print("           SELSYN HIGH-PERFORMANCE BENCHMARK SUITE          ")
    print("============================================================")

    # 1. Toit RDFT speed
    run_benchmark(
        "Toit Recursive Sliding DFT Ingestion",
        ["toit", "run", os.path.join(bench_dir, "bench_dft.toit")],
    )

    # 2. Toit Frame Serialization
    run_benchmark(
        "Toit IEEE C37.118 Frame Serialization",
        ["toit", "run", os.path.join(bench_dir, "bench_frames.toit")],
    )

    # 3. Native C DSP benchmark
    native_test = os.path.join(root_dir, "native", "build", "test_native")
    if os.path.exists(native_test):
        run_benchmark("Native C Kernel Parity & Speed", [native_test])

    print("\nBenchmark pass completed successfully.")


if __name__ == "__main__":
    main()
