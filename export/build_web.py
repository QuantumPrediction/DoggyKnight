"""Build the existing Godot game as a self-contained static website."""
import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "export/web"
PART_SIZE = 6 * 1024 * 1024
ENGINE = os.environ.get("GODOT", "godot")
ROOT_DIRS = ("assets", "core", "data", "game", "i18n", "platform", "ui")


def godot(*args, env=None):
    subprocess.run([ENGINE, "--headless", *map(str, args)], check=True, env=env)


def stage_sources(project):
    # Reimport only this private copy. Desktop/mobile retain their original import settings.
    for name in ROOT_DIRS:
        shutil.copytree(ROOT / name, project / name, ignore=shutil.ignore_patterns("*.translation"))
    for name in ("project.godot", "export_presets.cfg"):
        shutil.copyfile(ROOT / name, project / name)
    (project / "export/web").mkdir(parents=True)
    shutil.copyfile(WEB / "shell.html", project / "export/web/shell.html")
    art = project / "assets/illustrated"
    # The large painted backgrounds and inventory sheets are displayed scaled down.
    # Keep the recent combat motion, warnings, UI glyphs and all fonts lossless.
    sheets = sorted(art.glob("*.png.import")) + sorted((art / "equipment").glob("*.png.import"))
    for file in sheets:
        if file.name.startswith(("ui_icons.", "trick_icons.", "fx_sheet.")):
            continue
        source = file.with_suffix("")
        if source.stat().st_size < 512 * 1024:
            continue
        text = file.read_text().replace("compress/mode=0", "compress/mode=1")
        text = text.replace("compress/lossy_quality=0.7", "compress/lossy_quality=0.84")
        file.write_text(text)
    # Godot embeds both the full raw PNGs and their imported copies for these boot settings.
    # Use smaller browser-only raw files; the in-game title still loads its regular painting.
    settings = (project / "project.godot").read_text()
    for field, source, basename, limit in (
            ("config/icon", "app_icon", "web_icon", "128x128"),
            ("boot_splash/image", "title_art", "web_splash", "480x720")):
        relative = "assets/app_icon/" + basename + ".png"
        subprocess.run(["magick", str(art / (source + ".png")), "-thumbnail", limit,
                        "-strip", str(project / relative)], check=True)
        old = f'{field}="res://assets/illustrated/{source}.png"'
        if old not in settings:
            raise ValueError("Check the current game artwork for " + field)
        settings = settings.replace(old, f'{field}="res://{relative}"')
    (project / "project.godot").write_text(settings)


def write_parts(raw, site, name, mime):
    source = raw / name
    files = []
    with source.open("rb") as stream:
        while block := stream.read(PART_SIZE):
            compressed = gzip.compress(block, compresslevel=6, mtime=0)
            sha = hashlib.sha256(compressed).hexdigest()
            relative = "payload/" + sha + ".bin"
            (site / relative).write_bytes(compressed)
            files.append(relative)
    return {"size": source.stat().st_size, "type": mime, "parts": files}


def package(raw, site):
    (site / "payload").mkdir(parents=True)
    for name in ("index.html", "index.png", "index.icon.png", "index.apple-touch-icon.png",
                 "index.audio.worklet.js", "index.audio.position.worklet.js"):
        shutil.copy2(raw / name, site / name)
    assets = {name: write_parts(raw, site, name, mime) for name, mime in
              (("index.wasm", "application/wasm"), ("index.pck", "application/octet-stream"))}
    # Keep the official runtime intact, with a scoped fetch that streams just these two files.
    transport = (WEB / "transport.js").read_text()
    engine = (raw / "index.js").read_text()
    manifest = json.dumps(assets, separators=(",", ":"))
    (site / "index.js").write_text(
        "(function () {\n" + transport + "\nconst payload = " + manifest
        + ";\n(function (fetch) {\n" + engine
        + "\n})((request, options) => gameFetch(payload, request, options));\n})();\n")
    for name, asset in assets.items():
        digest = hashlib.sha256()
        for part in asset["parts"]:
            digest.update(gzip.decompress((site / part).read_bytes()))
        if digest.digest() != hashlib.sha256((raw / name).read_bytes()).digest():
            raise ValueError("Packed bytes changed for " + name)
    return sum(p.stat().st_size for p in site.rglob("*") if p.is_file())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", nargs="?", type=Path, default=ROOT / "export/build/web")
    args = parser.parse_args()
    version = subprocess.check_output([ENGINE, "--version"], text=True).strip()
    if not version.startswith("4.7.2.stable"):
        parser.error("Use the project's Godot 4.7.2 stable engine and web_nothreads_release.zip")
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=output.parent, prefix=".web-build-") as temporary:
        working = Path(temporary)
        project, raw, site, verify = (working / n for n in ("project", "raw", "site", "verify"))
        project.mkdir()
        raw.mkdir()
        verify.mkdir()
        stage_sources(project)
        godot("--path", project, "--import")
        godot("--path", project, "--import")
        godot("--path", project, "--export-release", "Web", raw / "index.html")
        godot("--path", verify, "--main-pack", raw / "index.pck", "--script",
              ROOT / "export/verify_packed_game.gd", env=dict(os.environ, XDG_DATA_HOME=str(verify)))
        size = package(raw, site)
        # A failed build never edits the destination. Refuse to replace unrelated files.
        if output.exists():
            allowed = {p.name for p in site.iterdir()}
            if not output.is_dir() or not {p.name for p in output.iterdir()} <= allowed:
                raise SystemExit("Output contains other files; select a dedicated game directory.")
            output.rename(working / "previous")
        try:
            site.rename(output)
        except OSError:
            if (working / "previous").exists():
                (working / "previous").rename(output)
            raise
        print(f"Web playtest ready in {output} ({size:,} bytes)")


if __name__ == "__main__":
    main()
