# IEEE C37.111 COMTRADE Format and Transient Oscillography Specification

This document details the file structure, channel definition schemas, scaling formulas, and serialization mechanisms for transient fault oscillograms implemented by Selsyn according to IEEE C37.111-1999 and IEEE C37.111-2013 / IEC 60255-24 (Common Format for Transient Data Exchange for Power Systems).

---

## 1. Overview and File Structure

When a grid event or fault trip occurs, Selsyn freezes its circular waveform ring buffers and writes a matched pair of files:
- **`.CFG` (Configuration File)**: ASCII metadata specifying station name, channel identifiers, phase assignments, physical measurement units, gain multipliers, offset constants, and sampling frequencies.
- **`.DAT` (Data File)**: The raw sampled waveform time-series, stored in either ASCII or binary format.

---

## 2. Configuration File (`.CFG`) Schema

A standard Selsyn `.CFG` file is formatted as follows:

```
SUBSTATION_ALPHA,SELSYN_PMU_01,1999
6,6A,0D
1,VA,A,,V,0.010000,0.000000,0,-32768,32767,1.0,1.0,P
2,VB,B,,V,0.010000,0.000000,0,-32768,32767,1.0,1.0,P
3,VC,C,,V,0.010000,0.000000,0,-32768,32767,1.0,1.0,P
4,IA,A,,A,0.001000,0.000000,0,-32768,32767,1.0,1.0,P
5,IB,B,,A,0.001000,0.000000,0,-32768,32767,1.0,1.0,P
6,IC,C,,A,0.001000,0.000000,0,-32768,32767,1.0,1.0,P
60.0
1
3840.0,512
08/11/2026,16:00:00.000000
08/11/2026,16:00:00.033333
ASCII
1.0
```

### 2.1 Line Breakdown

1. **Station and Device Line**:
   `station_name,rec_dev_id,rev_year`
2. **Channel Summary Line**:
   `total_channels,num_analogA,num_digitalD`
3. **Analog Channel Definitions**:
   `n,ch_id,ph,ccbm,uu,a,b,skew,min,max,primary,secondary,p_or_s`
   - `n`: Channel index (1 to total analog channels)
   - `ch_id`: Channel name (e.g. `VA`, `IA`)
   - `ph`: Phase identifier (`A`, `B`, `C`, or `N`)
   - `ccbm`: Circuit component monitored (optional)
   - `uu`: Physical units string (`V`, `kV`, `A`, `kA`)
   - `a`: Channel multiplier gain
   - `b`: Channel offset adder
   - `skew`: Time skew within sampling interval in microseconds
   - `min,max`: Channel integer limits (typically `-32768,32767`)
   - `primary,secondary`: Instrument transformer ratio
   - `p_or_s`: Scaling indicator (`P` for primary, `S` for secondary)
4. **Nominal System Frequency**:
   Grid base frequency in Hz (`60.0` or `50.0`).
5. **Sampling Rate Count**:
   Number of sampling rate entries (`1`).
6. **Sampling Rate Line**:
   `samp_rate,end_sample` (e.g. `3840.0,512` indicates 3,840 Hz up to sample index 512).
7. **Start Timestamp**:
   `dd/mm/yyyy,hh:mm:ss.ssssss` corresponding to sample 1.
8. **Trigger Timestamp**:
   `dd/mm/yyyy,hh:mm:ss.ssssss` corresponding to fault inception.
9. **Data File Format**:
   `ASCII` or `BINARY`.
10. **Time Multiplication Factor**:
    `1.0` (indicates timestamp units are in microseconds).

---

## 3. Data File (`.DAT`) Layout

### 3.1 ASCII Data Format

Each line represents an instantaneous multi-channel time step with comma-separated tokens:

```
<sample_number>,<timestamp_us>,<A1_val>,<A2_val>,...,<An_val>,<D1_val>,...,<Dm_val>
```

Example:
```
1,0,16970,-8485,-8485,7071,-3535,-3535
2,260,16912,-8731,-8181,7047,-3638,-3409
```

### 3.2 Physical Value Conversion Formula

To recover physical volts or amperes from raw values in the `.DAT` file:

$$Y_{\text{actual}} = a \cdot X_{\text{raw}} + b$$

For voltage channel $V_a$ with $a = 0.01$:
$$V_{\text{actual}} = 0.01 \cdot 16970 = 169.70\text{ V}$$

---

## 4. Sub-Cycle Pre- and Post-Fault Buffering

Selsyn's transient fault recorder maintains a rolling circular ring buffer to guarantee comprehensive oscillogram coverage:

- **Pre-Trigger Window**: 2 full grid cycles (128 samples at 3,840 Hz) capturing pristine steady-state waveforms prior to disturbance.
- **Post-Trigger Window**: 6 full grid cycles (384 samples at 3,840 Hz) capturing fault evolution, arc transients, and breaker trip operations.
- **Total Record Length**: 8 full grid cycles (512 samples, $133.3\text{ ms}$).
