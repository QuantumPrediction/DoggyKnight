# Golden Knight — current project state

Updated: 2026-11-20 (Hong Kong). Version: **0.9.1 development source**.

## Source and publication

- Repository: https://github.com/QuantumPrediction/DoggyKnight
- **Current development branch: `codex/combat-readability-stability`**, published as [draft PR #14](https://github.com/QuantumPrediction/DoggyKnight/pull/14) against merged default head `a8f547e8056c3dc4caa3a5ed0b5e2c7fdfbe1c78`. Screenshot publication commit `d54e8cd9ae81c0c4a689bd8465fca4034c632ce0` has complete tree `5e52a2337fbbae7ec5588eae0483b473ab307271`, identical to local `648f223`, including all ten original PNGs. Later handoff updates change documentation only. Default still contains merged 0.9.0. Continue from this open draft's live remote head. See [publication mapping](validation/0.9.1/publication.json) and [screenshot index](validation/0.9.1/captures/README.md).
- Screenshot publication block resolved on 2026-11-20: the owner directly approved public upload of all ten 0.9.1 validation screenshots (five final, five before correction) to this repository and existing draft PR #14, acknowledging public visibility. The connected GitHub service then accepted the remaining images; all ten are now referenced by the PR branch and their original blob hashes match. The earlier opaque-upload rejection and initial text-only snapshot remain historical records. This follow-up changes no game source and does not merge the draft.
- On 2026-11-20 the owner explicitly requested “PLEASE MERGE” for the published 0.8.1/0.9.0 work. Its required dependency chain #9 → #10 → #11 → #12 → #13 was merged in that order. Each successor was retargeted to the default branch; merge commits preserve the implementation history.
- All five PRs are confirmed closed and merged. The final integration commit is `08e2ef4ef799a8e6df9876ba8f42d0439dc4fbd5`. Its complete Git tree `77ad0187f5c2459a27f7b659d5222b9cdea1ec32` is identical to PR #13 head `d7cafb5e4a58b813121e26a89d989b7499bc2e0e` (3,545 entries compared by path, mode, type and object SHA). The subsequent handoff commit changes only this file and `docs/status/LINE_INT.md`.

| Merged PR | Merge commit |
| --- | --- |
| [#9](https://github.com/QuantumPrediction/DoggyKnight/pull/9) | `bd7c814154e9a6f7292bcf01dfac8e000b8a1843` |
| [#10](https://github.com/QuantumPrediction/DoggyKnight/pull/10) | `3ac0a19553625e8c1cdc307ed1ccb61f670371cd` |
| [#11](https://github.com/QuantumPrediction/DoggyKnight/pull/11) | `b77f8b6a0a22c4be92c2e8d0a88659c516c4bd77` |
| [#12](https://github.com/QuantumPrediction/DoggyKnight/pull/12) | `5097b6dce854c3fccb991084ac84839bf241ac94` |
| [#13](https://github.com/QuantumPrediction/DoggyKnight/pull/13) | `08e2ef4ef799a8e6df9876ba8f42d0439dc4fbd5` |

- Historical snapshot mapping is preserved: public 0.8.1 `34e3ca95f058ad45707ef69510771ac08f16e127` and recovered local `84e10a4a692f004d502a506f1b1736dd79bcafbc` share tree `d860984cc31e68aefe9f2b22b19b1fe6a492263c`; local 0.9 implementation `563665e5f4f64fe4f0cd4c494014ab5ebd944cf4` and public `0872941e698b53a6ac60c857eb48443551eac3cb` share tree `bb0757c48e950446c9196d2fe644c5ca335f8d14`. Different commit IDs reflect the recovered/public parent chains.
- During the earlier merge-only operation, GitHub reported no statuses, PR workflow runs, reviews or review threads on the five original heads, and zero check runs on the final source head. Its existing 896-test log was inspected without rerunning an unchanged tree. The new 0.9.1 evidence below comes from fresh local runs, not GitHub CI.
- Earlier publication blocks and “not merged” notes in dated reports are historical. This merge approval covers this completed stack; it is not blanket approval for future merges or store/payment activation.

## Implemented behavior

0.9.1 adds a touch-transparent combat readout for actual class attack state, archer focus and learned roll protection/cooldown. Snapshots use the live player's clocks; pauses do not advance them and detached actors cannot overwrite the new HUD. Archer enemy tracking and locked aim use different shapes. Aiming origins cannot drift under crowd separation, and cancelled/duplicate releases cannot fire arrows. SignalWatcher and parameterized story-test callbacks now handle emitter lifetime correctly. Save v11 and balance numbers are unchanged. See [contract](requests/20261120-INT-combat-readability.md) and [validation](validation/0.9.1/README.md).

The recovered game has three classes, six chapters, 36 stages, four companions, 18 permanent items, common Lv5 / epic Lv9 caps, forging, boss pity and specified coin/gem purchases, illustrated armory comparisons, four-element engraving/resonance, stage checkpoints, Q/touch Bedivere guard and optional first-chapter guard lessons. Real payments remain disabled. 0.8.1 committed melee warnings use the actual impact geometry; crowd separation cannot move a committed soldier; captain summons respect the four-minion cap; cancelled/duplicate attacks and hit-triggered equipment control preserve recovery correctly.

0.9.0 replaces the existing first-chapter 1-1 mid-wave event with two routes per class: knight bulwark/vanguard, mage spellweaver/mistwalker, archer marksman/outrider. Each grants one existing starter trick and visible stat tradeoffs. Later upgrade offers include one legal related option when absent; evolutions retain priority and other choices remain. An unrouted run retains original offer/RNG behavior. No extra event pause was added.

First-chapter 1-2 trades recovery against snacks/current vigor, 1-3 trades a future basic-trick bonus against an immediate choice and damage risk, and 1-5 trades defense/mobility against reach/vulnerability. Remaining events, later chapters, endless and custom tables keep their existing behavior. Existing generated artwork is reused. Event cards now fit the larger descriptions and properly constrain portrait/icon sizes; upgrade UI displays the route and related choices.

Save **v11** adds a sanitized route in the chapter's safe-point data. v10 checkpoints default to no route and retain their existing build. Stage retry restores the previous route/skills, banked continuation preserves them, and new runs clear the route. Rebuilds do not compound modifiers. See [exact rules](BUILD_ROUTES_ZH.md) and [integration contract](requests/20261120-INT-build-routes.md).

## Current evidence and limits

- Final full regression: **910 tests, zero failed, zero broken files, exit 0**. Fourteen new tests cover real focus/roll/range/hitstop, pause/lifetime/layout, committed arrows and signal teardown. The freed-lambda/null-signal errors reproduced before correction are absent. Existing resource/RID warnings remain: 33 ObjectDB instances and 24 resources at full-suite exit.
- New matched 0.9.0/0.9.1 grids: **11/12 → 10/12 complete; 5 → 10 downs**. Same six routes, seeds7/19, normal damage, common1 earth, fixed60/speed1 and unchanged cautious/reactive route-aware bot. Marksman seed19 now reaches three downs at1-4; outrider seed19 still fails and outrider seed7 has two downs. This is a material bot regression, not improved balance, and should remain a draft concern.
- Read-only pressure follow-up reproduces both marksman seed19 reports exactly. Baseline clears with94 damage (71 melee/23 projectiles); candidate fails across three attempts with386 (324 ordinary melee/26 captain sweep/30 projectiles/6 crow). Candidate's first failure takes133. First three stages match. Investigate mixed attack pressure and archer positioning at1-4 before adjusting numerical balance.
- Historical native thread/Node notification signal11 remains unexplained. Both new grids and pressure follow-ups run without native crash, but successful repeats do not establish a fix. Original log and six earlier successful repeats remain in [0.9.0 evidence](validation/0.9.0/README.md).
- Five final staged OpenGL llvmpipe captures cover540×960,360×640 and390×844 simulated notch. Safe bounds/text fit pass; early capture errors/overlap are retained. Native Linux operator smoke confirms new-run archer selection, dialogue skip, movement, focus buildup/x1.35, automatic fire/recovery and keyboard/on-screen pause/resume. Not a human comprehension study, full clear, Windows/mobile/touch/controller test or audible music review; audio uses Dummy.
- New logs, paired reports, traces, screenshots and fingerprints: [validation/0.9.1](validation/0.9.1/README.md). Earlier evidence remains in its version directories. No seed replacement or numerical tuning to force passes.
- **No new Windows export or download package this turn.** The previously delivered Windows ZIP remains 0.8.1. Its matching-template pack checks passed previously; native Windows execution remains untested.

## Owner preference and next work

Keep replies brief. Do not proactively create/upload Windows ZIPs, standalone progress reports or recovery archives unless requested. Keep code, assets, documents, test records and screenshots in the authorized GitHub workflow. Publication and the existing #9–#13 merges are explicitly approved and complete; do not ask again for those completed actions. Future work can use draft PRs. This approval does not activate payments or stores.

1. Address the observed archer1-4 regression with mixed melee/ranged pressure traces, additional seeds and distinct positioning policies. Preserve the current paired failures and distinguish fair warnings from encounter balance. Do not tune global HP around two seeds.
2. Observe unfamiliar players using both routes of each class and the new action/focus/roll indicators. Record comprehension and retry intent before a9/10 claim.
3. Reproduce/diagnose the native thread-notification crash and remaining resource warnings. The callback fixes above do not solve these; successful repeats alone are insufficient.
4. Validate target Windows/mobile hardware and controls/audio when available. Expand the proven first-chapter loop afterward. No popularity or 9/10 certification has been established.

Read `status/LINE_INT.md` for the latest integration checkpoint. Earlier dated notes and downloadable packages are historical and do not update automatically.
