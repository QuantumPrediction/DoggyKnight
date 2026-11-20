# Elemental equipment integration

Owner request: add earth, water, fire and wind to weapons and armor, grant a
bonus when all equipped elements match, and continue improving game quality.

- Full elemental set means the weapon AND armor slots, both occupied and same
  element. Treasures keep their existing family sets and are excluded from this
  two-piece condition. Mixed pieces keep each individual benefit.
- All 12 weapons/armor have a default affinity. Owned pieces may be re-engraved
  to any of the four elements for free in the armory, with explicit confirmation.
  Engraving belongs to the owned item and therefore affects any class sharing it.
- Element balance values and descriptions live in the catalog. They are flat
  additions independent of forging level, with one resonance per loadout; existing
  common Lv.5 / epic Lv.9 rules, currencies and rewards remain.
- Reuse actual defensive/loyalty/healing/counter/movement proc paths. No cosmetic
  stat claims, paid rerolls, elemental enemy weakness system or new damage-over-time
  loop. Cap aggregate guard/wave-heal/ultimate-heal to existing runtime maxima.
- Save v9 adds sanitized element choices to inventory and stage snapshots. Older
  equipment acquires catalog default affinities; progression/levels/currencies
  remain. New title/camp choices apply at the next stage; continue/retry retains
  the stage snapshot. Failed save transactions roll back engraving.
- UI shows affinity, per-piece benefits, matching bonus, preview gains/losses,
  shared-class impact and the combat snapshot's resonance. Generated rune atlas
  is integrated into real renders. Validate all classes, element combinations,
  legacy/save corruption, stage boundaries, combat procs and small safe areas.
- Keep the known public-push approval block; this request authorizes development
  but does not supply the direct publication confirmation requested last turn.
  Preserve a complete recovery checkpoint. No merge/store release/payment/export.
