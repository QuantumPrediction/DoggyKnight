# R03a — visible warning priority in the combat readout

Continue from public PR #16 head `3367a183599b2e1ecbb5efebec341cb7879f3965`
on `codex/combat-timing-r03`. The owner approved the enhancement/public draft
workflow and requested continued product work in this conversation.

Observed problem: the retained `0.9.1/captures/archer_locked_focus_ready.png`
shows the player inside a locked enemy lane while the readout emphasizes
"ready to fire / focus full". R01 also found movement-policy sensitivity at 1-4.
This work improves the information hierarchy; it does not claim to solve encounter
balance or prove human comprehension.

- A real visible attack warning overlapping the player's body takes priority
  over the readout's ready/moving label: tracking aim, committed warning, or
  overlapping warnings. Keep actual focus/roll clocks visible and unchanged.
- Add explicit arrival-marker semantics, including all current summon markers.
  Spawn/arrival circles must not masquerade as an attack. Do not infer this from
  tint, hide warnings, add automatic movement or change damage/AI/RNG/timing.
- Use the existing marked-sector geometry; circle/line body padding is a
  conservative proximity cue. Ignore hidden, detached and queued-for-deletion
  marks. This is a visible-warning cue, not an all-threat detector, safe-to-fire
  certificate, guaranteed escape direction or countdown to projectile impact.
- Extend the existing `player_tactics_changed(status)` dictionary with warning
  counts. No new signal or save schema. Keep the readout touch-transparent,
  stable in pause and within its existing small-screen/notch footprint.
- Cross-directory scope: combat marks, arrival call sites, player snapshots,
  readout/localized strings, regression tests and staged production captures.
- Before implementation, retain failing product regressions. Afterward run
  focused tests and the complete suite. Freeze both existing bots. Repeat the
  eight exact archer anchors (routes 0/1, seeds 7/19, cautious/escape) against
  PR #16 `r01/after_fix_anchors`; all complete reports must remain identical.
  A mismatch blocks the no-gameplay-change claim and requires diagnosis.
- Render tracking, locked, overlap and cleared states, including small/notched
  layouts. Retain the old image as baseline by reference. Do not claim staged
  captures or bots establish human benefit. Larger development/confirmation
  grids remain required for future mechanical changes; R03/P1 are not closed.

Evidence: `docs/validation/r03a/`. Keep the unresolved native crash/resource
issues and human/device gates visible. No new download build or store/payment.

Visual-review amendment: the first five renders exposed an existing text-row
overflow. Labels inherited a 17-unit minimum before the smaller font was applied;
the roll row extended below the 42-unit panel. Keep these actual first renders,
add a regression that fails on containment/row separation, apply the font before
the row size, and check vertical bounds as well as width in the capture harness.
The panel footprint and combat clocks remain unchanged. Repeat the full suite
and exact anchors after this production layout fix.
