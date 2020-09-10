#!/usr/bin/env python3
"""
Selsyn Unified Command-Line Interface and Grid Engineering Suite.

Provides unified entrypoints for all Selsyn subsystems:
  - selsyn sim       : Generate calibrated synthetic grid waveforms and HIL fault tests
  - selsyn pdc       : Live IEEE C37.118 Phasor Data Concentrator terminal client
  - selsyn scada     : Modbus-TCP register polling and telemetry inspection
  - selsyn comtrade  : Parse and visualize IEEE C37.111 oscillograms in ASCII
  - selsyn test      : Execute complete Toit and Python verification suites
  - selsyn bench     : Benchmark DSP algorithms and frame serialization throughput
"""

import argparse
import os
import subprocess
import sys
import time
from typing import List


def run_tests() -> int:
    """Execute complete Toit and typography verification pass."""
    print("=== Running Selsyn Verification Suite ===")
    root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    
    # Run typography lint
    lint_script = os.path.join(root_dir, "tools", "lint_no_em_dash.py")
    ret = subprocess.call([sys.executable, lint_script], cwd=root_dir)
    if ret != 0:
        print("[FAIL] Typography lint failed.")
        return ret

    # Run Toit test runner
    toit_runner = os.path.join(root_dir, "tools", "run_toit_tests.py")
    ret = subprocess.call([sys.executable, toit_runner], cwd=root_dir)
    if ret != 0:
        print("[FAIL] Toit test suite failed.")
        return ret

    print("=== All Verification Checks Passed Cleanly ===")
    return 0


def cmd_sim(args: argparse.Namespace) -> None:
    from sim.grid_simulator import GridFaultScenario, GridSimulator
    sim = GridSimulator(
        nominal_voltage=args.voltage,
        nominal_current=args.current,
        nominal_freq=args.freq,
        sampling_rate=args.rate,
    )
    print(f"Generating synthetic grid stream: {args.duration}s @ {args.rate} Hz...")
    sim.stream_csv(args.duration, args.output, fault=getattr(GridFaultScenario, args.fault.upper(), 0))
    print(f"Saved synthetic dataset to: {args.output}")


def cmd_comtrade(args: argparse.Namespace) -> None:
    from tools.comtrade_viewer import ComtradeParser
    parser = ComtradeParser(args.cfg_file)
    print(f"COMTRADE Station: {parser.station_name} | Channels: {parser.total_channels}")
    print(parser.render_ascii_plot(args.channel, width=args.width, height=args.height))


def cmd_scada(args: argparse.Namespace) -> None:
    from tools.modbus_poll import ModbusMaster, format_scada_poll
    master = ModbusMaster(host=args.host, port=args.port)
    try:
        master.connect()
        print(format_scada_poll(master))
    except Exception as e:
        print(f"Modbus connection error to {args.host}:{args.port}: {e}")
    finally:
        master.close()


def main() -> None:
    parser = argparse.ArgumentParser(
        prog="selsyn",
        description="Selsyn Real-Time Synchrophasor PMU & Grid Protection Suite",
    )
    subparsers = parser.add_subparsers(dest="command", help="Subcommand to execute")

    # test
    sub_test = subparsers.add_parser("test", help="Execute complete verification suite")

    # sim
    sub_sim = subparsers.add_parser("sim", help="Generate synthetic grid waveform dataset")
    sub_sim.add_argument("--duration", type=float, default=2.0, help="Duration in seconds")
    sub_sim.add_argument("--rate", type=float, default=3840.0, help="Sampling frequency in Hz")
    sub_sim.add_argument("--voltage", type=float, default=120.0, help="Nominal voltage RMS")
    sub_sim.add_argument("--current", type=float, default=5.0, help="Nominal current RMS")
    sub_sim.add_argument("--freq", type=float, default=60.0, help="Nominal grid frequency")
    sub_sim.add_argument("--fault", type=str, default="NONE", help="Fault scenario (NONE, SLG_A, LL_BC, DLG_AB, THREE_PHASE, ISLANDING)")
    sub_sim.add_argument("--output", type=str, default="grid_sim.csv", help="Output CSV path")

    # comtrade
    sub_comtrade = subparsers.add_parser("comtrade", help="View IEEE C37.111 COMTRADE oscillograms")
    sub_comtrade.add_argument("cfg_file", type=str, help="Path to .CFG file")
    sub_comtrade.add_argument("--channel", type=int, default=1, help="Channel index to plot")
    sub_comtrade.add_argument("--width", type=int, default=70, help="Plot width in characters")
    sub_comtrade.add_argument("--height", type=int, default=15, help="Plot height in characters")

    # scada
    sub_scada = subparsers.add_parser("scada", help="Poll Modbus-TCP SCADA registers")
    sub_scada.add_argument("--host", type=str, default="127.0.0.1", help="Target host")
    sub_scada.add_argument("--port", type=int, default=5502, help="Modbus TCP port")

    args = parser.parse_args()

    if args.command == "test":
        sys.exit(run_tests())
    elif args.command == "sim":
        cmd_sim(args)
    elif args.command == "comtrade":
        cmd_comtrade(args)
    elif args.command == "scada":
        cmd_scada(args)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
