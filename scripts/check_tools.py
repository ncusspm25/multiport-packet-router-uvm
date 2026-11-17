#!/usr/bin/env python3
"""Reject mismatched tools before compiling the testbench."""

import pathlib
import re
import shutil
import subprocess
import sys


def main():
    verilator, uvm_home = sys.argv[1:]
    version = subprocess.check_output([verilator, "--version"], text=True).strip()
    match = re.search(r"Verilator (\d+)\.(\d+)", version)
    if not match or tuple(map(int, match.groups())) < (5, 52):
        raise SystemExit(f"Need Verilator >= 5.052, found {version}")
    root = pathlib.Path(uvm_home)
    readme = (root / "README.md").read_text()
    if "1800.2 2020.3.2" not in readme:
        raise SystemExit("UVM_HOME must point to Accellera UVM 2020.3.2")
    for tool in ("g++", "make", "z3"):
        if not shutil.which(tool):
            raise SystemExit(f"Missing required tool: {tool}")
    print(version)
    print(f"Accellera UVM 2020.3.2: {root}")


if __name__ == "__main__":
    main()
