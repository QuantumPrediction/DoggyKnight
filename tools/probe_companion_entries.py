#!/usr/bin/env python3
"""Check a frozen pair of companion-directed scarecrow lane entries."""
import argparse
import csv
import gzip
import json
import subprocess
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import probe_scarecrow_windows as probe


ARCHIVE = probe.ROOT / "docs/validation/scarecrow-window"
MERGED = "7d63fffd4ca455837899679ca4b125b030f1f4b3"
CASES = ((0, "cautious"), (1, "cautious"))
EXPECTED = ("20980.1", "17197.2")
DIRECTIONS = ("stop", "left", "right")
SHAPES = ("circle", "sector", "line")


def read_csv(path):
    with path.open(newline="") as stream:
        return list(csv.DictReader(stream))


def is_outside_hit(row):
    return (row["case"] in {probe.name(c) for c in CASES}
            and row["outcome"] == "hit" and row["covered_start"] == "False")


def entry_delay(row):
    return int(row["last_observed_entry_after_start"])


def ticks_to_impact(row):
    return int(row["ticks"]) - entry_delay(row)


def register(swings):
    used = {(x["case"], x["id"]) for x in read_csv(ARCHIVE / "forks.csv")}
    rules = (lambda n: n <= 3, lambda n: n >= 14)
    selected = []
    for case, rule in zip(CASES, rules):
        rows = [x for x in swings if is_outside_hit(x) and x["case"] == probe.name(case)
                and x["player_target"] == "False" and int(x["max_production_overlap"]) >= 2
                and (x["case"], x["id"]) not in used and rule(ticks_to_impact(x))]
        selected.append(min(rows, key=lambda x: (int(x["start"]), x["id"])))
    if tuple(x["id"] for x in selected) != EXPECTED:
        raise ValueError("changed preregistered sample")
    return selected


def parse_control(raw):
    rows = [json.loads(line) for line in raw.splitlines()]
    index = {op: {r[key]: r for r in rows if r["op"] == op}
             for op, key in (("frame", "t"), ("begin", "id"), ("impact", "id"))}
    index["damage"] = [r for r in rows if r["op"] == "damage"]
    return index


def is_own(warning, start):
    return (warning[0] == 1 and warning[1:3] == start["origin"]
            and warning[3:5] == start["dir"]
            and warning[5:7] == [start["radius"], start["angle"]])


def visible_overlaps(frame, start):
    marks = frame["warnings"]
    own = [w for w in marks if is_own(w, start)]
    if len(own) != 1:
        raise ValueError(f"non-unique or ineligible committed warning at frame {frame['t']}")
    others = [SHAPES[w[0]] for w in marks if w[11] and w is not own[0]]
    if len(others) + int(own[0][11]) != frame["production"][0]:
        raise ValueError("production warning count mismatch")
    return own[0][11], others


def context(swing, trace):
    start = trace["begin"][swing["id"]]
    impact = trace["impact"][swing["id"]]
    elapsed = entry_delay(swing)
    tick = start["t"] + elapsed
    if start["covers"] or not impact["covers"] or not start["visible"] or elapsed <= 0:
        raise ValueError("invalid outside-entry premise")
    prev = trace["frame"][tick - 1]
    if visible_overlaps(prev, start)[0]:
        raise ValueError("not outside at the preceding tick")
    frame = trace["frame"][tick]
    at_impact = tick == impact["t"]
    if at_impact:
        # The actual check is before impact and is not a post-actor snapshot.
        entry_player, other_at_entry = impact["p"], None
    else:
        covered, other_at_entry = visible_overlaps(frame, start)
        if not covered:
            raise ValueError("did not enter the selected mark")
        entry_player = frame["p"]
    first_frame = trace["frame"][start["t"]]
    visible_overlaps(first_frame, start)
    return {
        "case": swing["case"], "id": swing["id"], "attempt": start["attempt"],
        "player_target": start["player_target"], "warning_eligible_tick": first_frame["t"],
        "last_entry_tick": tick, "impact_tick": impact["t"], "ticks_to_impact": impact["t"] - tick,
        "preceding_position": prev["p"]["xy"], "preceding_input": prev["p"]["input"],
        "preceding_velocity": prev["p"]["v"], "preceding_roll": prev["p"]["roll"],
        "preceding_other_overlaps": visible_overlaps(prev, start)[1],
        "entry_position": entry_player["xy"], "entry_input": entry_player["input"],
        "entry_velocity": entry_player["v"], "entry_roll": entry_player["roll"],
        "entry_phase": entry_player["phase"], "entry_snapshot": "impact" if at_impact else "post-actor",
        "entry_other_overlaps": other_at_entry, "max_overlap_in_attack": int(swing["max_production_overlap"]),
        "selected_damage": int(swing["damage_from_swing"]),
    }


