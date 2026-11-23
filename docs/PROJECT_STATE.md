# Golden Knight — current project state

Updated: 2026-11-23 (Hong Kong). Version: **0.9.1 development source**.

## Current work — field chest silhouettes and hinged lids

[Draft #27](https://github.com/QuantumPrediction/DoggyKnight/pull/27), `codex/field-chest-art`, starts from draft #26 at `b413b36bd47e8cb614210d3d714ee5154be0d5bf`. Ordinary, elite and boss field chests now have individual shells, clasps and three successive opening drawings. The production sprite clock and proximity pickup drive the pictures. At fixed 60 Hz all 414 pickup records match the baseline locally and on Ubuntu, including one reward per tier. The candidate passed 972/972 tests. Ten pairs of Linux 360×640 captures differ only inside the chest sprite bounds. The pickup ring and hero still obscure the clasp at first contact, and confetti partly covers the boss crown at tick 94. [Animation, full screenshots and verification](validation/field-chests/README.md)

Next, observe the first tier misidentification and the opening moment on a physical phone. Target-player sessions remain at zero and provisional quality stays at 6–6.5/10. A separate fresh baseline import crashed before the tests began. The retry passed 970/970. Both full suites listed 33 ObjectDB instances and 24 resources at exit on this machine. The raw stack, binary fingerprint and missing ELF build ID are recorded alongside the evidence.

## Previous work — Bedivere shield motion and permanent native evidence

[Draft #26](https://github.com/QuantumPrediction/DoggyKnight/pull/26) on `codex/storybook-combat-motion` remains stacked on #25. This continuation preserves that branch and adds one presentation-only candidate. [Registered comparison](requests/20261123-INT-companion-shield-motion.md) · [Validation](validation/companion-shield-motion/README.md)

- GPT Image produced four registered Bedivere drawings: shield raise, ready brace, real block impact and existing shield bash. The illustrated skin only reads the companion's current animation fields. It does not start or extend any guard, timer, hit, counter, collision or signal. Missing art falls back to the existing party drawing.
- Four cells have distinct silhouettes, alpha gutters and a common two-pixel baseline. The new focused checks verify all four selections and that reading them leaves cooldown, duration, block and bash counters unchanged. The first test attempt used unsupported assertion helpers and is retained as one broken-file failure; the corrected motion suite passes 10/10.
- Complete regression passes **970/970**, including the existing guard, warning, touch, save and three-minute tests. The three heroes' 480-row fixed physics record remains byte-identical to #26 at `6eceb282…408d`. Existing shutdown warnings remain: 27 ObjectDB objects, 21 resources and the listed RIDs.
- Both native-image artifacts were recovered before expiry and verified. Five final images and all ten before/after PNGs are now permanent project files under [hero-motion](validation/hero-motion/README.md), with the original archive and per-image hashes preserved.
- This host has no X11, Wayland or Xvfb, so there is no new native 360×640 candidate capture or phone frame-time evidence. Physical Windows, phone and controller input, listening, retention and human interpretation remain open. Target-player sessions total zero. Provisional quality stays at 6–6.5/10.

Next, use a matching native display to capture the four formal guard states at the fixed camera and the existing 360×640 composition. Reject any state that hides more of the enemy warning. Then run the existing 6–8-person uncoached trial when real participants are available; do not infer readability from the staged art.

## Previous work — three heroes in motion

[Draft #26](https://github.com/QuantumPrediction/DoggyKnight/pull/26) on `codex/storybook-combat-motion` stacks on [#25](https://github.com/QuantumPrediction/DoggyKnight/pull/25) at `6254f092a6c18931cb884c5f6d16d0aed713d262`. Ubuntu tested `7429b3634c19ff04dea5cbf9c461776d93dc73fb`. The corresponding game tree without the temporary verification workflow is `b0007fe639d0007225c25f127d84542d1404a099`. [Motion demo](validation/hero-motion/hero-demo.gif) · [Five native game screenshots](https://github.com/QuantumPrediction/DoggyKnight/actions/runs/45067182880/artifacts/14772175663) · [Illustrations, tests and source fingerprints](validation/hero-motion/README.md)

- Six GPT Image atlases drive 36 individual character drawings, twelve friendly effect frames, three weapons, three treasures and three in-world objects. Each hero has four running and four ordinary attack poses. The held windup changes to the release drawing at the actual swing or shot. Friendly slashes, flying bolts and hits animate on existing nodes. The equipment workshop uses the named gear illustrations.
- An Ubuntu run with the public game exposed an overflowing roll label. The bundled font lacked 緒. Changing the message to 起步可翻滾 kept all five native screenshot cases inside their existing panel and safe area, up from one of five. The complete Ubuntu test suite passed 968/968, with motion 8/8 and warnings 9/9. Three roles produce 480 byte-identical combat event rows. Initial failures and shutdown warnings are preserved.
- Cautious seed 19 differs across hosts. On the original workstation both archers went down three times. When #25 and #26 run on the same Ubuntu host, both Marksmen go down three times and both Outriders clear the chapter after two downs. Both pairs of reports and both entry saves match byte for byte on that host. Historical parity failed; its cause is unresolved.
- Physical Windows, phone and controller input, device frame times, listening, retention and human interpretation remain open. Target-player sessions total zero. Provisional quality stays at 6–6.5/10.

The inspected native PNGs have now been archived directly in the project by the continuation above. Keep the workflow read-only. The companion candidate still needs a fixed native render and real-phone crowd observation. [Uncoached trial entry](validation/scene-lifetime/archer-trial.md)

## Previous work — keyboard choices in chapter one

[Draft #25](https://github.com/QuantumPrediction/DoggyKnight/pull/25) on `codex/keyboard-choice-cards` stacks on [draft #24](https://github.com/QuantumPrediction/DoggyKnight/pull/24) at `8859306a2c29769b02c36101d2b6104f4e91358c`. [Public implementation](https://github.com/QuantumPrediction/DoggyKnight/commit/9b9e02e37e795fd8e8839e303484e8f604643307) and the tested local commit `b255592dff62e0c787417dcd9334a3921f9bc482` share tree `71cd5438cc9ba363a1d99cf50ad696689fe045a2`.

- Event, route and upgrade cards now take keyboard focus. The arrow keys or Tab cycle through the offer. Enter or Space selects a card. Holding confirm as cards arrive cannot make a late choice. The focus outline stays inside the card, and clicking or tapping another card selects the one touched.
- On #24, five of seven new input checks failed. Enter activated a background button twice and the real chapter flow stayed paused without a route. All seven now pass, including taking Outrider and Roll, applying a chosen upgrade once, and returning to combat without triggering an ultimate. The full Godot run passed 959/959. The original shutdown warnings remain. [Registered comparisons](requests/20261123-INT-choice-card-input.md) · [Evidence and replay instructions](validation/choice-card-input/README.md)
- Both cautious seed-19 archer reports and their 1-4 saves still match the archives byte for byte, including three downs per route. Gamepad and touch coverage used engine input events. This round produced no new native capture. Total target-player sessions are zero and provisional quality remains 6–6.5/10.

Next, verify the entire keyboard and controller path from a fresh title screen through class selection, route, first upgrade and resumed battle on Windows. Check first-tap behavior on a phone. Until those devices are available, the same path can be exercised through normal GUI events to locate the first remaining break. Keep the separate [two-route uncoached trial](validation/scene-lifetime/archer-trial.md) available for 6–8 participants. Guard-warning occlusion, the historical native crash, long sessions, audio, retention and market validation remain open.

## Previous work — both archer routes in the uncoached 1-4 trial

[Draft #24](https://github.com/QuantumPrediction/DoggyKnight/pull/24) on `codex/archer-guard-trial-pair` is based on [draft #23](https://github.com/QuantumPrediction/DoggyKnight/pull/23) at `a6595b21a970c1f7b7586cb7d8e7e461863b7959`. Public implementation `9b67f1b365e98031bc96bc042e7875ae8b59f6f8` has the tested tree `7d088aebe14c1cd3bfe79296e4f5a563f14ebf20`. [Playable entries and observer sheet](validation/scene-lifetime/archer-trial.md) · [Validation](validation/archer-guard-trial/README.md)

- Players can now start 1-4 as the Outrider or the Marksman with normal dialogue and controls. Each route loads its own first committed save after clearing 1-3. The Outrider arrives with 89 vigor and Roll III. The Marksman has 97 vigor and its existing build. Both full seed-19 reports match their archives byte for byte, including all six downs. Each launch uses a fresh temporary profile.
- The observer sheet distinguishes calling the companion, earning a charge, using a counter near a warning, seeing the success card, and what the player does next. Keep every first session and record unknown or absent exposure. Balance versions within the same route and keep a voluntary retry separate.
- Godot passed 952/952 tests on the implementation tree. The same three headless trial checks passed on #22 and this branch. All four pre-existing synthetic player files survived two simultaneous launches byte for byte. The nine existing contour-tool checks also passed.
- The rejected 0.60 backplates remain withdrawn. The known guard-button and tactics-panel intersections still need human observation. Target-player sessions total zero. The native crash, cleanup warnings, long sessions, Windows, mobile, controller, listening, retention and market evidence remain open. Provisional quality remains 6–6.5/10.

Next, use the two frozen entries with 6–8 uncoached participants when available. Record the first action and the participant's own explanation after play. Use recurring, observable confusion to select one presentation or encounter change.

## Previous work — readable choices and reliable progress

Continue `codex/guard-hud-contour` and [draft PR #23](https://github.com/QuantumPrediction/DoggyKnight/pull/23), based on merged #22. Source commit `c79919cdb39636c6b3a619f31caf9f909b89634e` has complete source tree `59bde2a97f460c125745ef96eddb3edb3de8e9a5`. Subsequent commits add validation and handoff only. Recheck the live head before continuing; do not merge without owner authorization.

- Story and route cards now keep small icons within their slots, measure titles with the correct CJK font, separate titles from effect descriptions, use dark ink on parchment and wrap numbers sensibly. All eight actual story events, three class routes and three encounters are covered.
- Save replacement fallback keeps a complete backup before deleting the primary. Failed promotion or restoration can recover the committed checkpoint; uncommitted temporary data is not promoted. Desktop pause focuses Resume on opening/reopening, including an actual accept-input regression. Save schema, event costs and combat balance remain unchanged.
- Final recovered-source checks and complete output are in [detail-recovery](validation/detail-recovery/README.md). Ten disk-failure tests, one pause-input test and three card-content/contrast tests were added. Recovered-source full regression passed 950/950 with no broken files; the existing nine comparison-tool controls also passed. Existing shutdown warnings remain.
- Before an unexpected execution reset, native Linux checks observed 19 event layouts, five warning layouts and ten guard/pause layouts passing. The original captures and full local artifacts were lost; the readme labels these as observed history, not retained evidence. Six recovered source/test/showcase blobs exactly match the pre-reset tool hashes. The complete suite was rerun after recovery; use its retained result, not an interrupted earlier run.
- The single 0.60-alpha HUD candidate failed three of four critical frame gates and was withdrawn. Both HUD production files remain identical to the public baseline. The original two down-limit outcomes, native crash/cleanup issues, human playability, long sessions and actual Windows/mobile/controller/audio validation remain open. No new download or store/payment activation; provisional overall quality remains 6–6.5/10.

Next: observe the first-chapter guard-to-counter decision without coaching, then implement one encounter/readability improvement supported by that observation. Re-capture native evidence when a functioning desktop is available; do not continue adding diagnostics as a substitute for gameplay improvement. [Scope](requests/20261122-INT-detail-recovery.md) · [Validation and recovery limits](validation/detail-recovery/README.md)

## Previous work — chapter 1-4 guard-success card

The change originates on `codex/guard-success-toast` from the verified merge of [PR #21](https://github.com/QuantumPrediction/DoggyKnight/pull/21), `8d21d1bc56f73741e9fa9b003715095395421877`. Recheck the live default and open PRs before continuing. [Registered comparison](requests/20261121-INT-guard-success-toast.md) · [Evidence](validation/guard-success-toast/README.md)

- Nearby attack warnings take priority over the optional success card. It waits for a short clear window without delaying the original guard lesson completion or save. Combat controls keep their previous positions during the warning and an active joystick drag. The hidden card's own close button no longer occupies touch space; the tactical danger readout stays unchanged.
- On two 360×640 native Linux replays, both complete reports and traces matched exactly. Marksman 35/35 renders were byte-identical. In Outrider, the original and candidate both showed the card before the warning; only the lower card footprint changed on the 33 sampled draws from the warning onset. The guard button did not move, so its overlap with the warning remains.
- The guard and flow checks (21), warning/readout checks (8), EventBus contract checks (2), and the full 936-test regression passed locally. Existing shutdown warnings remain.
- No attack, balance, enemy, AI or save format change; no new download. Do not infer better human comprehension, Windows/mobile/input-device qualification, or a native crash fix. Next, observe how unfamiliar players read actual first-chapter combat without coaching and prototype the first deliberate guard-to-counter choice before widening scope.

## Previous diagnostic — chapter 1-4 rendered companion warnings

The capture evidence originates on work branch `codex/scarecrow-render-cues` at the verified merge of [PR #20](https://github.com/QuantumPrediction/DoggyKnight/pull/20), `d81716df4c7d81fd49d368c6d42262fddc6adf93`. Recheck the live default and in-progress PRs before continuing. [Registered scope](requests/20261121-INT-scarecrow-render-cues.md) · [Rendered results](validation/scarecrow-render-cues/README.md)

- On a real Linux OpenGL window, 35 completed 360×640 viewport draws per case matched the two archived control reports and tick traces byte for byte. Parts of the selected sectors appeared at their first eligible physics ticks: Marksman `20980.1` at 4961 and Outrider `17197.2` at 366. This measures produced pixels, not screen latency or human perception.
- The selected outline intersects different HUD layers in the two cases. The tactical readout covers part of the Marksman outline; the shifted companion-guard button overlaps much of the Outrider outline. Actors also cover parts of the cue. Both HUDs show the warning count transition from one to two, not which way to dodge. The two controls still reach the three-down limit; no gameplay or production UI changed and no new download was built.
- All 8 focused checks and the full 931-test suite passed. Existing object, resource and renderer cleanup warnings remain.
- Next: register a presentation-only comparison that defers the noncritical guard-success toast during nearby attacks without moving touch targets or hiding tactical warnings. Compare conflict and no-conflict views, and measure visible cue and escape space before claiming improvement. Uncoached players, the native crash, actual Windows/mobile/audio/controller and long-session checks remain separate gates. Provisional project quality remains 6–6.5/10.

## Previous diagnostic — chapter 1-4 companion-directed swing controls

The evidence originated on work branch `codex/companion-swing-lanes` and was merged in [PR #20](https://github.com/QuantumPrediction/DoggyKnight/pull/20) at `d81716df4c7d81fd49d368c6d42262fddc6adf93`, from the verified merge of #19. No download was built. [Registered scope](requests/20261121-INT-companion-swing-lanes.md) · [Replay evidence](validation/companion-swing-lanes/README.md)

- Two predeclared, previously untested ally-directed swings had four stop and seven lateral interventions with no damage, roll or immunity; one late lateral move kept the original 5 damage. The two complete original chapter reports and their per-tick streams matched #19 exactly. Both cautious runs still reached the three-down limit.
- All 23 outside-at-start hits were aligned with the last entry, actual input and other production warnings. The selected attacks were eligible to draw on their first physics tick, but no actual rendered frame was measured. No production timing, damage, AI, encounter, UI, assets or save changes.
- The actual native-window follow-up is recorded above. Uncoached player observations remain at zero; crash attribution and target platform/audio/long-session checks are separate.

## Previous implementation — chapter 1-4 scarecrow escape windows

On 2026-11-21 the default branch `claude/sleepy-hawking-8cvkvl` contained merged PRs #15–18, at `b05224258e0bdc70cfde7d0cb874a6b36d7f4617`. This round branches directly from that merge. [Registered candidate](requests/20261121-INT-scarecrow-window.md) · [Measurements, failures and replay commands](validation/scarecrow-window/README.md)

Published as [draft PR #19](https://github.com/QuantumPrediction/DoggyKnight/pull/19), then merged into the default branch at `7d63fffd4ca455837899679ca4b125b030f1f4b3`. Its complete merged tree `df6caa02e6bcc3c71123612c0363439b6ef4ffa9` equals the reviewed public head. Public implementation `562e6f622b135abd099dcbda3d1fdc4c48717f2b` has complete tree `6800b3cf03042ac87da4be675714f8983b6a5a1b`; its next commit only records the publication handoff.

- A passive probe follows the game's damage-warning filter and records every physics tick of each ordinary scarecrow warning, including paused frames, moving enemies, player velocity, roll availability, bounds and the exact pre-damage sector. All four original seed-19 chapter reports and their 1-4 damage-source tallies were reproduced. The two cautious down-limit failures remain.
- The first ordinary hits in both cautious routes came from swings aimed at the companion while the archer still stood outside the sector at cue onset. For the first directly targeted, initially covered nonimmune hit on each route, radial walking last succeeded after 25/31 ticks for marksman and 17/31 for outrider. Every later tick in that direction took the original damage. All 95 interventions and their failures are archived. The registered wind-up extension was not warranted; ordinary scarecrow timing and damage remain at the frozen settings.
- The eight focused tests and the complete 931-test suite passed. Target-player trials still total zero. Overall provisional quality remains 6–6.5/10. The next engineering pass can align the 23 outside-at-start hits with the last entry into a sector, input changes and simultaneous threats. The uncoached 1-4 session can then test whether players recognise those overlapping sectors. The native crash, device, controller, listening, retention and independent target-quality review gates remain open. [Existing playtest scenario](validation/scene-lifetime/archer-trial.md) · [24-part rubric](QUALITY_9_ROADMAP_ZH.md)

## Previous implementation — battle resource lifetime and archer 1-4

Work continues on `codex/scene-resource-lifetime` from PR #17 head `70dc412ab8e1ac330e7ecfa57cd1581ddba06f62`. The previous releases through PR #14 are merged. The current stack starts at #15. [Contract](requests/20261120-INT-scene-resource-lifetime.md) · [Measured results and reproduction](validation/scene-lifetime/README.md)

Published as [draft PR #18](https://github.com/QuantumPrediction/DoggyKnight/pull/18) on #17. Public implementation `f6e29b71fca641af2bcc862b2f90655d54615b6d` and locally tested `a6f9df089f2d54533997160c77f73fc9edc0a8f7` have the identical complete tree `2959b848d4f0826e98614a08f399c95bed40abc6`. Resume the latest #18 head, including the subsequent documentation update.

- Pause volume changes now respect a requested music stop. The two layers are released after the fade, silence or the end of a short cue. After playing all six chapters' field and boss tracks and returning to title, 0/24 chapter audio assets remain loaded, down from 24/24. Repeated synchronous track loads are slower on this host. Device frame time and listening tests remain open.
- Combat particle scenes and animation frames belong to their arena and can be reused until it exits. Three real visits removed all 21 remaining combat-effect asset paths from the verbose exit list. In 100 real combat visits on each build, every visit reached combat and left no player, enemy or orphan. Exit resource messages fell from 56 to 35. Title-only startup and exit still intermittently report two Ogg resources.
- The 930-test suite passed. Eight archer reports match #17 byte for byte. Both cautious seed-19 cases still reach the down limit on 1-4. The [playable observation scenario](validation/scene-lifetime/archer-trial.md) starts at a captured level-6 marksman checkpoint. The native Linux 360×640 input / pause / title path was exercised. Target-player observations so far total zero.
- Four supplementary observed runs reproduce the seed-19 reports. Ordinary scarecrow swings account for 91 of 101 hits and 629 of 721 damage across the six cautious failures. [All four traces](validation/scene-lifetime/trial-traces.json)
- Next, trace the last feasible exit before these ordinary swings and compare one encounter change if the trace supports it. Run the six-to-eight-player uncoached trial when participants are available. Retain the native-crash record, remaining object/RID warnings, the three two-hour runs and actual Windows/mobile tests as open items. Overall provisional quality is 6–6.5/10. [24-part rubric](QUALITY_9_ROADMAP_ZH.md#9-每一部分如何到達目標)

## Previous implementation — R03a warning priority

Current work is `codex/combat-timing-r03`, based on public PR #16 head
`3367a183599b2e1ecbb5efebec341cb7879f3965`; preserve the full #15 → #16 stack.
The owner asked to continue product work within the authorized enhancement and
public draft workflow. [Contract](requests/20261120-INT-warning-priority.md) and
[evidence](validation/r03a/README.md) describe this bounded information/UI change.

**Published as [draft PR #17](https://github.com/QuantumPrediction/DoggyKnight/pull/17), stacked on #16; not merged.**
Public implementation `9282f88a367b0268f4ad67f092109304360d56d5` and tested local
`4de053fa7efeda7c7fa6ddcb1cd80a48ea4cc77d` share complete tree
`5e536bbe2096560500d07b83121e1b9cf319b049`. [Publication mapping](validation/r03a/publication.json)
records all ten image blob hashes. Subsequent handoff updates only documentation.
Resume the latest public PR #17 head, preserving any newer local work.

- Overlapping visible enemy attack warnings now outrank the ready/moving title:
  tracking aim, committed warning or multiple warnings, with words and a steady
  triangle. Focus/roll clocks remain truthful. Ten arrival/summon sites now use
  an explicit non-attack marker; appearance and game rules are unchanged.
- The first five real renders caught a pre-existing lower-row overflow missed
  by width-only checks. Apply the compact font before sizing the row; all text
  now stays inside the same 78×42 panel. All five first renders are retained,
  alongside five final captures at standard, small and simulated-notch sizes.
- Six new warning regressions failed before implementation and passed after;
  a seventh layout regression failed before its fix and now passes. Final full regression: 922 tests, zero failed/broken, exit 0; the same
  27 ObjectDB / 21 resources plus RID shutdown messages remain. First-run 921 passes
  did not establish correct vertical layout; that evidence is kept explicitly.
- All eight final archer reports are byte-identical to PR #16 post-fix anchors,
  including both cautious seed19 failures. Neither bot, combat tuning nor save
  schema changed. This establishes anchor invariance, not improved balance,
  human comprehension or fun. The final capture run exits 0 but retains
  43 ObjectDB / 19 resource and GL texture/font RID shutdown messages.
- Draft PR #17 is published and not merged. No download build
  or store/payment activation. R02 crash/cleanup, R03/P1, broad mechanical
  grids, long sessions, actual hardware and target-player gates remain open.
  Overall provisional quality remains 6–6.5/10.
- Next bounded engineering step: isolate retained resource ownership using
  real flow transitions and verbose shutdown types, preserving the original
  crash and failures. Prepare an uncoached archer 1-4 observation scenario for
  real players without treating staged captures/bots as their feedback.

The R01/R02 and earlier sections below are historical checkpoints; resume the
latest current branch/publication above, not an older stated head.

## Previous implementation — R01/R02

The owner requested repeated development toward the quality goal. Current
work is `codex/combat-fairness-r01`, based on roadmap PR #15 public head
`f73213fbded6f346b004794307f47e227a48fcb2`; it retains the complete roadmap.
[Contract](requests/20261120-INT-pressure-lifetime.md) and
[evidence](validation/r01/README.md) define this bounded iteration.

**Published as [draft PR #16](https://github.com/QuantumPrediction/DoggyKnight/pull/16),
stacked on #15; not merged.** Public implementation commit
`b959d6569c2394a99d7d9776336af148800e2c6e` and tested local commit
`129f11838514a34aa6cd1b972044063b4cbf2509` share the complete tree
`772179eaa1018da0fc9f9ea29e26ce25c24a11aa`. The owner directly answered
"Yes, accept all request for the game enhancement" to the explicit R01/R02 public
code/tests/docs/validation and draft-PR approval request on 2026-11-20. The same
publication path then succeeded. Earlier automatic approval rejections are
history, not a current blocker; [publication record](validation/r01/publication.json)
preserves them. Subsequent handoff changes only documentation. All 627 current
source hashes, two regression-test hashes and the final test-log hash still match;
the unchanged gameplay suite was not rerun for publication. Resume the latest
public PR #16 head, preserving any newer local work, rather than default or #15 alone.

- Fixed a demonstrated flow-exit defect: the three guard-lesson callbacks now
  disconnect on exit, so an old flow cannot change flags or overwrite its old
  checkpoint. The two new regression cases fail before the fix; all six guard
  flow cases pass afterward. This does not explain/fix the historical native crash.
- Added read-only warning/position/input snapshots and a separate fixed escape
  policy. The observer exactly reproduces the old marksman seed19 report; all12
  old cautious reports are unchanged. The48-case pilot gives cautious22/24,
  17 downs versus escape24/24,0 downs under the same game rules. Keep both archer
  seed19 failures; bot policy gains are not gameplay improvements or human ratings.
- Thirty real flow/scene churn cycles leave no players, enemies or orphan nodes;
  warmed resource/node counts are stable. Shutdown resource/RID warnings and the
  old thread-notification crash remain unresolved. This is not a long-session or
  Windows/mobile qualification.
- Full regression: 915 tests, zero failed/broken, exit0. All eight post-fix
  archer reports exactly match their pilot reports, including the two retained
  cautious seed19 failures. Shutdown still reports 27 ObjectDB/21 resources
  plus RIDs; this is local validation, not a GitHub CI pass. No new Windows
  package, image, save schema, balance change or store/payment activation.
- Daily continuation is enabled from 2026-11-21 at approximately08:00 Hong Kong.
  It resumes the latest bounded work package, keeps evidence and permitted draft PRs, and
  stops instead of repeatedly reporting a complete external-validation block.
  It cannot self-certify9/10, automatically merge or activate stores/payments.

## Roadmap foundation — PR #15

The owner requested a robust plan to reach 9/10 on 2026-11-20. The documentation-only branch `codex/quality9-roadmap` starts from live default head `e98d416e60781bf479d4a6df413127758bceaf10`. [The R1 quality roadmap](QUALITY_9_ROADMAP_ZH.md) defines seven gated phases, a first-chapter experience, all 24 quality areas, player/device evidence, failure actions and the next five work packages. These are proposed targets, not completed features or improved scores. No game behavior, balance, assets or save schema changes in this planning work.

Published as [draft PR #15](https://github.com/QuantumPrediction/DoggyKnight/pull/15), not merged. Initial public commit `38a4b0d07b8bc5be820094b00a7a50e4bf7c72eb` and local `d5da0cb58af62ee43e5f7a7f3f68866d9c0acfa5` share tree `103a34bfc8f1663a224e348de355053a06603954`; the subsequent handoff only records publication. All local links in the five changed documents and all 731 tested source fingerprints were checked. No gameplay tests were rerun for this documentation-only change.

R1 prioritized R01 (archer 1-4 pressure attribution and a second fixed positioning policy) and R02 (native crash/resource lifetime diagnosis); current results are above. Validate combat changes before adding new spatial/objective prototypes. Windows is the first complete playtest target while retaining mobile controls; each platform needs its own hardware evidence. Keep current implementation branches and their publication status in view before starting another branch; the last merged game remains 0.9.1.

## Source and publication

- Repository: https://github.com/QuantumPrediction/DoggyKnight
- **Last merged game is 0.9.1 on default branch `claude/sleepy-hawking-8cvkvl`; current follow-up work is identified above.** The owner explicitly requested “please merge and analysis what's the ranking in every part” on 2026-11-20. [PR #14](https://github.com/QuantumPrediction/DoggyKnight/pull/14) is confirmed closed/merged at `ddd517bb9b91486488717bea6fdf21eb53c3bdf2`; its complete tree `7abbc78693b6c3287509a1053702653f1a0ca8df` equals the tested/documented PR head `b653742c6209fcf365bcdf8e6e7ee72e96503ce7`, including all ten PNGs. Preserve the newer stacked work when continuing; do not restart from default alone.
- The final head had zero check runs, zero commit statuses and no review/comment entries. Its 731 tested source fingerprints remain unchanged and the existing final log has 910 passes; no GitHub CI pass is claimed. No game test was rerun for this tree-identical merge. Known archer and native-crash concerns remain open despite the owner-approved integration.
- Screenshot publication block was resolved before this merge: the owner directly approved all ten original 0.9.1 PNGs for public upload. Screenshot commit `d54e8cd9ae81c0c4a689bd8465fca4034c632ce0` matched local `648f223`; hashes and public paths were verified. Earlier rejection/text-only notes are historical. See [publication mapping](validation/0.9.1/publication.json) and [screenshot index](validation/0.9.1/captures/README.md).
- Updated [quality review](GOLDEN_KNIGHT_QUALITY_REVIEW_ZH.md): overall provisional 6–6.5/10, a recognizable complete prototype/early test build. Stronger areas are identity, equipment/build systems and continuation; encounter variety, economy, balance, animation and target-device reliability still constrain the overall experience. Scores are design judgments, not player ratings or market ranks.
- On 2026-11-20 the owner explicitly requested “PLEASE MERGE” for the published 0.8.1/0.9.0 work. Its required dependency chain #9 → #10 → #11 → #12 → #13 was merged in that order. Each successor was retargeted to the default branch; merge commits preserve the implementation history.
- All five PRs are confirmed closed and merged. The final integration commit is `08e2ef4ef799a8e6df9876ba8f42d0439dc4fbd5`. Its complete Git tree `77ad0187f5c2459a27f7b659d5222b9cdea1ec32` is identical to PR #13 head `d7cafb5e4a58b813121e26a89d989b7499bc2e0e` (3,545 entries compared by path, mode, type and object SHA). The subsequent handoff commit changes only this file and `docs/status/LINE_INT.md`.

| Merged PR | Merge commit |
| --- | --- |
| [#9](https://github.com/QuantumPrediction/DoggyKnight/pull/9) | `bd7c814154e9a6f7292bcf01dfac8e000b8a1843` |
| [#10](https://github.com/QuantumPrediction/DoggyKnight/pull/10) | `3ac0a19553625e8c1cdc307ed1ccb61f670371cd` |
| [#11](https://github.com/QuantumPrediction/DoggyKnight/pull/11) | `b77f8b6a0a22c4be92c2e8d0a88659c516c4bd77` |
| [#12](https://github.com/QuantumPrediction/DoggyKnight/pull/12) | `5097b6dce854c3fccb991084ac84839bf241ac94` |
| [#13](https://github.com/QuantumPrediction/DoggyKnight/pull/13) | `08e2ef4ef799a8e6df9876ba8f42d0439dc4fbd5` |

- Historical snapshot mapping is preserved: public 0.8.1 `34e3ca95f058ad45707ef69510771ac08f16e127` and recovered local `84e10a4a692f004d502a506f1b1736dd79bcafbc` share tree `d860984cc31e68aefe9f2b22b19b1fe6a492263c`; local 0.9 implementation `563665e5f4f64fe4f0cd4c494014ab5ebd944cf4` and public `0872941e698b53a6ac60c857eb48443551eac3cb` share tree `bb0757c48e950446c9196d2fe644c5ca335f8d14`. Different commit IDs reflect the recovered/public parent chains.
- During the earlier merge-only operation, GitHub reported no statuses, PR workflow runs, reviews or review threads on the five original heads, and zero check runs on the final source head. Its existing 896-test log was inspected without rerunning an unchanged tree. The new 0.9.1 evidence below comes from fresh local runs, not GitHub CI.
- Earlier publication blocks and “not merged” notes in dated reports are historical. This merge approval covers this completed stack; it is not blanket approval for future merges or store/payment activation.

## Implemented behavior

0.9.1 adds a touch-transparent combat readout for actual class attack state, archer focus and learned roll protection/cooldown. Snapshots use the live player's clocks; pauses do not advance them and detached actors cannot overwrite the new HUD. Archer enemy tracking and locked aim use different shapes. Aiming origins cannot drift under crowd separation, and cancelled/duplicate releases cannot fire arrows. SignalWatcher and parameterized story-test callbacks now handle emitter lifetime correctly. Save v11 and balance numbers are unchanged. See [contract](requests/20261120-INT-combat-readability.md) and [validation](validation/0.9.1/README.md).

The recovered game has three classes, six chapters, 36 stages, four companions, 18 permanent items, common Lv5 / epic Lv9 caps, forging, boss pity and specified coin/gem purchases, illustrated armory comparisons, four-element engraving/resonance, stage checkpoints, Q/touch Bedivere guard and optional first-chapter guard lessons. Real payments remain disabled. 0.8.1 committed melee warnings use the actual impact geometry; crowd separation cannot move a committed soldier; captain summons respect the four-minion cap; cancelled/duplicate attacks and hit-triggered equipment control preserve recovery correctly.

0.9.0 replaces the existing first-chapter 1-1 mid-wave event with two routes per class: knight bulwark/vanguard, mage spellweaver/mistwalker, archer marksman/outrider. Each grants one existing starter trick and visible stat tradeoffs. Later upgrade offers include one legal related option when absent; evolutions retain priority and other choices remain. An unrouted run retains original offer/RNG behavior. No extra event pause was added.

First-chapter 1-2 trades recovery against snacks/current vigor, 1-3 trades a future basic-trick bonus against an immediate choice and damage risk, and 1-5 trades defense/mobility against reach/vulnerability. Remaining events, later chapters, endless and custom tables keep their existing behavior. Existing generated artwork is reused. Event cards now fit the larger descriptions and properly constrain portrait/icon sizes; upgrade UI displays the route and related choices.

Save **v11** adds a sanitized route in the chapter's safe-point data. v10 checkpoints default to no route and retain their existing build. Stage retry restores the previous route/skills, banked continuation preserves them, and new runs clear the route. Rebuilds do not compound modifiers. See [exact rules](BUILD_ROUTES_ZH.md) and [integration contract](requests/20261120-INT-build-routes.md).

## Current evidence and limits

- Final full regression: **910 tests, zero failed, zero broken files, exit 0**. Fourteen new tests cover real focus/roll/range/hitstop, pause/lifetime/layout, committed arrows and signal teardown. The freed-lambda/null-signal errors reproduced before correction are absent. Existing resource/RID warnings remain: 33 ObjectDB instances and 24 resources at full-suite exit.
- New matched 0.9.0/0.9.1 grids: **11/12 → 10/12 complete; 5 → 10 downs**. Same six routes, seeds7/19, normal damage, common1 earth, fixed60/speed1 and unchanged cautious/reactive route-aware bot. Marksman seed19 now reaches three downs at1-4; outrider seed19 still fails and outrider seed7 has two downs. This remains a material bot regression and a priority for follow-up, not improved balance.
- Read-only pressure follow-up reproduces both marksman seed19 reports exactly. Baseline clears with94 damage (71 melee/23 projectiles); candidate fails across three attempts with386 (324 ordinary melee/26 captain sweep/30 projectiles/6 crow). Candidate's first failure takes133. First three stages match. Investigate mixed attack pressure and archer positioning at1-4 before adjusting numerical balance.
- Historical native thread/Node notification signal11 remains unexplained. Both new grids and pressure follow-ups run without native crash, but successful repeats do not establish a fix. Original log and six earlier successful repeats remain in [0.9.0 evidence](validation/0.9.0/README.md).
- Five final staged OpenGL llvmpipe captures cover540×960,360×640 and390×844 simulated notch. Safe bounds/text fit pass; early capture errors/overlap are retained. Native Linux operator smoke confirms new-run archer selection, dialogue skip, movement, focus buildup/x1.35, automatic fire/recovery and keyboard/on-screen pause/resume. Not a human comprehension study, full clear, Windows/mobile/touch/controller test or audible music review; audio uses Dummy.
- New logs, paired reports, traces, screenshots and fingerprints: [validation/0.9.1](validation/0.9.1/README.md). Earlier evidence remains in its version directories. No seed replacement or numerical tuning to force passes.
- **No new Windows export or download package this turn.** The previously delivered Windows ZIP remains 0.8.1. Its matching-template pack checks passed previously; native Windows execution remains untested.

## Owner preference and next work

Keep replies brief. Do not proactively create/upload Windows ZIPs, standalone progress reports or recovery archives unless requested. Keep code, assets, documents, test records and screenshots in the authorized GitHub workflow. Publication and the existing #9–#14 merges are explicitly approved and complete; do not ask again for those completed actions. Future work can use draft PRs. This approval does not activate payments or stores.

Follow the [R1 roadmap](QUALITY_9_ROADMAP_ZH.md) for staged deliverables and acceptance criteria. Its phases are planned; the completed evidence remains listed above.

1. Continue R01 from the retained 48-case pilot and frozen escape policy. The old-policy failures are unchanged; do not rerun this pilot and call it new progress. Use traces to distinguish readable escape opportunities from overlapping attacks, then register one focused candidate and evaluate the roadmap development/confirmation grids. Preserve the paired failures and do not tune global HP around two seeds.
2. Observe unfamiliar players using both routes of each class and the new action/focus/roll indicators. Record comprehension and retry intent before a9/10 claim.
3. Reproduce/diagnose the native thread-notification crash and remaining resource warnings. The callback fixes above do not solve these; successful repeats alone are insufficient.
4. Validate target Windows/mobile hardware and controls/audio when available. Expand the proven first-chapter loop afterward. No popularity or 9/10 certification has been established.

Read `status/LINE_INT.md` for the latest integration checkpoint. Earlier dated notes and downloadable packages are historical and do not update automatically.
