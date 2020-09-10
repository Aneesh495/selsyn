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
#include <math.h>

static inline selsyn_complex_t c_add(selsyn_complex_t a, selsyn_complex_t b) {
    selsyn_complex_t r;
    r.real = a.real + b.real;
    r.imag = a.imag + b.imag;
    return r;
}

static inline selsyn_complex_t c_scale(selsyn_complex_t a, double s) {
    selsyn_complex_t r;
    r.real = a.real * s;
    r.imag = a.imag * s;
    return r;
}

static inline selsyn_complex_t c_mul(selsyn_complex_t a, selsyn_complex_t b) {
    selsyn_complex_t r;
    r.real = a.real * b.real - a.imag * b.imag;
    r.imag = a.real * b.imag + a.imag * b.real;
    return r;
}

static inline double c_mag(selsyn_complex_t a) {
    return sqrt(a.real * a.real + a.imag * a.imag);
}

selsyn_sequence_t selsyn_fortescue_decompose(selsyn_complex_t va, selsyn_complex_t vb, selsyn_complex_t vc) {
    /* alpha = e^(j * 2*pi/3) = -0.5 + j * sqrt(3)/2 */
    static const double kSqrt3_2 = 0.8660254037844386;
    selsyn_complex_t alpha = {-0.5, kSqrt3_2};
    selsyn_complex_t alpha2 = {-0.5, -kSqrt3_2};

    /* V0 = 1/3 * (Va + Vb + Vc) */
    selsyn_complex_t sum0 = c_add(c_add(va, vb), vc);
    selsyn_complex_t v0 = c_scale(sum0, 1.0 / 3.0);

    /* V1 = 1/3 * (Va + alpha * Vb + alpha^2 * Vc) */
    selsyn_complex_t a_vb = c_mul(alpha, vb);
    selsyn_complex_t a2_vc = c_mul(alpha2, vc);
    selsyn_complex_t sum1 = c_add(c_add(va, a_vb), a2_vc);
    selsyn_complex_t v1 = c_scale(sum1, 1.0 / 3.0);

    /* V2 = 1/3 * (Va + alpha^2 * Vb + alpha * Vc) */
    selsyn_complex_t a2_vb = c_mul(alpha2, vb);
    selsyn_complex_t a_vc = c_mul(alpha, vc);
    selsyn_complex_t sum2 = c_add(c_add(va, a2_vb), a_vc);
    selsyn_complex_t v2 = c_scale(sum2, 1.0 / 3.0);

    selsyn_sequence_t seq;
    seq.v1 = v1;
    seq.v2 = v2;
    seq.v0 = v0;
    return seq;
}

double selsyn_compute_vuf(selsyn_complex_t v1, selsyn_complex_t v2) {
    double m1 = c_mag(v1);
    double m2 = c_mag(v2);
    if (m1 == 0.0) {
        return (m2 == 0.0) ? 0.0 : 100.0;
    }
    return (m2 / m1) * 100.0;
}
