# Actual staged warning-readout captures

Five final frames and five first-attempt frames are retained. The latter expose the inherited lower-row overflow and are not accepted final layout evidence. Frames are unedited Godot viewport PNGs. Actor positions/focus are staged; no human playtest or target-device claim.

| State | Final | Before layout fix | Pixels |
| --- | --- | --- | --- |
| locked_focus_priority | [locked_focus_priority.png](locked_focus_priority.png) | [first render](../captures_before_layout/locked_focus_priority.png) | 540×960 |
| locked_notched | [locked_notched.png](locked_notched.png) | [first render](../captures_before_layout/locked_notched.png) | 390×844 |
| outside_marked_area | [outside_marked_area.png](outside_marked_area.png) | [first render](../captures_before_layout/outside_marked_area.png) | 360×640 |
| overlap_small | [overlap_small.png](overlap_small.png) | [first render](../captures_before_layout/overlap_small.png) | 360×640 |
| tracking_aim | [tracking_aim.png](tracking_aim.png) | [first render](../captures_before_layout/tracking_aim.png) | 540×960 |

The historical ready/full-focus contradiction is retained in the [0.9.1 baseline](../../0.9.1/captures/archer_locked_focus_ready.png). New warning semantics were already active in all five first renders; only the text layout was corrected between these two R03a sets.

`checks.json` records warning counts, actual player status, full row rectangles, text fit and HUD safe-area containment. Here `safe` refers only to layout. All five final frames were visually inspected. Full hashes are in [capture_index.json](../capture_index.json); commands, failures, logs and limitations are in the [validation record](../README.md).
