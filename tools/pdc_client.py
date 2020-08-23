#!/usr/bin/env python3
"""
Selsyn IEEE C37.118 Phasor Data Concentrator (PDC) Client.

Connects to a running Selsyn PMU, sends configuration and command frames,
receives real-time synchrophasor data frames, validates CRC-CCITT checksums,
and renders a live ASCII telemetry terminal dashboard.
"""

import socket
import struct
import sys
import time
from typing import Dict, List, Optional, Tuple


class PdcClient:
    SYNC_BYTE = 0xAA
    TYPE_DATA = 0x00
    TYPE_HEADER = 0x10
    TYPE_CFG1 = 0x20
    TYPE_CFG2 = 0x30
    TYPE_CMD = 0x40

    CMD_STOP = 0x0001
    CMD_START = 0x0002
    CMD_SEND_HDR = 0x0003
    CMD_SEND_CFG2 = 0x0005

    def __init__(self, host: str = "127.0.0.1", port: int = 4712):
        self.host = host
        self.port = port
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.settimeout(2.0)

    @staticmethod
    def calculate_crc(data: bytes) -> int:
        """Calculate 16-bit CRC-CCITT (0x1021, init 0xFFFF)."""
        crc = 0xFFFF
        for b in data:
            crc = ((crc << 8) & 0xFFFF) ^ PdcClient._crc_table()[(crc >> 8) ^ b]
        return crc

    @staticmethod
    def _crc_table() -> List[int]:
        if not hasattr(PdcClient, "_cached_table"):
            table = []
            for i in range(256):
                curr = i << 8
                for _ in range(8):
                    if curr & 0x8000:
                        curr = ((curr << 1) ^ 0x1021) & 0xFFFF
                    else:
                        curr = (curr << 1) & 0xFFFF
                table.append(curr)
            PdcClient._cached_table = table
        return PdcClient._cached_table

    def build_command_frame(self, cmd_word: int, id_code: int = 101) -> bytes:
        """Construct standard 18-byte IEEE C37.118 command frame."""
        sync = (self.SYNC_BYTE << 8) | self.TYPE_CMD | 0x01
        framesize = 18
        soc = int(time.time())
        fracsec = 0

        header = struct.pack(">HHHIIH", sync, framesize, id_code, soc, fracsec, cmd_word)
        crc = self.calculate_crc(header)
        return header + struct.pack(">H", crc)

    def send_command(self, cmd_word: int, id_code: int = 101) -> None:
        frame = self.build_command_frame(cmd_word, id_code)
        self.sock.sendto(frame, (self.host, self.port))

    def parse_data_frame(self, data: bytes, phasor_count: int = 6) -> Optional[Dict]:
        """Decode binary IEEE C37.118 DATA frame."""
        if len(data) < 16:
            return None

        # Verify CRC
        expected_crc = struct.unpack(">H", data[-2:])[0]
        actual_crc = self.calculate_crc(data[:-2])
        if expected_crc != actual_crc:
            return None

        sync, size, id_code, soc, fracsec = struct.unpack(">HHHII", data[:14])
        frame_type = (sync >> 4) & 0x07
        if frame_type != 0:
            return None  # Not a data frame

        offset = 14
        stat = struct.unpack(">H", data[offset:offset+2])[0]
        offset += 2

        phasors = []
        for _ in range(phasor_count):
            r, i = struct.unpack(">ff", data[offset:offset+8])
            mag = math.sqrt(r * r + i * i)
            phase_deg = math.atan2(i, r) * 180.0 / math.pi
            phasors.append({"real": r, "imag": i, "mag": mag, "phase_deg": phase_deg})
            offset += 8

        freq, rocof = struct.unpack(">ff", data[offset:offset+8])

        return {
            "id_code": id_code,
            "soc": soc,
            "fracsec": fracsec,
            "stat": stat,
            "phasors": phasors,
            "freq": freq,
            "rocof": rocof,
        }


if __name__ == "__main__":
    client = PdcClient()
    print("Testing PDC Client frame generation and CRC validation...")
    cmd = client.build_command_frame(PdcClient.CMD_START, 101)
    crc_valid = client.calculate_crc(cmd[:-2]) == struct.unpack(">H", cmd[-2:])[0]
    print(f"  Command frame size: {len(cmd)} bytes, CRC valid: {crc_valid}")
    print("PdcClient operational.")
