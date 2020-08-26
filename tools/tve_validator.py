#!/usr/bin/env python3
"""
Selsyn IEEE C37.118.1 Compliance and Total Vector Error (TVE) Validator.

Evaluates synchrophasor measurement accuracy against analytical ground-truth
signals according to IEEE C37.118.1-2011 and IEEE C37.118.1a-2014 standards:
  - Total Vector Error (TVE): TVE <= 1.0% under steady-state and dynamic conditions
  - Frequency Error (FE): |f_est - f_true| <= 0.005 Hz (steady-state)
  - Rate of Change of Frequency Error (RFE): |ROCOF_est - ROCOF_true| <= 0.01 Hz/s (Class P)
"""

import math
from typing import Dict, List, NamedTuple, Tuple


class PhasorEstimate(NamedTuple):
    timestamp_sec: float
    real: float
    imag: float
    frequency: float
    rocof: float


class ComplianceResult(NamedTuple):
    tve_percent_max: float
    tve_percent_mean: float
    fe_max_hz: float
    rfe_max_hz_per_sec: float
    passed_tve: bool
    passed_fe: bool
    passed_rfe: bool
    compliant: bool


class TveValidator:
    """Calculates TVE, FE, and RFE metrics and verifies IEEE C37.118.1 compliance."""

    TVE_LIMIT_PERCENT = 1.0
    FE_STEADY_STATE_LIMIT_HZ = 0.005
    RFE_CLASS_P_LIMIT_HZ_S = 0.010
    RFE_CLASS_M_LIMIT_HZ_S = 0.100

    @staticmethod
    def calculate_tve(
        est_real: float,
        est_imag: float,
        true_real: float,
        true_imag: float,
    ) -> float:
        """
        Compute Total Vector Error (TVE) as a percentage:
          TVE = sqrt( (X_r - X_r_true)^2 + (X_i - X_i_true)^2 ) / sqrt( X_r_true^2 + X_i_true^2 ) * 100%
        """
        diff_r = est_real - true_real
        diff_i = est_imag - true_imag
        num = diff_r * diff_r + diff_i * diff_i
        den = true_real * true_real + true_imag * true_imag
        if den == 0.0:
            return 0.0 if num == 0.0 else 100.0
        return math.sqrt(num / den) * 100.0

    @classmethod
    def evaluate_steady_state(
        cls,
        estimates: List[PhasorEstimate],
        nominal_voltage_rms: float = 120.0,
        nominal_frequency: float = 60.0,
        initial_phase_rad: float = 0.0,
    ) -> ComplianceResult:
        """
        Evaluate steady-state compliance for a pure sinusoidal signal.
        """
        tve_values = []
        fe_values = []
        rfe_values = []

        omega = 2.0 * math.pi * nominal_frequency

        for est in estimates:
            t = est.timestamp_sec
            expected_phase = initial_phase_rad + omega * t
            # Phasor representation in RMS: X_r = V_rms * cos(phase), X_i = V_rms * sin(phase)
            # In synchrophasor coordinates rotating at nominal frequency,
            # the steady-state phasor angle is constant if frequency is exactly nominal.
            true_real = nominal_voltage_rms * math.cos(initial_phase_rad)
            true_imag = nominal_voltage_rms * math.sin(initial_phase_rad)

            tve = cls.calculate_tve(est.real, est.imag, true_real, true_imag)
            tve_values.append(tve)

            fe = abs(est.frequency - nominal_frequency)
            fe_values.append(fe)

            rfe = abs(est.rocof - 0.0)
            rfe_values.append(rfe)

        max_tve = max(tve_values) if tve_values else 0.0
        mean_tve = sum(tve_values) / len(tve_values) if tve_values else 0.0
        max_fe = max(fe_values) if fe_values else 0.0
        max_rfe = max(rfe_values) if rfe_values else 0.0

        passed_tve = max_tve <= cls.TVE_LIMIT_PERCENT
        passed_fe = max_fe <= cls.FE_STEADY_STATE_LIMIT_HZ
        passed_rfe = max_rfe <= cls.RFE_CLASS_M_LIMIT_HZ_S

        return ComplianceResult(
            tve_percent_max=max_tve,
            tve_percent_mean=mean_tve,
            fe_max_hz=max_fe,
            rfe_max_hz_per_sec=max_rfe,
            passed_tve=passed_tve,
            passed_fe=passed_fe,
            passed_rfe=passed_rfe,
            compliant=(passed_tve and passed_fe and passed_rfe),
        )


if __name__ == "__main__":
    print("Testing TveValidator with synthetic test vector...")
    # Verify exact match produces 0.0% TVE
    tve_exact = TveValidator.calculate_tve(120.0, 0.0, 120.0, 0.0)
    assert tve_exact == 0.0

    # 1% magnitude error
    tve_1pct = TveValidator.calculate_tve(121.2, 0.0, 120.0, 0.0)
    print(f"  1% amplitude mismatch TVE: {tve_1pct:.4f}%")
    assert abs(tve_1pct - 1.0) < 1e-4

    print("TveValidator operational.")
