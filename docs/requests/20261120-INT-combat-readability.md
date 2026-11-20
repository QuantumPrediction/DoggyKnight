# 0.9.1 integration: readable decisions and lifecycle reliability

Continue the owner's quality request from merged default head a8f547e. Cross-line
integration covers combat, HUD, audio lifetime, tests and evidence. No new save
schema, class balance values, shop, payment, download or store release.

- Make the existing class attack rhythm, actual archer focus bonus and learned
  roll readiness visible through a compact, touch-transparent HUD. A new
  `player_tactics_changed(status: Dictionary)` EventBus signal carries a snapshot;
  HUD never reads actor nodes or advances cooldowns independently. Existing status
  requests refresh both panels. Pauses, downed actors and detached old scenes must
  not invent readiness or overwrite a new actor's status.
- Archer enemy tracking and locked aim have distinct shapes. Once locked, both
  lane origin and direction stay fixed until release. Cancelled or duplicate
  releases cannot launch projectiles. Preserve warning duration, damage and speed.
- Fix reproducible signal teardown errors and investigate audio/resource cleanup.
  Keep the prior native thread crash open unless a root cause is established;
  successful reruns alone are not a fix.
- Validate actual ability timings, paused clocks, class differences, target range,
  cancellation and crowd pressure; rerun the full suite and paired normal-damage
  route cases. Inspect rendered production HUD at small/notched sizes. Preserve
  failures, test commands and fingerprints. Do not equate tests with human 9/10.
