"""Check two outputs from measure_touch_precision.gd (plain or gzipped ticks)."""

import csv
import gzip
import math
import sys
from itertools import groupby
from pathlib import Path


ROLES = ("knight", "mage", "archer")
SAME = (
    "right_0.0", "right_2.5", "diagonal_2.0", "right_16.0", "right_18.0", "right_27.0",
    "diagonal_18.0", "range_full", "range_short", "wall_full", "keyboard_full", "roll_full",
)


def read_rows(directory, name):
    path = directory / name
    if path.is_file():
        handle = path.open(encoding="utf-8")
    else:
        handle = gzip.open(path.with_suffix(path.suffix + ".gz"), "rt", encoding="utf-8")
    with handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def load(directory):
    def key(row):
        return row["role"], row["trial"]

    ticks = {k: list(v) for k, v in groupby(read_rows(directory, "ticks.tsv"), key)}
    trials = {key(row): row for row in read_rows(directory, "trials.tsv")}
    return ticks, trials


def check_run(ticks, trials, role, candidate):
    def rows(trial):
        return ticks[role, trial]

    def result(trial):
        return trials[role, trial]

    # Tick 0 is the first production physics step. Only mounting the real HUD adds two idle steps.
    for (sample_role, name), samples in ticks.items():
        if sample_role != role:
            continue
        for i, row in enumerate(samples):
            hud_warmup = 2 if name == "ownership" and row["phase"] in ("hud_blocked", "downed") else 0
            assert int(row["tick"]) == i and int(row["physics_step"]) == i + 1 + hud_warmup, (role, name, i)

    for (sample_role, name), info in trials.items():
        if sample_role != role or not name.startswith("right_"):
            continue
        radius = float(info["drag"])
        curve = min(1, max(0, (radius - 2.5) / (15.3 - 2.5)))
        expected = curve if candidate else float(radius > 2.5)
        assert abs(float(info["norm"]) - expected) < 0.00001, (role, name)

    for radius in (9, 18):
        axis = result(f"right_{radius}.0")
        diagonal = result(f"diagonal_{radius}.0")
        travel = math.hypot(float(diagonal["rest_dx"]), float(diagonal["rest_dy"]))
        assert abs(travel - float(axis["rest_dx"])) < 0.0004, (role, radius)
        assert abs(float(diagonal["rest_dy"]) / travel + 0.8) < 0.0001, (role, radius)
    glance = rows("shallow_left")[15]
    assert abs(float(glance["facing_x"]) + 0.08) < 0.00001 and glance["mirror"] == "1", role
    assert result("wall_full")["rest_dx"] == "2.000000", role

    half = result("range_half")
    assert half["combat_task"] == str(int(candidate)), role
    assert result("range_short")["combat_task"] == "1" and result("range_full")["combat_task"] == "0", role
    for trial in ("range_half", "range_short", "range_full"):
        info = result(trial)
        hold = int(info["hold_ticks"])
        observed = rows(trial)
        assert info["swings_held"] == "0" and observed[hold]["in_x"] == "0.000000", (role, trial)
        successful = info["combat_task"] == "1"
        assert (int(observed[-1]["target_hp"]) < int(observed[0]["target_hp"])) == successful, (role, trial)
        assert (int(info["first_swing"]) >= hold) == successful, (role, trial)

    for row in rows("ownership"):
        phase = row["phase"]
        if phase in ("primary", "secondary_drag", "secondary_release"):
            assert row["owner"] == "3" and row["in_x"] == half["norm"] and float(row["in_y"]) == 0, (role, phase)
        if phase in ("recenter", "resume", "before_pause"):
            assert row["owner"] == "3", (role, phase)
        if phase in ("cancel", "paused", "unpaused", "hud_blocked", "downed"):
            assert row["owner"] == "-1" and float(row["in_x"]) == float(row["in_y"]) == 0, (role, phase)
        if phase in ("hud_blocked", "downed"):
            assert float(row["vx"]) == float(row["vy"]) == 0, (role, phase)

    half_roll, full_roll = rows("roll_half"), rows("roll_full")
    for light, full in zip(half_roll, full_roll, strict=True):
        for field in ("roll", "invulnerable", "cooldown", "facing_x", "facing_y"):
            assert light[field] == full[field], (role, light["tick"], field)
    protected = [i for i, row in enumerate(half_roll[:188]) if row["invulnerable"] == "1"]
    assert protected == list(range(18)) and half_roll[188]["roll"] == "1", role
    assert next(i for i, row in enumerate(half_roll) if float(row["cooldown"]) == 0) == 179, role
    assert (float(half_roll[17]["x"]) < float(full_roll[17]["x"])) == candidate, role


def compare(before, after):
    base, baseline_trials = load(before)
    candidate, candidate_trials = load(after)
    assert base.keys() == candidate.keys() and baseline_trials.keys() == candidate_trials.keys()
    assert {role for role, _ in base} == set(ROLES)
    same_ticks = 0
    for role in ROLES:
        check_run(base, baseline_trials, role, False)
        check_run(candidate, candidate_trials, role, True)
        for trial in SAME:
            assert base[role, trial] == candidate[role, trial], (role, trial)
            same_ticks += len(base[role, trial])
        # A 15.3-unit drag entered at x=28 is subject to float32 event-position rounding.
        for a, b in zip(base[role, "right_15.3"], candidate[role, "right_15.3"], strict=True):
            assert a["x"] == b["x"] and abs(float(a["vx"]) - float(b["vx"])) < 0.00001, role
    count = sum(map(len, base.values()))
    assert count == sum(map(len, candidate.values()))
    print(f"{count} physics samples per build. {same_ticks} control samples match in every saved column.")
    for role in ROLES:
        pre, post = (rows[role, "range_half"] for rows in (baseline_trials, candidate_trials))
        print(f"{role}: {pre['rest_dx']} -> {post['rest_dx']} units, first damage tick {pre['first_damage']} -> {post['first_damage']}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("Usage: python3 tools/compare_touch_precision.py BEFORE_DIR AFTER_DIR")
    compare(Path(sys.argv[1]), Path(sys.argv[2]))
