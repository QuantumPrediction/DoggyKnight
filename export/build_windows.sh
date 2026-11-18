#!/usr/bin/env bash
# Build a self-contained Windows x64 playtest from the original Godot project.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
if ! command -v "$GODOT" >/dev/null 2>&1; then
    echo "Godot 4.7.2 is required; set GODOT to its executable." >&2
    exit 2
fi
version="$("$GODOT" --version)"
if [[ "$version" != 4.7.2.stable* ]]; then
    echo "Expected Godot 4.7.2.stable, got $version" >&2
    exit 2
fi
mkdir -p export/build/windows
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --export-release "Windows Desktop" export/build/windows/DoggyKnight.exe
test -s export/build/windows/DoggyKnight.exe
check_data="$(mktemp -d)"
trap 'rm -rf "$check_data"' EXIT
XDG_DATA_HOME="$check_data" "$GODOT" --headless --path "$check_data" \
    --main-pack "$PWD/export/build/windows/DoggyKnight.exe" \
    --script "$PWD/export/verify_packed_game.gd"
echo "Built export/build/windows/DoggyKnight.exe"
