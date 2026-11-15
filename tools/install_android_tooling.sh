#!/usr/bin/env bash
# 在雲端工作階段(Linux)安裝建置 Android 版所需的工具。擁有者:Phase 0 / 整合。
#
# 安裝:
#   - Godot 4.7.2 匯出範本  → ~/.local/share/godot/export_templates/4.7.2.stable/
#   - Android SDK            → /opt/android-sdk(platform-tools、build-tools 36.1.0、
#                              platforms android-36、NDK r29、CMake 3.10.2)
# 需要的網絡:github.com(範本)、dl.google.com(SDK)。JDK 用系統已有的 OpenJDK 17 或以上。
# 已安裝的部分會略過,可重複執行。

set -euo pipefail

TEMPLATE_DIR="$HOME/.local/share/godot/export_templates/4.7.2.stable"
SDK_DIR="${ANDROID_HOME:-/opt/android-sdk}"
CLT_ZIP="commandlinetools-linux-16111833_latest.zip"

if [ ! -f "$TEMPLATE_DIR/version.txt" ]; then
	echo "== 下載 Godot 4.7.2 匯出範本(約 1 GB)=="
	tmp="$(mktemp -d)"
	curl -sSL -o "$tmp/templates.tpz" \
		https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz
	(cd "$tmp" && unzip -q templates.tpz)
	mkdir -p "$TEMPLATE_DIR"
	cp -r "$tmp/templates/"* "$TEMPLATE_DIR/"
	rm -rf "$tmp"
else
	echo "== 匯出範本已安裝,略過 =="
fi

mkdir -p "$SDK_DIR"
if [ ! -x "$SDK_DIR/cmdline-tools/latest/bin/sdkmanager" ]; then
	echo "== 下載 Android 命令列工具 =="
	tmp="$(mktemp -d)"
	curl -sSL -o "$tmp/clt.zip" "https://dl.google.com/android/repository/$CLT_ZIP"
	(cd "$tmp" && unzip -q clt.zip)
	mkdir -p "$SDK_DIR/cmdline-tools/latest"
	cp -r "$tmp/cmdline-tools/"* "$SDK_DIR/cmdline-tools/latest/"
	rm -rf "$tmp"
fi

echo "== 安裝 Android SDK 套件 =="
(yes | "$SDK_DIR/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$SDK_DIR" --licenses >/dev/null) || true
"$SDK_DIR/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$SDK_DIR" \
	"platform-tools" "build-tools;36.1.0" "platforms;android-36" "ndk;29.0.14206865" "cmake;3.10.2.4988404"

echo "完成。Android SDK:$SDK_DIR;匯出範本:$TEMPLATE_DIR"
echo "建置步驟見 export/README.md。"
