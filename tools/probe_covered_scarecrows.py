#!/usr/bin/env python3
"""Apply the same interventions to the registered already-covered cautious hits."""
import argparse
import csv
import json
import shutil
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from probe_scarecrow_windows import DELAYS, DIRECTIONS, digest, examine_fork, name, source_digest, trace_rows, write_json


def first_covered_hit(rows):
    starts = {r["id"]: r for r in rows if r["op"] == "begin"}
    for hit in (r for r in rows if r["op"] == "damage" and r["id"]):
        s = starts[hit["id"]]
        if s["player_target"] and s["covers"] and not s["p"]["immune"] and s["p"]["roll"] != "rolling":
            return s["id"]
    raise ValueError("No eligible previously covered hit")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("completed_run", type=Path)
    parser.add_argument("--jobs", type=int, choices=range(1, 9), default=4)
    args = parser.parse_args()
    original = args.completed_run.resolve()
    previous = json.loads((original / "evidence/fingerprint.json").read_text())
    source = source_digest()
    if source != previous["source_sha256"]:
        raise ValueError("Frozen game and primary runner changed")
    out = original / "covered"
    out.mkdir()
    evidence = out / "evidence"
    evidence.mkdir()
    (evidence / "forks").mkdir()
    cases = [(0, "cautious"), (1, "cautious")]
    targets = {}
    for case in cases:
        folder = out / name(case)
        folder.mkdir()
        raw = original / name(case) / "report.json.windows.jsonl"
        shutil.copyfile(raw, folder / raw.name)
        targets[case] = first_covered_hit(trace_rows(raw))
    def run(job):
        case, delay, direction = job
        return examine_fork(case, targets[case], delay, direction, out, evidence)
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        jobs = [(case, d, dr) for d in DELAYS for case in cases for dr in DIRECTIONS]
        forks = list(pool.map(run, jobs))
        finer = []
        for case in cases:
            walks = [r for r in forks if r["case"] == name(case) and r["classification"] == "walk"]
            if walks:
                best = max(walks, key=lambda r: r["delay"])
                finer.extend((case, d, best["direction"]) for d in range(best["delay"]+1, best["window_ticks"]) if d not in DELAYS)
        forks.extend(pool.map(run, finer))
    with (evidence / "forks.csv").open("w", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=forks[0].keys(), lineterminator="\n")
        writer.writeheader()
        writer.writerows(forks)
    if source != source_digest():
        raise ValueError("Source changed during covered cases")
    write_json(evidence / "fingerprint.json", dict(primary_source_sha256=source,
               supplemental_runner_sha256=digest(Path(__file__).read_bytes()),
               targets={name(case): target for case, target in targets.items()}))


if __name__ == "__main__":
    main()
