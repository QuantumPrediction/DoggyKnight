"""Write one auditable CSV row per registered ordinary scarecrow warning."""
import argparse
import csv
import gzip
import hashlib
import json
import math
from collections import Counter
from pathlib import Path


def wall_gap(player):
    x, y = player["xy"]
    x0, y0, x1, y1 = player["bounds"]
    return min(x-x0, x1-x, y-y0, y1-y)


def coverage(frame, start):
    # Ordinary marks do not move. Match the production observer's exact sector;
    # identical geometry gives identical membership even for coincident marks.
    for w in frame["warnings"]:
        if w[0] == 1 and w[1:3] == start["origin"] and w[3:5] == start["dir"] and w[5] == start["radius"] and w[6] == start["angle"]:
            return w[11]
    return None


def swings(path):
    with gzip.open(path, "rt") as file:
        data = [json.loads(line) for line in file]
    frames = {r["t"]: r for r in data if r["op"] == "frame"}
    ends = {r["id"]: r for r in data if r["op"] in ("impact", "cancel")}
    damage = [r for r in data if r["op"] == "damage"]
    case = path.name.removesuffix(".jsonl.gz")
    for s in (r for r in data if r["op"] == "begin"):
        e = ends[s["id"]]
        ticks = range(s["t"], e["t"] + 1)
        seq = [frames[t] for t in ticks]
        same = [r for r in damage if r["id"] == s["id"]]
        all_damage = sum(r["amount"] for r in damage if r["t"] in ticks)
        states = [s["p"]] + [f["p"] for f in seq]
        if "p" in e:
            states.append(e["p"])
        rolling = any(r["rolling_left"] > 0 or r["roll"] == "rolling" for r in states)
        immune = any(r["immune"] for r in states)
        outcome = "unproven"
        if e["op"] == "cancel":
            outcome = "cancelled"
        elif same:
            outcome = "hit"
        elif s["covers"] and not e["covers"] and not all_damage and not immune and not rolling:
            outcome = "observed_walk_exit"
        elif s["covers"] and not e["covers"] and not all_damage and rolling:
            outcome = "observed_roll_assisted_exit"
        elif not s["covers"] and not e["covers"]:
            outcome = "outside_at_both_ends"
        last_entry = last_exit = None
        last = s["covers"]
        for t in ticks:
            current = e.get("covers") if t == e["t"] else coverage(frames[t], s)
            if current is None:
                last = None
                continue
            if last is False and current:
                last_entry = t - s["t"]
            if last is True and not current:
                last_exit = t - s["t"]
            last = current
        owner = int(s["id"].split(".")[0])
        yield dict(case=case, id=s["id"], attempt=s["attempt"], start=s["t"], end=e["t"],
                   ticks=e["t"]-s["t"], paused_ticks=sum(f["paused"] for f in seq[1:]), outcome=outcome,
                   player_target=s["player_target"], covered_start=s["covers"], covered_end=e.get("covers"),
                   last_observed_entry_after_start=last_entry, last_observed_exit_after_start=last_exit,
                   starting_phase=s["p"]["phase"], starting_roll=s["p"]["roll"],
                   start_speed=round(math.hypot(*s["p"]["v"]), 3), max_path_speed=round(max(math.hypot(*r["v"]) for r in states), 3),
                   min_wall_gap=round(min(wall_gap(r) for r in states), 3),
                   other_moving_enemies_max=max(sum(a[0] != owner and a[6] == 1 and math.hypot(a[4], a[5]) > .001 for a in f["actors"]) for f in seq),
                   max_production_overlap=max(f["production"][0] for f in seq),
                   damage_from_swing=sum(r["amount"] for r in same), all_interval_damage=all_damage)


