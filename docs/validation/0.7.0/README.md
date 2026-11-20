# 0.7.0 evidence — 2026-11-20

Exact engine: Godot **4.7.2.stable.official.ed1daf0bf**. Source hashes, artifact hashes and scope are in `verification.json`. Do not infer human quality, retention or device FPS from these checks.

## Final checks

- `regression_final.log`: **860 tests, 0 failed, 0 broken files, exit 0**. No script errors. Existing null-object/freed-lambda test cleanup errors and exit resource/RID warnings remain; this is not an error-free engine log.
- `guard_visual_final.log`: **14 tests, 0 failed, exit 0**, after active-icon readability polish. Covers actual approach, circle boundary, mitigation, one counter, all classes, equipment non-stacking, projectile block, invulnerability, daze, expiry, failure to arrive, pause, down/revive, stage end, real melee reach, genuine misses, HUD routing/layout, captain timing and cue clearing. Exit cleanup warnings remain.
- `screenshots/`: **7 real OpenGL captures**, 540×960, 360×640, 390×844 with simulated safe insets. `layout_checks.json` verifies guard button and caption, boss cue and pause panel safety and no guard/ultimate button overlap. The final capture exits 0; `capture_visual_final.log` retains engine warnings. No audible output was reviewed (Dummy audio).
- `git diff --check` and Python audit compile passed.

Captures are staged using production arena, actors, HUD, damage and guard arrival. Enemy AI and player physics are paused for composition; incidental companion bump attacks are suppressed in this capture scene only. The guard physically runs to its point; the counter screenshot calls the production damage method. These images are not a natural playthrough, final art-direction certification or Windows/mobile device evidence. The displayed incoming 20 becomes 10 with this staged earth starter build because equipment mitigation occurs before guard mitigation; the no-equipment test separately verifies 20→13.

## Combat comparison

Every run uses chapter 1, normal damage, no permanent training, a three-down limit and a separate temporary save. `common1` buys a level-1 weapon and armor for 240 of the actual starting 250 coins via production transactions; engraving is free. No subsequent gear upgrades. Fixed 60 Hz and speed 1; driver time is not measured device performance.

| Source and movement | Guard | Runs / completed | Downs | Total damage taken | Guard damage prevented |
| --- | --- | ---: | ---: | ---: | ---: |
| 0.6 / original | off | 6 / 4 | 8 | 2,522 | 0 |
| 0.7 / original | off | 6 / 4 | 8 | 2,522 | 0 |
| 0.7 / original | reactive | 6 / 4 | 10 | 3,033 | 124 |
| 0.6 / cautious | off | 6 / 6 | 1 | 1,518 | 0 |
| 0.7 / cautious | off | 6 / 6 | 1 | 1,518 | 0 |
| 0.7 / cautious | reactive | 6 / 6 | 2 | 1,776 | 151 |

Knight cases: seeds 7, 19, 41 × earth/fire. `baseline_instrumented/` runs recovered commit `d6c69bc` with the same instrumentation and policies, without guard mechanics. `knight_final/` holds 24 final-mechanics comparisons. `original` retains the preceding bot's movement; `cautious` uses actual telegraph geometry instead of a generic enemy danger radius and stops within actual melee range. `reactive` calls guard on two nearby enemies or a visible danger while leaving movement unchanged.

The no-command outcomes match across versions; better movement also helps the old version. Therefore neither the new guard nor melee readiness is credited with fixing the earlier 1-4 failures. The command mitigates real hits but indiscriminate use increases knight downs, likely through changes to companion positioning and subsequent combat; this causal explanation is a hypothesis, not a proven attribution. Human timing and positioning remain unvalidated.

`ranged_smoke/`: mage/archer × four elements × seed 7, original movement and reactive command: **8/8 complete, 0 downs**, 662 damage taken, 39 prevented. These are function smoke checks, not an equal-strength comparison with knight or a new class-balance conclusion. All **32 new final-mechanics runs have no script errors**. Gameplay losses and resource warnings are retained.

Audit manifests were captured at launch. Only the disabled icon color and staged capture harness were subsequently polished; all combat, rule and bot files are unchanged. `verification.json` records the exact two-file delta rather than rewriting audited manifests to pretend they ran a later source tree. Final icon behavior was checked by targeted tests and actual rendering.

## Iterations retained

`guard_iteration.log` records an initial test-helper argument parse failure, fixed before passing tests. `regression_iteration.log` records the expected strict EventBus-contract failure while new signals were not yet listed; the updated declared contract passes final regression. `baseline/`, `knight_comparison/` and their logs are exploratory runs, distinct from the controlled final-mechanics comparisons above. Initial display connection failure is in `capture.log`; a same-process temporary X server then rendered successfully. No failed evidence is relabelled as a pass.

## Reproduce

```sh
TEST_TIMEOUT=900 tools/run_tests.sh
TEST_TIMEOUT=120 tools/run_tests.sh companion_guard
python3 tools/run_balance_audit.py --out /tmp/knight-audit --heroes knight --gear common1 --seeds 7,19,41 --elements earth,fire --policies original,cautious --guard-modes off,reactive --jobs 3
python3 tools/run_balance_audit.py --out /tmp/ranged-audit --heroes mage,archer --gear common1 --seeds 7 --elements earth,water,fire,wind --guard-modes reactive --jobs 3
ART_CAPTURE_DIR=/tmp/guard-captures xvfb-run -a godot --path . --rendering-driver opengl3 --audio-driver Dummy res://tests/integration/guard_showcase.tscn
```

Run the last command in an isolated user-data directory for clean screenshots. On this execution host local Unix display sockets were unavailable; a temporary Xvfb TCP display and Godot were started by the same subprocess wrapper, then the display was terminated. All rendering uses the real Godot OpenGL pipeline, not an image-generation mockup.
