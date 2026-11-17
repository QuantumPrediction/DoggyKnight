#!/usr/bin/env bash
# 以 headless 模式執行 tests/ 下所有 test_*.gd。任何測試失敗、腳本錯誤或逾時都回傳非零。
#
# 用法:
#   tools/run_tests.sh            執行全部測試
#   tools/run_tests.sh line_a     只執行路徑包含 "line_a" 的測試檔
#
# Godot 執行檔:環境變數 GODOT(預設為 PATH 上的 godot)。逾時秒數:TEST_TIMEOUT(預設 300)。
# 擁有者:Phase 0 / 整合。四條線不得修改。

set -uo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
TIMEOUT="${TEST_TIMEOUT:-300}"
FILTER="${1:-}"

if ! command -v "$GODOT" >/dev/null 2>&1; then
	echo "找不到 Godot 執行檔($GODOT)。請安裝 CLAUDE.md 指定的版本,或設定環境變數 GODOT。" >&2
	exit 2
fi

IMPORT_LOG="$(mktemp)"
TEST_LOG="$(mktemp)"
# 每次測試用自己的 user:// 資料夾:同時執行的測試不會互相覆蓋存檔,也不會碰到真正玩家的存檔。
TEST_DATA_HOME="$(mktemp -d)"
trap 'rm -rf "$IMPORT_LOG" "$TEST_LOG" "$TEST_DATA_HOME"' EXIT

# 1. 匯入資源。新 clone 沒有 .godot/,不匯入的話圖檔與 class_name 都讀不到。
echo "== 匯入資源 =="
timeout "$TIMEOUT" "$GODOT" --headless --path . --import >"$IMPORT_LOG" 2>&1
import_status=$?
# 新加入的資源互相引用時,第一次匯入可能因次序報錯(例如主題引用尚未匯入的圖);再匯入一次。
if [ "$import_status" -eq 0 ] && grep -qE "SCRIPT ERROR|Parse Error|non-existent resource" "$IMPORT_LOG"; then
	timeout "$TIMEOUT" "$GODOT" --headless --path . --import >"$IMPORT_LOG" 2>&1
	import_status=$?
fi
if [ "$import_status" -ne 0 ]; then
	cat "$IMPORT_LOG"
	echo "匯入失敗(代碼 $import_status)。" >&2
	exit 1
fi
if grep -qE "SCRIPT ERROR|Parse Error" "$IMPORT_LOG"; then
	grep -E -A2 "SCRIPT ERROR|Parse Error" "$IMPORT_LOG"
	echo "匯入時發現腳本錯誤。" >&2
	exit 1
fi

# 2. 執行測試。
echo "== 執行測試 =="
args=()
if [ -n "$FILTER" ]; then
	args=(-- "--filter=$FILTER")
fi
XDG_DATA_HOME="$TEST_DATA_HOME" timeout "$TIMEOUT" "$GODOT" --headless --path . res://tests/framework/test_runner.tscn "${args[@]}" 2>&1 | tee "$TEST_LOG"
status=${PIPESTATUS[0]}

if [ "$status" -eq 124 ]; then
	echo "測試逾時($TIMEOUT 秒)。常見原因:測試中的 await 等不到訊號,或執行時錯誤令協程中斷。" >&2
	exit 1
fi
if grep -qE "SCRIPT ERROR|Parse Error|Failed to load script" "$TEST_LOG"; then
	echo "測試期間發現腳本錯誤(見上方 SCRIPT ERROR)。" >&2
	exit 1
fi
if [ "$status" -ne 0 ]; then
	echo "測試失敗。" >&2
	exit "$status"
fi
echo "全部測試通過。"
