// Selsyn: IEEE C37.118 Synchrophasor Measurement and Grid Stability Controller
// Virtual Synchronous Generator (VSG) Swing Equation Synthetic Inertia Emulation.

import math

/**
Virtual Synchronous Generator (VSG) emulating physical synchronous machine rotor dynamics.
Provides synthetic inertia (H) and damping (D) for low-inertia renewable grids.
*/
class VirtualSynchronousGenerator:
  inertia-h       /float  // Virtual inertia constant (seconds, e.g. 4.0s)
  damping-d       /float  // Damping factor (e.g. 15.0 pu)
  nominal-omega   /float  // Base angular speed (rad/s): 2 * pi * 60 = 376.99
  p-rated         /float  // Rated power (W or kW)

  // Dynamic states
  omega           /float := 0.0  // Current virtual angular velocity (rad/s)
  theta           /float := 0.0  // Virtual rotor angle (radians)

  constructor
      --inertia-h/float=4.0
      --damping-d/float=15.0
      --nominal-freq/float=60.0
      --p-rated/float=100.0:
    this.inertia-h = inertia-h
    this.damping-d = damping-d
    this.nominal-omega = 2.0 * math.PI * nominal-freq
    this.p-rated = p-rated
    this.omega = nominal-omega
    this.theta = 0.0

  /** Reset rotor speed and angle to nominal. */
  reset -> none:
    omega = nominal-omega
    theta = 0.0

  /**
  Integrate swing equation over time step $dt:
    2 * H * (d_omega / dt) = (P_m - P_e) / P_rated - D * (omega - omega_0) / omega_0
  $p-mech: Virtual mechanical input power setpoint.
  $p-elec: Measured actual electrical output power.
  $dt: Integration step in seconds (e.g. 0.001s = 1 ms).
  Returns current electrical frequency in Hz: f = omega / (2 * pi).
  */
  step p-mech/float p-elec/float dt/float -> float:
    // Per-unit power accelerating difference
    p-acc-pu := (p-mech - p-elec) / p-rated

    // Damping power term: D * Delta_omega_pu
    delta-omega-pu := (omega - nominal-omega) / nominal-omega
    p-damp-pu := damping-d * delta-omega-pu

    // Accelerating torque: 2*H * d_omega_pu / dt = P_acc - P_damp
    d-omega-pu-dt := (p-acc-pu - p-damp-pu) / (2.0 * inertia-h)

    // Integrate angular velocity
    omega += d-omega-pu-dt * nominal-omega * dt

    // Integrate rotor angle
    theta += omega * dt
    while theta >= 2.0 * math.PI:
      theta -= 2.0 * math.PI
    while theta < 0.0:
      theta += 2.0 * math.PI

    return omega / (2.0 * math.PI)
