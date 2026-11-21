#!/usr/bin/env python3
"""Reproduce four seed-19 controls, then steer during one registered swing per case."""
import argparse
import csv
import gzip
import hashlib
import json
import os
import subprocess
import tempfile
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from run_pressure_audit import ENGINE, ROOT


SCENE = "res://tests/integration/scarecrow_window_probe.tscn"
ANCHORS = ROOT / "docs/validation/r03a/anchors"
OLD = ROOT / "docs/validation/scene-lifetime"
CASES = [(route, policy) for route in (0, 1) for policy in ("cautious", "escape")]
DIRECTIONS = ("radial", "left", "right")
DELAYS = (0, 15, 24, 30)
GAME_PATHS = ("core", "game", "data", "ui", "i18n", "project.godot", "tests/integration",
              "tools/run_pressure_audit.py", "tools/probe_scarecrow_windows.py")


def name(case):
    route, policy = case
    return f"archer_route{route}_s19_{policy}"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def source_digest():
    h = hashlib.sha256()
    for src in GAME_PATHS:
        p = ROOT / src
        for f in sorted(p.rglob("*") if p.is_dir() else [p]):
            if f.is_file() and not f.name.endswith(".uid"):
                h.update(f.relative_to(ROOT).as_posix().encode() + b"\0" + hashlib.sha256(f.read_bytes()).digest())
    return h.hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def old_control(case, index):
    case_name = name(case)
    old = index["cases"][case_name]
    path = OLD / old["raw_trace_path"]
    data = gzip.decompress(path.read_bytes()) if path.suffix == ".gz" else path.read_bytes()
    if digest(data) != old["trace_sha256"]:
        raise ValueError(f"stale archived trace: {case_name}")
    # Read the original hits directly, including zero-hit visits.
    rows = [x for x in json.loads(data)["damage"] if x["level"] == "1-4"]
    amounts = [x["amount"] for x in rows if any(y["source"].endswith("/scarecrow.gd") and y["function"] == "_swing" for y in x["stack"])]
    return old, (len(rows), sum(x["amount"] for x in rows), len(amounts), sum(amounts))


def run_engine(directory, case, extra):
    directory.mkdir()
    case_name = name(case)
    original = json.loads((ANCHORS / (case_name + ".command.json")).read_text())
    cmd = list(original)
    cmd[cmd.index("--path") + 1] = str(ROOT)
    scene = next(i for i, s in enumerate(cmd) if s.startswith("res://"))
    cmd[scene] = SCENE
    report = directory / "report.json"
    cmd = [f"--report={report}" if s.startswith("--report=") else s for s in cmd] + extra
    with tempfile.TemporaryDirectory(prefix="doggy-swing-") as save, (directory / "engine.log").open("x") as log:
        rc = subprocess.run(cmd, cwd=ROOT, env=dict(os.environ, XDG_DATA_HOME=save),
                            stderr=subprocess.STDOUT, stdout=log, timeout=600).returncode
    log = (directory / "engine.log").read_text()
    write_json(directory / "command.json", cmd)
    if "SCRIPT ERROR" in log or "Program crashed" in log or rc not in (0, 1):
        raise RuntimeError(f"{directory}: Godot exit {rc}; see retained log")
    return rc, report, report.with_suffix(".json.windows.jsonl")


def trace_rows(path):
    return [json.loads(line) for line in path.read_bytes().splitlines()]


def choose_attack(rows):
    hits = [x["id"] for x in rows if x["op"] == "damage" and x["id"]]
    impacts = {x["id"] for x in rows if x["op"] == "impact"}
    return hits[0] if hits else next(x["id"] for x in rows if x["op"] == "begin" and x["player_target"] and x["id"] in impacts)


