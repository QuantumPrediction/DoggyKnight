# Battle effects, music and the playable archer checkpoint

Godot 4.7.2.stable.official.ed1daf0bf. Both builds descend from the public #17 head `70dc412ab8e1ac330e7ecfa57cd1581ddba06f62`. The normal game and these probes ran on Linux.

## What changed for a player

When a scene orders the music to stop, opening or closing pause during the fade used to let a score keep playing. A stopped or muted deck now relinquishes both the melody and rhythm track. A crossfade keeps its outgoing pair alive until the fade ends. Muting during a transition and turning music back on starts the selected loop. The victory cue releases its stream when it finishes.

An arena now owns the sprite frames and particle scenes used by its effects. Bursts in that arena share the loaded assets. If two arenas overlap during a transition, each can continue using its own effects. Seven new behavior checks failed on #17 and passed on this branch. An earlier test-authoring parse error and the subsequent valid baseline are retained separately. [Baseline checks](ownership-before.log) · [Passing checks](ownership-after.log) · [Authoring log](test-authoring.log)

## What the engine retained

| Observation | Before | After |
| --- | ---: | ---: |
| Previously played chapter melody/rhythm assets still loaded after the final fade to title | 24 of 24 | 0 of 24 |
| Three real combat visits, Godot objects / resources reported at exit | 111 / 58 | 82 / 37 |
| Paths under `res://assets/fx/` in that detailed exit report | 21 | 0 |
| 100 real combat visits, Godot objects / resources reported at exit | 106 / 56 | 79 / 35 |
| Resource count after scene cleanup, median of visits 4–13 and 91–100 | 299 → 299 | 277 → 277 |
| Static memory in bytes, median of the same windows | 136,952,910 → 137,957,601 | 135,609,848 → 136,602,862 |

Both runs reached all 100 arenas. After every visit there were zero orphan nodes, players or enemies. The warm and late node medians were 26 on both builds. Late median static memory was about 0.73% higher than the warm median on the candidate. Godot's static-memory monitor and counts at the end of the process measure different things.

Title-only shutdown varied. Across the original check plus three repeats per build, all four baseline runs reported four objects and two resources. The candidate produced two clean exits and two with the same title Ogg stream, packet sequence and playback objects. After three combat visits, the diagnostic still lists music, font, effects scripts and sound-effect resources. The project-level release tests establish ownership while the game is running. The remaining shutdown warnings and the earlier native thread-notification crash are open. [Raw cycle counters](lifecycle.csv) · [Shutdown messages, resource paths and raw output hashes](shutdown.json)

## The cost of loading a score again

Releasing old music makes revisiting a track more expensive. On this host, two runs of 15 repeat switches each had median synchronous `play()` times of 1.28 and 1.35 ms on #17, and 5.10 and 6.31 ms on the candidate. The highest repeat measurement was 11.36 ms on the candidate. All 80 requested tracks started across four runs. Measure end-to-end frame time and audible transitions on target devices before drawing a performance or listening conclusion. [All timings](music-switches.json) · [Probe](music_switch_probe.gd)

## Archer 1-4

The new developer scene opens a real level-entry checkpoint from the marksman seed-19 run. Its normal game flow, archer input, temporary save, play log and clean disposal were exercised by an integration test. In a native 360×640 Godot window on Linux, the chapter-1 dialogue, 稻草人包圍網 title card, move input, pause, music toggle and return to title were exercised. Rendering used Mesa llvmpipe and Dummy audio. Two simultaneous launches sharing an established synthetic player profile left both pre-existing gameplay files byte-identical. Target-player sessions completed this round: 0. [Profile comparison](profile-isolation.json) [Uncoached playtest protocol](archer-trial.md) · [Integration result](trial-smoke.log)

All eight archer reports, across two routes, two seeds and two input policies, matched the previous complete reports byte for byte. On seed 19 both cautious routes failed 1-4 three times. Their first failed attempts took 133 damage (marksman) and 120 (outrider). Both escape-policy runs completed that seed. This points the next playtest toward decisions under overlapping pressure. [Case results and hashes](anchors.json) · [Previous complete reports](../r03a/anchors)

Four supplemental seed-19 runs used the existing read-only pressure observer. Each reproduced its complete #17 gameplay report. For the cautious marksman and outrider respectively, ordinary scarecrow swings caused 46/53 and 45/48 hits across their three failed 1-4 attempts. Together that is 629 of 721 damage. The escape policy cleared 1-4 with zero and three hits on the same routes. This identifies an attack to observe in a human trial. The 16 nearby sample points in the traces do not establish whether the player could reach an exit before impact. [All 104 hit events](archer-1-4-hits.csv) · [Four trace files, outcomes and checksums](trial-traces.json)

## Reproduction

Start each independent run from a clean temporary user-data directory. Run the original commit for the baseline. The chapter-score tests require Godot's normal wall-clock timers and audio updates. The scene-visit probe uses accelerated fixed steps.

```sh
tools/run_tests.sh resource_lifetime
tools/run_tests.sh archer_trial
tools/run_tests.sh

godot --headless --path . --fixed-fps 60 --max-fps 0 --disable-render-loop --verbose --quit-after 300
godot --headless --path . --fixed-fps 60 --max-fps 0 --disable-render-loop --verbose res://tests/integration/lifecycle_probe.tscn -- --cycles=3 --report=/tmp/dk-three.json
godot --headless --path . --fixed-fps 60 --max-fps 0 --disable-render-loop res://tests/integration/lifecycle_probe.tscn -- --cycles=100 --report=/tmp/dk-hundred.json
godot --headless --path . --script docs/validation/scene-lifetime/music_switch_probe.gd
python tools/run_pressure_audit.py --out /tmp/dk-new-anchors --classes archer --routes 0 1 --seeds 7 19 --policies cautious escape --jobs 3
python tools/run_pressure_audit.py --out /tmp/dk-new-traces --classes archer --routes 0 1 --seeds 19 --policies cautious escape --jobs 2 --trace
```

The full suite passed all 930 tests with zero broken scripts. Its regular invocation still printed three canvas RID warnings, 33 objects, 24 resources and one body and one texture RID allocation. The earlier #17 run comprised 922 tests and reported 27 objects and 21 resources. A fresh paired verbose run then executed the same 930 tests on the same Godot build, with #17 or candidate game code. Both processes reported 27 objects and 21 resources. The seven valid baseline failures disappeared with the game changes. The regular run's higher shutdown counts are retained. [Complete regression log](regression.log) · [Paired results and resource types](paired-suite.json)

Next engineering verification is the last window for escaping an overlapping 1-4 attack on the two failing routes, plus the outstanding shutdown owner and target-device music switching. External observations, device measurements, and the three two-hour sessions are still needed for a 9/10 assessment.