def run_trial(case, target, delay, direction, out, evidence, trace):
    result = probe.examine_fork(case, target, delay, direction, out, evidence)
    stem = f"{probe.name(case)}_{direction}_{delay:02d}"
    archived = (evidence / "forks" / f"{stem}.jsonl.gz").read_bytes()
    raw = gzip.decompress(archived)
    rows = [json.loads(line) for line in raw.splitlines()]
    if probe.digest(raw) != result["suffix_sha256"]:
        raise ValueError(f"archived suffix hash mismatch: {stem}")
    baseline = trace["impact"][target]
    actual = next(r for r in rows if r["op"] in ("impact", "cancel") and r["id"] == target)
    same_attack = (actual["op"] == "impact" and all(actual[k] == baseline[k]
                   for k in ("t", "origin", "dir")))
    if not same_attack:
        # Retain the path but do not count geometry/timing divergence as an escape.
        result["classification"] = "unproven_different_impact"
    input_line = next(r for r in rows if r["op"] == "input")
    frames = [r for r in rows[2:] if r["op"] == "frame"]
    if direction == "stop" and (input_line["dir"] != [0, 0]
                                or any(r["p"]["input"] != [0, 0] for r in frames)):
        raise ValueError(f"stop does not hold the zero override: {stem}")
    hits = [{"tick": r["t"], "source": r["source"], "id": r["id"], "amount": r["amount"]}
            for r in rows[2:] if r["op"] == "damage"]
    control_hits = [{"tick": r["t"], "source": r["source"], "id": r["id"], "amount": r["amount"]}
                    for r in trace["damage"] if input_line["t"] < r["t"] <= baseline["t"]]
    if result["classification"] == "walk":
        result["classification"] = "stopped_outside" if direction == "stop" else "lateral_clear"
    result.update(same_attack=same_attack, control_hits=control_hits, hits=hits,
                  steering=input_line["dir"], terminal_position=actual.get("p", {}).get("xy"),
                  impact_input=actual.get("p", {}).get("input"),
                  render_frame_observed=False, suffix_file=f"forks/{stem}.jsonl.gz")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True, help="fresh directory")
    parser.add_argument("--jobs", type=int, default=3, choices=range(1, 5))
    args = parser.parse_args()
    if subprocess.check_output(["godot", "--version"], text=True).strip() != probe.ENGINE:
        parser.error("Godot version does not match the archived transitions")
    out = args.out.resolve()
    out.mkdir()
    evidence = out / "evidence"
    (evidence / "forks").mkdir(parents=True)
    before = probe.source_digest()
    swings = read_csv(ARCHIVE / "swings.csv")
    selected = register(swings)
    jobs = [(c, s["id"], d, direction) for c, s in zip(CASES, selected)
            for d in (entry_delay(s)-1, max(0, entry_delay(s)-7)) for direction in DIRECTIONS]
    plan = [{"case": probe.name(c), "id": target, "delay": delay, "direction": d}
            for c, target, delay, d in jobs]
    probe.write_json(evidence / "registered.json", plan)
    older = json.loads((probe.OLD / "trial-traces.json").read_text())
    published = {c["case"]: c for c in json.loads((ARCHIVE / "controls.json").read_text())}
    traces = {}
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        controls = list(pool.map(lambda c: probe.collect_control(c, out, evidence, older), CASES))
        for c in controls:
            k = c["case"]
            raw = gzip.decompress((evidence / f"{k}.jsonl.gz").read_bytes())
            original = gzip.decompress((ARCHIVE / f"{k}.jsonl.gz").read_bytes())
            if raw != original or any(c[key] != published[k][key] for key in ("report_sha256", "raw_sha256")):
                raise ValueError(f"complete chapter or per-tick control diverged: {k}")
            traces[k] = parse_control(raw)
        entries = [context(s, traces[s["case"]]) for s in swings if is_outside_hit(s)]
        probe.write_json(evidence / "entries.json", entries)
        results = list(pool.map(lambda j: run_trial(*j, out, evidence, traces[probe.name(j[0])]), jobs))
    if before != probe.source_digest():
        raise ValueError("source changed during the experiment")
    probe.write_json(evidence / "results.json", results)
    binary = Path(subprocess.check_output(["which", "godot"], text=True).strip()).resolve()
    probe.write_json(evidence / "provenance.json", {
        "baseline": MERGED, "engine": probe.ENGINE, "engine_sha256": probe.digest(binary.read_bytes()),
        "source_sha256": before, "runner_sha256": probe.digest(Path(__file__).read_bytes()),
        "headless": True, "actual_rendered_frame": "unverified",
        "control": [{k: c[k] for k in ("case", "exit_code", "report_sha256", "raw_sha256")}
                    for c in controls],
        "case_selection": [{"case": s["case"], "id": s["id"], "start": int(s["start"]),
                            "last_entry_delay": entry_delay(s), "ticks_to_impact": ticks_to_impact(s)}
                           for s in selected],
        "counts": dict(Counter(r["classification"] for r in results)),
    })
    print(f"{len(entries)} outside entries aligned; {len(results)} paired trials retained", flush=True)


if __name__ == "__main__":
    main()
