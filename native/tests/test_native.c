/**
 * Copyright (C) 2026 Aneesh Krishna
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "selsyn_native.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <assert.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

void test_crc16(void) {
    printf("[RUN] test_crc16...\n");
    const uint8_t test_vector[] = "123456789";
    uint16_t crc = selsyn_crc16_ccitt(test_vector, 9);
    assert(crc == 0x29B1);
    printf("  [PASS] CRC-CCITT vector: 0x%04X\n", crc);
}

void test_fortescue(void) {
    printf("[RUN] test_fortescue...\n");
    /* Balanced 120V system: Va = 120<0, Vb = 120<-120, Vc = 120<+120 */
    selsyn_complex_t va = {120.0, 0.0};
    selsyn_complex_t vb = {-60.0, -120.0 * 0.8660254037844386};
    selsyn_complex_t vc = {-60.0, 120.0 * 0.8660254037844386};

    selsyn_sequence_t seq = selsyn_fortescue_decompose(va, vb, vc);

    assert(fabs(seq.v1.real - 120.0) < 1e-4);
    assert(fabs(seq.v1.imag) < 1e-4);
    assert(fabs(seq.v2.real) < 1e-4);
    assert(fabs(seq.v2.imag) < 1e-4);
    assert(fabs(seq.v0.real) < 1e-4);
    assert(fabs(seq.v0.imag) < 1e-4);

    double vuf = selsyn_compute_vuf(seq.v1, seq.v2);
    assert(vuf < 0.001);
    printf("  [PASS] Fortescue balanced sequence decomposed, VUF = %.4f%%\n", vuf);
}

void test_rdft(void) {
    printf("[RUN] test_rdft...\n");
    selsyn_rdft_state_t state;
    size_t window_size = 64;
    double f_fund = 60.0;
    double f_samp = 3840.0; /* 64 samples per cycle */

    int rc = selsyn_rdft_init(&state, window_size, f_fund, f_samp);
    assert(rc == 0);

    /* Feed 2 full cycles of pure 120V RMS sine wave */
    double v_peak = 120.0 * sqrt(2.0);
    selsyn_complex_t last_phasor = {0.0, 0.0};
    for (size_t i = 0; i < 128; i++) {
        double theta = 2.0 * M_PI * f_fund * (double)i / f_samp;
        double s = v_peak * cos(theta);
        last_phasor = selsyn_rdft_update(&state, s);
    }

    double mag = sqrt(last_phasor.real * last_phasor.real + last_phasor.imag * last_phasor.imag);
    assert(fabs(mag - 120.0) < 0.1);
    selsyn_rdft_free(&state);
    printf("  [PASS] RDFT tracking steady-state phasor magnitude: %.3f V\n", mag);
}

int main(void) {
    printf("=== Selsyn Native C DSP Acceleration Test Suite ===\n");
    test_crc16();
    test_fortescue();
    test_rdft();
    printf("=== All C DSP Tests Passed Cleanly ===\n");
    return 0;
}