def collect_control(case, out, evidence, index):
    case_name = name(case)
    old, old_hits = old_control(case, index)
    rc, report, trace = run_engine(out / case_name, case, [])
    baseline = (ANCHORS / (case_name + ".json")).read_bytes()
    if report.read_bytes() != baseline or digest(baseline) != old["report_sha256"]:
        raise ValueError(f"changed complete chapter report: {case_name}")
    rows = trace_rows(trace)
    end = rows[-1]
    observed = [x for x in rows if x["op"] == "damage"]
    ordinary_hits = [x["amount"] for x in observed if x["id"]]
    if (len(observed), sum(x["amount"] for x in observed), len(ordinary_hits), sum(ordinary_hits)) != old_hits:
        raise ValueError(f"damage source mismatch vs. half-second trace: {case_name}")
    started = {x["id"]: x for x in rows if x["op"] == "begin"}
    closed = {x["id"]: x for x in rows if x["op"] in ("impact", "cancel")}
    if len(started) != len([x for x in rows if x["op"] == "begin"]) or len(closed) != len([x for x in rows if x["op"] in ("impact", "cancel")]) or started.keys() != closed.keys() or end["op"] != "end":
        raise ValueError(f"unpaired or duplicate swing: {case_name}")
    target = choose_attack(rows)
    impacts = [x for x in closed.values() if x["op"] == "impact"]
    lengths = Counter(x["t"] - started[x["id"]]["t"] for x in impacts)
    if any(started[x["id"]]["tracking"] or x["tracking"] or x["dir"] != started[x["id"]]["dir"] for x in impacts):
        raise ValueError(f"expected committed aim: {case_name}")
    frames = {x["t"]: x for x in rows if x["op"] == "frame"}
    if any(x["production"][0] + sum(x["excluded"]) != x["legacy"] for x in frames.values()):
        raise ValueError(f"unexplained observer discrepancy: {case_name}")
    if any(not set(range(s["t"], closed[k]["t"] + 1)) <= frames.keys() for k, s in started.items()):
        raise ValueError(f"missing physics frame in a swing: {case_name}")
    raw = trace.read_bytes()
    (evidence / (case_name + ".jsonl.gz")).write_bytes(gzip.compress(raw, compresslevel=9, mtime=0))
    hit_rows = [x for x in observed if x["id"]]
    result = dict(case=case_name, report_sha256=digest(baseline), old_trace_sha256=old["trace_sha256"],
                  raw_sha256=digest(raw), exit_code=rc, selected=target, old_damage=old_hits, starts=len(started),
                  impacts=len(impacts), cancelled=len(started)-len(impacts), impact_ticks=dict(sorted(lengths.items())),
                  hit_started_outside=sum(not started[x["id"]]["covers"] for x in hit_rows),
                  hit_aimed_at_companion=sum(not started[x["id"]]["player_target"] for x in hit_rows),
                  selected_start=started[target], selected_impact=closed[target], **end)
    print(f"{case_name}: {len(impacts)} impacts, {len(ordinary_hits)} ordinary hits. Selected {target}.", flush=True)
    return result


