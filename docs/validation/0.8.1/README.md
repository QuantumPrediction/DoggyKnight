# Golden Knight 0.8.1 evidence — 2026-11-20

Baseline: complete local 0.8.0 `b0b711a`; branch `codex/captain-fairness`. Public dependency remains PR #11 `a7597b4`. Engine: **4.7.2.stable.official.ed1daf0bf**. Exact source hashes and results are in `verification.json` and `comparison.json`.

## Final evidence

- `regression_final.log`: **885 tests, 0 failed, 0 broken files, exit 0**, no script/parse errors. Existing cleanup and exit resource/RID errors remain. Baseline has 874 passing tests. The earlier passing `regression_iteration1.log` has 884; final adds hit-triggered equipment-control coverage.
- `fairness_final.log`: 11 focused tests. Actual wedge boundary, rear safety, body overlap on side, committed/clamped origin and direction, no leftover chase velocity, stun cancellation, duplicate resolution, live summon cap and warning consistency, normal/elite soldiers, separation freeze, real equipment control preserving recovery.
- `before_main` / `final_main`: 12 matched cases each. `before_check` / `final_check`: 4 additional knight cases each. All reports/logs retained, no script errors. See the full Chinese comparison and machine-readable `comparison.json`. No HP/damage/timing/economy/guard/bot tuning. Fixed-step outcomes are not human balance or retention measures.
- `pressure_baseline.json.trace.json`: synchronous read-only damage call stacks and periodic captain state. Its full ordinary report equals the 0.8 seed-7 knight report. Two 1-4 failures: 291 damage = 209 scarecrow (including play-dead loss), 72 projectile, 10 crow; no captain sweep. This does not attribute every loss to the collision defect.
- `captures/`: six real OpenGL staged images. Existing arena/HUD/actors, frozen and positioned for presentation. At 540×960, outside-warning body takes no sweep damage; captain reaches the announced origin; three summons yield one new warning, then four living summons. 360×640 and 390×844 simulated-notch checks cover the boss instruction's safe rectangle. This is not a comprehensive UI-overlap check. Images 01, 03 and 06 were visually inspected. Actors are not human-controlled; audio is Dummy.
- `manual_preview.log`: separate actual native Linux window. Observed 0.8.1 title, three-class selection, knight into live first battle, movement, pause/resume. Not a full manual chapter, performance benchmark or audio listening test.
- `windows_build.log` / `windows_build.json`: new Windows x64 export using matching official templates. Matching Linux Godot loads the embedded pack: version, current feature resources, arena, 36 levels, four companions, 28 illustrated textures, production pause UI; tests excluded. **Not native Windows execution.** Binary delivered separately, not in Git.

## Iterations and limitations

`fairness_before.log` retains a test-authoring error (player body radius field). `fairness_reproduced.log` is the corrected old-code run: outside-warning, rear-circle and summon-cap checks fail; side-overlap passes. `fairness_after_iteration1.log` passes 10 tests. `fairness_control_reproduced.log` then reproduces an introduced ordering issue: the first implementation overwrote a soldier's hit-triggered stun recovery. Final code establishes animation/phase/lunge first, preserves the warning world transform, then applies damage last so synchronous equipment effects retain their state. Final 11 tests and full 885 suite pass.

`after_main` / `after_check` retain the initial 16 patched runs. `final_main` / `final_check` rerun all 16 after the ordering fix. Comparison lists any changed metrics. Main initial manifest captured project version 0.8.0 before the version-only edit; final manifests include 0.8.1. Original manifests are not rewritten.

Rendered images and manual launch predate only the final synchronous-control ordering fix. Geometry, rendering, data and UI are unchanged; final tests, bots and packed export exercise that fix. Native Windows/mobile, controller, human audio, unfamiliar-player usability/retention are untested. Existing resource-cleanup errors are not relabelled as fixed. No 9/10 claim or real-money integration.

## Reproduce

```sh
TEST_TIMEOUT=900 tools/run_tests.sh
tools/run_tests.sh captain_fairness
python tools/run_balance_audit.py --out /tmp/melee-main --heroes knight,mage,archer --gear common1 --seeds 7,19 --elements earth --policies original,cautious --guard-modes reactive --jobs 3
python tools/run_balance_audit.py --out /tmp/melee-check --heroes knight --gear common1 --seeds 37,53 --elements earth --policies original,cautious --guard-modes reactive --jobs 2
ART_CAPTURE_DIR=/tmp/melee-captures godot --path . --rendering-method gl_compatibility --audio-driver Dummy res://tests/integration/melee_fairness_showcase.tscn
export/build_windows.sh
```

Run baseline comparisons in a clean 0.8.0 worktree. Capture requires a display; this host used its native desktop, with isolated save directories. Read-only trace uses `pressure_trace.tscn` with the ordinary bot flags.
