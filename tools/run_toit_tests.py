#!/usr/bin/env python3
"""
Test runner for Toit test suite in Selsyn.

Discovers and executes all 'tests/test_*.toit' files using 'toit run',
measuring execution duration and verifying exit codes.
"""

import os
import subprocess
import sys
import time
from pathlib import Path


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    tests_dir = root / 'tests'
    if not tests_dir.exists():
        print("No tests directory found.")
        return 0

    toit_tests = sorted(list(tests_dir.glob('test_*.toit')))
    if not toit_tests:
        print("No Toit test files found in tests/.")
        return 0

    print(f"Discovered {len(toit_tests)} Toit test suite files.")
    passed = 0
    failed = 0
    start_total = time.time()

    for test_file in toit_tests:
        rel_path = test_file.relative_to(root)
        print(f"  [RUN] {rel_path}...", end=' ', flush=True)
        t0 = time.time()
        res = subprocess.run(
            ['toit', 'run', str(test_file)],
            cwd=str(root),
            capture_output=True,
            text=True
        )
        dt = (time.time() - t0) * 1000.0

        if res.returncode == 0:
            print(f"PASSED ({dt:.1f}ms)")
            passed += 1
        else:
            print(f"FAILED (exit {res.returncode}) ({dt:.1f}ms)")
            if res.stdout:
                print("    STDOUT:", res.stdout.strip())
            if res.stderr:
                print("    STDERR:", res.stderr.strip())
            failed += 1

    total_time = (time.time() - start_total) * 1000.0
    print("-" * 60)
    print(f"Toit Test Summary: {passed} passed, {failed} failed in {total_time:.1f}ms.")

    return 1 if failed > 0 else 0


if __name__ == '__main__':
    sys.exit(main())
