# R01/R02 integration: combat pressure and scene lifetime

The owner requested repeated implementation toward the R1 quality roadmap.
Continue from roadmap PR #15 head `f73213fbded6f346b004794307f47e227a48fcb2`;
the gameplay baseline is merged 0.9.1. Branch: `codex/combat-fairness-r01`.

- Extend read-only pressure observations to visible warnings, player movement,
  escape candidates and attack phases. Verify the old cautious-policy report
  against its retained baseline before using the new observer for attribution.
- Add a separately named, deterministic exit-aware policy based on visible enemy
  positions and warnings. Keep the original/cautious policies unchanged. Freeze
  this policy before comparisons; it is a coverage tool, not a human simulator.
- Register the first 48-case grid: six routes × seeds 7/19/31/43 × cautious/escape,
  common1 earth, no training, normal damage, fixed60/speed1, reactive guard,
  route-aware choices, max three downs, max1200 simulation seconds. Keep all
  failures. Changes to game rules require paired baseline/candidate evidence.
- Diagnose real scene enter/exit lifetime separately from full-suite leaks and
  the historical native crash. No successful run alone establishes a crash fix.
- Cross-directory integration may fix a demonstrated combat or lifetime defect
  with regression coverage. Do not change global HP, damage or economy to force
  bot completions. No new save/EventBus schema, payment/store activation or
  download package. The initial diagnostic work does not advance the version.
- Record commands, source fingerprints, failures and limitations in
  `docs/validation/r01/`, then publish a draft stacked on the roadmap work.

The daily continuation task is enabled for approximately 08:00 Hong Kong time
starting 2026-11-21. It resumes one bounded work package from the latest repository
checkpoint, retains evidence, and cannot self-certify player/device quality or
merge/publish stores without the relevant owner instruction.
