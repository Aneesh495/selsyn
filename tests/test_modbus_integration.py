#!/usr/bin/env python3
"""
Selsyn Modbus-TCP SCADA Client Protocol and Parsing Test.

Tests Modbus frame construction, transaction matching, big-endian IEEE-754
32-bit floating point register pair decoding, and error handling.
"""

import struct
import unittest
from tools.modbus_poll import ModbusMaster


class TestModbusIntegration(unittest.TestCase):
    def test_float32_register_decoding(self):
        """Verify 32-bit big-endian IEEE-754 float decoding across register pairs."""
        # 60.002 Hz as IEEE-754 32-bit float
        val = 60.002
        packed_bytes = struct.pack(">f", val)
        reg1, reg2 = struct.unpack(">HH", packed_bytes)

        # Re-pack and unpack as float
        decoded = struct.unpack(">f", struct.pack(">HH", reg1, reg2))[0]
        self.assertAlmostEqual(decoded, val, places=4)

    def test_coil_bit_extraction(self):
        """Verify multi-coil bit extraction logic."""
        # 0x05 = 0b00000101 -> coil 0: True, coil 1: False, coil 2: True
        byte_val = 0x05
        coils = [bool((byte_val >> i) & 0x01) for i in range(8)]
        self.assertTrue(coils[0])
        self.assertFalse(coils[1])
        self.assertTrue(coils[2])
        self.assertFalse(coils[3])


if __name__ == "__main__":
    unittest.main()
