# 0.9.1 integration: companion shield motion

Baseline is draft PR #26 at `1577dc7c81e9c73e5ddea80c358ce2e91be77d65`. This slice changes only Bedivere's illustrated presentation. The existing `BulldogCompanion` state machine, physics, shield radius, reduction, counter bonus, damage, cooldown, targeting, input hit areas and enemy warnings remain authoritative and unchanged.

## Registered candidate

- Use one transparent four-cell painting with a shared baseline: raise on the first existing guard frames, brace during the existing guard state, block while the existing `_block_flash_left` is positive, and bash while the existing attack animation is active.
- The illustrated skin may read those existing presentation fields but must not create a timer, signal, collision, attack, damage or state transition.
- Keep the original `AnimatedSprite2D` frames as the clock. If the new painting is missing, the current party-sheet drawing remains the fallback.

## Fixed comparison

- Capture the production guard showcase at the same 540×960 composition and its existing 360×640 and 390×844 views. Add deterministic close frames for raise, brace, block and bash without moving the player, enemies, HUD or camera between baseline and candidate.
- Record selected atlas cell, original sprite animation, rally state, block-flash state, button rectangle, warning geometry, protection result and combat counters.
- Compare the complete existing guard tests and the fixed hero-motion event log. This candidate is presentational and must not alter either.

## Failure gates

Reject the candidate if any pose is clipped at alpha ≥32/255, lacks a distinct silhouette, changes baseline registration by more than two logical pixels, faces away from the threat, obscures the enemy warning more than the old drawing at the fixed camera, moves or shrinks a touch target, changes a combat event/counter, or fails any existing regression. A staged screenshot can establish geometry and state selection only; it cannot establish player comprehension or phone performance.

