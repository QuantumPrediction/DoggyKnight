#!/usr/bin/env bash
# 《金毛騎士》Android 建置腳本(D6)。給雲端工作階段與 Linux / macOS 電腦用;Windows 請照 export/README.md 用編輯器匯出。
#
# 用法(在專案根目錄):
#   export/build_android.sh debug      除錯版 APK  → export/build/doggyknight-debug.apk
#   export/build_android.sh sandbox    D 線測試 APK → export/build/doggyknight-sandbox-debug.apk(開機進營地沙盒)
#   export/build_android.sh aab        上傳 Google Play 的 AAB → export/build/doggyknight-release.aab
#   export/build_android.sh verify     檢查已建好的 APK / AAB(套件名稱、SDK 版本、權限、16 KB 分頁)
#
# 需要的環境變數(有預設值的可以不設):
#   GODOT                 Godot 4.7.2 執行檔(預設:PATH 上的 godot)
#   ANDROID_HOME          Android SDK(預設:/opt/android-sdk,其次 ~/Android/Sdk)
#   JAVA_HOME             JDK 17 或以上(預設:/usr/lib/jvm/java-21-openjdk-amd64)
#   DEBUG_KEYSTORE        除錯金鑰(預設:~/.android/debug.keystore;不存在時自動產生,密碼 android)
# 建置 AAB 時必須設定(上傳金鑰;絕對不要放進 repo):
#   UPLOAD_KEYSTORE       上傳金鑰檔的完整路徑
#   UPLOAD_KEY_ALIAS      金鑰別名
#   UPLOAD_KEY_PASSWORD   金鑰密碼
#
# 這個腳本不會改動你的 Godot 編輯器設定:Linux 上用一份臨時的編輯器設定(XDG_CONFIG_HOME)。

set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
MODE="${1:-}"
OUT_DIR="export/build"
mkdir -p "$OUT_DIR"

if [ -z "${ANDROID_HOME:-}" ]; then
	if [ -d /opt/android-sdk ]; then ANDROID_HOME=/opt/android-sdk; else ANDROID_HOME="$HOME/Android/Sdk"; fi
fi
JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-21-openjdk-amd64}"
DEBUG_KEYSTORE="${DEBUG_KEYSTORE:-$HOME/.android/debug.keystore}"
BUILD_TOOLS="$(ls -d "$ANDROID_HOME"/build-tools/* 2>/dev/null | sort -V | tail -1 || true)"

need() {
	command -v "$1" >/dev/null 2>&1 || { echo "找不到 $1。$2" >&2; exit 2; }
}

prepare_editor_settings() {
	need "$GODOT" "請安裝 Godot 4.7.2,或設定環境變數 GODOT。"
	[ -d "$ANDROID_HOME/platform-tools" ] || { echo "Android SDK 不完整:$ANDROID_HOME" >&2; exit 2; }
	[ -x "$JAVA_HOME/bin/java" ] || { echo "找不到 JDK:$JAVA_HOME" >&2; exit 2; }
	if [ ! -f "$DEBUG_KEYSTORE" ]; then
		mkdir -p "$(dirname "$DEBUG_KEYSTORE")"
		"$JAVA_HOME/bin/keytool" -genkeypair -keystore "$DEBUG_KEYSTORE" -storepass android -alias androiddebugkey \
			-keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" >/dev/null
		echo "已產生除錯金鑰:$DEBUG_KEYSTORE"
	fi
	if [ "$(uname -s)" = "Linux" ]; then
		CONFIG_HOME="$(mktemp -d)"
		trap 'rm -rf "$CONFIG_HOME"' EXIT
		mkdir -p "$CONFIG_HOME/godot"
		cat >"$CONFIG_HOME/godot/editor_settings-4.7.tres" <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$ANDROID_HOME"
export/android/java_sdk_path = "$JAVA_HOME"
export/android/debug_keystore = "$DEBUG_KEYSTORE"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
EOF
		export XDG_CONFIG_HOME="$CONFIG_HOME"
	else
		echo "(非 Linux:使用你自己的 Godot 編輯器設定;請先在 編輯器設定 → 匯出 → Android 填好 SDK 與 JDK 路徑)"
	fi
	# 除錯金鑰也用環境變數傳給 Godot(Godot 4 支援),不寫進 export_presets.cfg。
	export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$DEBUG_KEYSTORE"
	export GODOT_ANDROID_KEYSTORE_DEBUG_USER="androiddebugkey"
	export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="android"
	"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
}

