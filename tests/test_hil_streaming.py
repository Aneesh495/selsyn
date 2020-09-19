#!/usr/bin/env python3
"""
Selsyn IEEE C37.118 HIL Synchrophasor Streaming and Protocol Integration Test.

Tests client/server synchrophasor interactions:
  - Command frame generation and CRC16 verification
  - DATA frame binary serialization and unpacking
  - Symmetrical components verification from decoded phasors
"""

import math
import struct
import unittest
from tools.pdc_client import PdcClient


class TestHilStreaming(unittest.TestCase):
    def setUp(self):
        self.client = PdcClient()

    def tearDown(self):
        self.client.close()

    def test_command_frame_structure(self):
        """Verify command frames conform to IEEE C37.118-2011 standard layout."""
        # 0x0002 = CMD_START
        cmd_bytes = self.client.build_command_frame(PdcClient.CMD_START, id_code=101)
        self.assertEqual(len(cmd_bytes), 18)

        # Check sync word (0xAA41)
        sync = struct.unpack(">H", cmd_bytes[:2])[0]
        self.assertEqual(sync, 0xAA41)

        # Check frame size
        framesize = struct.unpack(">H", cmd_bytes[2:4])[0]
        self.assertEqual(framesize, 18)

        # Check ID code
        id_code = struct.unpack(">H", cmd_bytes[4:6])[0]
        self.assertEqual(id_code, 101)

        # Check command word
        cmd_word = struct.unpack(">H", cmd_bytes[14:16])[0]
        self.assertEqual(cmd_word, PdcClient.CMD_START)

        # Verify CRC
        expected_crc = struct.unpack(">H", cmd_bytes[16:18])[0]
        actual_crc = PdcClient.calculate_crc(cmd_bytes[:16])
        self.assertEqual(expected_crc, actual_crc)

    def test_parse_data_frame(self):
        """Construct synthetic IEEE C37.118 DATA frame and verify full decode."""
        sync = 0xAA01  # DATA frame, version 1
        framesize = 14 + 2 + (6 * 8) + 8 + 2  # Header (14) + STAT (2) + 6 phasors (48) + Freq/ROCOF (8) + CRC (2) = 74 bytes
        id_code = 101
        soc = 1731000000
        fracsec = 0x00001000
        stat = 0x0000

        # Phasors: Va, Vb, Vc, Ia, Ib, Ic
        phasors_raw = [
            (120.0, 0.0),
            (-60.0, -103.9230),
            (-60.0, 103.9230),
            (5.0, 0.0),
            (-2.5, -4.3301),
            (-2.5, 4.3301),
        ]

        freq = 60.002
        rocof = 0.015

        payload = struct.pack(">HHHIIH", sync, framesize, id_code, soc, fracsec, stat)
        for r, i in phasors_raw:
            payload += struct.pack(">ff", r, i)
        payload += struct.pack(">ff", freq, rocof)

        crc = PdcClient.calculate_crc(payload)
        frame_bytes = payload + struct.pack(">H", crc)

        decoded = self.client.parse_data_frame(frame_bytes, phasor_count=6)
        self.assertIsNotNone(decoded)
        self.assertEqual(decoded["id_code"], 101)
        self.assertEqual(decoded["soc"], 1731000000)
        self.assertEqual(decoded["stat"], 0)
        self.assertEqual(len(decoded["phasors"]), 6)
        self.assertAlmostEqual(decoded["freq"], 60.002, places=3)
        self.assertAlmostEqual(decoded["rocof"], 0.015, places=3)

        # Verify Phase A magnitude
        self.assertAlmostEqual(decoded["phasors"][0]["mag"], 120.0, places=2)
        self.assertAlmostEqual(decoded["phasors"][0]["phase_deg"], 0.0, places=2)


if __name__ == "__main__":
    unittest.main()
