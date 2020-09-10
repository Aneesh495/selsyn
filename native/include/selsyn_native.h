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

#ifndef SELSYN_NATIVE_H_
#define SELSYN_NATIVE_H_

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    double real;
    double imag;
} selsyn_complex_t;

typedef struct {
    selsyn_complex_t v1;  /* Positive sequence */
    selsyn_complex_t v2;  /* Negative sequence */
    selsyn_complex_t v0;  /* Zero sequence */
} selsyn_sequence_t;

typedef struct {
    size_t window_size;
    size_t write_idx;
    size_t sample_count;
    double* history_buffer;
    selsyn_complex_t phasor_acc;
    double cos_step;
    double sin_step;
} selsyn_rdft_state_t;

/**
 * Initialize a Recursive Discrete Fourier Transform state machine.
 */
int selsyn_rdft_init(selsyn_rdft_state_t* state, size_t window_size, double fundamental_freq, double sampling_freq);

/**
 * Free memory associated with RDFT state.
 */
void selsyn_rdft_free(selsyn_rdft_state_t* state);

/**
 * Update RDFT state with one new incoming sample. Returns updated phasor.
 */
selsyn_complex_t selsyn_rdft_update(selsyn_rdft_state_t* state, double new_sample);

/**
 * Compute Fortescue symmetrical components from three-phase complex phasors.
 */
selsyn_sequence_t selsyn_fortescue_decompose(selsyn_complex_t va, selsyn_complex_t vb, selsyn_complex_t vc);

/**
 * Compute Voltage Unbalance Factor (VUF) percentage: (|V2| / |V1|) * 100.
 */
double selsyn_compute_vuf(selsyn_complex_t v1, selsyn_complex_t v2);

/**
 * Fast CRC-CCITT (0x1021, init 0xFFFF) calculation over memory buffer.
 */
uint16_t selsyn_crc16_ccitt(const uint8_t* data, size_t length);

#ifdef __cplusplus
}
#endif

#endif  /* SELSYN_NATIVE_H_ */
