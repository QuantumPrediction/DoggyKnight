# Quality review and equipment progression audit

The owner requested a detailed rating of each part of Golden Knight, the gap to
9/10, and continued development. This integration batch recovers the 0.4.0 tree
from its verified bundle, adds repeatable offline developer audits, and fixes
intermediate equipment effect levels that previously charged currency without
changing their effect. Existing publication approval is retained; no merge,
store release or real payment is included.

`EquipmentRules.effect_levels` defines the existing level 1/3/6/9 anchors.
Intermediate effect multipliers interpolate between those anchors. Endpoint
strength, item prices, forging caps, drop odds and save version are unchanged.
Integer damage, healing and projectile count still have quantization thresholds;
the audit reports those limits separately. This is not evidence of human balance.

Developer tools may stage inventories, unlock the requested chapter, fix seeds,
skip dialogue and control the hero. The shipped gameplay does none of these.
Each audit process uses a separate user-data directory and does not send data.

The first matrix exposed incomplete RNG control. The bot now seeds enemy
initial decisions, player critical hits, loot, equipment rewards and minigames
in addition to flow/global RNG. The enemy override defaults to zero and does
not change normal gameplay; the flow equipment seed only applies when its
existing developer seed is nonzero. Repeated cases must be checked before
calling a comparison controlled. Cosmetic camp dialogue remains unseeded.

The observed low-contrast pause heading receives the existing dark ink color.
This is a readability fix, not a typography redesign or a new art feature.
