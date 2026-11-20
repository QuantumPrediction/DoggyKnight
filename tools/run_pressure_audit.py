#!/usr/bin/env python3
"""Registered two-policy route coverage; every attempt/log is retained, never resumed over."""
import argparse
import concurrent.futures
import hashlib
import itertools
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

ENGINE = "4.7.2.stable.official.ed1daf0bf"
ROOT = Path(__file__).resolve().parents[1]


def fingerprints(root):
    paths = [root / "project.godot"]
    for folder in ("core", "game", "data", "ui", "tests/integration", "tools", "i18n"):
        paths += [p for p in (root / folder).rglob("*") if p.suffix in (".gd", ".tscn", ".tres", ".py", ".csv")]
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(paths)}


def run_case(root, out, case, scene):
    hero, route, seed, policy = case
    name = f"{hero}_route{route}_s{seed}_{policy}"
    report = out / f"{name}.json"
    command = ["godot", "--headless", "--path", str(root), "--fixed-fps", "60", "--max-fps", "0",
               "--disable-render-loop", scene, "--", "--speed=1", "--chapter=1", f"--class={hero}",
               f"--route={route}", "--build=route", f"--seed={seed}", "--gear=common1", "--element=earth",
               f"--policy={policy}", "--guard=reactive", "--max-downs=3", "--max-sim-seconds=1200",
               f"--report={report}"]
    (out / f"{name}.command.json").write_text(json.dumps(command, indent=2) + "\n")
    started = time.monotonic()
    with tempfile.TemporaryDirectory(prefix="doggy-pressure-") as save, (out / f"{name}.log").open("x") as log:
        try:
            code = subprocess.run(command, cwd=root, env=dict(os.environ, XDG_DATA_HOME=save),
                                  stdout=log, stderr=subprocess.STDOUT, timeout=600).returncode
        except subprocess.TimeoutExpired:
            code = 124
    row = dict(case=name, hero=hero, route_choice=route, seed=seed, policy=policy,
               exit_code=code, elapsed_seconds=round(time.monotonic() - started, 3))
    if report.exists():
        try:
            r = json.loads(report.read_text())
            row.update(route=r["route"], finished=r["finished"], downs=r["downs"], outcome=r["outcome"],
                       damage=sum(x["damage_taken"] for x in r["attempts"]),
                       cleared=sum(x["victory"] for x in r["attempts"]),
                       simulated_seconds=r["simulation_seconds"])
        except (ValueError, KeyError, TypeError) as error:
            row["report_error"] = str(error)
    log = (out / f"{name}.log").read_text()
    row["script_error"] = any(text in log for text in ("SCRIPT ERROR", "Parse Error", "Failed to load script"))
    row["engine_error"] = any(line.startswith("ERROR:") for line in log.splitlines())
    row["native_crash"] = "Program crashed" in log or "caller thread" in log
    print(json.dumps(row), flush=True)
    return row


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--seeds", nargs="+", type=int, default=[7, 19, 31, 43])
    parser.add_argument("--policies", nargs="+", choices=["cautious", "escape"], default=["cautious", "escape"])
    parser.add_argument("--classes", nargs="+", choices=["knight", "mage", "archer"], default=["knight", "mage", "archer"])
    parser.add_argument("--routes", nargs="+", choices=[0, 1], type=int, default=[0, 1])
    parser.add_argument("--jobs", type=int, choices=range(1, 5), default=3)
    parser.add_argument("--trace", action="store_true")
    args = parser.parse_args()
    root, out = args.root.resolve(), args.out.resolve()
    if out.exists() and any(out.iterdir()):
        parser.error("Use a fresh output directory; failures and partial runs must not be overwritten.")
    cases = list(itertools.product(args.classes, args.routes, args.seeds, args.policies))
    if len(cases) != len(set(cases)):
        parser.error("Duplicate cases are not allowed.")
    engine = subprocess.check_output(["godot", "--version"], text=True).strip()
    if engine != ENGINE:
        parser.error(f"Expected {ENGINE}, found {engine}")
    out.mkdir(parents=True, exist_ok=True)
    before = fingerprints(root)
    scene = "res://tests/integration/pressure_trace.tscn" if args.trace else "res://tests/integration/playthrough_bot.tscn"
    manifest = dict(engine=engine, root=str(root), source_sha256=before, cases=cases, jobs=args.jobs, scene=scene,
                    rules="Normal damage, fixed60/speed1, common1 earth bought for240/250, no training; reactive guard, route-aware choices, max3 downs/max1200 simulation seconds. Separate visible-position policies; not human balance/fun evidence.")
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        rows = list(pool.map(lambda case: run_case(root, out, case, scene), cases))
    after = fingerprints(root)
    changed = sorted(key for key in set(before) | set(after) if before.get(key) != after.get(key))
    (out / "summary.json").write_text(json.dumps(rows, indent=2) + "\n")
    (out / "integrity.json").write_text(json.dumps({"source_changed_during_run": changed}, indent=2) + "\n")
    return int(bool(changed) or any(r["exit_code"] not in (0, 1) or r["script_error"] or r["native_crash"] or "finished" not in r for r in rows))


if __name__ == "__main__":
    raise SystemExit(main())
