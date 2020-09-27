# IEEE C37.118 Protocol and Synchrophasor Wire Format Specification

This document provides a technical specification of the binary frame formats, field layouts, bit definitions, and validation criteria implemented by Selsyn according to IEEE C37.118.2-2011 (Standard for Synchrophasor Data Transfer for Power Systems) and IEEE C37.118.1-2011 / IEEE C37.118.1a-2014 (Standard for Synchrophasor Measurements for Power Systems).

---

## 1. Common Frame Header Layout

Every IEEE C37.118 frame begins with a mandatory 14-byte binary header followed by a payload and a 2-byte CRC-CCITT trailer:

| Byte Offset | Field | Type | Description |
|---|---|---|---|
| 0..1 | `SYNC` | uint16 | Synchronization word and frame type identifier |
| 2..3 | `FRAMESIZE` | uint16 | Total frame size in bytes including header and CRC |
| 4..5 | `IDCODE` | uint16 | Stream identification code (PMU or PDC ID) |
| 6..9 | `SOC` | uint32 | Second-of-Century (Unix epoch seconds) |
| 10..13 | `FRACSEC` | uint32 | Fraction of second and time quality flags |
| 14..N-3 | `PAYLOAD` | bytes | Frame-specific payload data |
| N-2..N-1 | `CHK` | uint16 | CRC-CCITT checksum over bytes 0 through N-3 |

### 1.1 Synchronization Word (`SYNC`) Bitfield

```
Bit:  15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
     [   0xAA (Sync Byte)   ] [R] [Frame Type] [Version]
```

- **Bits 15..8**: Constant `0xAA` sync byte.
- **Bit 7**: Reserved (must be 0).
- **Bits 6..4**: Frame Type:
  - `000` (0): DATA frame
  - `001` (1): Header frame (HDR)
  - `010` (2): Configuration frame 1 (CFG-1)
  - `011` (3): Configuration frame 2 (CFG-2)
  - `100` (4): Command frame (CMD)
  - `101` (5): Configuration frame 3 (CFG-3)
- **Bits 3..0**: Protocol version number (1 for IEEE C37.118-2005 / IEEE C37.118.2-2011).

---

## 2. DATA Frame Structure

A DATA frame transmits instantaneous synchrophasor measurements, frequency deviation, ROCOF, analog telemetry, and digital status words.

### 2.1 PMU Status Word (`STAT`)

A 16-bit bitfield reporting measurement synchronization quality and internal health:

| Bit(s) | Name | Definition |
|---|---|---|
| 15..14 | `DATA_ERROR` | 00 = Good, 01 = PMU error, 10 = Test mode, 11 = Error |
| 13 | `SYNC_ERROR` | 0 = Synchronized to UTC GPS, 1 = Out of sync |
| 12 | `DATA_SORT` | 0 = Sorted by timestamp, 1 = Arrival order |
| 11 | `PMU_TRIGGER` | 0 = Normal, 1 = PMU triggered event active |
| 10 | `CFG_CHANGE` | 0 = Unchanged, 1 = Configuration changed within 1 min |
| 9..6 | `TIME_QUALITY`| Leap second and time synchronization quality code |
| 5..4 | `TRIGGER_REASON`| 00 = Manual, 01 = Magnitude, 10 = Frequency, 11 = Phase |
| 3..0 | `RESERVED` | Reserved for security extensions |

### 2.2 Phasor Representation Formats

Selsyn supports both rectangular and polar 32-bit single-precision floating point representations:
- **Rectangular Format**: 8 bytes per phasor consisting of real component $X_r$ (float32 big-endian) followed by imaginary component $X_i$ (float32 big-endian). Units are true RMS volts or amperes.
- **Polar Format**: 8 bytes per phasor consisting of magnitude $|X|$ (float32 big-endian) followed by phase angle $\theta$ in radians (float32 big-endian) in the range $[-\pi, +\pi]$.

### 2.3 Frequency and ROCOF Fields

- **Frequency Deviation (`FREQ`)**: 4-byte float32 big-endian representing actual frequency minus nominal frequency in Hz:
  $$f_{\text{actual}} = f_{\text{nominal}} + \text{FREQ}$$