def bundle_forks(primary, covered, dest):
    """Keep the matched-control prefix once, and all raw suffixes, including failures."""
    starts = {}
    for p in primary.glob("archer_*.jsonl.gz"):
        with gzip.open(p, "rt") as file:
            records = [json.loads(line) for line in file]
        starts[p.name.removesuffix(".jsonl.gz")] = {r["id"]: r for r in records if r["op"] == "begin"}
    rows = []
    with (dest / "fork-paths.jsonl.gz").open("wb") as raw, gzip.GzipFile(fileobj=raw, filename="", mode="wb", mtime=0) as packed:
        for stage, source in (("first", primary), ("covered", covered)):
            with (source / "forks.csv").open() as file:
                for row in csv.DictReader(file):
                    case = row["case"]
                    target = row["id"]
                    key = f"{case}_{row['direction']}_{int(row['delay']):02d}"
                    suffix = gzip.decompress((source / "forks" / (key + ".jsonl.gz")).read_bytes())
                    if hashlib.sha256(suffix).hexdigest() != row["suffix_sha256"]:
                        raise ValueError("Changed intervention: " + key)
                    trace = [json.loads(l) for l in suffix.splitlines()]
                    launch = trace[0]
                    target_start = starts[case][target]
                    result = row["classification"]
                    inside = coverage(launch, target_start)
                    if inside is None or launch["op"] != "frame":
                        raise ValueError("Missing target geometry at input: " + key)
                    path = result
                    if result in ("walk", "roll_assisted"):
                        path += "_exit" if inside else "_from_outside"
                    damage_sources = ",".join((r["id"] or r["source"]) for r in trace if r["op"] == "damage")
                    rows.append(dict(stage=stage, **row, covered_at_input=inside, path=path,
                                     damage_sources=damage_sources, launch_phase=launch["p"]["phase"],
                                     launch_speed=round(math.hypot(*launch["p"]["v"]), 3),
                                     launch_wall_gap=round(wall_gap(launch["p"]), 3)))
                    header = dict(op="trial", stage=stage, case=case, id=target, delay=int(row["delay"]),
                                  direction=row["direction"], suffix_bytes=len(suffix))
                    packed.write((json.dumps(header, separators=(",", ":")) + "\n").encode())
                    packed.write(suffix)
    with (dest / "forks.csv").open("w", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=rows[0].keys(), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def verify_bundle(evidence):
    """Check every published prefix and suffix without booting the engine."""
    controls = {}
    for case in json.loads((evidence / "controls.json").read_text()):
        raw = gzip.decompress((evidence / (case["case"] + ".jsonl.gz")).read_bytes())
        if hashlib.sha256(raw).hexdigest() != case["raw_sha256"]:
            raise ValueError("Changed control: " + case["case"])
        controls[case["case"]] = raw.splitlines(keepends=True)
    def key(r):
        return r["stage"], r["case"], r["id"], int(r["delay"]), r["direction"]
    with (evidence / "forks.csv").open() as file:
        rows = list(csv.DictReader(file))
    expected = {key(r): r for r in rows}
    if len(expected) != len(rows):
        raise ValueError("Duplicate fork")
    with gzip.open(evidence / "fork-paths.jsonl.gz", "rb") as archive:
        while header := archive.readline():
            trial = json.loads(header)
            r = expected.pop(key(trial))
            suffix = archive.read(trial["suffix_bytes"])
            prefix = controls[r["case"]][:int(r["matched_prefix_rows"])]
            if hashlib.sha256(b"".join(prefix)).hexdigest() != r["prefix_sha256"]:
                raise ValueError("Changed pre-input prefix: " + str(key(r)))
            if hashlib.sha256(suffix).hexdigest() != r["suffix_sha256"] or not suffix.startswith(prefix[-1]):
                raise ValueError("Changed intervention path: " + str(key(r)))
    if expected:
        raise ValueError("Missing intervention paths")
    print(f"Verified {len(controls)} complete controls and {len(rows)} matched prefix/suffix pairs.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence", type=Path)
    parser.add_argument("--covered", type=Path, help="supplemental evidence directory, for bundling all input forks")
    parser.add_argument("--dest", type=Path, help="output directory (defaults to primary evidence)")
    parser.add_argument("--verify", action="store_true", help="verify stored replay data read-only")
    args = parser.parse_args()
    if args.verify:
        verify_bundle(args.evidence)
        raise SystemExit(0)
    dest = args.dest or args.evidence
    rows = [r for p in sorted(args.evidence.glob("archer_*.jsonl.gz")) for r in swings(p)]
    with (dest / "swings.csv").open("w", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=rows[0], lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    for case in sorted({r["case"] for r in rows}):
        print(case, Counter(r["outcome"] for r in rows if r["case"] == case))
    if args.covered:
        bundle_forks(args.evidence, args.covered, dest)
