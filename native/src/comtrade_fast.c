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
#include <stdint.h>
#include <string.h>

/**
 * Packs 16-bit signed integer COMTRADE sample record from physical floating point values.
 * Record structure: [sample_num: 32-bit LE][timestamp_us: 32-bit LE][A1..An: 16-bit LE][D1..Dm bits]
 */
size_t selsyn_comtrade_pack_record(
    uint8_t* out_buffer,
    uint32_t sample_num,
    uint32_t timestamp_us,
    const double* analog_values,
    const double* analog_multipliers,
    const double* analog_offsets,
    size_t analog_count,
    const uint16_t* digital_words,
    size_t digital_word_count
) {
    size_t offset = 0;

    /* Sample number (4 bytes little-endian) */
    out_buffer[offset++] = (uint8_t)(sample_num & 0xFF);
    out_buffer[offset++] = (uint8_t)((sample_num >> 8) & 0xFF);
    out_buffer[offset++] = (uint8_t)((sample_num >> 16) & 0xFF);
    out_buffer[offset++] = (uint8_t)((sample_num >> 24) & 0xFF);

    /* Timestamp in microseconds (4 bytes little-endian) */
    out_buffer[offset++] = (uint8_t)(timestamp_us & 0xFF);
    out_buffer[offset++] = (uint8_t)((timestamp_us >> 8) & 0xFF);
    out_buffer[offset++] = (uint8_t)((timestamp_us >> 16) & 0xFF);
    out_buffer[offset++] = (uint8_t)((timestamp_us >> 24) & 0xFF);

    /* Analog channels: unscaled_int16 = (val - offset) / multiplier */
    for (size_t i = 0; i < analog_count; i++) {
        double mult = analog_multipliers[i];
        double off = analog_offsets[i];
        double raw = (mult != 0.0) ? ((analog_values[i] - off) / mult) : 0.0;

        int32_t clamped = (int32_t)raw;
        if (clamped > 32767) clamped = 32767;
        if (clamped < -32768) clamped = -32768;

        int16_t val16 = (int16_t)clamped;
        out_buffer[offset++] = (uint8_t)(val16 & 0xFF);
        out_buffer[offset++] = (uint8_t)((val16 >> 8) & 0xFF);
    }

    /* Digital channels (16-bit words little-endian) */
    for (size_t i = 0; i < digital_word_count; i++) {
        uint16_t dw = digital_words[i];
        out_buffer[offset++] = (uint8_t)(dw & 0xFF);
        out_buffer[offset++] = (uint8_t)((dw >> 8) & 0xFF);
    }

    return offset;
}
