#!/usr/bin/env python3
"""Check UVM summaries and independently replay the observed ready/valid transfers."""

import collections
import csv
import hashlib
import json
import pathlib
import re
import sys


def replay_trace(path):
    expected = [collections.deque(), collections.deque()]
    accepted = delivered = aborted = 0
    previous_cycle = -1
    for row in csv.DictReader(path.open()):
        cycle = int(row["cycle"])
        if cycle < previous_cycle:
            raise ValueError("Trace cycles moved backwards")
        previous_cycle = cycle
        kind = row["kind"]
        port, destination = int(row["port"]), int(row["dest"])
        data = int(row["data"], 16)
        if kind == "reset":
            aborted += sum(map(len, expected))
            for queue in expected:
                queue.clear()
        elif kind == "in":
            if port not in (0, 1) or destination not in (0, 1):
                raise ValueError("Invalid ingress route in trace")
            expected[destination].append(data)
            accepted += 1
        elif kind == "out":
            if port != destination or port not in (0, 1):
                raise ValueError("Invalid egress port in trace")
            if not expected[port]:
                raise ValueError(f"Unexpected/duplicated output at cycle {cycle}")
            wanted = expected[port].popleft()
            if data != wanted:
                raise ValueError(f"Data/routing/order mismatch at cycle {cycle}: {data:x} != {wanted:x}")
            delivered += 1
        else:
            raise ValueError(f"Unknown trace event {kind}")
    if any(expected):
        raise ValueError("Accepted input packets missing at end of trace")
    if not accepted or accepted != delivered + aborted:
        raise ValueError("Trace conservation check failed")
    return {"accepted": accepted, "delivered": delivered, "reset_aborted": aborted}


def validate(run_dir):
    run_dir = pathlib.Path(run_dir)
    text = (run_dir / "run.log").read_text()
    for severity in ("ERROR", "FATAL"):
        match = re.search(rf"UVM_{severity}\s*:\s*(\d+)", text)
        if not match or int(match.group(1)):
            raise ValueError(f"Missing or nonzero UVM_{severity} summary")
    if "[ROUTER_PASS]" not in text:
        raise ValueError("Router completion marker missing")
    result = json.loads((run_dir / "result.json").read_text())
    if result["uvm_errors"] or result["uvm_fatals"]:
        raise ValueError("Nonzero errors in JSON report")
    observed = replay_trace(run_dir / "trace.csv")
    for key, value in observed.items():
        if result[key] != value:
            raise ValueError(f"SV/Python result mismatch for {key}")
    if not (run_dir / "coverage.dat").is_file():
        raise ValueError("Native Verilator coverage output missing")
    result["trace_sha256"] = hashlib.sha256((run_dir / "trace.csv").read_bytes()).hexdigest()
    result["python_oracle"] = "PASS"
    return result


if __name__ == "__main__":
    print(json.dumps(validate(sys.argv[1]), indent=2))
