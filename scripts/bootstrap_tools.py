#!/usr/bin/env python3
"""Fetch pinned official sources and build a project-scoped Linux toolchain."""

import argparse
import hashlib
import json
import pathlib
import shutil
import subprocess
import tarfile
import urllib.request


ROOT = pathlib.Path(__file__).resolve().parents[1]


def run(*args, cwd=None):
    print("+", " ".join(map(str, args)), flush=True)
    subprocess.run(list(map(str, args)), cwd=cwd, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache-dir", type=pathlib.Path, default=ROOT / ".tools")
    parser.add_argument("--jobs", type=int, default=2)
    args = parser.parse_args()
    if args.jobs < 1:
        parser.error("--jobs must be positive")
    cache = args.cache_dir.resolve()
    if any(char.isspace() for char in str(cache)):
        parser.error("GNU Make/Verilator tool directories cannot contain whitespace")
    for tool in ("git", "autoconf", "flex", "bison", "g++", "make", "z3"):
        if not shutil.which(tool):
            raise SystemExit(f"Missing {tool}. Install documented Ubuntu prerequisites first.")
    lock = json.loads((ROOT / "toolchain.lock.json").read_text())
    cache.mkdir(parents=True, exist_ok=True)
    uvm = lock["uvm"]
    archive = cache / f"uvm-{uvm['version']}.tar.gz"
    if not archive.exists():
        print(f"Downloading official UVM archive from {uvm['url']}", flush=True)
        with urllib.request.urlopen(uvm["url"], timeout=60) as response:
            with archive.open("xb") as destination:
                shutil.copyfileobj(response, destination)
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    if digest != uvm["sha256"]:
        raise SystemExit(f"UVM archive checksum mismatch. Inspect {archive} before retrying.")
    uvm_root = cache / f"1800.2-{uvm['version']}"
    if not uvm_root.exists():
        with tarfile.open(archive) as package:
            package.extractall(cache, filter="data")
    if "1800.2 2020.3.2" not in (uvm_root / "README.md").read_text():
        raise SystemExit("Extracted UVM kit version mismatch")
    if not (uvm_root / "LICENSE.txt").is_file():
        raise SystemExit("UVM license is missing")

    verilator = lock["verilator"]
    source = cache / f"verilator-{verilator['version']}"
    if not source.exists():
        run("git", "clone", "--depth", "1", "--branch", verilator["tag"],
            verilator["repository"], source)
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=source, text=True).strip()
    if commit != verilator["commit"]:
        raise SystemExit(f"Unexpected Verilator commit {commit}, expected {verilator['commit']}")
    run("git", "diff", "--exit-code", cwd=source)
    if not (source / "LICENSE").is_file():
        raise SystemExit("Verilator license is missing")
    binary = source / "bin/verilator_bin"
    if not binary.exists():
        run("autoconf", cwd=source)
        run("./configure", cwd=source)
        run("make", "-C", "src", f"-j{args.jobs}", "opt", cwd=source)
    run("git", "diff", "--exit-code", cwd=source)
    env_dir = ROOT / ".tools"
    env_dir.mkdir(exist_ok=True)
    (env_dir / "env.mk").write_text(
        f"VERILATOR := {source}/bin/verilator\n"
        f"export VERILATOR_ROOT := {source}\n"
        f"UVM_HOME := {uvm_root}\n"
    )
    run(source / "bin/verilator", "--version")
    print(f"Pinned toolchain configured in {env_dir / 'env.mk'}")


if __name__ == "__main__":
    main()
