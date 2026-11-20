# Golden Knight — current project state

Updated: 2026-11-20 (Hong Kong). Version: **0.8.1 development playtest**.

## Source and publication

- Repository: https://github.com/QuantumPrediction/DoggyKnight
- Current working branch: `codex/captain-fairness`.
- Recovered local baseline: `b0b711a` (complete 0.8.0). Public base remains `codex/music-classes-type`, draft PR #11, `a7597b4bb863875a0d1a2bf224ccdea7077176e3`.
- Preserve the dependency chain: Windows PR #9 → art PR #10 → classes/music PR #11 → recovered 0.4 equipment/checkpoints → 0.5 armory → 0.6 elements → 0.7 guard → 0.8 learning/feedback → 0.8.1 melee fairness. Main/default branches are not the latest development source.
- Publication status: the ordinary `git push --set-upstream origin codex/captain-fairness` was rejected by automatic approval review in this round. It did not accept prior-conversation authorization as direct authorization for publishing the branch/contents to public GitHub. No alternate write route was used; no new remote branch or PR was created. Implementation commit is `4c43612ebcad5346497d2a7343499ca04f8580f0`; the following checkpoint changes only handoff/publication records. Complete stacked PR text: `PR_MELEE_FAIRNESS.md`. A recovery package preserves the full source and unpublished Git history; Windows download is separate. Remaining public push/draft PR needs direct current-conversation approval.

## Implemented behavior

Three classes, six chapters, 36 stages and four companions remain. Recovered 0.4–0.6 adds 18 permanent gear items, common Lv5 / epic Lv9 caps, four slots per class, family sets, named coin/gem purchases, forging, boss pity, illustrated workshop, actual comparisons, free four-element engraving and matching weapon/armor resonance. Real payments remain disabled.

0.7 adds Q/touch Bedivere guard: physical approach, radius 32 for 2.8 seconds, 35% mitigation after equipment defenses, one +25% normal-hit charge on the first actually reduced hit or valid shield interception. Charge lasts the existing three-second combat window; strongest equipment charge wins; ultimates neither consume nor multiply it. Command cooldown is 10 seconds from request with no failed-approach refund. Knight windup uses actual reach, movement can cancel, real misses still spend cooldown. Captain cues reflect actual attack/recovery state.

0.8 makes coverage and charge readable: actual inside/outside state, real charge magnitude/time, movement/range/recovery guidance, and danger priority. The first-chapter optional coach appears after the intro at 1-3/1-4, can be dismissed for this run or replayed from pause, and marks completion only after an earned guard counter is consumed by an ordinary hit. Shield interception can teach this without deliberate damage. New GPT Image icons are production assets; the pause menu fits the base and simulated safe areas. Detached/deleting previous-stage actors no longer publish snapshots to newly constructed HUDs. No combat number or bot policy was changed.

0.8.1 aligns ordinary/elite scarecrow and captain warnings with their actual clamped lunge origin and direction. Hit tests intersect victim bodies with the exact rendered polygon; no hidden rear circle. Committed soldiers no longer drift under crowd separation. Captain reinforcements honor the existing four-living-summon cap at warning and release, without unannounced additions. Cancelled/duplicate attacks cannot resolve; hit-triggered equipment stun retains its recovery state because damage resolves after attack-state setup. No damage/HP/speed/timing, economy, guard or bot-policy tuning.

Save remains **v10**, adding the verified lesson-completion flag. Older equipment, engraving, currency and stage checkpoints migrate. Story resume is a stage boundary, not frame-by-frame; endless has no mid-run resume. Skipping the lesson is run-local; completed lessons remain manually replayable.

## Current evidence and build

- Authoritative final counts, source fingerprints and retained failures: `validation/0.8.1/README.md`, `verification.json` and `comparison.json`. Final full suite: **885 tests, 0 failed, 0 broken files, exit 0**; baseline 874. Eleven focused geometry/cap/cancellation/equipment-control checks pass. Existing cleanup and exit resource/RID errors remain.
- Read-only seed-7 trace exactly matches the old complete bot report. Two 1-4 failures: 291 damage = 209 scarecrow, 72 projectile, 10 crow; no captain sweep. Do not attribute the loss solely to the captain.
- All 16 final matched bot cases have no script errors. Main 12: 10→11 completions, 7→5 total downs. Extra four knight cases: both complete all, two total downs each; individual outcomes improve and worsen. Original-policy knight seed 7 still fails at 1-4. Not human balance, fun or retention evidence.
- Six staged OpenGL captures at 540×960, 360×640 and 390×844 simulated notch verify warning/dodge/summons and the boss instruction's safe rectangle. Separate native Linux launch checks title, class selection, live battle, movement and pause/resume. Audio is Dummy. Rendered checks precede only the final synchronous equipment-control ordering fix; final tests, bots and export cover it.
- **New Windows x64 0.8.1 EXE** exported with matching official Godot 4.7.2 templates. Embedded-pack checks pass for current resources, all 36 levels, four companions, illustrated textures, UI and test exclusion. Native Windows execution remains untested. Binary delivered separately, not committed.

## Next concrete work

1. Observe unfamiliar humans playing the first chapter without a developer explaining it. Record whether they understand stop-to-attack, guard arrival/radius, charge expiry and safe counter timing. This implementation has not established human usability or retention.
2. Study mixed melee/projectile pressure and safe approach opportunities in 1-4 using the new attribution and equal starting economy. The seed-7 loss remains; do not inflate global health or optimize one bot as proof of quality.
3. Complete two distinct build routes per class and three first-chapter encounter choices with meaningful risk/reward. These are next work, not features shipped in 0.8.1.
4. Resolve existing cleanup warnings and validate the exported build on target Windows/mobile hardware, controller/touch and headphones. Expand the proven loop afterward. No store launch, real-money integration, popularity or 9/10 claim.

Read `MELEE_FAIRNESS_ZH.md`, `requests/20261120-INT-captain-fairness.md`, `validation/0.8.1/README.md` and `status/LINE_INT.md`. Historical 0.7 and earlier notes remain in Git and dated reports. Existing older downloads do not update automatically.
