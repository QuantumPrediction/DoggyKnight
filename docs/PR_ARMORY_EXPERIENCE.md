# Add permanent equipment, stage resume and the illustrated armory

Players can buy, equip and forge permanent gear, resume their saved stage build,
and see the actual stat and set-bonus changes before committing to a purchase or
upgrade. The armory now shows illustrated item cards, prices, chapter locks,
slot shortcuts and fixed action buttons that remain reachable on small screens.

This draft builds on `codex/music-classes-type` (PR #11). It preserves the
recovered 0.4.0 equipment/checkpoint and quality-audit history, followed by the
0.5.0 armory changes; it is not intended to merge directly into the older default
branch. Previous dependency order is #9 → #10 → #11.

## Behavior and scope

- 18 persistent equipment items; common level cap 5, epic cap 9; four loadout
  slots per class, sets, forging, deterministic shop purchases, boss pity and
  duplicate conversion. Actual payments remain disabled.
- Save v8 preserves the stage-boundary build, XP, tricks, temporary modifiers,
  vigor, equipment and selected random states. Continue repeats the current
  stage. Loadout changes apply at the next stage, including retry. Endless has no
  mid-run resume; missing old-save build data cannot be reconstructed.
- Read-only comparisons use production stat and permanent-training rules,
  including rounded damage/vigor, two treasure slots, set losses/gains and proc
  effects. Confirmation binds the original item/class/currency. Failed save
  transactions retain rollback behavior.
- Training sword and stormbow gain an additional -1% of class base attack
  interval per level after level one, additive and capped at -4%/-8%. Other
  damage/pierce anchors, item prices and rewards remain unchanged. This is a
  small balance change; physics timing can quantize adjacent numeric gains.
- New forge art and transparent equipment atlas are integrated into the actual
  UI. Prompts, provenance and hashes are included. No new executable, store
  release, real-money flow or merge is part of this draft.

## Validation

Godot `4.7.2.stable.official.ed1daf0bf`; tested implementation
`c56e9534ebb0a753e05949297e5bac4c915418c0`.

- Final full regression: 831 tests, 0 failed, 0 broken files, exit 0. Targeted
  equipment suite: 28 passed. Existing teardown/resource warnings remain.
- Production numeric audit: 330 states, zero unchanged adjacent upgrade
  signatures, down from nine in the preceding quality checkpoint. This does not
  prove that every hit has higher damage or that every upgrade advances a frame.
- 12 actual Linux OpenGL screenshots and safe-area checks, including 360×640
  and simulated-notch layouts. Mature inventories are staged. Separate native
  UI operation with a fresh save completed purchase → equip → forge → return;
  coins 250 → 110 → 60 and the next unaffordable forge is disabled.
- Normal-damage fixed-seed smoke: knight/common5 failed at 1-4 with three downs;
  archer/epic9 completed six stages without a down. Both results are preserved.
  Different policies/loadouts and one seed are not a human balance comparison.

Evidence: `docs/validation/0.5.0/README.md` and `verification.json`. Follow-up:
melee approach/fairness across seeds, earned first-run economy, active companion
interaction, unfamiliar-player tests and target-device checks. This PR does not
claim the full game has reached 9/10.
