#!/usr/bin/env python3
"""Treat a zero process exit alone as insufficient evidence of UVM success."""

import pathlib
import re
import sys


text = pathlib.Path(sys.argv[1]).read_text()
if "[SMOKE_PASS]" not in text:
    raise SystemExit("Missing smoke completion marker")
for severity in ("ERROR", "FATAL"):
    match = re.search(rf"UVM_{severity}\s*:\s*(\d+)", text)
    if not match or int(match.group(1)):
        raise SystemExit(f"Invalid UVM_{severity} summary")
print("Verified UVM smoke PASS")
