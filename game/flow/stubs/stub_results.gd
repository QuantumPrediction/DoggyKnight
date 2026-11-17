extends Control
## 過關結算的替身。正式版:ui/screens/results.tscn(C 線)。
##   setup(result: Dictionary);出現時播 Sfx clear;訊號 continue_pressed。result 的鍵見 DEV_PLAN 4.9、4.10
##   (替身也顯示星級與三個目標,方便在沙盒裡檢查)。

signal continue_pressed()

const StubUI := preload("res://game/flow/stubs/stub_ui.gd")
## 替身用英文顯示星級目標(預設字型沒有中文字)。
const GOAL_TEXT: Dictionary = {
	"STAR_CLEAR": "Clear",
	"STAR_TIME": "Clear within %d s",
	"STAR_DAMAGE": "Lose %d vigor or less",
	"STAR_NO_DAMAGE": "Never get hit",
}

var _column: VBoxContainer
var result: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	StubUI.prepare_root(self)
	StubUI.add_background(self, Color(StubUI.BG, 0.85))
	_column = StubUI.add_column(self)


func setup(data: Dictionary) -> void:
	result = data
	Sfx.play(&"clear")      # 與 C 線的正式畫面相同:畫面出現時自己播音效
	var final: bool = data.get("is_final", false)
	StubUI.add_label(_column, ("CHAPTER %d CLEAR!" % int(data.get("chapter", 1))) if final else "CLEAR!",
			StubUI.ACCENT, 16)
	if data.get("next_chapter_unlocked", false):
		StubUI.add_label(_column, "Chapter %d unlocked!" % (int(data.get("chapter", 1)) + 1), StubUI.ACCENT)
	StubUI.add_label(_column, "Chapter %d  Level %s%s" % [int(data.get("chapter", 1)), data.get("level_id", ""),
			"  [HARD]" if data.get("difficulty", &"normal") == &"hard" else ""])
	var stars := int(data.get("stars", 0))
	StubUI.add_label(_column, "%s  (best %d)%s" % ["*".repeat(stars) + "-".repeat(3 - stars),
			int(data.get("best_stars", 0)), "  NEW BEST!" if data.get("new_best", false) else ""], StubUI.ACCENT, 12)
	for goal: Dictionary in data.get("star_goals", []):
		var template: String = GOAL_TEXT.get(goal.get("key", ""), String(goal.get("key", "")))
		var text := template % int(goal.get("value", 0)) if template.contains("%d") else template
		StubUI.add_label(_column, "[%s] %s" % ["x" if goal.get("met", false) else " ", text],
				Color.WHITE if goal.get("met", false) else Color(1, 1, 1, 0.5))
	StubUI.add_label(_column, "Time %.1f s" % float(data.get("time_sec", 0.0)))
	StubUI.add_label(_column, "Kills %d" % int(data.get("kills", 0)))
	StubUI.add_label(_column, "Hero Lv %d" % int(data.get("hero_level", 1)))
	var tricks: Array = data.get("tricks", [])
	StubUI.add_label(_column, "New tricks: %s" % (", ".join(tricks.map(func(t: Variant) -> String: return str(t))) if not tricks.is_empty() else "-"))
	if data.get("next_is_camp", false):
		StubUI.add_label(_column, "Next: camp", Color(1, 1, 1, 0.6))
	StubUI.add_button(_column, "Title" if final else "Next", continue_pressed.emit)
