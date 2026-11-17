#!/usr/bin/env python3
"""Run seeded positive/negative simulations and retain actual verification evidence."""

import argparse
import datetime
import json
import pathlib
import platform
import resource
import shutil
import subprocess
import time

from check_run import replay_trace, validate


ROOT = pathlib.Path(__file__).resolve().parents[1]
NEGATIVES = [
    (1, "drop", "single", "SB_LOSS"),
    (2, "duplicate", "single", "SB_DUPLICATE"),
    (3, "corrupt", "single", "SB_CORRUPTION_OR_ORDER"),
    (4, "route", "single", "SB_ROUTING"),
    (5, "priority", "contention", "SB_ARBITRATION"),
    (6, "unstable", "backpressure", "SVA_OUTPUT_STABLE"),
    (0, "protocol_negative", "protocol_negative", "SVA_INPUT_STABLE"),
]


def execute(binary, folder, scenario, seed, count, extra=()):
    folder.mkdir(parents=True, exist_ok=True)
    for name in ("result.json", "trace.csv", "coverage.dat"):
        (folder / name).unlink(missing_ok=True)
    command = [str(binary), f"+CASE={scenario}", f"+SEED={seed}", f"+N_PACKETS={count}",
               f"+verilator+seed+{seed}", "+UVM_NO_RELNOTES", *extra]
    started = time.monotonic()
    with (folder / "run.log").open("w") as log:
        process = subprocess.run(command, cwd=folder, stdout=log, stderr=subprocess.STDOUT, timeout=900)
    return process.returncode, round(time.monotonic() - started, 3), command


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-dir", type=pathlib.Path, required=True)
    parser.add_argument("--report-dir", type=pathlib.Path, default=ROOT / "reports")
    parser.add_argument("--width", type=int, default=32)
    args = parser.parse_args()
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    build = args.build_dir.resolve()
    report_dir = args.report_dir.resolve()
    logs_dir = report_dir / "logs"
    logs_dir.mkdir(parents=True, exist_ok=True)
    normal = build / f"uvm-{args.width}/Vuvm_top"
    mutants = build / f"mutation-{args.width}/Vuvm_top"
    report = {
        "status": "running", "timestamp_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "platform": platform.system(), "width": args.width,
        "toolchain": json.loads((ROOT / "toolchain.lock.json").read_text()),
        "positive_runs": [], "negative_runs": [], "reproducibility": {},
    }

    def positive(name, scenario, seed=1, count=32, binary=normal, extra=()):
        folder = build / "regression" / name
        code, elapsed, command = execute(binary, folder, scenario, seed, count, extra)
        shutil.copyfile(folder / "run.log", logs_dir / f"{name}.log")
        if code != 0:
            raise RuntimeError(f"{name} exited {code}. See {folder / 'run.log'}")
        result = validate(folder)
        result.update(name=name, scenario=scenario, elapsed_seconds=elapsed,
                      command=command, run_dir=str(folder))
        report["positive_runs"].append(result)
        print(f"PASS {name}: accepted={result['accepted']} cycles={result['cycles']}", flush=True)
        return result

    try:
        for scenario in ("single", "simultaneous", "contention", "backpressure", "reset"):
            positive(scenario, scenario)
        for seed in (1, 17, 123):
            positive(f"random-{seed}", "random", seed=seed, count=512)
        positive("stress", "stress", count=5000)
        all_run = positive("all", "all")
        if all_run["native_functional_coverage"] != 100.0 or all_run["completed_scenarios"] != 127:
            raise RuntimeError("Native functional coverage/scenario completion gate failed")
        if (not all(all_run["route_hits"]) or not all(all_run["contention_grants"])
                or not all(all_run["output_stall_cycles"]) or not all_run["reset_busy_events"]):
            raise RuntimeError("Observed scenario evidence is incomplete")
        original = next(run for run in report["positive_runs"] if run["name"] == "random-17")
        replay = positive("random-17-replay", "random", seed=17, count=512)
        if original["trace_sha256"] != replay["trace_sha256"]:
            raise RuntimeError("Same-seed random regression produced a different transfer trace")
        report["reproducibility"] = {"seed": 17, "trace_sha256": replay["trace_sha256"], "identical": True}
        positive("passive-source1", "single", extra=("+PASSIVE_SOURCE=1",))
        wrapper = positive("mutation-wrapper-clean", "single", binary=mutants, extra=("+MUTATION=0",))
        clean = next(run for run in report["positive_runs"] if run["name"] == "single")
        if wrapper["trace_sha256"] != clean["trace_sha256"]:
            raise RuntimeError("Clean mutation wrapper changed production behavior")

        for mutation, name, scenario, marker in NEGATIVES:
            folder = build / "regression" / f"negative-{name}"
            binary = normal if name == "protocol_negative" else mutants
            extra = () if name == "protocol_negative" else (f"+MUTATION={mutation}",)
            code, elapsed, command = execute(binary, folder, scenario, 1, 16, extra)
            text = (folder / "run.log").read_text()
            shutil.copyfile(folder / "run.log", logs_dir / f"negative-{name}.log")
            if marker not in text or "[ROUTER_PASS]" in text:
                raise RuntimeError(f"Negative {name} was not detected by {marker}")
            negative = {"name": name, "detected": True, "expected_marker": marker,
                        "returncode": code, "elapsed_seconds": elapsed, "command": command}
            if name in ("drop", "duplicate", "corrupt", "route"):
                try:
                    replay_trace(folder / "trace.csv")
                except ValueError as error:
                    negative["python_oracle"] = str(error)
                else:
                    raise RuntimeError(f"Independent Python oracle missed RTL mutation {name}")
            report["negative_runs"].append(negative)
            print(f"DETECTED {name}: {marker}", flush=True)
        report["status"] = "passed"
    except Exception as error:
        report["status"] = "failed"
        report["failure"] = str(error)
        raise
    finally:
        (report_dir / "regression.json").write_text(json.dumps(report, indent=2) + "\n")
    print("Regression acceptance gates PASS", flush=True)


if __name__ == "__main__":
    main()
