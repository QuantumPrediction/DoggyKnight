# Golden Knight — current project state

Updated: 2026-11-20 (Hong Kong). Version: **0.9.0 development source**.

## Source and publication

- Repository: https://github.com/QuantumPrediction/DoggyKnight
- Current local working branch: `codex/first-chapter-build-routes`, based on the complete local 0.8.1 checkpoint `84e10a4a692f004d502a506f1b1736dd79bcafbc`.
- **Recovered 0.4–0.8.1 is now publicly available in [draft PR #12](https://github.com/QuantumPrediction/DoggyKnight/pull/12)**, head `codex/captain-fairness`, public commit `34e3ca95f058ad45707ef69510771ac08f16e127`, base `codex/music-classes-type` / PR #11 / `a7597b4bb863875a0d1a2bf224ccdea7077176e3`.
- Public tree `d860984cc31e68aefe9f2b22b19b1fe6a492263c` exactly matches local 0.8.1 checkpoint 84e10a4. Local Git history remains intact. CLI push lacked credentials; the connected GitHub Git Data API published the exact tree under the owner's explicit current-turn approval. Earlier approval-block records are history and do not require approval again.
- 0.9.0 implementation and evidence are complete; its separate stacked draft is being prepared above `codex/captain-fairness`. Record the actual PR/implementation commit after publication. Nothing has been merged.
- Dependency chain: Windows #9 → art #10 → classes/music #11 → recovered equipment/checkpoints/armory/elements/guard/learning/fairness #12 → 0.9 build routes. Main/default is not the latest development source.

## Implemented behavior

The recovered game has three classes, six chapters, 36 stages, four companions, 18 permanent items, common Lv5 / epic Lv9 caps, forging, boss pity and specified coin/gem purchases, illustrated armory comparisons, four-element engraving/resonance, stage checkpoints, Q/touch Bedivere guard and optional first-chapter guard lessons. Real payments remain disabled. 0.8.1 committed melee warnings use the actual impact geometry; crowd separation cannot move a committed soldier; captain summons respect the four-minion cap; cancelled/duplicate attacks and hit-triggered equipment control preserve recovery correctly.

0.9.0 replaces the existing first-chapter 1-1 mid-wave event with two routes per class: knight bulwark/vanguard, mage spellweaver/mistwalker, archer marksman/outrider. Each grants one existing starter trick and visible stat tradeoffs. Later upgrade offers include one legal related option when absent; evolutions retain priority and other choices remain. An unrouted run retains original offer/RNG behavior. No extra event pause was added.

First-chapter 1-2 trades recovery against snacks/current vigor, 1-3 trades a future basic-trick bonus against an immediate choice and damage risk, and 1-5 trades defense/mobility against reach/vulnerability. Remaining events, later chapters, endless and custom tables keep their existing behavior. Existing generated artwork is reused. Event cards now fit the larger descriptions and properly constrain portrait/icon sizes; upgrade UI displays the route and related choices.

Save **v11** adds a sanitized route in the chapter's safe-point data. v10 checkpoints default to no route and retain their existing build. Stage retry restores the previous route/skills, banked continuation preserves them, and new runs clear the route. Rebuilds do not compound modifiers. See [exact rules](BUILD_ROUTES_ZH.md) and [integration contract](requests/20261120-INT-build-routes.md).

## Current evidence and limits

- Final full regression: **896 tests, zero failed, zero broken files, exit 0**. Eleven new route tests exercise real abilities/stats, caps/evolved sources, legal offers, migration, retry, production flow and double-choice prevention. Existing teardown and resource/RID warnings remain; final exit reports 33 ObjectDB instances and 24 resources.
- Original 12-case normal-damage grid: **10 complete, one gameplay failure, one native crash**. Six routes × seeds 7/19, common1 earth purchased from the starting budget, fixed60/speed1, cautious movement/reactive guard and explicitly route-aware choices. This is functional coverage, not a paired comparison against 0.8.1 or human balance evidence. Archer outrider seed19 reaches the three-down limit after three cleared stages.
- The native-crash case (archer marksman seed7) logs a thread/Node notification error and native signal11, exit -6, no report. Three sequential and three concurrent isolated repeats all complete with one down and 250 damage each. The original crash remains retained and unresolved; lack of reproduction is not a fix.
- Nine staged OpenGL llvmpipe captures show the production UI over the arena at 540×960, 360×640 and 390×844 simulated notch. Cards and description heights fit. The initial showcase's missing owned-bark state is corrected and the failed image retained. These are staged captures, not an unfamiliar-player session. Audio uses Dummy; native Windows/mobile, controller, real touch hardware and headphones remain unverified.
- Evidence and tested fingerprints: [validation/0.9.0](validation/0.9.0/README.md). Earlier matched 0.8.1 tests/bots remain in their version directory. All failures are retained; no tuning to force passes.
- **No new Windows export or download package this turn.** The previously delivered Windows ZIP remains 0.8.1. Its matching-template pack checks passed previously; native Windows execution remains untested.

## Owner preference and next work

Keep replies brief. Do not proactively create/upload Windows ZIPs, standalone progress reports or recovery archives unless requested. Keep code, assets, documents, test records and screenshots in the authorized GitHub draft workflow. Do not ask again for that publication scope; do not infer merge, payments or store activation.

1. Observe unfamiliar players using both routes of each class: do they understand the cost, choose related upgrades deliberately, and change positioning/attack timing? Record comprehension and retry intent before making a 9/10 claim.
2. Investigate the large bot gap between bulwark and vanguard/outrider with additional seeds, builds and distinct control policies; preserve failures and separate survivability from playstyle bias. Do not tune global HP around two seeds.
3. Reproduce/diagnose the native thread-notification crash and clean up teardown/resource warnings. Check single/parallel execution separately; do not label it fixed from six successful repeats.
4. Validate target Windows/mobile hardware and controls/audio when available. Expand the proven first-chapter loop afterward. No popularity or 9/10 certification has been established.

Read `status/LINE_INT.md` for the latest integration checkpoint. Earlier dated notes and downloadable packages are historical and do not update automatically.
