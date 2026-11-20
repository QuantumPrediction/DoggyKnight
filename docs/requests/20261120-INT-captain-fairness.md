# 0.8.1 integration: readable melee and first captain fairness

Continue the owner's existing integration scope from 0.8.0 (`b0b711a`).

## Player problem and bounded change

The captain's sweep currently warns at the old position and then lunges before
checking damage. Its shared sector helper also invents a rear contact circle
and misses body overlap at the wedge's side. Rally checks capacity before
starting but can add three minions to three living summons despite a cap of four.

Reproduce these behaviors before changing production code. Commit the sweep's
actual clamped impact origin and direction when warning begins. Hit testing must
intersect the victim's body circle with that same sector, with no rear shortcut.
The same issue affects ordinary/elite scarecrows. Their windup must also stop
separation drift. Both use the actual drawn polygon for body-circle overlap;
other enemies and player attacks retain their existing collision contract.
Rally must show and create only the available slots, rechecking at release.

Damage, health, movement speed, tell/recovery times, gear, economy, bot inputs,
guard rules and saves are unchanged. This patch does not promise to eliminate
the seed-7 knight failure. No new art style: the ground shape is precise gameplay
geometry rendered by the existing telegraph, not an illustration.

## Evidence fixed before the change

- Full baseline and final regression; deterministic boundary/cap regressions.
- Read-only trace of seed-7 knight, ordinary Lv1 earth gear, original movement,
  reactive guard. Record synchronous damage call stacks and captain state without
  touching RNG, actor inputs, rewards or balance. Verify the ordinary bot result
  is unchanged by the observer.
- Matched before/after chapter 1: all three classes, seeds 7/19, original and
  cautious policies, reactive guard, common-Lv1 earth starter set; 12 cases each.
- Additional knight check: seeds 37/53, both policies, same conditions; 4 cases
  each. Do not tune combat numbers against those checks or discard failures.
- Actual rendered warning/recovery/summon captures, plus current Windows export
  and embedded pack checks. Native Windows/mobile and human play remain untested.

No new EventBus/save schema contract, real payments or store publication.

## Attribution before implementation

The read-only seed-7 trace exactly matches the original bot report (all fields).
Its two 1-4 failures total 291 damage: 209 from scarecrow swings (including
play-dead loss), 72 from projectiles and 10 from crow dives. There are no captain
sweep damage events. The captain issue is real but cannot explain those losses
alone. Scope therefore includes the same misleading tell in regular/elite
scarecrows. New checks cover both, plus interruption, boundary clamp, body-edge
overlap and preventing duplicate attack/summon resolution.
