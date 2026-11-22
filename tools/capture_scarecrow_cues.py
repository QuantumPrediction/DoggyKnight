#!/usr/bin/env python3
"""Run live, matched chapter 1-4 capture from a real Godot desktop."""
import argparse
import gzip
import hashlib
import json
import os
import struct
import subprocess
import tempfile
from collections import Counter
from pathlib import Path

import probe_scarecrow_windows as probe


SCENE = "res://tests/integration/scarecrow_cue_capture.tscn"
BASE = "d81716df4c7d81fd49d368c6d42262fddc6adf93"
HUD_BASE = "d9188279e0b4720dd35b7b7532f42a9dbb6f4b8e"
PRODUCTION = ("assets", "core", "game", "data", "ui", "i18n", "platform", "store", "project.godot")
ARCHIVE = probe.ROOT / "docs/validation/scarecrow-window"
PAIRS = {
    "marksman": ((0, "cautious"), "20980.1", 4961, 4990, 4992),
    "outrider": ((1, "cautious"), "17197.2", 366, 375, 397),
}
CAPTURE_FILES = ("tests/integration/scarecrow_cue_capture.gd",
                 "tests/integration/scarecrow_cue_capture.tscn", "tools/capture_scarecrow_cues.py")
SOURCE_PATHS = ("assets", "core", "game", "data", "ui", "i18n", "platform", "store", "project.godot",
                "tests/integration", "tools/run_pressure_audit.py", "tools/probe_scarecrow_windows.py",
                *CAPTURE_FILES, "docs/validation/scarecrow-window", "docs/validation/r03a/anchors")


def git(*args):
    return subprocess.check_output(["git", *args], cwd=probe.ROOT)


def source_fingerprint():
    # Use index paths, but hash actual file bytes (including local modifications).
    # Cold editor import writes untracked/ignored *.translation outside .godot.
    files = set(git("ls-files", "-z", "--", *SOURCE_PATHS).split(b"\0")) - {b""}
    files.update(os.fsencode(path) for path in CAPTURE_FILES)
    per_file, whole = {}, hashlib.sha256()
    for path in sorted(files):
        name = os.fsdecode(path)
        with (probe.ROOT / name).open("rb") as stream:
            digest = hashlib.file_digest(stream, "sha256").digest()
        per_file[name] = digest
        whole.update(path + b"\0" + digest)
    return whole.hexdigest(), per_file


def hud_comparison_inputs(files):
    # Old checkouts can still run the original capture without the newer comparison.
    base_known = subprocess.run(["git", "cat-file", "-e", HUD_BASE], cwd=probe.ROOT,
                                stderr=subprocess.DEVNULL).returncode == 0
    if not base_known:
        return None
    changed = git("diff", "--name-only", "-z", HUD_BASE, "--", *PRODUCTION)
    added = git("ls-files", "--others", "--exclude-standard", "-z", "--", *PRODUCTION)
    observer = hashlib.sha256()
    for path, digest in sorted(files.items()):
        if not path.startswith(tuple(p + "/" for p in PRODUCTION)) and path not in PRODUCTION:
            observer.update(os.fsencode(path) + b"\0" + digest)
    return {"base": HUD_BASE, "production_paths_changed": sorted(os.fsdecode(p) for p in
            set((changed + added).split(b"\0")) if p), "observer_sha256": observer.hexdigest()}


def png_size(path):
    with path.open("rb") as file:
        header = file.read(24)
    if header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        raise ValueError("not a PNG")
    return list(struct.unpack(">II", header[16:24]))


def engine(argv, log, env):
    with log.open("x") as stream:
        return subprocess.run(argv, cwd=probe.ROOT, env=env, stdout=stream,
                              stderr=subprocess.STDOUT, timeout=900).returncode


