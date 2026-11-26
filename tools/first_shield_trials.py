#!/usr/bin/env python3
"""Measure the first normal-route shield opportunity from clean Godot profiles."""

import argparse
import concurrent.futures
import itertools
import json
import os
from pathlib import Path
import subprocess
import tempfile


def trial(args, case):
    hero, seed, borrow, response = case
    name = f"{hero}-{seed}-{borrow}-{response}"
    output = args.out / (name + ".json")
    with tempfile.TemporaryDirectory(prefix="first-shield-") as temp:
        command = [
            args.godot, "--headless", "--fixed-fps", "60", "--max-fps", "0",
            "--disable-render-loop", "--path", str(args.root),
            "res://tests/integration/first_shield_probe.tscn", "--",
            "--speed=1", "--policy=escape", "--guard=off", "--build=route",
            "--seed=" + str(seed), "--class=" + hero, "--borrow=" + borrow,
            "--response=" + response, "--route=" + str(args.route),
            "--report=" + str(output),
        ]
        if args.reinforced:
            command.append("--reinforced")
        result = subprocess.run(
            command, capture_output=True, text=True, timeout=120,
            env={**os.environ, "XDG_DATA_HOME": temp, "XDG_CONFIG_HOME": temp},
        )
    log = result.stdout + result.stderr
    (args.out / (name + ".log")).write_text(log)
    if result.returncode or "SCRIPT ERROR" in log or not output.is_file():
        raise RuntimeError(f"{name} failed; inspect {args.out / (name + '.log')}")
    report = json.loads(output.read_text())
    if report["actual_class"] != hero or report["mode"] != ("reinforced" if args.reinforced else "normal"):
        raise RuntimeError(f"{name} did not enter the requested class and difficulty")
    if "route_confirmed" not in report["first"] or (borrow == "on" and "borrow_checked" not in report["first"]):
        raise RuntimeError(f"{name} did not click the requested route controls")
    return report


def record_trial(args, case):
    try:
        return trial(args, case)
    except (RuntimeError, subprocess.TimeoutExpired) as ex:
        hero, seed, borrow, response = case
        if isinstance(ex, subprocess.TimeoutExpired):
            name = f"{hero}-{seed}-{borrow}-{response}.log"
            (args.out / name).write_bytes((ex.stdout or b"") + (ex.stderr or b""))
        return {"hero": hero, "seed": seed, "borrow": borrow == "on", "response": response,
                "outcome": "execution_failed", "error": str(ex)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True, help="Imported game checkout including the probe scene")
    parser.add_argument("--out", type=Path, required=True, help="New directory for full JSON and process logs")
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--workers", type=int, default=2)
    parser.add_argument("--borrow", nargs="+", choices=("off", "on"), default=["off"])
    parser.add_argument("--seed", nargs="+", type=int, default=[7, 19])
    parser.add_argument("--hero", nargs="+", choices=("knight", "mage", "archer"), default=["knight", "mage", "archer"])
    parser.add_argument("--response", nargs="+", choices=("skip", "call", "follow"), default=["skip", "call"])
    parser.add_argument("--reinforced", action="store_true", help="Click the reinforced departure in class selection")
    parser.add_argument("--route", type=int, choices=(0, 1), default=0)
    args = parser.parse_args()
    args.root = args.root.resolve()
    args.out = args.out.resolve()
    args.out.mkdir(parents=True, exist_ok=False)
    cases = itertools.product(args.hero, args.seed, args.borrow, args.response)
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        reports = list(pool.map(lambda case: record_trial(args, case), cases))
    (args.out / "observations.jsonl").write_text(
        "".join(json.dumps(r, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n" for r in reports)
    )
    if any(row["outcome"] == "execution_failed" for row in reports):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