def examine_fork(case, target, delay, direction, out, evidence):
    case_name = name(case)
    ident = f"{case_name}_{direction}_{delay:02d}"
    rc, _, path = run_engine(out / ident, case, [f"--fork={target}", f"--delay={delay}", f"--direction={direction}"])
    if rc != 0:
        raise ValueError(f"target not reached: {ident}")
    lines = path.read_bytes().splitlines(keepends=True)
    ip = next(i for i, line in enumerate(lines) if json.loads(line)["op"] == "input")
    # Exact original bytes from the first 1-4 event through the sampled input tick.
    with (out / case_name / "report.json.windows.jsonl").open("rb") as control:
        if any(control.readline() != line for line in lines[:ip]):
            raise ValueError(f"pre-input divergence: {ident}")
    rows = [json.loads(x) for x in lines]
    decision = rows[ip]
    launch = rows[ip-1]
    assert launch["op"] == "frame" and launch["t"] == decision["t"] and target in launch["ids"]
    baseline_began = next(x for x in rows if x["op"] == "begin" and x["id"] == target)
    terminal = next(x for x in rows if x["op"] in ("cancel", "impact") and x["id"] == target)
    path_rows = [x for x in rows[ip+1:] if x["op"] == "frame"]
    if [x["t"] for x in path_rows] != list(range(decision["t"] + 1, terminal["t"] + 1)):
        raise ValueError(f"discontinuous intervention path: {ident}")
    phases = [launch["p"]] + [x["p"] for x in path_rows] + ([terminal["p"]] if terminal["op"] == "impact" else [])
    rolling = any(x["roll"] == "rolling" or x["rolling_left"] > 0 for x in phases)
    immune = any(x["immune"] for x in phases)
    damage = sum(x["amount"] for x in rows[ip+1:] if x["op"] == "damage")
    committed = terminal["op"] == "impact"
    same_geometry = committed and terminal["dir"] == baseline_began["dir"] and all(abs(x-y) < 0.0001 for x, y in zip(terminal["origin"], baseline_began["origin"]))
    if committed and not same_geometry:
        raise ValueError(f"moving terminal geometry: {ident}")
    outside = committed and not terminal["covers"]
    result = "unproven"
    if outside and not damage and not immune and not rolling:
        result = "walk"
    elif outside and not damage and rolling:
        result = "roll_assisted"
    suffix = b"".join(lines[ip-1:])
    (evidence / "forks" / (ident + ".jsonl.gz")).write_bytes(gzip.compress(suffix, compresslevel=9, mtime=0))
    row = dict(case=case_name, id=target, direction=direction, delay=delay, window_ticks=terminal["t"]-baseline_began["t"],
               input_tick=decision["t"], terminal_tick=terminal["t"], outcome=terminal["op"], covers=terminal.get("covers"),
               launch_roll=phases[0]["roll"], rolling=rolling, immune=immune, damage=damage, classification=result,
               matched_prefix_rows=ip, prefix_sha256=digest(b"".join(lines[:ip])), suffix_sha256=digest(suffix))
    print(f"{ident}: {result}, {row['outcome']}, damage {damage}", flush=True)
    return row


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=Path, help="fresh working directory; raw logs and failures stay here")
    parser.add_argument("--jobs", type=int, choices=range(1, 9), default=4)
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir()
    evidence = out / "evidence"
    evidence.mkdir()
    (evidence / "forks").mkdir()
    if subprocess.check_output(["godot", "--version"], text=True).strip() != ENGINE:
        parser.error("Godot version does not match archived transitions")
    before = source_digest()
    index = json.loads((OLD / "trial-traces.json").read_text())
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        controls = list(pool.map(lambda c: collect_control(c, out, evidence, index), CASES))
        write_json(evidence / "controls.json", controls)
        targets = {case: r["selected"] for case, r in zip(CASES, controls)}
        def run(job):
            case, delay, direction = job
            return examine_fork(case, targets[case], delay, direction, out, evidence)
        jobs = [(case, delay, dr) for delay in DELAYS for case in CASES for dr in DIRECTIONS]
        forks = list(pool.map(run, jobs))
        # Closest-to-impact walking success per case; test each unsampled later tick
        # in the same direction, retaining every failure. Other directions stay sampled.
        refine = []
        for case in CASES:
            walks = [r for r in forks if r["case"] == name(case) and r["classification"] == "walk"]
            if walks:
                best = max(walks, key=lambda r: r["delay"])
                refine.extend((case, d, best["direction"]) for d in range(best["delay"]+1, best["window_ticks"]) if d not in DELAYS)
        forks.extend(pool.map(run, refine))
    with (evidence / "forks.csv").open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=forks[0].keys())
        writer.writeheader()
        writer.writerows(forks)
    after = source_digest()
    if before != after:
        raise ValueError("game or probe source changed during run")
    write_json(evidence / "fingerprint.json", dict(engine=ENGINE, source_sha256=before, source_paths=GAME_PATHS,
               source_definition="sorted relative path + NUL + binary SHA256 for each file; see source_digest()",
               tested_against="b05224258e0bdc70cfde7d0cb874a6b36d7f4617", fixed_fps=60, delays=DELAYS, directions=DIRECTIONS))


if __name__ == "__main__":
    main()