def take(name, out, env, display, without_selected_ink=False):
    case, target, start, entry, impact = PAIRS[name]
    label = probe.name(case)
    dest = out / name
    dest.mkdir()
    report = dest / "report.json"
    command = json.loads((probe.ANCHORS / (label + ".command.json")).read_text())
    _, *args = command
    cli = ["godot", "--display-driver", display, "--rendering-method", "gl_compatibility",
           "--audio-driver", "Dummy", "--windowed", "--resolution", "360x640", "--disable-vsync"]
    for arg in args:
        if arg in ("--headless", "--disable-render-loop"):
            continue
        if arg.startswith("res://"):
            arg = SCENE
        elif arg.startswith("--report="):
            arg = f"--report={report}"
        cli.append(arg)
    cli[cli.index("--path") + 1] = str(probe.ROOT)
    cli += [f"--capture-dir={dest}", f"--capture-id={target}",
            f"--capture-first={start-2}", f"--capture-last={impact+1}"]
    if without_selected_ink:
        cli.append("--without-selected-ink")
    print(f"{name}: starting native replay for {target}, physics ticks {start-2} to {impact+1}", flush=True)
    with tempfile.TemporaryDirectory(prefix="doggy-cue-save-") as save:
        code = engine(cli, dest / "godot.log", dict(env, XDG_DATA_HOME=save))
    log = (dest / "godot.log").read_text(errors="replace")
    trace = report.with_suffix(".json.windows.jsonl")
    archive = gzip.decompress((ARCHIVE / (label + ".jsonl.gz")).read_bytes())
    trace_bytes = trace.read_bytes() if trace.exists() else b""
    report_bytes = report.read_bytes() if report.exists() else b""
    trace_match = trace_bytes == archive
    report_match = report_bytes == (probe.ANCHORS / (label + ".json")).read_bytes()
    meta_file = dest / "frames.json"
    meta = json.loads(meta_file.read_text()) if meta_file.exists() else {}
    frames = meta.get("frames", [])
    ticks = Counter(f["tick"] for f in frames)
    problems = []
    if code != 1 or "SCRIPT ERROR" in log or "Program crashed" in log:
        problems.append("unexpected engine result (these two controls normally exit 1 for down-limit)")
    if not trace_match:
        left, right = archive.splitlines(), trace_bytes.splitlines()
        line = next((i for i, (a, b) in enumerate(zip(left, right), 1) if a != b),
                    min(len(left), len(right)) + 1)
        problems.append(f"archived per-tick control differed at line {line}")
    if not report_match:
        problems.append("complete chapter report differed")
    if not meta or meta.get("display", "").lower() != display or meta.get("error"):
        problems.append("native draw metadata unavailable or reported an error")
    skipped = sorted(set(range(start-2, impact+2)) - ticks.keys())
    if skipped:
        problems.append("incomplete physics-to-render coverage; first visible frame is inconclusive")
    if any(a["process_frame"] >= b["process_frame"] or a["tick"] > b["tick"]
           for a, b in zip(frames, frames[1:])):
        problems.append("out-of-order or repeated draw callback")
    eligible = [f for f in frames if f["warning_eligible"]]
    if not eligible or eligible[0]["tick"] != start:
        problems.append("no eligible draw callback at the registered onset")
    for f in frames:
        image = dest / f["file"]
        if not image.is_file() or png_size(image) != [360, 640] or f["image_size"] != [360, 640]:
            problems.append("PNG missing or wrong viewport dimensions")
            break
        f["sha256"] = probe.digest(image.read_bytes())
    return dict(case=name, target=target, start=start, entry=entry, impact=impact, accepted=not problems,
                engine_exit=code, complete_report_identical=report_match, complete_trace_identical=trace_match,
                trace_sha256=probe.digest(trace_bytes), report_sha256=probe.digest(report_bytes),
                display=meta.get("display"), adapter=meta.get("adapter"), render_device=meta.get("render_device"),
                captured_frames=len(frames), missing_physics_ticks=skipped,
                multiple_draw_ticks={t: n for t, n in ticks.items() if n > 1},
                first_eligible_draw_tick=eligible[0]["tick"] if eligible else None,
                first_visible_pixels="requires review of original images", problems=problems, frames=frames)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True, help="new output directory")
    parser.add_argument("--case", choices=("both", *PAIRS), default="both")
    parser.add_argument("--without-selected-ink", action="store_true",
                        help="diagnostic draw with only the selected warning canvas item muted")
    opts = parser.parse_args()
    display = "x11" if os.environ.get("DISPLAY") else ("wayland" if os.environ.get("WAYLAND_DISPLAY") else None)
    if display is None:
        parser.error("run in a real Linux desktop terminal (headless is not a capture)")
    out = opts.out.resolve()
    out.mkdir()
    before, before_files = source_fingerprint()
    head = git("rev-parse", "HEAD").decode().strip()
    with tempfile.TemporaryDirectory(prefix="doggy-cue-editor-") as editor:
        env = dict(os.environ, XDG_DATA_HOME=editor, XDG_CONFIG_HOME=editor, XDG_CACHE_HOME=editor)
        version = subprocess.check_output(["godot", "--version"], text=True, env=env).strip()
        if version != probe.ENGINE:
            raise SystemExit("Godot version differs from the archived engine")
        print("Importing the pinned source into the local Godot cache.", flush=True)
        if engine(["godot", "--headless", "--editor", "--import", "--path", str(probe.ROOT)],
                  out / "import.log", env):
            raise SystemExit("Godot import failed; see import.log")
        if "SCRIPT ERROR" in (out / "import.log").read_text(errors="replace"):
            raise SystemExit("Godot import contained a script error; see import.log")
        result = []
        for name in PAIRS if opts.case == "both" else (opts.case,):
            row = take(name, out, env, display, opts.without_selected_ink)
            result.append(row)
            after, after_files = source_fingerprint()
            changed = sorted(path for path in before_files.keys() | after_files.keys()
                             if before_files.get(path) != after_files.get(path))
            print(f"{name}: {row['captured_frames']} completed draws, "
                  f"trace match={row['complete_trace_identical']}, accepted={row['accepted'] and not changed}",
                  flush=True)
            probe.write_json(out / "validation.json", {
                "registered_base": BASE, "checkout_head": head, "engine": version,
                "without_selected_ink": opts.without_selected_ink,
                "hud_comparison_inputs": hud_comparison_inputs(after_files),
                "source_sha256": before, "source_sha256_after": after,
                "source_fingerprint_schema": "git-index-paths-plus-capture-v1: sorted path + NUL + binary SHA256",
                "source_file_count": len(before_files), "changed_source_paths": changed,
                "source_unchanged": not changed, "cases": result,
            })
            if changed:
                raise SystemExit("Capture source changed; see validation.json")
    if not all(r["accepted"] for r in result):
        raise SystemExit("Capture evidence is incomplete or not comparable; see validation.json")


if __name__ == "__main__":
    main()
