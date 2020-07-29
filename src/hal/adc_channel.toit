// Selsyn: IEEE C37.118 Synchrophasor Measurement and Grid Stability Controller
// Multi-Channel Synchronous ADC Interface and Calibration Scaling.

/**
Analog input channel calibration parameters.
Maps raw integer ADC sample counts to calibrated engineering units (Volts or Amperes).
  V_actual = (raw_adc - offset) * gain
*/
class AdcCalibration:
  offset /float := 0.0
  gain   /float := 1.0

  constructor --offset/float=0.0 --gain/float=1.0:
    this.offset = offset
    this.gain = gain

  /** Convert raw integer ADC count to floating-point engineering measurement. */
  scale raw/int -> float:
    return (raw.to-float - offset) * gain

/**
Represents an ADC input channel.
*/
class AdcChannel:
  name        /string
  pin         /int
  calibration /AdcCalibration

  constructor .name --pin/int=0 --calibration/AdcCalibration=(AdcCalibration):
    this.pin = pin
    this.calibration = calibration

  /** Process raw sample count into calibrated physical measurement. */
  read-scaled raw-sample/int -> float:
    return calibration.scale raw-sample
