// Selsyn: IEEE C37.118 Synchrophasor Measurement and Grid Stability Controller
// Dual Second-Order Generalized Integrator Phase-Locked Loop (DSOGI-PLL).

import math

/**
Dual Second-Order Generalized Integrator Phase-Locked Loop (DSOGI-PLL).
Extracts fundamental positive-sequence grid frequency and phase angle even under severe
grid unbalance, harmonic distortion, and voltage sags.
*/
class DsogiPll:
  nominal-freq /float
  omega-0      /float
  sampling-rate /float
  dt           /float

  // SOGI damping ratio: standard optimal damping xi = 1 / sqrt(2) = 0.7071
  xi /float := 0.70710678

  // SOGI state variables for alpha axis: x1 = v', x2 = q v'
  sogi-alpha-x1 /float := 0.0
  sogi-alpha-x2 /float := 0.0

  // SOGI state variables for beta axis: x1 = v', x2 = q v'
  sogi-beta-x1 /float := 0.0
  sogi-beta-x2 /float := 0.0

  // PI loop filter parameters for phase locking
  kp /float := 60.0
  ki /float := 1800.0
  pi-integrator /float := 0.0

  // PLL output states: estimated frequency (Hz) and synchronized angle (radians [0, 2*pi))
  estimated-freq /float := 0.0
  synchronized-angle /float := 0.0

  /**
  Initialize DSOGI-PLL.
  $nominal-freq: Base grid frequency in Hz (50.0 or 60.0).
  $sampling-rate: Waveform sampling rate in Hz (e.g. 3840.0).
  */
  constructor --nominal-freq/float=60.0 --sampling-rate/float=3840.0:
    this.nominal-freq = nominal-freq
    this.omega-0 = 2.0 * math.PI * nominal-freq
    this.sampling-rate = sampling-rate
    this.dt = 1.0 / sampling-rate
    this.estimated-freq = nominal-freq
    this.synchronized-angle = 0.0

  /** Reset internal integrators and filter states. */
  reset -> none:
    sogi-alpha-x1 = 0.0
    sogi-alpha-x2 = 0.0
    sogi-beta-x1 = 0.0
    sogi-beta-x2 = 0.0
    pi-integrator = 0.0
    estimated-freq = nominal-freq
    synchronized-angle = 0.0

  /**
  Process single-step two-axis stationary coordinates (v_alpha, v_beta).
  For single-phase PMU: feed v_alpha = v_in, v_beta = 0.
  For three-phase PMU: feed Clarke-transformed alpha and beta voltages.
  Returns estimated frequency in Hz.
  */
  process v-alpha/float v-beta/float -> float:
    omega := 2.0 * math.PI * estimated-freq

    // 1. SOGI-QSG integration for Alpha axis
    err-alpha := v-alpha - sogi-alpha-x1
    dx1-alpha := (2.0 * xi * omega * err-alpha) - (omega * sogi-alpha-x2)
    dx2-alpha := omega * sogi-alpha-x1

    sogi-alpha-x1 += dx1-alpha * dt
    sogi-alpha-x2 += dx2-alpha * dt

    // 2. SOGI-QSG integration for Beta axis
    err-beta := v-beta - sogi-beta-x1
    dx1-beta := (2.0 * xi * omega * err-beta) - (omega * sogi-beta-x2)
    dx2-beta := omega * sogi-beta-x1

    sogi-beta-x1 += dx1-beta * dt
    sogi-beta-x2 += dx2-beta * dt

    // 3. Positive Sequence Calculation (PSC):
    // v_alpha+ = 0.5 * (v_alpha' - q v_beta')
    // v_beta+  = 0.5 * (q v_alpha' + v_beta')
    v-alpha-pos := 0.5 * (sogi-alpha-x1 - sogi-beta-x2)
    v-beta-pos  := 0.5 * (sogi-alpha-x2 + sogi-beta-x1)

    // 4. Amplitude normalization to maintain consistent loop bandwidth
    vm := math.sqrt ((v-alpha-pos * v-alpha-pos) + (v-beta-pos * v-beta-pos))
    if vm < 1.0: vm = 1.0

    // 5. Synchronous Reference Frame (Park transform):
    // v_q = (-v_alpha+ * sin(theta) + v_beta+ * cos(theta)) / vm
    cos-theta := math.cos synchronized-angle
    sin-theta := math.sin synchronized-angle
    v-q := ((-v-alpha-pos * sin-theta) + (v-beta-pos * cos-theta)) / vm

    // 6. PI Loop Filter driving normalized v_q to 0
    pi-integrator += ki * v-q * dt
    // Anti-windup on PI integrator
    if pi-integrator > 100.0: pi-integrator = 100.0
    if pi-integrator < -100.0: pi-integrator = -100.0

    delta-omega := (kp * v-q) + pi-integrator
    estimated-freq = (omega-0 + delta-omega) / (2.0 * math.PI)

    // Clamp frequency to reasonable utility bounds [40 Hz, 80 Hz]
    if estimated-freq < 40.0: estimated-freq = 40.0
    if estimated-freq > 80.0: estimated-freq = 80.0

    // 7. Integrate synchronized phase angle
    synchronized-angle += (2.0 * math.PI * estimated-freq) * dt
    while synchronized-angle >= 2.0 * math.PI:
      synchronized-angle -= 2.0 * math.PI
    while synchronized-angle < 0.0:
      synchronized-angle += 2.0 * math.PI

    return estimated-freq
