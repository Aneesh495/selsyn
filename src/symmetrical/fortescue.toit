// Selsyn: IEEE C37.118 Synchrophasor Measurement and Grid Stability Controller
// Fortescue Symmetrical Components Decomposition and Synthesis.

import math
import ..dsp.complex show Complex

/**
Fortescue Symmetrical Components (Zero, Positive, Negative sequences).
Decomposes unbalanced three-phase power waveforms into balanced symmetrical modes.
*/
class SymmetricalComponents:
  zero     /Complex := Complex.zero  // V0 or I0
  positive /Complex := Complex.zero  // V1 or I1
  negative /Complex := Complex.zero  // V2 or I2

  constructor .zero .positive .negative:

  /** Complex rotation operator alpha = e^(j * 2*pi / 3) = 1.0 /_ 120 deg. */
  static ALPHA /Complex ::= Complex (-0.5) ((math.sqrt 3.0) / 2.0)

  /** Complex rotation operator alpha^2 = e^(j * 4*pi / 3) = 1.0 /_ 240 deg. */
  static ALPHA-SQ /Complex ::= Complex (-0.5) (-((math.sqrt 3.0) / 2.0))

  /**
  Decompose three phase phasors (A, B, C) into Symmetrical Components (V0, V1, V2).
  */
  static decompose phase-a/Complex phase-b/Complex phase-c/Complex -> SymmetricalComponents:
    one-third := 1.0 / 3.0

    // V0 = 1/3 * (Va + Vb + Vc)
    sum-zero := phase-a + phase-b + phase-c
    v0 := sum-zero.scale one-third

    // V1 = 1/3 * (Va + alpha * Vb + alpha^2 * Vc)
    term-b-pos := phase-b * ALPHA
    term-c-pos := phase-c * ALPHA-SQ
    sum-pos := phase-a + term-b-pos + term-c-pos
    v1 := sum-pos.scale one-third

    // V2 = 1/3 * (Va + alpha^2 * Vb + alpha * Vc)
    term-b-neg := phase-b * ALPHA-SQ
    term-c-neg := phase-c * ALPHA
    sum-neg := phase-a + term-b-neg + term-c-neg
    v2 := sum-neg.scale one-third

    return SymmetricalComponents v0 v1 v2

  /**
  Synthesize three phase phasors from symmetrical components (V0, V1, V2).
  Returns a List [phase_a, phase_b, phase_c].
  */
  synthesize -> List:
    // Va = V0 + V1 + V2
    va := zero + positive + negative

    // Vb = V0 + alpha^2 * V1 + alpha * V2
    vb := zero + (positive * ALPHA-SQ) + (negative * ALPHA)

    // Vc = V0 + alpha * V1 + alpha^2 * V2
    vc := zero + (positive * ALPHA) + (negative * ALPHA-SQ)

    return [va, vb, vc]
