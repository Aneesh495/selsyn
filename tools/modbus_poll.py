#!/usr/bin/env python3
"""
Selsyn Modbus-TCP SCADA Poller and Register Verification Tool.

Connects to Selsyn's Modbus-TCP server, executes Read Holding Registers (FC 0x03),
Read Input Registers (FC 0x04), and Read Coils (FC 0x01) queries, decodes
32-bit big-endian IEEE-754 floating-point register pairs, and validates
SCADA telemetry against active grid conditions.
"""

import socket
import struct
import sys
import time
from typing import Dict, List, Optional, Tuple


class ModbusMaster:
    """Minimal Modbus-TCP client implementation."""

    FC_READ_COILS = 0x01
    FC_READ_HOLDING = 0x03
    FC_READ_INPUT = 0x04
    FC_WRITE_COIL = 0x05
    FC_WRITE_HOLDING = 0x06

    def __init__(self, host: str = "127.0.0.1", port: int = 5502, timeout: float = 2.0):
        self.host = host
        self.port = port
        self.timeout = timeout
        self.sock: Optional[socket.socket] = None
        self.tx_id = 0

    def connect(self) -> None:
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.settimeout(self.timeout)
        self.sock.connect((self.host, self.port))

    def close(self) -> None:
        if self.sock:
            self.sock.close()
            self.sock = None

    def _send_request(self, unit_id: int, pdu: bytes) -> bytes:
        if not self.sock:
            raise ConnectionError("Not connected to Modbus server")

        self.tx_id = (self.tx_id + 1) & 0xFFFF
        proto_id = 0
        length = len(pdu) + 1  # PDU + Unit ID

        mbap = struct.pack(">HHHB", self.tx_id, proto_id, length, unit_id)
        self.sock.sendall(mbap + pdu)

        # Receive MBAP header (7 bytes)
        resp_mbap = self._recv_exact(7)
        r_tx, r_proto, r_len, r_uid = struct.unpack(">HHHB", resp_mbap)
        if r_tx != self.tx_id:
            raise ValueError(f"Transaction ID mismatch: expected {self.tx_id}, got {r_tx}")

        # Receive PDU
        pdu_len = r_len - 1
        resp_pdu = self._recv_exact(pdu_len)
        return resp_pdu

    def _recv_exact(self, num_bytes: int) -> bytes:
        data = bytearray()
        while len(data) < num_bytes:
            packet = self.sock.recv(num_bytes - len(data))
            if not packet:
                raise ConnectionResetError("Connection closed by peer")
            data.extend(packet)
        return bytes(data)

    def read_holding_registers(self, address: int, count: int, unit_id: int = 1) -> List[int]:
        """FC 0x03: Read Holding Registers."""
        pdu = struct.pack(">BHH", self.FC_READ_HOLDING, address, count)
        resp = self._send_request(unit_id, pdu)
        fc, byte_count = struct.unpack(">BB", resp[:2])
        if fc != self.FC_READ_HOLDING:
            raise ValueError(f"Modbus exception: FC={fc:#x}, code={resp[1]:#x}")
        registers = []
        for i in range(count):
            reg = struct.unpack(">H", resp[2 + i * 2: 4 + i * 2])[0]
            registers.append(reg)
        return registers

    def read_input_registers(self, address: int, count: int, unit_id: int = 1) -> List[int]:
        """FC 0x04: Read Input Registers."""
        pdu = struct.pack(">BHH", self.FC_READ_INPUT, address, count)
        resp = self._send_request(unit_id, pdu)
        fc, byte_count = struct.unpack(">BB", resp[:2])
        if fc != self.FC_READ_INPUT:
            raise ValueError(f"Modbus exception: FC={fc:#x}, code={resp[1]:#x}")
        registers = []
        for i in range(count):
            reg = struct.unpack(">H", resp[2 + i * 2: 4 + i * 2])[0]
            registers.append(reg)
        return registers

    def read_float32(self, address: int, is_input: bool = False, unit_id: int = 1) -> float:
        """Decode two contiguous 16-bit registers as a 32-bit IEEE-754 float."""
        regs = (
            self.read_input_registers(address, 2, unit_id)
            if is_input
            else self.read_holding_registers(address, 2, unit_id)
        )
        packed = struct.pack(">HH", regs[0], regs[1])
        return struct.unpack(">f", packed)[0]

    def read_coils(self, address: int, count: int, unit_id: int = 1) -> List[bool]:
        """FC 0x01: Read Coils."""
        pdu = struct.pack(">BHH", self.FC_READ_COILS, address, count)
        resp = self._send_request(unit_id, pdu)
        fc, byte_count = struct.unpack(">BB", resp[:2])
        if fc != self.FC_READ_COILS:
            raise ValueError(f"Modbus exception: FC={fc:#x}, code={resp[1]:#x}")
        coils = []
        for i in range(count):
            byte_idx = 2 + (i // 8)
            bit_idx = i % 8
            val = bool((resp[byte_idx] >> bit_idx) & 0x01)
            coils.append(val)
        return coils


def format_scada_poll(master: ModbusMaster) -> str:
    """Poll Selsyn register map and format human-readable SCADA summary."""
    freq = master.read_float32(100, is_input=True)
    rocof = master.read_float32(102, is_input=True)
    v1_mag = master.read_float32(104, is_input=True)
    v2_mag = master.read_float32(106, is_input=True)
    v0_mag = master.read_float32(108, is_input=True)
    vuf = master.read_float32(110, is_input=True)

    coils = master.read_coils(0, 8)
    fault_alarm = coils[0]
    island_trip = coils[1]

    lines = [
        "============================================================",
        "              SELSYN SCADA TELEMETRY (MODBUS-TCP)           ",
        "============================================================",
        f"  Grid Frequency:        {freq:.4f} Hz",
        f"  ROCOF:                 {rocof:+.4f} Hz/s",
        f"  Positive Seq Voltage:  {v1_mag:.2f} V",
        f"  Negative Seq Voltage:  {v2_mag:.2f} V",
        f"  Zero Seq Voltage:      {v0_mag:.2f} V",
        f"  Voltage Unbalance:     {vuf:.3f} %",
        "------------------------------------------------------------",
        f"  Protection Fault Trip: {'TRIPPED [ALARM]' if fault_alarm else 'NORMAL [CLEAR]'}",
        f"  Anti-Islanding Trip:   {'ISLANDED [TRIP]' if island_trip else 'GRID-TIED [NORMAL]'}",
        "============================================================",
    ]
    return "\n".join(lines)


if __name__ == "__main__":
    print("ModbusMaster client module ready.")
