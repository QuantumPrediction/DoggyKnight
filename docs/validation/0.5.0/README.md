# 0.5.0 validation

Engine: `4.7.2.stable.official.ed1daf0bf`. Runtime/test source:
`c56e9534ebb0a753e05949297e5bac4c915418c0`.

## Checks

- Recovered baseline equipment suite: 23 passed (`baseline_equipment.log`).
- New targeted equipment suite: 28 passed (`equipment_tests.log`). Includes
  three-class production/preview equivalence with training, no preview mutation,
  set loss, moving unique treasures, every-rank cadence and real melee/projectile
  cooldowns. The first draft of the cooldown test omitted an archer target; it was
  corrected to spawn a real enemy before checking a fired projectile.
- Final full suite after the final asset and version import: **831 tests, 0
  failed, 0 broken files, runner exit 0** (`full_regression.log`). The earlier
  preflight also passed 831. Structured results and file hashes are in
  `verification.json`.
- Production-function audit: 330 hero/item/level states, zero identical adjacent
  signatures (`equipment_audit.json`). Prior quality batch had nine.
- All 12 renderer cases keep the root and fixed actions within the safe rectangle
  with a positive scroll height (`screenshots/layout_checks.json`).
- Native Linux production UI operated with a fresh isolated save: title → armory
  → buy sword → equip → forge once → return. Coins 250 → 110 → 60; Lv.2 weapon;
  next forge disabled and reports 40 missing coins. `native_review.log` has no
  script errors. This is AI operation, not an unfamiliar human playtest.

## Combat smoke checks

Fixed seed 7; normal damage; zero training; existing class-specific bot; three-down
limit; staged loadouts. These runs do not represent naturally earned first-chapter
inventories, equal-cost builds, human completion rates or a balance study.

| Case | Result | Downs | Cleared stages | Combat seconds | Damage taken |
| --- | --- | ---: | ---: | ---: | ---: |
| Knight, common Lv.5 | down limit at 1-4 | 3 | 3 | 529.600 | 600 |
| Archer, epic Lv.9 | chapter complete | 0 | 6 | 346.733 | 52 |

Both produced reports, with no script errors or runtime `ERROR:` lines. The knight
case also reached the down limit at 1-4 in the previous controlled batch. Its
individual attempts changed; faster attacks alter event/RNG consumption, so this
is not a controlled estimate of the causal benefit. The failure is retained in
full, not omitted or relabelled as a pass. Do not increase global difficulty based
on these two cases.

The smoke manifests record the earlier git HEAD because the code was still
uncommitted when they started. All 542 source-file hashes in each manifest were
checked against the final implementation commit and match; retain the original
manifests unchanged.

## Screenshots

Actual Godot Compatibility/OpenGL/llvmpipe renders, not concept mockups. Twelve
screens: fresh loadout, common shop, purchase comparison, equipped slots, forge
comparison, confirmation, success, epic shop, chapter lock, 360×640 detail and
confirmation, 390×844 simulated-notch bow detail. Rich inventories/wallets are
staged by `tools/capture_armory.gd`; the fresh-start screenshots use the normal
250-coin default. The screenshot process does not read or write a player save.

The generated images' source and hashes are in the armory art manifest. Caption
all use as Linux renders with staged data; do not present as Windows/mobile
hardware testing or earned progression.

## Limits

The full suite retains pre-existing teardown and exit resource/RID warnings;
passing assertions are not a clean error-free log. No Windows or mobile device
playtest, new executable export, human listening/balance study, FPS benchmark,
store release, real payment or server-side economy is claimed. Numeric cadence
can be quantized by the physics step; integer healing/damage thresholds remain.

Reproduce:

```sh
GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64 TEST_TIMEOUT=900 tools/run_tests.sh
GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64 TEST_TIMEOUT=180 tools/run_tests.sh equipment
ART_CAPTURE_DIR=/absolute/output/path godot --path . --audio-driver Dummy --rendering-driver opengl3 --script res://tools/capture_armory.gd
```

Use a graphics display for captures and separate `XDG_DATA_HOME` directories for
manual testing. The test runner and balance runner isolate saves automatically.
