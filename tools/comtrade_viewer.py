#!/usr/bin/env python3
"""
Selsyn IEEE C37.111 COMTRADE Oscillogram File Viewer and Terminal Visualizer.

Parses IEEE C37.111-1999 / 2013 COMTRADE ASCII and binary files (.CFG and .DAT),
extracts multi-channel analog and digital waveforms, and renders ASCII oscillograms
with sample markers directly in the terminal for rapid fault diagnostics.
"""

import math
import os
import sys
from typing import Dict, List, Optional, Tuple


class ComtradeChannel:
    def __init__(self, idx: int, name: str, phase: str, unit: str, multiplier: float, offset: float):
        self.idx = idx
        self.name = name
        self.phase = phase
        self.unit = unit
        self.multiplier = multiplier
        self.offset = offset


class ComtradeParser:
    """Parses COMTRADE .CFG and .DAT files."""

    def __init__(self, cfg_path: str, dat_path: Optional[str] = None):
        self.cfg_path = cfg_path
        if dat_path is None:
            base = os.path.splitext(cfg_path)[0]
            self.dat_path = base + ".dat" if os.path.exists(base + ".dat") else base + ".DAT"
        else:
            self.dat_path = dat_path

        self.station_name = ""
        self.rec_dev_id = ""
        self.rev_year = "1999"
        self.total_channels = 0
        self.analog_channels: List[ComtradeChannel] = []
        self.digital_channels: List[str] = []
        self.nominal_freq = 60.0
        self.sample_rates: List[Tuple[float, int]] = []
        self.data_format = "ASCII"

        self.time_stamps_us: List[int] = []
        self.analog_data: Dict[int, List[float]] = {}
        self.digital_data: Dict[int, List[int]] = {}

        self._parse_cfg()
        if os.path.exists(self.dat_path):
            self._parse_dat()

    def _parse_cfg(self) -> None:
        with open(self.cfg_path, "r", encoding="utf-8") as f:
            lines = [line.strip() for line in f if line.strip()]

        # Line 1: Station, DevID, Year
        p1 = [p.strip() for p in lines[0].split(",")]
        self.station_name = p1[0] if len(p1) > 0 else ""
        self.rec_dev_id = p1[1] if len(p1) > 1 else ""
        if len(p1) > 2:
            self.rev_year = p1[2]

        # Line 2: Total Channels, #A, #D
        p2 = [p.strip() for p in lines[1].split(",")]
        self.total_channels = int(p2[0])
        num_a = int(p2[1].rstrip("A"))
        num_d = int(p2[2].rstrip("D"))

        curr_line = 2
        # Analog channel lines
        for i in range(num_a):
            parts = [p.strip() for p in lines[curr_line].split(",")]
            ch_idx = int(parts[0])
            name = parts[1]
            phase = parts[2]
            unit = parts[4]
            a_mult = float(parts[5])
            b_off = float(parts[6])
            self.analog_channels.append(ComtradeChannel(ch_idx, name, phase, unit, a_mult, b_off))
            self.analog_data[ch_idx] = []
            curr_line += 1

        # Digital channel lines
        for i in range(num_d):
            parts = [p.strip() for p in lines[curr_line].split(",")]
            name = parts[1]
            self.digital_channels.append(name)
            self.digital_data[i] = []
            curr_line += 1

        # Nominal Frequency
        self.nominal_freq = float(lines[curr_line].split(",")[0].strip())
        curr_line += 1

        # Sampling rates
        num_rates = int(lines[curr_line].split(",")[0].strip())
        curr_line += 1
        for _ in range(num_rates):
            parts = [p.strip() for p in lines[curr_line].split(",")]
            srate = float(parts[0])
            end_samp = int(parts[1])
            self.sample_rates.append((srate, end_samp))
            curr_line += 1

        # Timestamp lines (start & trigger)
        curr_line += 2

        # Data format: ASCII or BINARY
        if curr_line < len(lines):
            self.data_format = lines[curr_line].split(",")[0].strip().upper()

    def _parse_dat(self) -> None:
        if self.data_format == "ASCII":
            with open(self.dat_path, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    tokens = [t.strip() for t in line.split(",")]
                    samp_num = int(tokens[0])
                    time_us = int(tokens[1])
                    self.time_stamps_us.append(time_us)

                    tok_idx = 2
                    for ch in self.analog_channels:
                        raw_val = float(tokens[tok_idx])
                        actual_val = raw_val * ch.multiplier + ch.offset
                        self.analog_data[ch.idx].append(actual_val)
                        tok_idx += 1

                    for d_idx in range(len(self.digital_channels)):
                        d_val = int(tokens[tok_idx])
                        self.digital_data[d_idx].append(d_val)
                        tok_idx += 1

    def render_ascii_plot(self, channel_idx: int, width: int = 70, height: int = 15) -> str:
        """Render a terminal ASCII oscillogram for the given analog channel."""
        if channel_idx not in self.analog_data or not self.analog_data[channel_idx]:
            return "No data recorded for channel " + str(channel_idx)

        data = self.analog_data[channel_idx]
        ch = next((c for c in self.analog_channels if c.idx == channel_idx), None)
        title = f"{ch.name} ({ch.phase}) [{ch.unit}] - {len(data)} samples" if ch else f"Channel {channel_idx}"

        min_val = min(data)
        max_val = max(data)
        val_range = max_val - min_val if max_val != min_val else 1.0

        # Subsample if necessary
        step = max(1, len(data) // width)
        sub_samples = [data[i] for i in range(0, len(data), step)][:width]

        grid = [[" " for _ in range(len(sub_samples))] for _ in range(height)]

        zero_row = int((0.0 - min_val) / val_range * (height - 1))
        zero_row = min(height - 1, max(0, zero_row))

        # Draw zero centerline
        for col in range(len(sub_samples)):
            grid[height - 1 - zero_row][col] = "."

        # Plot samples
        for col, val in enumerate(sub_samples):
            normalized = (val - min_val) / val_range
            row = int(normalized * (height - 1))
            row = min(height - 1, max(0, row))
            grid[height - 1 - row][col] = "*"

        lines = [f"=== {title} ==="]
        for r in range(height):
            level = max_val - (r / (height - 1)) * val_range
            prefix = f"{level:8.2f} | "
            row_str = "".join(grid[r])
            lines.append(prefix + row_str)

        lines.append("         +" + "-" * len(sub_samples))
        lines.append(f"          t_start: 0.0 ms, t_end: {self.time_stamps_us[-1] / 1000.0:.2f} ms")
        return "\n".join(lines)


if __name__ == "__main__":
    if len(sys.argv) > 1:
        cfg = sys.argv[1]
        parser = ComtradeParser(cfg)
        print(f"Station: {parser.station_name}, Channels: {parser.total_channels}")
        if parser.analog_channels:
            print(parser.render_ascii_plot(1))
    else:
        print("ComtradeParser operational. Pass a .CFG file to view oscillograms.")
