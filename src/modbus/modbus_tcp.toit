// Selsyn: IEEE C37.118 Synchrophasor Measurement and Grid Stability Controller
// Modbus-TCP Slave Protocol Server Engine.

import io show BIG-ENDIAN
import .register_map show ModbusRegisterMap

/**
Modbus standard exception codes.
*/
class ModbusException:
  static ILLEGAL-FUNCTION /int ::= 0x01
  static ILLEGAL-ADDRESS  /int ::= 0x02
  static ILLEGAL-VALUE    /int ::= 0x03
  static SERVER-FAILURE   /int ::= 0x04

/**
Modbus-TCP protocol engine. Parses MBAP requests and generates response packets.
*/
class ModbusTcpServer:
  register-map /ModbusRegisterMap

  // Function codes
  static FC-READ-COILS             /int ::= 0x01
  static FC-READ-DISCRETE-INPUTS   /int ::= 0x02
  static FC-READ-HOLDING-REGISTERS /int ::= 0x03
  static FC-READ-INPUT-REGISTERS   /int ::= 0x04
  static FC-WRITE-SINGLE-COIL      /int ::= 0x05
  static FC-WRITE-SINGLE-REGISTER  /int ::= 0x06

  constructor .register-map:

  /**
  Handle an incoming Modbus-TCP request byte array and return the response byte array.
  MBAP Header (7 bytes):
    Transaction ID (2), Protocol ID (2), Length (2), Unit ID (1)
  PDU:
    Function Code (1), Data (N)
  */
  handle-request request/ByteArray -> ByteArray:
    if request.size < 8:
      throw "Modbus-TCP request underflow: minimum 8 bytes required"

    trans-id := BIG-ENDIAN.uint16 request 0
    proto-id := BIG-ENDIAN.uint16 request 2
    len      := BIG-ENDIAN.uint16 request 4
    unit-id  := request[6]
    fc       := request[7]

    if proto-id != 0:
      return make-exception trans-id unit-id fc ModbusException.SERVER-FAILURE

    try:
      if fc == FC-READ-INPUT-REGISTERS or fc == FC-READ-HOLDING-REGISTERS:
        if request.size < 12:
          return make-exception trans-id unit-id fc ModbusException.ILLEGAL-VALUE
        start-addr := BIG-ENDIAN.uint16 request 8
        reg-count  := BIG-ENDIAN.uint16 request 10

        if reg-count < 1 or reg-count > 125:
          return make-exception trans-id unit-id fc ModbusException.ILLEGAL-VALUE

        byte-count := reg-count * 2
        pdu-len := 1 + 1 + 1 + byte-count  // Unit ID (1) + FC (1) + ByteCount (1) + Bytes
        resp := ByteArray (6 + pdu-len)

        // MBAP header
        BIG-ENDIAN.put-uint16 resp 0 trans-id
        BIG-ENDIAN.put-uint16 resp 2 0x0000
        BIG-ENDIAN.put-uint16 resp 4 (pdu-len)
        resp[6] = unit-id
        resp[7] = fc
        resp[8] = byte-count

        offset := 9
        for i := 0; i < reg-count; i++:
          val := register-map.read-input-register (start-addr + i)
          BIG-ENDIAN.put-uint16 resp offset val
          offset += 2
        return resp

      else if fc == FC-READ-DISCRETE-INPUTS:
        if request.size < 12:
          return make-exception trans-id unit-id fc ModbusException.ILLEGAL-VALUE
        start-addr := BIG-ENDIAN.uint16 request 8
        bit-count  := BIG-ENDIAN.uint16 request 10

        byte-count := (bit-count + 7) / 8
        pdu-len := 1 + 1 + 1 + byte-count
        resp := ByteArray (6 + pdu-len)

        BIG-ENDIAN.put-uint16 resp 0 trans-id
        BIG-ENDIAN.put-uint16 resp 2 0x0000
        BIG-ENDIAN.put-uint16 resp 4 pdu-len
        resp[6] = unit-id
        resp[7] = fc
        resp[8] = byte-count

        for b := 0; b < byte-count; b++:
          resp[9 + b] = 0

        for i := 0; i < bit-count; i++:
          bit-val := register-map.read-discrete-input (start-addr + i)
          if bit-val:
            byte-idx := 9 + (i / 8)
            bit-pos := i % 8
            resp[byte-idx] |= (1 << bit-pos)

        return resp

      else:
        return make-exception trans-id unit-id fc ModbusException.ILLEGAL-FUNCTION

    finally:
      // Exception fallback handled in catch

    return make-exception trans-id unit-id fc ModbusException.ILLEGAL-ADDRESS

  /** Construct standard Modbus exception response. */
  make-exception trans-id/int unit-id/int fc/int exception-code/int -> ByteArray:
    resp := ByteArray 9
    BIG-ENDIAN.put-uint16 resp 0 trans-id
    BIG-ENDIAN.put-uint16 resp 2 0x0000
    BIG-ENDIAN.put-uint16 resp 4 3  // Length: Unit ID (1) + Exception FC (1) + Code (1)
    resp[6] = unit-id
    resp[7] = fc | 0x80  // Exception flag (MSB set)
    resp[8] = exception-code
    return resp
