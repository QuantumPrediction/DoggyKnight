# 0.6.0 elemental equipment verification

Date: 2026-11-19 (Hong Kong). Implementation commit: `3bd1d335bd72040f4b8a8a5f63d3b58ef451e138`. Engine: **4.7.2.stable.official.ed1daf0bf**. This is development evidence, not a 9/10 rating, human playtest or platform certification.

## Automated checks

| Check | Observed result | Evidence |
| --- | --- | --- |
| Final complete regression | 846 tests, 0 failed, 0 broken files; exit 0 | `full_regression.log` |
| Targeted equipment suite | 43 tests, 0 failed, 0 broken files; exit 0 | `equipment_tests.log` |
| Element pairs | Three classes × 16 pairs; both slots required, treasures excluded | `tests/equipment/test_elements.gd` |
| Production effects | Guard/cooldown, wave/ultimate healing, loyalty, counter consumption, movement charge, attack interval and speed | `tests/equipment/test_combat.gd` |
| Save/UI | v8 defaults, v9 round trip, continued/retried stage snapshots, next stage changes, shared armor, save failure rollback, confirmation binding, HUD snapshot | equipment checkpoint/UI tests |
| Real OpenGL renders | 14 screenshots; root and fixed actions inside safe rectangles in all cases | `screenshots/layout_checks.json`, `render.log` |
| Native UI operation | Fresh 250 coins → buy/equip weapon + armor → free water engraving → 10 coins, Lv.1, water resonance on live combat HUD; v9 on disk | `native_operation.json`, `native_review.log` |

Final command:

```bash
GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64 TEST_TIMEOUT=900 tools/run_tests.sh
```

Two failures in `full_regression_preflight.log` were old version-8 expectations in the save/chapter tests. Those explicit expectations now require version 9, while legacy-load behavior and new element persistence are tested separately. The final suite passed after this correction. The earlier `elements_iteration.log` also remains: a `#` comment in the TRES catalog prevented the newly appended resource fields from loading; it was corrected to the resource format's `;` comment syntax before the targeted pass and final regression.

The final full log still contains existing story/teardown null-object and freed-lambda errors, ObjectDB/resource/RID exit warnings. The targeted suite retains exit-resource warnings. Passing assertions are **not** a claim of an error-free log. No script parse errors remain in the final suite or the 12 smoke runs.

## Starter equipment chapter-one smoke

Each case purchases a class weapon (140 coins) and class armor (100) through the production transaction function from the normal 250-coin budget, equips them, then freely engraves both to the named element. Both items are Lv.1; there is no training, additional wallet grant, later gear buying or forging. This establishes affordable starting equipment, not a tested long-term economy.

Fixed 60 Hz, speed 1, normal damage, seed 7, existing class-specific bot policy and first offered trick. Stop at three downs, 1200 driver-loop seconds or 600 wall seconds. Raw reports/logs and the exact 543 runtime-source fingerprints are in `element_starters/`. All fingerprints match the committed implementation. The manifest's source HEAD is the pre-commit `913c150...` because the source was uncommitted at execution; the recorded content hashes, not that older HEAD alone, identify the tested source.

| Class | Earth | Water | Fire | Wind |
| --- | --- | --- | --- | --- |
| Knight | 3 stages cleared; stopped at 1-4; 3 downs | 6 stages; 1 down | 3 stages cleared; stopped at 1-4; 3 downs | 6 stages; 2 downs |
| Mage | 6 stages; 0 downs | 6 stages; 0 downs | 6 stages; 0 downs | 6 stages; 0 downs |
| Archer | 6 stages; 0 downs | 6 stages; 0 downs | 6 stages; 0 downs | 6 stages; 0 downs |

Ten of twelve cases completed. The two bounded knight failures are retained, not retried until a pass. Nine cases show only resource-release errors at exit; none reports a script error. The audit driver's exit 0 means collection completed and does not convert failed cases to successes.

One seed, different class policies, changing trick/RNG consumption and nonhuman behavior prevent class or element strength rankings. The knight failures can reflect approach policy, vigor carried between stages, encounter tuning or their combination. Repeated 1-4 difficulty warrants dedicated investigation; the new elements do not establish a melee-balance fix.

Reproduce:

```bash
python3 tools/run_balance_audit.py --godot /path/to/Godot_v4.7.2-stable_linux.x86_64 --out /tmp/element-starters-new --seeds 7 --heroes knight,mage,archer --gear common1 --elements earth,water,fire,wind --jobs 3
```

## Visual evidence and limits

Screenshots are actual Linux OpenGL compatibility renders, not concept mockups. The capture helper buys the affordable starter set through production rules but injects that profile for UI capture and uses a custom in-memory commit callback; it does not exercise disk persistence. The separate native operation used the normal save path and transaction flow in an isolated test user directory.

The 14 images include four choices, lost/gained stats and resonance, the mixed loadout, completed fire set, confirmation, 360×640 and simulated-notched 390×844 layouts. Native operation also checked water preview scrolling and the live HUD. Safe-area geometry does not prove every phone's readability or touch ergonomics. No Windows, mobile, controller, human audio, long-term retention or paid-transaction validation was performed. No new EXE was exported.

Public upload remains blocked by the previous automatic approval review, which did not accept historical/retrieved approval as current direct authorization. This turn performed no public write. A complete recovery bundle includes all unpublished changes after the public PR #11 base.
