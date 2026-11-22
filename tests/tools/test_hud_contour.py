"""Synthetic controls for the four-way native frame comparison."""
import json
import sys
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import check_hud_contour as gate


class ContourControls(unittest.TestCase):
    def setUp(self):
        self.poly = [[4, 6], [27, 6], [27, 23], [4, 23]]
        self.points = gate.sample_points(self.poly, [[0, 0], [32, 32]])
        self.plain = np.full((32, 32, 3), 50, dtype=np.uint8)

    def test_recovered_edge(self):
        normal = self.plain.copy()
        normal[6, 4:28, 0] += 32
        self.assertGreaterEqual(gate.contour_count(normal, self.plain, self.points), 3)

    def test_new_foreground_decoration(self):
        decoration = self.plain.copy()
        decoration[6, 4:28, 0] += 100
        self.assertEqual(gate.contour_count(decoration, decoration, self.points), 0)

    def test_uniform_fill_and_one_sided_step(self):
        self.assertEqual(gate.contour_count(self.plain + 35, self.plain, self.points), 0)
        normal = self.plain.copy()
        normal[6:, :, 0] += 50
        self.assertEqual(gate.contour_count(normal, self.plain, self.points), 0)

    def test_threshold_boundary(self):
        sample = [((8, 6), (8, 3), (8, 9))]
        for value, expected in [(15, 0), (16, 1)]:
            normal = self.plain.copy()
            normal[6, 8, 0] += value
            self.assertEqual(gate.contour_count(normal, self.plain, sample), expected)

    def test_knockout_attribution(self):
        normal = self.plain.copy()
        witness = [(8, 6)]
        self.assertFalse(gate.knockout_valid(normal, self.plain, self.poly, witness))
        normal[6, 8, 1] += 20
        self.assertTrue(gate.knockout_valid(normal, self.plain, self.poly, witness))
        self.assertFalse(gate.knockout_valid(normal, self.plain, []))
        normal[0, 0, 2] += 20
        self.assertFalse(gate.knockout_valid(normal, self.plain, self.poly, witness))

    def test_registered_pixels_are_unique_and_inside_plate(self):
        obs = json.loads((gate.ARCHIVE.parent / "scarecrow-render-cues/observations.json").read_text())
        for case in obs["cases"]:
            _, _, critical, _, rect = gate.CASES[case["case"]]
            for frame in case["original_frame_samples"]:
                if frame["tick"] in critical:
                    samples = gate.sample_points(frame["selected_sector_px"], rect)
                    self.assertGreaterEqual(len(samples), 3)
                    self.assertEqual(len(samples), len({p[0] for p in samples}))
                    self.assertTrue(all(rect[0][0] <= x < rect[1][0] and rect[0][1] <= y < rect[1][1]
                                        for points in samples for x, y in points))

    def test_archived_reference_files(self):
        hashes, anchors = gate.frozen()
        self.assertEqual(len(hashes), 70)
        self.assertEqual(len(anchors), 2)

    def test_incomplete_manifests_cannot_waive_controls_or_persistence(self):
        complete = {key: False for key in gate.FRAME_FIELDS}
        complete["coach_hud"] = {key: False for key in gate.HUD_FIELDS}
        complete["coach_hud"]["foreground"] = {key: False for key in gate.FOREGROUND_FIELDS}
        gate.validate_frame_schema(complete)
        for container, key in ((complete, "production_overlap"),
                               (complete["coach_hud"], "persisted_completion_flag"),
                               (complete["coach_hud"]["foreground"], "guard_blocks_touch")):
            value = container.pop(key)
            with self.assertRaisesRegex(ValueError, "incomplete"):
                gate.validate_frame_schema(complete)
            container[key] = value
            container[key] = None
            with self.assertRaisesRegex(ValueError, "incomplete"):
                gate.validate_frame_schema(complete)
            container[key] = value

    def test_all_ten_archived_metadata_gates_are_present(self):
        _, anchors = gate.frozen()
        self.assertEqual({route: len(gate.archived_metadata(anchor)) for route, anchor in anchors.items()},
                         {"marksman": 5, "outrider": 5})
        for anchor in anchors.values():
            for reference in anchor["selected_candidate_metadata"]:
                frame = {"tick": reference["tick"], "production_overlap": reference["production_overlap"],
                         "coach_hud": dict(reference["coach_hud"])}
                gate.require_archived_state(frame, gate.archived_metadata(anchor))
                frame["coach_hud"]["persisted_completion_flag"] = not frame["coach_hud"]["persisted_completion_flag"]
                with self.assertRaisesRegex(ValueError, "HUD, controls or persistence"):
                    gate.require_archived_state(frame, gate.archived_metadata(anchor))


if __name__ == "__main__":
    unittest.main()
