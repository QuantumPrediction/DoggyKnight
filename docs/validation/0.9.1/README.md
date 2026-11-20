# 0.9.1 combat readability and reliability

Engine: `4.7.2.stable.official.ed1daf0bf`. Work starts from merged default
`a8f547e8056c3dc4caa3a5ed0b5e2c7fdfbe1c78`, branch
`codex/combat-readability-stability`. Save v11, combat numbers, warning durations,
shops and bot policy are unchanged. No download/export was requested.

## What changed

- The live HUD receives snapshots of the current player's actual attack, focus
  and learned roll clocks. It distinguishes movement, target reach, windup,
  recovery, empty field and action lock. Archer focus shows the actual x1.35
  threshold; roll shows protection/cooldown and the stop-before-restart rule.
  It does not advance gameplay clocks or consume touch input.
- Enemy archer warnings distinguish tracking and locked aim by shape. Crowd
  separation no longer slides an aiming archer. Cancelled or repeated release
  calls cannot create a ghost or duplicate arrow.
- SignalWatcher teardown tolerates freed emitters. Parameterized story tests
  disconnect callbacks before freeing each captured dialogue box. These are
  test lifetime fixes, not a claimed fix for the historical native crash.

## Reproduction and regression

`baseline_archer.log` records three failing behavioural tests on the original
archer: a crowd moves the committed origin, cancelled aim fires, and duplicate
release fires twice. `archer_iteration1.log` passes all three after correction.
The fourth final test checks tracking-to-lock, fixed direction and stun cleanup.

`baseline_story.log` has eleven assertion passes but freed-lambda and null signal
errors; assertion counts alone were misleading. `story_iteration1.log` has the
same eleven passes without those errors. An exploratory audio shutdown cleanup
did not reduce exit leaks and was reverted; no audio cleanup fix is claimed.

`tactics_iteration1.log` retains a failed test which incorrectly expected
recovery during real melee hitstop. The corrected test asserts busy during
hitstop, then recovery. Eight HUD/actor checks now cover actual focus and roll,
exact full-focus notification, range, hitstop, pause, detached actors, downing,
touch transparency and layout. Two additional lifetime tests cover live/freed
emitters and retained signal evidence.

`regression_iteration1.log` and `regression_final.log`: **910 tests, 0 failed,
0 broken files, exit 0** each. The final run includes the taller HUD layout and
corrected showcase. Subsequent changes are evidence/handoff documentation only.

```sh
TEST_TIMEOUT=600 tools/run_tests.sh
```

Known exit warnings remain: 33 ObjectDB instances, 24 resources, three CanvasItem
RIDs, one physics-body RID and one dummy texture RID in the first full run.
Do not describe this as an error-free engine log.

## Paired normal-damage first-chapter audit

The same unchanged runner, fixed 60 Hz/speed1, normal damage, common Lv1 earth
gear purchased for 240/250 starting coins, no training, cautious movement,
reactive guard, route-aware choices and seeds 7/19 run on both versions.
The baseline checkout `9658fd9` has the same production game source as merged
0.9.0; its publication documentation differs. Each folder retains source
fingerprints, all logs and reports. Three isolated processes run concurrently.
The runner's exit 0 means complete reports without script/process failures;
it explicitly allows the bot to reach its three-down limit.

| Route / seed | 0.9.0 complete / downs / damage | 0.9.1 complete / downs / damage |
| --- | --- | --- |
| Bulwark / 7 | Yes / 0 / 42 | Yes / 0 / 42 |
| Bulwark / 19 | Yes / 0 / 26 | Yes / 0 / 31 |
| Vanguard / 7 | Yes / 1 / 366 | Yes / 1 / 340 |
| Vanguard / 19 | Yes / 0 / 232 | Yes / 0 / 204 |
| Spellweaver / 7 | Yes / 0 / 91 | Yes / 0 / 91 |
| Spellweaver / 19 | Yes / 0 / 99 | Yes / 0 / 99 |
| Mistwalker / 7 | Yes / 0 / 114 | Yes / 0 / 103 |
| Mistwalker / 19 | Yes / 0 / 124 | Yes / 0 / 127 |
| Marksman / 7 | Yes / 1 / 250 | Yes / 1 / 250 |
| Marksman / 19 | Yes / 0 / 94 | No / 3 / 386 |
| Outrider / 7 | Yes / 0 / 279 | Yes / 2 / 527 |
| Outrider / 19 | No / 3 / 377 | No / 3 / 372 |

