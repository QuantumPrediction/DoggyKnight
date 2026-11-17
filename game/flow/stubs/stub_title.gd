extends Control
## 標題畫面的替身。正式版:ui/screens/title.tscn(C 線)。介面完全相同(DEV_PLAN 4.9、4.11):
##   setup(has_save: bool);訊號 new_game_pressed、continue_pressed、credits_pressed。
##   v2.3:GameState.chapter_cleared 時多一個「Hard」按鈕;按下「New Game」/「Hard」先設定
##   GameState.difficulty(normal / hard)才發 new_game_pressed。
##   v2.4(DEV_PLAN 4.12):通關後多一個「Endless」按鈕(先設定 GameState.mode = &"endless" 才發
##   endless_pressed);「Training」按鈕發 training_pressed。
##   v2.6(DEV_PLAN 4.13):GameState.chapters_cleared ≥ 1 時顯示選章「<  Chapter N  >」;只能選
##   1 至 min(chapters_cleared + 1, 3)。按「New Game」/「Hard」先設定 GameState.chapter 才發 new_game_pressed。

signal new_game_pressed()
signal continue_pressed()
signal credits_pressed()
signal endless_pressed()
signal training_pressed()

const StubUI := preload("res://game/flow/stubs/stub_ui.gd")
const CHAPTER_COUNT: int = 3

var _continue_button: Button
var _hard_button: Button
var _endless_button: Button
var _chapter_row: HBoxContainer
var _chapter_label: Label
## 標題上選的章(1 起算)。
var selected_chapter: int = 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	StubUI.prepare_root(self)
	StubUI.add_background(self)
	var column := StubUI.add_column(self)
	StubUI.add_label(column, "GOLDEN KNIGHT", StubUI.ACCENT, 16)
	StubUI.add_label(column, "(stand-in title)", Color(1, 1, 1, 0.6))
	_chapter_row = HBoxContainer.new()
	_chapter_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_chapter_row.add_theme_constant_override(&"separation", StubUI.GAP)
	column.add_child(_chapter_row)
	var previous := StubUI.add_button(_chapter_row, "<", pick_chapter.bind(-1))
	previous.custom_minimum_size = Vector2(24, 24)
	_chapter_label = StubUI.add_label(_chapter_row, "Chapter 1")
	_chapter_label.custom_minimum_size = Vector2(56, 0)
	var next := StubUI.add_button(_chapter_row, ">", pick_chapter.bind(1))
	next.custom_minimum_size = Vector2(24, 24)
	selected_chapter = clampi(GameState.chapter, 1, max_chapter())
	_refresh_chapter()
	StubUI.add_button(column, "New Game", _new_game.bind(&"normal"))
	_hard_button = StubUI.add_button(column, "New Game (Hard)", _new_game.bind(&"hard"))
	_hard_button.visible = GameState.chapter_cleared
	_continue_button = StubUI.add_button(column, "Continue", continue_pressed.emit)
	_continue_button.visible = false
	_endless_button = StubUI.add_button(column, "Endless", _endless)
	_endless_button.visible = GameState.chapter_cleared
	StubUI.add_button(column, "Training", training_pressed.emit)
	StubUI.add_button(column, "Credits", credits_pressed.emit)


func setup(has_save: bool) -> void:
	_continue_button.visible = has_save
	_hard_button.visible = GameState.chapter_cleared


func _process(_delta: float) -> void:
	_hard_button.visible = GameState.chapter_cleared     # 沙盒可以隨時切換
	_endless_button.visible = GameState.chapter_cleared
	_refresh_chapter()


## 可以選的最高章(DEV_PLAN 4.13)。
func max_chapter() -> int:
	return clampi(GameState.chapters_cleared + 1, 1, CHAPTER_COUNT)


## 選上一章(step = -1)或下一章(+1);未解鎖的章選不到。
func pick_chapter(step: int) -> void:
	selected_chapter = clampi(selected_chapter + step, 1, max_chapter())
	_refresh_chapter()


func _refresh_chapter() -> void:
	selected_chapter = clampi(selected_chapter, 1, max_chapter())
	_chapter_row.visible = GameState.chapters_cleared >= 1
	_chapter_label.text = "Chapter %d (%d open)" % [selected_chapter, max_chapter()]


func _new_game(mode: StringName) -> void:
	GameState.difficulty = mode if GameState.chapter_cleared else &"normal"
	GameState.chapter = selected_chapter
	new_game_pressed.emit()


func _endless() -> void:
	GameState.mode = &"endless"
	endless_pressed.emit()
