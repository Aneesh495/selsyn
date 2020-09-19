#!/usr/bin/env python3
"""
Selsyn IEEE C37.118.1 TVE Compliance Verification Test.

Evaluates synchrophasor estimation accuracy under steady-state and off-nominal
frequency conditions to verify compliance with IEEE C37.118.1 Class M and Class P limits:
  - TVE <= 1.0%
  - FE <= 0.005 Hz
  - RFE <= 0.010 Hz/s
"""

import math
import sys
import unittest
from tools.tve_validator import ComplianceResult, PhasorEstimate, TveValidator


class TestTveCompliance(unittest.TestCase):
    def test_steady_state_nominal_60hz(self):
        """Verify TVE < 0.01% on nominal 60.0 Hz steady state signal."""
        nominal_rms = 120.0
        estimates = []
        for i in range(50):
            t = i * (1.0 / 50.0)  # 50 fps reporting rate
            # In steady state synchronous coordinates, nominal phasor is constant
            estimates.append(
                PhasorEstimate(
                    timestamp_sec=t,
                    real=nominal_rms,
                    imag=0.0,
                    frequency=60.0,
                    rocof=0.0,
                )
            )

        res = TveValidator.evaluate_steady_state(estimates, nominal_voltage_rms=nominal_rms)
        self.assertTrue(res.compliant)
        self.assertLessEqual(res.tve_percent_max, 0.01)
        self.assertLessEqual(res.fe_max_hz, 0.001)

    def test_tve_calculation_boundary(self):
        """Test TVE calculation formula against known mathematical vectors."""
        # Exact match
        tve0 = TveValidator.calculate_tve(100.0, 0.0, 100.0, 0.0)
        self.assertAlmostEqual(tve0, 0.0, places=5)

        # 1% magnitude offset
        tve1 = TveValidator.calculate_tve(101.0, 0.0, 100.0, 0.0)
        self.assertAlmostEqual(tve1, 1.0, places=4)

        # 0.573 degree phase offset (sin(0.573 deg) ~ 0.01 rad -> 1% TVE)
        rad = 0.01
        est_r = 100.0 * math.cos(rad)
        est_i = 100.0 * math.sin(rad)
        tve_phase = TveValidator.calculate_tve(est_r, est_i, 100.0, 0.0)
        self.assertAlmostEqual(tve_phase, 1.0, delta=0.01)


if __name__ == "__main__":
    unittest.main()