**Completion decreases from 11/12 to 10/12; downs rise from 5 to 10.** Both
candidate failures occur at 1-4 after three cleared stages. Fixing lane stability
changes crowd trajectories and subsequent encounters even though damage and
timing values are unchanged. This is a material regression for this bot policy;
it is not evidence of improved overall balance. Keep the draft pending broader
archer pressure/positioning work and human checks. Do not lower enemy HP or
replace failed seeds merely to make this table green.

```sh
DOGGY_ROUTE_AUDIT_OUT=/tmp/doggy-route-fresh python tools/run_route_audit.py
```

`pressure_followup/` records an additional matched marksman/seed19 diagnostic
using the existing read-only pressure observer. Both complete report objects
exactly match their respective original runs: baseline clears with 94 damage;
candidate fails with 386 damage over three attempts. Call stacks attribute
baseline damage to 71 scarecrow melee + 23 projectiles; candidate to 324 scarecrow
melee + 26 captain sweep + 30 projectiles + 6 crow dives. Candidate's first failed
1-4 attempt takes 133
damage, so its larger aggregate is partly repeated attempts. This is not simply
an increase in arrow damage. First three stages are unchanged. The next
investigation should examine mixed melee/ranged crowd pressure and archer
positioning at 1-4 with additional seeds and policies, before any numerical
balance change. Commands, raw stacks/positions and `summary.json` are retained.

The historical signal11/thread-notification crash remains unresolved. Neither
current twelve-case run reproduces it; this does not establish its cause or fix.
The original failure is preserved in `../0.9.0/route_audit/archer_route0_s7.log`.

## Rendered and native checks

The local implementation contains five final production-engine staged views: tracking aim,
locked aim/full focus, mage roll cooldown, 360x640 knight and 390x844 simulated
notch archer. Default size is 540x960. `captures/checks.json` records safe-area containment,
no overlap with the guard button and text fit for all five. Actors are frozen
and focus is staged; these are not human playthroughs. Existing artwork is reused.

PNG publication was stopped by automatic approval review. It rejected an opaque
binary upload because it did not accept prior authorization as covering this
specific asset. The publication scope is now inspectable UTF-8 source and
evidence only; the ten new PNGs remain in local commit `91a62f1`. Four blob
objects had been accepted before rejection, but no branch referenced them.
The public draft will not reference those new image objects. No alternative
image-upload route is used. The showcase reproduces the captures, and source/test
fingerprints are unaffected by omitting validation images.

The first capture script called a nonexistent helper; its error log and empty
checks are retained. The second capture set is retained locally in `captures/iteration2`:
it exposed a meter/text overlap and a staging-induced frozen hit flash. The final
panel is taller, with separate text/meter rows, and the showcase stages focus
without firing a real arrow. `capture.log` retains the final OpenGL llvmpipe
run and remaining exit warnings.

```sh
ART_CAPTURE_DIR=/tmp/doggy-readability-capture godot --path . \
  --rendering-method gl_compatibility --audio-driver Dummy \
  res://tests/integration/combat_readability_showcase.tscn
```

Native Linux smoke test used a fresh isolated save and the normal main scene,
not the showcase: title showed 0.9.1; selected archer; skipped opening and stage
dialogue; entered 1-1; moved left/right with keyboard; observed focus rebuilding
(43%) then x1.35 and automatic firing/recovery; paused with Escape, resumed with
the button, and paused again using the on-screen button. The game is left paused.
`manual.log` has no script errors during this observation. Audio was Dummy.
This is an operator smoke test, not an unfamiliar-player study, full clear,
Windows run, real touch test or an audible music assessment.

There is no 9/10, popularity, retention or release-readiness certification.