run_export() {
	local kind="$1" preset="$2" out="$3"
	shift 3
	local log
	log="$(mktemp)"
	if ! "$GODOT" --headless --path . "$@" "$kind" "$preset" "$out" >"$log" 2>&1; then
		grep -E "ERROR|error:|FAILURE|What went wrong" -A4 "$log" | head -40 >&2 || true
		echo "匯出失敗(完整記錄:$log)" >&2
		exit 1
	fi
	if [ ! -f "$out" ]; then
		tail -30 "$log" >&2
		echo "匯出沒有產生 $out(完整記錄:$log)" >&2
		exit 1
	fi
	rm -f "$log"
	echo "完成:$out($(du -h "$out" | cut -f1))"
}

verify() {
	[ -n "$BUILD_TOOLS" ] || { echo "找不到 Android build-tools" >&2; exit 2; }
	for apk in "$OUT_DIR"/*.apk; do
		[ -f "$apk" ] || continue
		echo "== $apk"
		"$BUILD_TOOLS/aapt2" dump badging "$apk" 2>/dev/null | grep -E "^package:|^minSdkVersion|^targetSdkVersion|^uses-permission|^application-label:|^native-code" || true
		echo "權限(沒有任何 uses-permission 就是不需要權限):"
		"$BUILD_TOOLS/aapt2" dump permissions "$apk" 2>/dev/null || true
		if "$BUILD_TOOLS/zipalign" -c -P 16 -v 4 "$apk" >/dev/null 2>&1; then
			echo "zipalign -c -P 16:通過"
		else
			echo "zipalign -c -P 16:不通過" >&2
		fi
	done
	if command -v python3 >/dev/null 2>&1; then
		packages=()
		for f in "$OUT_DIR"/*.apk "$OUT_DIR"/*.aab; do [ -f "$f" ] && packages+=("$f"); done
		if [ "${#packages[@]}" -gt 0 ]; then
			python3 -I export/tools/check_16k.py "${packages[@]}" || echo "有 64 位元程式庫不支援 16 KB 分頁" >&2
		fi
	fi
	for aab in "$OUT_DIR"/*.aab; do
		[ -f "$aab" ] || continue
		echo "== $aab"
		"$JAVA_HOME/bin/jarsigner" -verify "$aab" 2>/dev/null | grep -E "verified|unsigned" || true
	done
	if [ -f android/build/build/intermediates/merged_manifests/standardRelease/processStandardReleaseManifest/AndroidManifest.xml ]; then
		echo "AAB 的 AndroidManifest(Gradle 中間檔):"
		grep -E 'package=|versionCode|versionName|minSdkVersion|targetSdkVersion|uses-permission' \
			android/build/build/intermediates/merged_manifests/standardRelease/processStandardReleaseManifest/AndroidManifest.xml || true
	fi
}

case "$MODE" in
	debug)
		prepare_editor_settings
		run_export --export-debug "Android" "$OUT_DIR/doggyknight-debug.apk"
		;;
	sandbox)
		prepare_editor_settings
		run_export --export-debug "Android Sandbox" "$OUT_DIR/doggyknight-sandbox-debug.apk"
		;;
	aab)
		: "${UPLOAD_KEYSTORE:?請設定 UPLOAD_KEYSTORE(上傳金鑰檔的完整路徑)}"
		: "${UPLOAD_KEY_ALIAS:?請設定 UPLOAD_KEY_ALIAS}"
		: "${UPLOAD_KEY_PASSWORD:?請設定 UPLOAD_KEY_PASSWORD}"
		prepare_editor_settings
		export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$UPLOAD_KEYSTORE"
		export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$UPLOAD_KEY_ALIAS"
		export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$UPLOAD_KEY_PASSWORD"
		extra=()
		if [ ! -f android/build/build.gradle ]; then
			extra=(--install-android-build-template)
			echo "第一次建置:安裝 Android 建置範本到 android/(已被 .gitignore 排除),Gradle 會下載所需套件。"
		fi
		run_export --export-release "Android AAB" "$OUT_DIR/doggyknight-release.aab" ${extra[@]+"${extra[@]}"}
		;;
	verify)
		verify
		;;
	*)
		sed -n '2,20p' "$0"
		exit 2
		;;
esac
