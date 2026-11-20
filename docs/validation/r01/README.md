# R01 / R02 — pressure attribution and flow lifetime

2026-11-20 (Hong Kong). Continue from roadmap PR #15
`f73213fbded6f346b004794307f47e227a48fcb2`, gameplay baseline 0.9.1.
Engine: `4.7.2.stable.official.ed1daf0bf`.

## Scope and interpretation

This iteration separates three questions: whether the observation tool changes
the run, whether a different visible-position policy can handle the same enemy
pressure, and whether exited flow objects can still mutate a checkpoint.
No enemy HP, damage, economy, spawn timetable or warning duration is changed.

`observer_anchor_comparison.json` confirms the enhanced read-only observer's
entire marksman/seed19 report equals the retained 0.9.1 report. The first 1-4
failure takes 133 damage; the next attempts take 129 and 124, total386. The
observer records actual player input, velocity, visible marks, enemy phases and
damage call stacks. Its 16 short candidate endpoints are a local geometric
diagnostic, not proof that an escape is reachable before impact. The player may
already be inside overlapping danger, and the samples do not predict future
attacks, acceleration or bodies.

The separately named `escape` policy scores short steps from visible enemy
positions and warnings at a fixed 0.12s decision interval; it does not inspect
spawn schedules, enemy cooldowns or future RNG. Original and cautious policies
are unchanged. The new policy is engineering coverage, not a human reaction model.
Better results under another bot policy do not mean the game was improved or
that the original failures are acceptable for new players.

## Registered baseline coverage

`baseline_grid/manifest.json` registers six routes × seeds7/19/31/43 ×
cautious/escape =48 cases before execution. Normal damage, common1 earth bought
for240/250 starting coins, zero training, fixed60/speed1, reactive guard,
route-aware choices, three-down limit,1200 simulated seconds, isolated saves,
three parallel processes. All reports, command lines, engine errors and failed
outcomes are retained. `integrity.json` checks source hashes before/after.

All48 cases completed their registered execution with no script error or native
crash, and the source integrity check is unchanged. Gameplay failures remain:

| Route | Cautious: clears / downs | Escape: clears / downs |
| --- | --- | --- |
| Bulwark | 4/4 /0 | 4/4 /0 |
| Vanguard | 4/4 /2 | 4/4 /0 |
| Spellweaver | 4/4 /2 | 4/4 /0 |
| Mistwalker | 4/4 /0 | 4/4 /0 |
| Marksman | 3/4 /6 | 4/4 /0 |
| Outrider | 3/4 /7 | 4/4 /0 |

Totals: cautious22/24,17 downs; escape24/24,0 downs. Both failures are archer
seed19 at1-4. All12 cautious reports on legacy seeds7/19 are **entirely identical**
to their0.9.1 reports. Exit resource errors remain in many logs and are reported
by `engine_error`; successful gameplay/runner exit does not mean error-free
shutdown. `policy_comparison.json` retains the per-route breakdown.

The pilot supports a positioning-sensitive explanation: this ruleset has working
solutions under the fixed alternate policy, while the cautious policy can become
trapped in overlapping warnings. It does not establish human fairness, isolate
each enemy change's causal contribution, or justify lowering global difficulty.
The next combat work should test whether players can see and learn those escape
and stop-to-attack decisions; the larger registered development/confirmation
grids are still pending, not silently replaced by this48-case pilot.

Reproduce into a fresh directory:

```sh
python tools/run_pressure_audit.py --out /tmp/doggy-pressure-new
```

`--trace` selects the read-only observer. Output directories containing prior
evidence are rejected. Same-policy comparisons with the old12 cases are recorded
separately; do not pool policies and call the combined result a human win rate.

## Scene lifetime diagnosis

`lifecycle_baseline.json` records30 production flow/scene cycles: each enters
the real first stage, skips dialogue, opens pause, returns to title, then frees
the flow. All30 reach a real arena; after cleanup there are zero player/enemy
nodes and zero orphan nodes. After warming all three classes, cycles4–30 have
26 nodes,299 resources and2029–2032 objects. Static memory ranges from136,886,563
to137,136,321 bytes; the probe retains result rows, which are included in memory.

This is accelerated scene churn, **not** a two-hour session or target-hardware
qualification. Exit still reports90 ObjectDB instances/49 resources plus texture
and text RIDs. A separate three-cycle verbose diagnostic reports110/58; counts
vary with the observed shutdown, so neither count is a claimed leak fix. The
available engine binary is stripped and `addr2line` could not symbolize the old
native crash stack. The original thread-notification crash remains unresolved.

## Demonstrated checkpoint defect

`guard_lifetime_before.log`: six guard-flow checks, two failed. An old flow that
has exited the tree still receives three guard-lesson EventBus callbacks.
Completion changes the shared flag **and writes its old checkpoint**; dismissal
also changes the shared flag. This is a distinct, reproducible lifecycle defect,
not an explanation of the historical native crash.

`FlowMain._exit_tree()` now disconnects the three lesson callbacks alongside the
existing input/pause callbacks. `guard_lifetime_after.log`: all six checks pass,
including the same two previously failing cases and the four existing
completion/replay/migration scenarios. Save schema and gameplay rules are
unchanged. The fix prevents a detached old flow from changing lesson flags or
writing an old checkpoint; it does **not** claim to fix the native crash.

`policy_checks.log`: three targeted checks pass for transformed visible geometry,
hidden marks and a bounded wall-escape choice without mutating enemy state/RNG.

`regression_final.log`: **915 tests, 0 failed, 0 broken files, exit 0**. This
includes the existing 910 tests, the two new guard-flow regressions and three
policy/geometry checks. Exit still reports 27 ObjectDB instances, 21 resources,
three CanvasItem RIDs and physics/texture RIDs; a passing suite is not a claim
that these warnings or the historical native crash are fixed.

`after_fix_anchors/` repeats both archer routes, seeds7/19 and both policies after
the callback fix. All eight complete reports are identical to their corresponding
`baseline_grid/` reports (`post_fix_comparison.json`). The two cautious seed19
failures remain. Source fingerprints are unchanged during this repeat. The
production fix therefore changes the demonstrated exited-flow behavior without
changing these combat outcomes. `tested-source.json` identifies the final source
and added regression tests; this is local evidence, not a GitHub CI result.

## Remaining gates

Broader fixed development/confirmation seeds, unfamiliar-player comprehension,
natural economy progression, Windows/mobile/controller input, audible listening,
long sessions and native-crash attribution remain outstanding. No9/10 or player
balance certification is claimed. No new art, screenshots or download build.
