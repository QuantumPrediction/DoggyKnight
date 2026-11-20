# 0.8.0 integration: readable protection and optional guard lesson

Owner request: continue developing Golden Knight here toward a high-quality game. This integration slice extends the existing cross-directory combat/UI/save work; it does not change damage, cooldowns, encounter tuning, shops, or monetization.

## Contracts

- `companion_guard_coverage(protected: bool)`: Bulldog reports whether the living player is inside its actual active protection circle. Arrival, daze, cancellation, and leaving the radius revoke coverage.
- `player_combat_status_requested()`: late UI requests a fresh player snapshot.
- `player_combat_readiness(state: StringName, charge_left: float, charge_bonus: float)`: player-owned charge clock and actual readiness. States: idle, moving, out_of_range, recovering, windup, ready, busy, unavailable. UI never reads actors or runs a second charge clock. Countdown display rounds up to a tenth; pause freezes the source clock.
- `companion_counter_resolved(result: StringName)`: used, expired, or cancelled. Only the existing normal melee-hit/projectile-impact charge consumption can emit used. An ultimate, a missed sword swing, a command, or entering the circle cannot complete the lesson. Strongest-charge semantics remain unchanged.
- `guard_lesson_requested()`: pause UI requests replay. Flow owns eligibility and lifecycle.
- `guard_lesson_completed()` and `guard_lesson_dismissed()`: HUD coach reports verified use or voluntary dismissal. Flow persists completion only; dismissal lasts this run.

Save v10 adds `guard_lesson_done: bool`, default false for older saves. Equipment, chapter checkpoints, and other settings retain their existing migrations. Auto-show only in story chapter 1, stages 1-3/1-4 after intro, if unfinished and not dismissed. Replay is available during any story encounter with Bulldog. The lesson is non-modal, never pauses combat, and explicitly prioritizes avoiding danger over absorbing damage.

## Acceptance evidence

Test actual inside/outside boundaries, late subscribers, movement/range/cooldown guidance, real consumption versus misses/ultimates/expiry, pause, death, completion, v9 migration, optional dismissal/replay, and safe-area layout. Run regression and unchanged-policy chapter smoke checks. Capture actual Godot output, clearly label staged scenes. No rating, balance, human-usability, or native-device claim from automated tests alone.
