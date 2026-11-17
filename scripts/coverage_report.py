#!/usr/bin/env python3
"""Merge native Verilator coverage and report project-owned counters only."""

import argparse
import collections
import json
import pathlib
import re
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-dir", type=pathlib.Path, required=True)
    parser.add_argument("--report-dir", type=pathlib.Path, required=True)
    parser.add_argument("--verilator-coverage", required=True)
    args = parser.parse_args()
    report = json.loads((args.report_dir / "regression.json").read_text())
    if report["status"] != "passed":
        raise SystemExit("Coverage acceptance requires a passing regression")
    files = [pathlib.Path(run["run_dir"]) / "coverage.dat" for run in report["positive_runs"]
             if run["name"] != "mutation-wrapper-clean"]
    destination = args.build_dir / "coverage"
    destination.mkdir(parents=True, exist_ok=True)
    merged = destination / "merged.dat"
    subprocess.run([args.verilator_coverage, "--write", str(merged), *map(str, files)], check=True)
    subprocess.run([args.verilator_coverage, "--write-info", str(destination / "coverage.info"),
                    str(merged)], check=True)
    functional = []
    rtl = collections.defaultdict(list)
    for line in merged.read_text().splitlines():
        match = re.fullmatch(r"C '(.*)' (\d+)", line)
        if not match:
            continue
        metadata = dict(part.split("\x02", 1) for part in match.group(1).split("\x01") if "\x02" in part)
        hits = int(match.group(2))
        filename = metadata.get("f", "")
        if metadata.get("t") == "covergroup" and filename.endswith("tb/uvm/router_model.svh"):
            if metadata.get("Bt") != "ignore":
                functional.append({"bin": metadata["h"].split("goals.")[-1], "hits": hits})
        if filename.endswith("rtl/packet_router.sv") and metadata.get("t") in ("line", "branch", "toggle"):
            rtl[metadata["t"]].append(hits)
    if not functional or any(bin_["hits"] == 0 for bin_ in functional):
        raise SystemExit("Native functional coverage contains missing bins")
    summary = {"native_functional_bins": functional,
               "functional_covered": sum(bin_["hits"] > 0 for bin_ in functional),
               "functional_total": len(functional), "rtl_counters": {}}
    for kind, hits in sorted(rtl.items()):
        summary["rtl_counters"][kind] = {"covered": sum(hit > 0 for hit in hits), "total": len(hits),
                                         "percent": round(100 * sum(hit > 0 for hit in hits) / len(hits), 2)}
    if not summary["rtl_counters"]:
        raise SystemExit("No production RTL counters found")
    (args.report_dir / "coverage.json").write_text(json.dumps(summary, indent=2) + "\n")
    lines = ["# Measured coverage", "", "Native covergroup bins are read from merged Verilator coverage data.",
             "Ignore bins represent idle sampling values and are excluded by their native metadata.",
             "Only `rtl/packet_router.sv` contributes to the RTL counter table.", "",
             f"Functional bins hit: **{summary['functional_covered']}/{summary['functional_total']}**.", "",
             "| Native functional bin | Hits |", "| --- | ---: |"]
    lines += [f"| {bin_['bin']} | {bin_['hits']} |" for bin_ in functional]
    lines += ["", "| RTL counter type | Covered | Total | Percent |", "| --- | ---: | ---: | ---: |"]
    lines += [f"| {kind} | {data['covered']} | {data['total']} | {data['percent']}% |"
              for kind, data in summary["rtl_counters"].items()]
    lines += ["", "These are instrumentation-counter results. They do not establish exhaustive functional",
              "correctness, formal proof, or X-propagation coverage. Raw merged data and LCOV output",
              "are generated in the build directory's `coverage/` folder.", ""]
    (args.report_dir / "coverage.md").write_text("\n".join(lines))
    print(f"Native functional coverage: {len(functional)}/{len(functional)} bins hit")


if __name__ == "__main__":
    main()
