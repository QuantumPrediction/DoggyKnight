#!/usr/bin/env python3
"""Run the twelve fixed opening-playthrough cases and retain every attempt."""
import argparse
import concurrent.futures
import hashlib
import itertools
import json
import os
from pathlib import Path
import subprocess
import tempfile

ENGINE = "4.7.2.stable.official.ed1daf0bf"
SCENE = "res://tests/integration/opening_pace_probe.tscn"
FIXED = ["--speed=1", "--chapter=1", "--route=0", "--build=route", "--gear=none",
         "--guard=off", "--max-downs=3", "--max-sim-seconds=360"]
ATTEMPT_FIELDS = ("level_id", "difficulty", "victory", "kills", "damage_taken", "time_sec", "stars",
                  "hero_level", "snacks_earned", "remaining_vigor", "build_tricks",
                  "active_enemy_histogram")


def fingerprints(root):
    names = ["project.godot", "tests/integration/escape_policy.gd",
             "tests/integration/equipment_profiles.gd", "tests/integration/playthrough_bot.gd",
             "tests/integration/opening_pace_probe.gd", "tests/integration/opening_pace_probe.tscn",
             "data/levels/level_1_1.tres", "data/levels/level_1_2.tres", "game/flow/wave_spawner.gd",
             "game/progression/difficulty_data.gd", "game/progression/difficulty.tres",
             "game/flow/flow_main.gd", "game/flow/level_session.gd", "game/flow/save_store.gd",
             "core/game_state.gd", "core/data/wave_data.gd", "core/data/level_data.gd",
             "core/data/spawn_entry.gd"]
    return {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in names}


def run_case(root, case, fixed):
    hero, seed, policy = case
    with tempfile.TemporaryDirectory(prefix="doggy-opening-") as work:
        report = Path(work) / "report.json"
        cmd = ["godot", "--headless", "--path", str(root), "--fixed-fps", "60", "--max-fps",
               "0", "--disable-render-loop", SCENE, "--", *fixed, f"--class={hero}",
               f"--seed={seed}", f"--policy={policy}", f"--report={report}"]
        env = dict(os.environ, XDG_DATA_HOME=work)
        try:
            process = subprocess.run(cmd, cwd=root, env=env, capture_output=True, text=True, timeout=180)
            code, output = process.returncode, process.stdout + process.stderr
        except subprocess.TimeoutExpired as error:
            code, output = 124, (error.stdout or b"").decode() + (error.stderr or b"").decode()
        row = {"hero": hero, "seed": seed, "policy": policy, "exit_code": code}
        issues = [line for line in output.splitlines() if line.startswith(("WARNING:", "ERROR:", "SCRIPT ERROR:"))]
        row["messages"] = list(dict.fromkeys(issues))
        if report.exists():
            data = json.loads(report.read_text())
            row.update(outcome=data["outcome"], downs=data["downs"], route=data["route"],
                       attempts=[{key: a[key] for key in ATTEMPT_FIELDS} for a in data["attempts"]])
        if code not in (0, 1) or "outcome" not in row:
            row["run_log"] = output
        print(hero, seed, policy, row.get("outcome", code), flush=True)
        return row


def compare_runs(reference, measured):
    """Compare every archived gameplay field. New mode tags and engine-exit messages are checked separately."""
    before, after = (json.loads(p.read_text()) for p in (reference, measured))
    mode = "reinforced" if "--reinforced" in after["fixed"] else "normal"

    def records(data):
        result = {}
        for case in data["cases"]:
            key = (case["hero"], case["seed"], case["policy"])
            row = {k: v for k, v in case.items() if k not in ("messages", "attempts")}
            row["attempts"] = [{k: v for k, v in a.items() if k != "difficulty"} for a in case["attempts"]]
            result[key] = row
        return result

    old, new = records(before), records(after)
    cases = old.keys() | new.keys()
    differing = sorted(key for key in cases if old.get(key) != new.get(key))
    attempts = [a for row in after["cases"] for a in row["attempts"]]
    wrong_mode = sum(a.get("difficulty") != mode for a in attempts)
    old_messages = {(r["hero"], r["seed"], r["policy"]): r["messages"] for r in before["cases"]}
    diagnostic_matches = sum(r["messages"] == old_messages.get((r["hero"], r["seed"], r["policy"]))
                             for r in after["cases"])
    return {"reference": reference.name, "measured": measured.name, "mode": mode, "cases": len(cases),
            "exact_gameplay_cases": len(cases) - len(differing), "different_cases": differing,
            "attempts": len(attempts), "incorrect_result_modes": wrong_mode,
            "identical_exit_messages": diagnostic_matches}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--output", type=Path)
    action.add_argument("--compare", nargs=2, type=Path, metavar=("REFERENCE", "MEASURED"))
    parser.add_argument("--jobs", type=int, choices=(1, 2, 3, 4), default=2)
    parser.add_argument("--seeds", nargs=2, type=int, default=[7, 19], metavar=("FIRST", "SECOND"))
    parser.add_argument("--reinforced", action="store_true", help="Select the opening reinforcements at new game.")
    args = parser.parse_args()
    if args.compare:
        comparison = compare_runs(*args.compare)
        print(json.dumps(comparison, ensure_ascii=False, indent=2))
        return int(bool(comparison["different_cases"] or comparison["incorrect_result_modes"]))
    if args.seeds[0] == args.seeds[1]:
        parser.error("Select two distinct seeds.")
    root = args.root.resolve()
    if args.output.exists():
        parser.error("Select a fresh output file so earlier attempts are retained.")
    engine = subprocess.check_output(["godot", "--version"], text=True).strip()
    if engine != ENGINE:
        parser.error("Use the project's matching Godot 4.7.2 stable binary.")
    before = fingerprints(root)
    fixed = [*FIXED, "--reinforced"] if args.reinforced else FIXED
    mode = "reinforced" if args.reinforced else "normal"
    cases = itertools.product(("knight", "mage", "archer"), args.seeds, ("cautious", "escape"))
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        rows = list(pool.map(lambda case: run_case(root, case, fixed), cases))
    if before != fingerprints(root):
        raise RuntimeError("The measured inputs changed during the run")
    output = {"engine": engine, "fixed": fixed, "physics_fps": 60, "sha256": before, "cases": rows}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("x") as target:
        json.dump(output, target, ensure_ascii=False, indent=2)
        target.write("\n")
    return int(any(row.get("outcome") not in {"opening_complete", "down_limit", "simulation_limit"}
                   or any(attempt["difficulty"] != mode for attempt in row.get("attempts", []))
                   or row["exit_code"] not in (0, 1) or "SCRIPT ERROR" in " ".join(row["messages"])
                   for row in rows))


if __name__ == "__main__":
    raise SystemExit(main())
