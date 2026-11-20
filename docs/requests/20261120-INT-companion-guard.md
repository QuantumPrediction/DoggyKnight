# 0.7.0: companion command and melee readiness

The owner's continuing quality-development request authorizes this integrated gameplay iteration across combat, core signals, data, input and UI. Preserve all recovered 0.4–0.6 history.

- A knight starts auto-attack windup only when a valid target's body is in actual weapon reach. Movement still cancels windup; real misses still spend cooldown. Damage, enemy health, waves and reach are unchanged.
- All three classes can press Q or the illustrated touch button to call Bedivere to a point 14 world units ahead. He runs there, never teleports, and holds a 32-unit circle for 2.8 seconds. A 1.2-second failed approach spends the command; 10-second cooldown starts on request.
- Inside an active circle, incoming damage is multiplied by 0.65 after existing reductions, rounded with minimum 1. This is an additional mitigation source, not an increase to the equipment guard cap. Leaving, companion daze, player down or stage completion ends protection.
- The first actually reduced hit, or physically intercepted projectile while the player is inside, readies one +25% normal attack for the existing 3-second synergy window. It shares the strongest-only charge with fire, wind and family-set bonuses. No charge refresh from further hits in the same cast; no ultimate amplification.
- EventBus: `companion_guard_requested`, `companion_guard_status_requested`, `companion_guard_state(state, cooldown_left, duration_left)`, `companion_counter_granted(bonus)`. HUD uses signals exclusively. No save migration: command timers are stage-local, reset with the existing stage checkpoint.
- New original GPT Image shield art is used in the actual HUD and world-space guard indicator. Provenance accompanies the asset.
- Validation separates the unchanged bot policy, a guarded policy and a more cautious movement policy; automation does not establish human fun or a numerical quality score.
- The first captain publishes `boss_intent_changed(enemy_id, intent, remaining)` from its actual attack/recovery state. The HUD explains sweep, throw, returning fork, rally and shout, and displays the real recovery countdown. It does not imply all other enemies are safe, add recovery time or predict the next move.
