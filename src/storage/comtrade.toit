// Selsyn: IEEE C37.118 Synchrophasor Measurement and Grid Stability Controller
// IEEE C37.111 COMTRADE (1999/2013) Oscillogram Configuration and Data Serializer.

import .fault_recorder show OscillogramSnapshot

/**
IEEE C37.111 COMTRADE generator for power system transient oscillography.
Produces standard ASCII .CFG configuration files and .DAT sample records.
*/
class ComtradeWriter:
  station-name /string
  device-id    /string
  revision     /string := "1999"

  constructor --station-name/string="SELSYN_PMU" --device-id/string="PMU_101" --revision/string="1999":
    this.station-name = station-name
    this.device-id = device-id
    this.revision = revision

  /**
  Generate IEEE C37.111 .CFG configuration ASCII string.
  */
  generate-cfg snapshot/OscillogramSnapshot -> string:
    num-analogs := snapshot.channel-names.size
    num-digitals := 0
    total-ch := num-analogs + num-digitals

    lines := []
    // Line 1: Station, Device, Standard Revision Year
    lines.add "$station-name,$device-id,$revision"

    // Line 2: Channel counts
    lines.add "$total-ch,$(num-analogs)A,$(num-digitals)D"

    // Analog channel descriptors
    for i := 0; i < num-analogs; i++:
      ch-name := snapshot.channel-names[i]
      phase := (ch-name.size >= 2) ? ch-name[1..2] : ""
      unit := (ch-name.starts-with "I") ? "A" : "V"
      // idx,name,phase,circuit,unit,a,b,skew,min,max,primary,secondary,scaling
      lines.add "$(i + 1),$ch-name,$phase,,$unit,1.0,0.0,0.0,-32768,32767,1.0,1.0,S"

    // Nominal grid frequency
    lines.add "60.0"

    // Sampling rate: 1 rate, sampling_rate Hz, total_samples
    total-samples := snapshot.channel-data[0].size
    lines.add "1,$(snapshot.sampling-rate.round),$total-samples"

    // Timestamps: start and trigger
    lines.add "01/01/2026,00:00:00.000000"
    lines.add "01/01/2026,00:00:00.100000"

    // Data file format: ASCII
    lines.add "ASCII"

    // Timestamp multiplication factor
    lines.add "1.0"

    return (lines.join "\r\n") + "\r\n"

  /**
  Generate IEEE C37.111 .DAT data record ASCII string.
  Format: sample_number,time_us,ch1,ch2,ch3,...
  */
  generate-dat snapshot/OscillogramSnapshot -> string:
    num-analogs := snapshot.channel-names.size
    total-samples := snapshot.channel-data[0].size
    dt-us := 1000000.0 / snapshot.sampling-rate

    lines := []
    for s := 0; s < total-samples; s++:
      time-us := (s.to-float * dt-us).round.to-int
      row := ["$(s + 1)", "$time-us"]
      for ch := 0; ch < num-analogs; ch++:
        val /float := snapshot.channel-data[ch][s]
        row.add "$val"
      lines.add (row.join ",")

    return (lines.join "\r\n") + "\r\n"
