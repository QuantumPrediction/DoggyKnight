# Quality audit evidence — 2026-11-19

Engine: `4.7.2.stable.official.ed1daf0bf`. Scope: engineering evidence for the 0.4.0 development tree; not a human playtest or release certification.

## Final validation

- `final_regression.log`: **826 tests, 0 failed, 0 broken files, exit 0**.
- Previous `full_regression.log`: 825 tests passed before the enemy seed regression was added. Do not add these counts together.
- Cleanup diagnostics persist: 44 freed capture-0 errors, one freed capture-1 error, three null-object errors, plus resource/RID exit warnings. The capture/null counts match the prior 825-case run. The suite's assertions pass; its log is not error-free.
- Equipment baseline: 21 cases pass. Adding the new progression assertions reproduced one failure out of 23 before the fix (`forge_before_fix.log`); all 23 pass after (`forge_after_fix.log`). The final full suite includes them.
- `equipment_before.json` / `equipment_after.json`: 330 legal hero/item/level rows each; unchanged adjacent upgrades fall from 81 to 9. These compare zero-training, zero-trick base stats and effect parameters, with projectile penetration rounded. They do not prove a per-hit improvement after every integer damage/healing calculation.
- Remaining unchanged base-state steps: training_sword 2→3, 3→4, 4→5; stormbow 1→2, 2→3, 3→4, 4→5, 5→6, 7→8.
- 10,000 six-boss reward trials using the production inventory code: unique epic P10/median/P90 = 1/1/2; first epic boss ordinal = 1/4/5. No purchases or human session times are simulated.
- `repeatability.json`: knight and mage, chapter 1, no gear, seed 7 each repeat with identical complete attempt arrays, downs, ultimates and outcome. This does not prove every arm or platform is deterministic.

## Controlled chapter-one matrix

All three heroes × five staged loadouts × seeds 7 and 19 = 30 cases. Fixed 60 Hz, speed 1, ordinary damage, zero permanent training. The bot selects the first offered trick, skips dialogue and plays camp minigames. It stops after three downs, 1,200 driver-loop seconds or a 600-second wall limit. The driver-loop clock excludes frames awaited inside helper functions. Combat seconds come from the actual level results, including failed attempts.

Each cell is **chapter completions / 2 cases (total downs)**, not a human win rate.

| Gear | Knight | Mage | Archer |
| --- | --- | --- | --- |
| none | 1/2 (3) | 2/2 (0) | 2/2 (1) |
| common5 | 1/2 (3) | 2/2 (0) | 2/2 (0) |
| epic1 | 2/2 (2) | 2/2 (0) | 2/2 (1) |
| epic3 | 2/2 (2) | 2/2 (0) | 2/2 (0) |
| epic9 | 2/2 (0) | 2/2 (0) | 2/2 (0) |

Totals: knight 8/10 chapters, 10 downs; mage 10/10, 0 downs; archer 10/10, 2 downs. All 30 generated reports without script or parse errors. Two knight failures were retained, not rerun until successful. Full per-attempt stats, final vigor, skills, times, damage, raw logs and source hashes are under `controlled_chapter1/`.

The preset may include items only available in later chapters. Common uses two equipment slots; epic uses four, so this is a whole-loadout stress comparison, not an equal-cost or single-effect experiment. Knight and ranged bots use different approach/kiting policies. Same initial seed does not ensure identical random-event consumption after combat changes. A stronger preset need not produce a faster particular run. Do not use these two seeds to prescribe a blanket melee buff or a ranged nerf.

The earlier `chapter1/` matrix and `smoke/` are preserved as preliminary smoke evidence. They had incomplete RNG control and must not be pooled with the controlled matrix or presented as deterministic comparisons. Current seeded scope: global RNG, flow, enemies' initial decisions by spawn order, player crit, loot, equipment drops and minigames. Cosmetic camp dialogue RNG remains unseeded.

## Reproduce

From the repository with the required engine imported:

```bash
GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64 TEST_TIMEOUT=900 tools/run_tests.sh
/path/to/Godot_v4.7.2-stable_linux.x86_64 --headless --path . res://tests/integration/equipment_audit.tscn -- --report=/absolute/path/equipment.json
python3 tools/run_balance_audit.py --godot /path/to/Godot_v4.7.2-stable_linux.x86_64 --out /absolute/path/new_audit --seeds 7,19 --chapters 1 --jobs 3
```

The matrix runner isolates each case's user data and retains every failure. Use a fresh output directory; rerunning into the same directory replaces its reports. `manifest.json` fingerprints the runtime/test sources, including uncommitted changes, because the captured source HEAD is the recovered parent commit. All manifest source hashes were checked against the final tested working tree. Runtime error lines are retained separately from gameplay failures.

## Actual UI review and limits

An AI-operated native Linux window was inspected from title through purchase, equip, class selection, dialogue, brief combat and pause. It was not a complete human playthrough. Shop prices required a detail screen, and the light pause heading was difficult to read on its light panel. The heading now uses the existing dark ink color. No new rendered screenshot was captured after this one-line fix; pause UI regression tests passed. A separate screenshot attempt could not start because this shell lacked xvfb-run; no screenshot result is claimed.

Audio fell back to a Dummy driver, so there was no listening assessment. Existing screenshots in 0.3.0/0.4.0 are historical staged captures. No new EXE export, Windows/mobile device verification, external-player retention study, true payments, store release or merge is part of this batch.
