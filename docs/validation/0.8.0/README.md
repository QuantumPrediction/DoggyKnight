# Golden Knight 0.8.0 evidence — 2026-11-20

Engine: **Godot 4.7.2.stable.official.ed1daf0bf**. `verification.json` records source and artifact hashes. This continues local 0.7 commit `1f1fc1d`, retaining the entire unpublished chain above public PR #11 base `a7597b4`.

## Verified release candidate

- `regression_release.log`: **874 tests, 0 failed, 0 broken files, exit 0**, no SCRIPT ERROR/parse failures. Existing null-object/freed-lambda test cleanup errors and exit resource/RID warnings remain; this is not a clean engine log.
- `lesson_14_final.log`: **14 focused cases pass**. Coverage boundary, late subscribers, actual melee use, ranged ultimate exclusion, real misses, expiry, movement/range/recovery, pause, death, danger priority, optional dismissal, safe layout, detached prior-stage actors, v9 migration with owned gear/engraving/currency, automatic stage eligibility, replay, and persistence. These also pass in the final full suite.
- `captures/`: **10 real OpenGL staged images**, at 540×960, 360×640 and 390×844 with simulated insets. All final safe-area, caption, coach text rectangle, control non-overlap and settled pause-panel checks pass. Actors and hazards are positioned/frozen for composition; the guard physically approaches and protection/charge/use execute production methods. Not human gameplay evidence. Audio driver is Dummy.
- `flow_captures/`: **36 real OpenGL captures from a separate normal-damage knight bot**. New game, six stages, choices, dialogue, camps and results complete with zero downs. Seed 19, common-Lv1 earth equipment, cautious movement, reactive guard, speed 4. This exercises actual FlowMain transitions and automatic coach appearance. It is a functional rendered run, not a fixed-step balance comparison or device FPS benchmark. `rendered_playthrough.log/json` retain results and exit warnings.
- `windows_release.log` and `windows_build.json`: exported current **Windows x64 EXE** using matching official 4.7.2 templates. The matching Linux engine validated the embedded pack: current project version, new production scripts/art, 36 stages, four companions, illustrated resources, production pause UI and exclusion of tests. This does not execute the Windows binary natively. The binary is delivered separately, not stored in Git.

## Fixed-step smoke results

Same existing bot policies and actual starting economy: seed 7/19 × knight/mage/archer; common-Lv1 earth weapon and armor bought for 240 of the starting 250 coins; no training or subsequent upgrades. Fixed 60 Hz, speed 1, first offered trick, original movement and reactive guard, maximum three downs. Isolated save directory per run. All six final cases have **no script errors**. Exit resource warnings remain.

| Class | Seed | Completed chapter | Downs | Damage received |
| --- | ---: | --- | ---: | ---: |
| Knight | 7 | No; down limit at 1-4 | 3 | 616 |
| Knight | 19 | Yes | 0 | 207 |
| Mage | 7 | Yes | 0 | 71 |
| Mage | 19 | Yes | 0 | 96 |
| Archer | 7 | Yes | 0 | 53 |
| Archer | 19 | Yes | 0 | 91 |

The matching knight 0.7 cases have exactly the same completion, downs and damage. This patch improves feedback/learning; it does **not** demonstrate improved balance, human success or a 9/10 rating. The six-case sample is functional coverage, not class-equality evidence. No passing-only filtering.

Only `ui/hints/guard_coach.gd` changed after the final fixed-step audit: three AtlasTexture resources are cached instead of allocated per refresh. Combat/rules/bot code is byte-identical. Final full regression and staged rendering exercise that cache. The separate rendered playthrough predates this allocation-only change. Source manifests are retained as launched, not rewritten to pretend they exercised later code.

## Retained failures and limits

`lesson_iteration_1/2.log` retain initial test expectation errors (base damage and sanitized equipment shape), a stub-HUD test setup error, and the close-button minimum-size overrun. These were corrected and the actual production flow was tested. `capture_parse_iteration.log` records a typed-Variant parse failure. `captures/layout_checks_first_iteration.json` and `capture_layout_iteration.log` retain the pause-panel failure; visual inspection additionally caught body text exceeding its panel, so the final checks include actual text rectangles.

`chapter_smoke_initial/` retains the genuine scene-transition error: removed prior-stage Bulldog nodes answered a newly created HUD's status request before deferred deletion. The publisher now ignores detached/deleting actors; a focused regression test and all six repeated final cases verify the fix. Initial gameplay failures are not relabelled as successes.

`regression_iteration_1/2.log` retain stale hard-coded save-v9 expectations after the intentional v10 migration. `regression_intermediate.log` records a passing intermediate run; **`regression_release.log` is the authoritative fresh final-source run**.

No Windows/mobile hardware, controller, human listening, real-payment integration, store launch, external player retention or popularity validation. Existing cleanup errors remain a separate reliability task. Screenshots are engine captures, not GPT Image gameplay mockups; GPT Image supplied only the new production icon atlas.

## Reproduce

```sh
TEST_TIMEOUT=900 tools/run_tests.sh
tools/run_tests.sh guard_learning
python tools/run_balance_audit.py --out /tmp/guard-learning-audit --heroes knight,mage,archer --gear common1 --seeds 7,19 --elements earth --policies original --guard-modes reactive --jobs 3
ART_CAPTURE_DIR=/tmp/guard-learning-captures xvfb-run -a godot --path . --rendering-method gl_compatibility --audio-driver Dummy res://tests/integration/guard_learning_showcase.tscn
export/build_windows.sh
```

On this host, local Unix display sockets were unavailable. A temporary Xvfb TCP server and Godot ran in the same shell, then the server was stopped. Capture and bot save directories were isolated. This environment workaround is not a game runtime requirement.
