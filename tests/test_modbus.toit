// Selsyn test suite: Modbus register mapping and Modbus-TCP server.

import io show BIG-ENDIAN
import ..src.modbus.register_map show ModbusRegisterMap
import ..src.modbus.modbus_tcp show ModbusTcpServer ModbusException

main:
  reg-map := ModbusRegisterMap
  server := ModbusTcpServer reg-map

  // 1. Update telemetry in register map
  reg-map.update-telemetry
    --freq=60.02
    --rocof=-0.15
    --va-mag=120.4
    --vb-mag=120.0
    --vc-mag=119.8
    --ia-mag=5.25
    --ib-mag=5.20
    --ic-mag=5.18
    --p-kw=45.0
    --q-kvar=12.5
    --v0=0.2
    --v1=120.0
    --v2=0.4
    --vuf=0.33
    --fault-code=0
    --tripped=false
    --islanded=false

  if (reg-map.read-input-register 0) != 6002:
    throw "Frequency register mismatch: expected 6002, got $(reg-map.read-input-register 0)"
  if (reg-map.read-input-register 2) != 1204:
    throw "Va register mismatch: expected 1204, got $(reg-map.read-input-register 2)"

  // 2. Test Modbus-TCP FC 0x04 (Read Input Registers: start 0, count 3)
  req := ByteArray 12
  BIG-ENDIAN.put-uint16 req 0 0x1234  // Transaction ID
  BIG-ENDIAN.put-uint16 req 2 0x0000  // Protocol ID
  BIG-ENDIAN.put-uint16 req 4 0x0006  // Length: 6 bytes follow
  req[6] = 1                         // Unit ID
  req[7] = 4                         // FC 0x04
  BIG-ENDIAN.put-uint16 req 8 0x0000  // Start address
  BIG-ENDIAN.put-uint16 req 10 3      // Count: 3 registers

  resp := server.handle-request req

  // Verify response
  if (BIG-ENDIAN.uint16 resp 0) != 0x1234:
    throw "Response transaction ID mismatch"
  if resp[7] != 4:
    throw "Response function code mismatch"
  if resp[8] != 6:
    throw "Response byte count mismatch: expected 6 bytes, got $(resp[8])"

  r0 := BIG-ENDIAN.uint16 resp 9
  r2 := BIG-ENDIAN.uint16 resp 13
  if r0 != 6002:
    throw "Modbus returned incorrect freq register: expected 6002, got $r0"
  if r2 != 1204:
    throw "Modbus returned incorrect Va register: expected 1204, got $r2"

  // 3. Test Unsupported Function Code Exception (FC 0x2B)
  req-bad := ByteArray 12
  BIG-ENDIAN.put-uint16 req-bad 0 0x9999
  BIG-ENDIAN.put-uint16 req-bad 2 0x0000
  BIG-ENDIAN.put-uint16 req-bad 4 0x0006
  req-bad[6] = 1
  req-bad[7] = 0x2B  // Unknown function code

  resp-bad := server.handle-request req-bad
  if resp-bad[7] != (0x2B | 0x80):
    throw "Expected exception response code 0xAB, got 0x$(%x resp-bad[7])"
  if resp-bad[8] != ModbusException.ILLEGAL-FUNCTION:
    throw "Expected ILLEGAL_FUNCTION exception code 1, got $(resp-bad[8])"

  print "test_modbus: ALL TESTS PASSED."
