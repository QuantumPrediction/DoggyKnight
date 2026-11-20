# 0.9.0 build routes — validation

Godot `4.7.2.stable.official.ed1daf0bf`. Baseline local checkpoint `84e10a4a692f004d502a506f1b1736dd79bcafbc` (0.8.1). Production runtime, route data, UI and migration are covered; new downloads were not requested or exported.

## Automated checks

- `routes_iteration1.log`: 11 new tests, zero failed/broken, exit 0. Checks real granted Player abilities/stats, one-time grants, class restrictions, caps/evolved sources, pending bonus preservation, guided offer legality, original unrouted RNG, retry/new-run resets, JSON migration, production event flow and small/notched UI/double-tap behavior.
- `regression_iteration1.log`: 896 tests, zero failed/broken, exit 0.
- `regression_final.log`: 896 tests, zero failed/broken, exit 0, after final translations/showcase changes. Reproduce with `TEST_TIMEOUT=900 tools/run_tests.sh`. After these checks only an extra blank line at EOF was removed from the two new route scripts; no executable statement changed.
- Legacy event tests explicitly use a duplicate custom event table to retain their original contract. `tests/routes/test_route_flow.gd` separately exercises the real default-table override; this is not a silent production bypass.
- Logs still include teardown errors and resource/RID warnings. Final full-suite exit reports 33 ObjectDB instances and 24 resources; this is not an error-free engine log or a cleanup fix.

## Original functional route grid

All 12 registered cases are retained in `route_audit/`. Fixed 60 Hz / speed 1, normal damage, chapter 1, common Lv1 earth gear purchased for 240 of 250 starting coins, no training/upgrades, cautious movement/reactive guard, two seeds per route. Route-aware choices prefer evolution, then the ordered route skills, then the first option; non-route events always choose index 0. Saves are isolated, three processes ran concurrently. `manifest.json` records engine, cases and tested source hashes. This changes the choice policy from the earlier audit and is **not a paired balance comparison with 0.8.1**.

| Route | Seed 7: completion / downs / damage | Seed 19: completion / downs / damage |
| --- | --- | --- |
| Knight bulwark | Yes / 0 / 42 | Yes / 0 / 26 |
| Knight vanguard | Yes / 1 / 366 | Yes / 0 / 232 |
| Mage spellweaver | Yes / 0 / 91 | Yes / 0 / 99 |
| Mage mistwalker | Yes / 0 / 114 | Yes / 0 / 124 |
| Archer marksman | Native crash; no report | Yes / 0 / 94 |
| Archer outrider | Yes / 0 / 279 | No / 3 / 377; three stages cleared |

The original grid has **10 completions, one gameplay failure and one native crash**. Repeated attempts are included in reported damage. Do not replace the failed rows with later successes. No HP/damage/clock adjustment was made to force passes. Two seeds and one movement/choice policy cannot establish route balance, human skill ceilings, fun or retention.

The crash log reports a non-caller-thread `Node.propagate_notification()` error, then signal 11/native backtrace and process exit -6. There is no completed playthrough JSON and no recorded GDScript parse/load error. Its root cause has not been established. `native_crash_followup/` repeats that exact archer/marksman seed-7 case three times sequentially: all complete, one down and 250 damage each. `native_crash_parallel_followup/` repeats the same case in three concurrent isolated processes after regression/import completion: all three also complete, one down and 250 damage each. Its command manifest is retained. All six follow-ups are separate from the original grid; the native crash remains unexplained. Existing cleanup warnings remain.

To repeat the grid without overwriting evidence:

```sh
DOGGY_ROUTE_AUDIT_OUT=/tmp/doggy-route-new-run python tools/run_route_audit.py
```

## Rendered checks

`tests/integration/build_routes_showcase.tscn` renders the real event/trick UI and farm arena with actors staged/frozen for inspection. This is **not a recorded human playthrough**. Nine final PNGs and `captures/checks.json` cover three class choices, three encounters, 360×640 small view, 390×844 simulated notch, and a guided upgrade. Normal views use 540×960. All card rectangles are inside the simulated safe rect and all description line heights fit.

The original guided-upgrade staging forgot to populate the owned starter, incorrectly displaying NEW. Its image is retained at `captures/iteration1/guided_upgrade_missing_owned_state.png`; final staging includes bark and correctly displays Lv2. This was a showcase-data correction, not a live route-grant change. `capture.log` retains OpenGL llvmpipe and exit leak warnings. Existing generated artwork is reused; no new bitmap artwork was generated in this round.

Native Windows/mobile, hardware touch/controller, audible music evaluation, unfamiliar-player understanding, repeat-play intent, long-term economy and route balance remain unverified. The isolated native crash remains open even when follow-ups succeed. This draft is not a 9/10 certification.
