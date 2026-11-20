# R03a — visible warning priority and contained text rows

2026-11-20 (Hong Kong). Branch `codex/combat-timing-r03`, based on public
PR #16 head `3367a183599b2e1ecbb5efebec341cb7879f3965`.
[Contract](../../requests/20261120-INT-warning-priority.md).

Published as [draft PR #17](https://github.com/QuantumPrediction/DoggyKnight/pull/17), stacked on #16, not merged.
The public implementation `9282f88a367b0268f4ad67f092109304360d56d5` and tested local
`4de053fa7efeda7c7fa6ddcb1cd80a48ea4cc77d` share complete tree
`5e536bbe2096560500d07b83121e1b9cf319b049`; [publication mapping](publication.json)
records all ten uploaded PNG blob hashes. Subsequent handoff changes only docs.

## Product change and limits

The retained [0.9.1 baseline](../0.9.1/captures/archer_locked_focus_ready.png)
shows a player inside a locked archer lane while the readout emphasizes ready
and full focus. The readout now gives overlapping visible warnings priority:
tracking aim, committed warning, or overlapping warnings. A steady triangle and
border accompany the words. Focus and roll still show the actor's actual state.
Exiting or cancelling a mark restores the normal phase label.

Explicit arrival markers cover the ten current spawn/summon call sites and do
not count as attacks. Their rendering is unchanged. Classification does not
depend on colour. Sectors reuse the existing hit polygon; circles and lines use
conservative body padding. Hidden, detached and queued-for-deletion marks are
ignored. A missing warning is **not** a safe-to-fire verdict: moving projectiles,
unmarked/contact damage and impact timing are outside this cue's scope.

The first five new captures revealed a separate real layout defect: the label
size was applied before its smaller font, retaining a 17-unit control height.
The roll row ended below the 42-unit panel. The fix applies font/theme first,
then sizes the row; the lower row sits at y=29. The panel is still 78×42 logical
units. Final capture checks include text height, panel containment, separation
between rows, and clearance from the focus meter. No clipping hides overflow.

No damage, HP, enemy AI, spawn timing, cooldown, focus clock, progression, RNG,
save schema, movement assist, or either fixed bot was changed. This is an
information/UI change, not a demonstrated balance or completion-rate gain.

## Retained validation

| Evidence | Actual result / scope |
| --- | --- |
| `warning_before.log` | 6 new product regressions fail before warning implementation; zero broken files |
| `warning_after.log` | Same 6 pass after warning implementation |
| `before_layout_regression_final.log` | 921 pass; width-only checks missed the visual layout defect |
| `captures_before_layout/` | All 5 first actual renders retained; not accepted final layout evidence |
| `layout_before.log` | 7 cases, 1 fails on real row containment/separation before the layout fix |
| `layout_after.log` | All 7 pass after the fix |
| `regression_final.log` | 922 tests, 0 failed, 0 broken files, exit 0; 27 ObjectDB / 21 resources plus RID shutdown messages remain |
| `anchors_before_layout/` | 8 first repeat reports byte-identical to PR #16 anchors; initial comparison retained |
| `anchors/`, `anchor_comparison.json` | Final same-input comparison recorded after layout fix |
| `captures/`, `capture.log` | 5 final actual Godot frames, all warning counts/layout checks pass, render exits 0 |
| `tested-source.json` | Final production/integration/test and evidence hashes, frozen before publication |

The seven new cases exercise real melee/archer warnings, tracking→lock→release,
boundary/cancellation refresh, tint-independent arrival classification,
transformed geometry, hidden/detached marks, overlapping warnings, pause,
unchanged combat/focus state and contained text rows. They do not mirror a
snapshot of arbitrary styling constants alone.

The two cautious seed19 failures remain failures. The eight full JSON reports
are compared with `../r01/after_fix_anchors`, not only a selected success metric.
Runner commands, source fingerprints, logs, exit codes and integrity records
are retained. Both policies are unchanged; the runner intentionally returns
success after completing the registered grid even when a case hits down_limit.
Consult individual outcomes. Eight cases are anchors for this UI change, not
the 240-development/120-confirmation grid for a future mechanical candidate.

## Rendering and limitations

See [capture index](captures/README.md). These are staged production actors and
HUD states, not player sessions. 540×960, 360×640 and 390×844 with a simulated
notch were inspected. `safe` in the JSON means HUD safe-area/layout containment;
it says nothing about combat safety. `warnings_match` checks expected counts
1, 1, 2, 0, 1. No source screenshot was painted or edited.

The first and final renders use the existing native Linux display, Godot
4.7.2, software OpenGL and Dummy audio. No Windows/mobile/controller, audible
mix, input-latency, GPU performance, long-session or human comprehension claim.
Preflight failures are recorded: missing `xvfb-run`, failed non-root package
setup, native `python`/temporary-path launch errors, and the command runtime's
inability to open a local Xvfb socket. None was a game run or an approval block.
The last preflight's repeated socket errors are represented by their ends,
byte/line count and full hash in `capture_xvfb_failure.json`.

Native rendering exits with V-Sync unsupported, 43 ObjectDB / 19 resources,
5 GLES texture RIDs and 1 font RID plus individual texture-leak messages.
Focused tests also retain exit resource/RID messages. These successful test
and capture exit codes **do not fix** the historical native crash or shutdown
cleanup problem; R02 remains open. This is local evidence, not a GitHub CI pass.

## Next bounded work

Keep this UI candidate frozen. Next isolate ownership of resources retained
across real flow exits, starting with the R01 churn harness and matching verbose
shutdown types against steady-state counts; only call a leak fixed when a
failing lifetime check passes. In parallel planning, prepare the short uncoached
archer 1-4 scenario for actual target players to test tracking/lock/escape
comprehension. Do not substitute a bot for that evidence. R03/P1, mechanical
pressure comparisons, three two-hour runs, 100 transitions and target hardware
remain open. Overall provisional quality stays 6–6.5/10.
