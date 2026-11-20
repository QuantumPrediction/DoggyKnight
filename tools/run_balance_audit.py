#!/usr/bin/env python3
"""Run isolated, fixed-step Godot chapter bots and retain every success/failure.

No player telemetry is uploaded. These staged-loadout runs are engineering
comparisons, not human completion rates or purchase-economy simulations.
"""
from __future__ import annotations

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

ROOT = Path(__file__).resolve().parents[1]
ENGINE = "4.7.2.stable.official.ed1daf0bf"
PRESETS = {"none", "common1", "common5", "epic1", "epic3", "epic9"}


def csv_values(value: str) -> list[str]:
    return [part.strip() for part in value.split(",") if part.strip()]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--seeds", default="7,19")
    parser.add_argument("--chapters", default="1")
    parser.add_argument("--heroes", default="knight,mage,archer")
    parser.add_argument("--gear", default="none,common5,epic1,epic3,epic9")
    parser.add_argument("--jobs", type=int, default=3)
    parser.add_argument("--elements", default="default", help="default,earth,water,fire,wind; common1 purchases a starting set for 240 coins")
    parser.add_argument("--policies", default="original")
    parser.add_argument("--guard-modes", default="off")
    args = parser.parse_args()
    heroes, gear = csv_values(args.heroes), csv_values(args.gear)
    elements = csv_values(args.elements)
    policies, guard_modes = csv_values(args.policies), csv_values(args.guard_modes)
    if not policies or not set(policies) <= {"original", "cautious"} or not guard_modes or not set(guard_modes) <= {"off", "reactive"}:
        parser.error("Unknown movement or guard policy")
    if not elements or not set(elements) <= {"default", "earth", "water", "fire", "wind"}:
        parser.error("Choose known element names")
    chapters, seeds = list(map(int, csv_values(args.chapters))), list(map(int, csv_values(args.seeds)))
    if not heroes or not set(heroes) <= {"knight", "mage", "archer"} or not gear or not set(gear) <= PRESETS:
        parser.error("Choose known hero and equipment preset names")
    if not chapters or any(c < 1 or c > 6 for c in chapters) or not seeds or 0 in seeds or args.jobs < 1:
        parser.error("Chapters must be 1–6, seeds must be nonzero, jobs must be positive")
    version = subprocess.check_output([args.godot, "--version"], text=True).strip()
    if version != ENGINE:
        parser.error(f"Expected {ENGINE}, found {version}")
    output = args.out.resolve()
    output.mkdir(parents=True, exist_ok=True)
    cases = list(itertools.product(chapters, heroes, gear, seeds, elements, policies, guard_modes))
    # A checked source fingerprint includes uncommitted runtime/audit changes.
    source_hashes = {}
    for directory in ("core", "game", "data", "ui", "tests/integration"):
        for path in sorted((ROOT / directory).rglob("*")):
            if path.suffix in {".gd", ".tres", ".tscn"}:
                source_hashes[str(path.relative_to(ROOT))] = hashlib.sha256(path.read_bytes()).hexdigest()
    source_hashes["project.godot"] = hashlib.sha256((ROOT / "project.godot").read_bytes()).hexdigest()
    manifest = {
        "engine": version, "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "source_hashes": source_hashes, "cases": cases,
        "policy": "Original movement retains the earlier bot; cautious uses actual melee reach and telegraph geometry instead of a generic danger radius. Reactive guard calls on 2 nearby foes or visible danger; movement remains unchanged. Fixed 60 Hz, speed 1, class-specific existing bot, first offered trick; 3 downs or 1200 driver-loop seconds, 600 wall seconds. common1 buys/equips a level-1 starting set through production transactions (240 of 250 coins); other gear is staged and can include late-chapter items. Free element choice before departure; no further gear changes. No training. Separate user-data directory per case.",
        "limits": "Same seeds do not guarantee identical event consumption across equipment arms. AI decisions and camp results are not representative of human players. Simulated clock is not device performance.",
    }
    (output / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")

    def run(case: tuple[int, str, str, int, str, str, str]) -> dict:
        chapter, hero, preset, seed, element, policy, guard_mode = case
        key = f"c{chapter}_{hero}_{preset}_s{seed}" + (f"_{element}" if element != "default" else "")
        key += f"_{policy}_{guard_mode}"
        report = output / f"{key}.json"
        # Refuse to mistake an earlier result for a fresh run.
        if report.exists():
            report.unlink()
        command = [args.godot, "--headless", "--path", str(ROOT), "--fixed-fps", "60", "--max-fps", "0", "--disable-render-loop",
                   "res://tests/integration/playthrough_bot.tscn", "--", "--speed=1", f"--class={hero}", f"--chapter={chapter}",
                   f"--seed={seed}", f"--gear={preset}", f"--element={element}", f"--policy={policy}", f"--guard={guard_mode}", "--max-downs=3", "--max-sim-seconds=1200", f"--report={report}"]
        started = time.monotonic()
        with tempfile.TemporaryDirectory(prefix="golden-knight-balance-") as user_data:
            env = dict(os.environ, XDG_DATA_HOME=user_data)
            with (output / f"{key}.log").open("w") as log:
                try:
                    result = subprocess.run(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=600)
                    code = result.returncode
                except subprocess.TimeoutExpired:
                    code = 124
        item = {"case": key, "exit_code": code, "wall_seconds": round(time.monotonic() - started, 3)}
        if report.exists():
            data = json.loads(report.read_text())
            item.update(policy=policy, guard=guard_mode, hero=hero, gear=preset, element=element, chapter=chapter, seed=seed, outcome=data["outcome"], finished=data["finished"], downs=data["downs"],
                        cleared=sum(bool(a["victory"]) for a in data["attempts"]),
                        combat_seconds=round(sum(a["time_sec"] for a in data["attempts"]), 3),
                        damage_taken=sum(a["damage_taken"] for a in data["attempts"]),
                        empty_swings=sum(a.get("melee_empty_swings",0) for a in data["attempts"]),
                        guard_commands=sum(a.get("guard_commands",0) for a in data["attempts"]),
                        protected_hits=sum(a.get("guard_protected_hits",0) for a in data["attempts"]),
                        prevented_damage=sum(a.get("guard_prevented_damage",0) for a in data["attempts"]))
        else:
            item["outcome"] = "missing_report"
        text = (output / f"{key}.log").read_text(errors="replace")
        item["script_error"] = any(marker in text for marker in ("SCRIPT ERROR", "Parse Error", "Failed to load script"))
        item["runtime_error_lines"] = [line for line in text.splitlines() if line.startswith("ERROR:")]
        print(json.dumps(item, ensure_ascii=False), flush=True)
        return item

    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        results = list(pool.map(run, cases))
    (output / "summary.json").write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n")
    # Genuine gameplay losses are data, not a broken audit. Missing reports/errors are failures.
    return int(any(row["exit_code"] not in (0, 1) or row["script_error"] or row["outcome"] == "missing_report" for row in results))


if __name__ == "__main__":
    raise SystemExit(main())