- **Rate of Change of Frequency (`ROCOF`)**: 4-byte float32 big-endian representing frequency derivative in Hz per second.

---

## 3. Configuration Frame CFG-2 Structure

The CFG-2 frame describes the channel configuration, data formats, calibration scales, and station identifiers necessary for a PDC to decode DATA frames:

| Field | Size | Description |
|---|---|---|
| `TIME_BASE` | uint32 | Sub-second resolution ticks per second (default: 1,000,000) |
| `NUM_PMU` | uint16 | Number of PMUs contained in data stream (typically 1) |
| `STN` | 16 bytes | Station name ASCII string (null or space padded) |
| `IDCODE` | uint16 | PMU hardware ID code |
| `FORMAT` | uint16 | Data format bitfield (Rectangular/Polar, Float/Int) |
| `PHNMR` | uint16 | Number of phasors (e.g., 6: Va, Vb, Vc, Ia, Ib, Ic) |
| `ANNMR` | uint16 | Number of analog channels |
| `DGNMR` | uint16 | Number of digital 16-bit status words |
| `CHNAM` | N * 16 B | ASCII channel names (16 bytes per channel) |
| `PHUNIT` | N * 4 B | Phasor conversion scaling factors |
| `ANUNIT` | N * 4 B | Analog channel scaling factors |
| `DIGUNIT`| N * 4 B | Digital channel mask definitions |
| `FNOM` | uint16 | Nominal line frequency: 0 = 60 Hz, 1 = 50 Hz |
| `CFGCNT` | uint16 | Configuration change counter |
| `DATA_RATE`| int16 | Transmit frame rate in frames per second (e.g. 50 or 60) |

---

## 4. Command Frame (`CMD`) Structure

A 18-byte frame sent from a PDC to interrogate or control the PMU:

| Field | Value | Action |
|---|---|---|
| `CMD_STOP` | `0x0001` | Turn off real-time synchrophasor data transmission |
| `CMD_START` | `0x0002` | Turn on real-time synchrophasor data transmission |
| `CMD_SEND_HDR`| `0x0003` | Transmit Header frame (HDR) |
| `CMD_SEND_CFG1`| `0x0004` | Transmit Configuration frame 1 (CFG-1) |
| `CMD_SEND_CFG2`| `0x0005` | Transmit Configuration frame 2 (CFG-2) |
| `CMD_SEND_CFG3`| `0x0006` | Transmit Configuration frame 3 (CFG-3) |

---

## 5. CRC-CCITT Calculation

The frame checksum is a 16-bit CRC calculated across all bytes from offset 0 up to (size - 2).

- **Polynomial**: $x^{16} + x^{12} + x^5 + 1$ (`0x1021`)
- **Initial Value**: `0xFFFF`
- **Output XOR**: `0x0000`
- **Standard Test Vector**: ASCII `"123456789"` yields `0x29B1`.

---

## 6. IEEE C37.118.1 Compliance Criteria

Selsyn is tested against the compliance limits specified in IEEE C37.118.1-2011 and amendment IEEE C37.118.1a-2014:

### 6.1 Total Vector Error (TVE)

$$\text{TVE} = \sqrt{\frac{(X_r - X_{r,\text{true}})^2 + (X_i - X_{i,\text{true}})^2}{X_{r,\text{true}}^2 + X_{i,\text{true}}^2}} \times 100\%$$

- **Steady-State Range**: $\text{TVE} \le 1.0\%$ across $|f - f_0| \le 5.0\text{ Hz}$ for Class M and $|f - f_0| \le 2.0\text{ Hz}$ for Class P.
- **Harmonic Distortion**: $\text{TVE} \le 1.0\%$ with $1.0\%$ single harmonic injection up to the 50th harmonic.

### 6.2 Frequency and ROCOF Error

- **Frequency Error (FE)**: $|f_{\text{est}} - f_{\text{true}}| \le 0.005\text{ Hz}$
- **ROCOF Error (RFE)**:
  - Class P: $|\text{ROCOF}_{\text{est}} - \text{ROCOF}_{\text{true}}| \le 0.010\text{ Hz/s}$
  - Class M: $|\text{ROCOF}_{\text{est}} - \text{ROCOF}_{\text{true}}| \le 0.100\text{ Hz/s}$
