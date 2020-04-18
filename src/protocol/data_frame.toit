// Selsyn: IEEE C37.118 Synchrophasor Measurement and Grid Stability Controller
// IEEE C37.118 DATA Frame Encoder and Decoder.

import io show BIG-ENDIAN
import .crc16 show CrcCcitt
import .frame show Frame
import ..dsp.complex show Complex

/**
Phasor coordinate representation format in DATA frames.
*/
class PhasorFormat:
  static RECTANGULAR /int ::= 0
  static POLAR       /int ::= 1

/**
Number format in DATA frames: 32-bit IEEE float or 16-bit scaled integer.
*/
class NumberFormat:
  static FLOAT   /int ::= 0
  static INTEGER /int ::= 1

/**
Represents a single PMU measurement block inside an IEEE C37.118 DATA frame.
*/
class PmuDataBlock:
  stat       /int := 0
  phasors    /List := []       // List of Complex phasors
  frequency  /float := 60.0    // Frequency in Hz
  rocof      /float := 0.0     // Rate of Change of Frequency in Hz/s
  analogs    /List := []       // List of float analog channel values
  digitals   /List := []       // List of int 16-bit digital channel words

  constructor
      --stat/int=0
      --phasors/List=[]
      --frequency/float=60.0
      --rocof/float=0.0
      --analogs/List=[]
      --digitals/List=[]:
    this.stat = stat
    this.phasors = phasors
    this.frequency = frequency
    this.rocof = rocof
    this.analogs = analogs
    this.digitals = digitals

/**
IEEE C37.118 DATA frame encoder and decoder.
*/
class DataFrame extends Frame:
  blocks /List := []  // List of PmuDataBlock

  constructor
      --id-code/int
      --soc/int
      --fracsec/int
      --blocks/List:
    this.blocks = blocks
    // Compute total frame length
    payload-size := 0
    blocks.do: | block/PmuDataBlock |
      // STAT (2) + Phasors (num * 8 for float) + FREQ (4) + DFREQ (4) + Analogs (num * 4) + Digitals (num * 2)
      payload-size += 2 + (block.phasors.size * 8) + 8 + (block.analogs.size * 4) + (block.digitals.size * 2)

    total-size := 14 + payload-size + 2  // Header (14) + Payload + CRC (2)
    sync := (Frame.SYNC-BYTE << 8) | Frame.TYPE-DATA | Frame.VERSION-1
    super sync total-size id-code soc fracsec

  /**
  Encode DATA frame to a newly allocated binary ByteArray with valid CRC-CCITT.
  */
  encode --phasor-format/int=PhasorFormat.RECTANGULAR -> ByteArray:
    buffer := ByteArray frame-size
    serialize-header buffer 0

    offset := 14
    blocks.do: | block/PmuDataBlock |
      // 1. STAT word (16-bit)
      BIG-ENDIAN.put-uint16 buffer offset block.stat
      offset += 2

      // 2. Phasors (32-bit floats)
      block.phasors.do: | p/Complex |
        if phasor-format == PhasorFormat.RECTANGULAR:
          BIG-ENDIAN.put-float32 buffer offset p.real
          BIG-ENDIAN.put-float32 buffer (offset + 4) p.imag
        else:
          BIG-ENDIAN.put-float32 buffer offset p.magnitude
          BIG-ENDIAN.put-float32 buffer (offset + 4) p.phase
        offset += 8

      // 3. Frequency and ROCOF (32-bit floats)
      BIG-ENDIAN.put-float32 buffer offset block.frequency
      BIG-ENDIAN.put-float32 buffer (offset + 4) block.rocof
      offset += 8

      // 4. Analog values (32-bit floats)
      block.analogs.do: | val/float |
        BIG-ENDIAN.put-float32 buffer offset val
        offset += 4

      // 5. Digital status words (16-bit uints)
      block.digitals.do: | dig/int |
        BIG-ENDIAN.put-uint16 buffer offset dig
        offset += 2

    // 6. Compute and append 16-bit CRC
    CrcCcitt.append-crc buffer
    return buffer

  /**
  Decode raw bytes into a DataFrame.
  $bytes: Raw incoming byte array.
  $phasor-count: Number of phasor channels per PMU block.
  $analog-count: Number of analog channels.
  $digital-count: Number of digital status words.
  $phasor-format: PhasorFormat.RECTANGULAR or POLAR.
  */
  static decode bytes/ByteArray
      --phasor-count/int
      --analog-count/int=0
      --digital-count/int=0
      --phasor-format/int=PhasorFormat.RECTANGULAR -> DataFrame:
    if not (CrcCcitt.verify bytes):
      throw "CRC verification failure on IEEE C37.118 DATA frame"

    base := Frame.parse-header bytes
    if base.frame-type != Frame.TYPE-DATA:
      throw "Invalid frame type: expected DATA (0x00), got $(%x base.frame-type)"

    offset := 14
    blocks := []

    // Parse single PMU block
    stat := BIG-ENDIAN.uint16 bytes offset
    offset += 2

    phasor-list := []
    phasor-count.repeat:
      c1 := BIG-ENDIAN.float32 bytes offset
      c2 := BIG-ENDIAN.float32 bytes (offset + 4)
      p := (phasor-format == PhasorFormat.RECTANGULAR) ? (Complex c1 c2) : (Complex.polar c1 c2)
      phasor-list.add p
      offset += 8

    freq := BIG-ENDIAN.float32 bytes offset
    rocof := BIG-ENDIAN.float32 bytes (offset + 4)
    offset += 8

    analog-list := []
    analog-count.repeat:
      aval := BIG-ENDIAN.float32 bytes offset
      analog-list.add aval
      offset += 4

    digital-list := []
    digital-count.repeat:
      dval := BIG-ENDIAN.uint16 bytes offset
      digital-list.add dval
      offset += 2

    block := PmuDataBlock
      --stat=stat
      --phasors=phasor-list
      --frequency=freq
      --rocof=rocof
      --analogs=analog-list
      --digitals=digital-list
    blocks.add block

    return DataFrame
      --id-code=base.id-code
      --soc=base.soc
      --fracsec=base.fracsec
      --blocks=blocks
