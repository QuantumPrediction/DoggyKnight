extends Node
## C 線介面沙盒(M1 驗收)。不依賴 A、B 線:這裡用按鈕模擬 EventBus 訊號,
## 並暫代 B 線處理暫停、繼續、回標題,暫代 A 線處理必殺技。
##
## 執行:godot --path . res://tests/line_c/ui_sandbox.tscn
## 按左上「工具」打開按鈕面板,選一個動作後面板自動收起;面板最後一格「更多▶」切換第二頁
## (v2.2:頭目血條、連擊、過關慶祝、必殺技切入、星級結算、教學、轉場、音樂)。
## Esc = Android 返回鍵(打開/關閉暫停選單)。
## 這是開發工具,文字不翻譯。

const TRICK_IDS: Array[String] = ["sit", "wag", "fetch", "shake", "spin", "bark"]

var hud: Control
var trick_choice: Control
var pause_menu: Control
var screen_layer: CanvasLayer
var panel: PanelContainer
var status_label: Label

var _vigor: int = 100
var _exp: int = 0
var _exp_needed: int = 5
var _level: int = 1
var _loyalty: float = 0.0
var _wave: int = 0
var _paused: bool = false
var _screen: Control
var _boss_hp: int = 700
var _combo: int = 0
var _music_index: int = 0
var _tools_page: int = 0
var _grid: GridContainer
var _transition: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_world()
	hud = _add_layer(10, "res://ui/hud/hud.tscn")
	trick_choice = _add_layer(20, "res://ui/trick_choice/trick_choice.tscn")
	pause_menu = _add_layer(20, "res://ui/pause/pause.tscn")
	screen_layer = CanvasLayer.new()
	screen_layer.layer = 30
	add_child(screen_layer)
	_build_tools()
	# 暫代 B 線
	EventBus.back_requested.connect(_on_back)
	EventBus.app_backgrounded.connect(func() -> void: _set_paused(true))
	EventBus.resume_requested.connect(func() -> void: _set_paused(false))
	EventBus.quit_to_title_requested.connect(func() -> void:
		_set_paused(false)
		_open_screen("title"))
	EventBus.trick_chosen.connect(func(id: StringName) -> void:
		get_tree().paused = false
		_status("trick_chosen: %s" % id))
	# 暫代 A 線
	EventBus.ultimate_requested.connect(_on_ultimate_requested)
	_emit_all()


func _build_world() -> void:
	var world := Node2D.new()
	add_child(world)
	world.add_child((load("res://assets/backgrounds/meadow.tscn") as PackedScene).instantiate())
	for c: Array in [["goldie", &"idle", Vector2(90, 232)], ["bulldog", &"idle", Vector2(64, 240)],
			["scarecrow", &"run", Vector2(50, 150)], ["crow", &"run", Vector2(140, 190)]]:
		var s := AnimatedSprite2D.new()
		s.sprite_frames = load("res://assets/sprites/%s/%s_frames.tres" % [c[0], c[0]])
		s.position = c[2]
		world.add_child(s)
		s.play(c[1])
	var cam := Camera2D.new()
	cam.position = SafeArea.GAME_CENTER
	world.add_child(cam)
	cam.make_current()


func _add_layer(n: int, path: String) -> Control:
	var cl := CanvasLayer.new()
	cl.layer = n
	add_child(cl)
	var c := (load(path) as PackedScene).instantiate() as Control
	cl.add_child(c)
	return c


func _build_tools() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 40
	add_child(cl)
	var root := Control.new()
	root.theme = UiKit.THEME
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(root)
	var toggle := UiKit.button("工具", &"ButtonAlt", Vector2(40, 24))
	toggle.name = "ToolsToggle"
	root.add_child(toggle)
	panel = PanelContainer.new()
	panel.theme_type_variation = &"PanelDark"
	root.add_child(panel)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override(&"h_separation", 4)
	_grid.add_theme_constant_override(&"v_separation", 4)
	panel.add_child(_grid)
	_fill_tools()
	status_label = UiKit.label("", &"LabelLight", HORIZONTAL_ALIGNMENT_LEFT)
	root.add_child(status_label)
	toggle.pressed.connect(func() -> void: panel.visible = not panel.visible)
	var relayout := func() -> void:
		var safe := SafeArea.get_safe_rect()
		toggle.size = toggle.custom_minimum_size
		toggle.position = Vector2(safe.position.x + 4, safe.position.y + 34)
		panel.size = panel.get_minimum_size()
		panel.position = Vector2(floorf(safe.get_center().x - panel.size.x * 0.5), toggle.position.y + 28)
		status_label.position = Vector2(safe.position.x + 4, safe.end.y - 16)
		status_label.size = Vector2(safe.size.x - 8, 14)
	get_viewport().size_changed.connect(relayout)
	relayout.call()
	panel.visible = true
	set_meta(&"relayout", relayout)
	_transition = (load("res://ui/transition/transition.tscn") as PackedScene).instantiate() as CanvasLayer
	add_child(_transition)


func _fill_tools() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var page_a: Array = [
		["活力 -15", func() -> void: _set_vigor(_vigor - 15)],
		["活力 +15", func() -> void: _set_vigor(_vigor + 15)],
		["經驗 +1", _add_exp],
		["升級", _level_up],
		["忠誠 +25", func() -> void: _set_loyalty(_loyalty + 25.0)],
		["忠誠 滿", func() -> void: _set_loyalty(100.0)],
		["下一波", _next_wave],
		["頭目關", _boss_level],
		["頭目二階", func() -> void: EventBus.boss_phase_changed.emit(2)],
		["把戲三選一", _offer_tricks],
		["暫停/繼續", func() -> void: AppLifecycle.simulate_back()],
		["切到背景", func() -> void: AppLifecycle.simulate_background()],
		["模擬瀏海", _toggle_notch],
		["標題", func() -> void: _open_screen("title")],
		["過關結算", func() -> void: _open_screen("results")],
		["結局結算", func() -> void: _open_screen("results_final")],
		["失敗結算", func() -> void: _open_screen("failure")],
		["製作名單", func() -> void: _open_screen("credits")],
	]
	var page_b: Array = [
		["頭目血 -80", _boss_hit],
		["連擊 +1", func() -> void:
			_combo += 1
			EventBus.combo_changed.emit(_combo)
			_status("combo_changed(%d)" % _combo)],
		["連擊中斷", func() -> void:
			_combo = 0
			EventBus.combo_changed.emit(0)
			_status("combo_changed(0)")],
		["關卡開場", func() -> void:
			EventBus.level_started.emit(&"1-%d" % (randi() % 6 + 1))
			_status("level_started")],
		["過關慶祝", func() -> void:
			EventBus.level_completed.emit(&"1-2")
			_status("level_completed")],
		["必殺切入", func() -> void:
			EventBus.ultimate_used.emit()
			_status("ultimate_used")],
		["星級結算", func() -> void: _open_screen("results_stars")],
		["教學提示", _open_tutorial],
		["轉場", _play_transition],
		["換音樂", _next_music],
		["停音樂", func() -> void:
			Music.stop()
			_status("Music.stop()")],
		["治療 +30", func() -> void: _set_vigor(_vigor + 30)],
	]
	var actions: Array = page_a if _tools_page == 0 else page_b
	for a: Array in actions:
		var b := UiKit.button(a[0], &"", Vector2(80, 24))
		b.pressed.connect(a[1])
		# 按下後收起面板,才看得到效果;再按「工具」打開。
		b.pressed.connect(func() -> void: panel.visible = false)
		_grid.add_child(b)
	var more := UiKit.button("更多 ▶" if _tools_page == 0 else "◀ 返回", &"ButtonAlt", Vector2(80, 24))
	more.pressed.connect(func() -> void:
		_tools_page = 1 - _tools_page
		_fill_tools.call_deferred())
	_grid.add_child(more)


func _process(_delta: float) -> void:
	var relayout: Callable = get_meta(&"relayout", Callable())
	if relayout.is_valid():
		relayout.call()


func _status(text: String) -> void:
	status_label.text = text
	print("[ui_sandbox] ", text)


func _emit_all() -> void:
	EventBus.vigor_changed.emit(_vigor, 100)
	EventBus.exp_changed.emit(_exp, _exp_needed)
	EventBus.leveled_up.emit(_level)
	EventBus.loyalty_changed.emit(_loyalty, 100.0)


func _set_vigor(v: int) -> void:
	var old := _vigor
	_vigor = clampi(v, 0, 100)
	if _vigor < old:
		EventBus.player_damaged.emit(old - _vigor)
	EventBus.vigor_changed.emit(_vigor, 100)
	_status("vigor_changed(%d, 100)" % _vigor)


func _add_exp() -> void:
	_exp += 1
	if _exp >= _exp_needed:
		_level_up()
		return
	EventBus.exp_changed.emit(_exp, _exp_needed)
	_status("exp_changed(%d, %d)" % [_exp, _exp_needed])


func _level_up() -> void:
	_level += 1
	_exp = 0
	_exp_needed += 3
	EventBus.leveled_up.emit(_level)
	EventBus.exp_changed.emit(_exp, _exp_needed)
	_status("leveled_up(%d)" % _level)
	_offer_tricks()


func _set_loyalty(v: float) -> void:
	_loyalty = clampf(v, 0.0, 100.0)
	EventBus.loyalty_changed.emit(_loyalty, 100.0)
	_status("loyalty_changed(%d, 100)" % int(_loyalty))


func _on_ultimate_requested() -> void:
	_status("ultimate_requested → ultimate_used")
	await get_tree().create_timer(0.3).timeout
	EventBus.ultimate_used.emit()
	_set_loyalty(0.0)


func _next_wave() -> void:
	if _wave == 0:
		EventBus.level_started.emit(&"1-2")
	_wave = _wave % 3 + 1
	EventBus.wave_started.emit(_wave, 3)
	_status("wave_started(%d, 3)" % _wave)


func _boss_level() -> void:
	_wave = 0
	EventBus.level_started.emit(&"1-6")
	EventBus.wave_started.emit(1, 1)
	_status("level_started(1-6)")


func _boss_hit() -> void:
	if _boss_hp <= 0:
		_boss_hp = 700
	if _boss_hp == 700:
		EventBus.boss_hp_changed.emit(700, 700)      # 出場
	var was := _boss_hp
	_boss_hp = maxi(0, _boss_hp - 80)
	EventBus.boss_hp_changed.emit(_boss_hp, 700)
	if was > 350 and _boss_hp <= 350:
		EventBus.boss_phase_changed.emit(2)
	_status("boss_hp_changed(%d, 700)" % _boss_hp)


func _open_tutorial() -> void:
	var tut := (load("res://ui/hints/tutorial.tscn") as PackedScene).instantiate()
	trick_choice.get_parent().add_child(tut)
	tut.connect(&"finished", func() -> void: _status("tutorial finished"))
	_status("tutorial: drag 20 px, then release")


func _play_transition() -> void:
	_status("transition cover(0.12) → reveal(0.3)")
	await _transition.call(&"cover", 0.12)
	await get_tree().create_timer(0.2).timeout
	await _transition.call(&"reveal", 0.3)


func _next_music() -> void:
	var tracks: Array[StringName] = [&"title", &"field", &"boss", &"camp", &"victory", &"fail", &"chapter_clear"]
	var t := tracks[_music_index % tracks.size()]
	_music_index += 1
	Music.play(t)
	_status("Music.play(%s)" % t)


func _offer_tricks() -> void:
	var ids := TRICK_IDS.duplicate()
	ids.shuffle()
	var options: Array = []
	for id: String in ids.slice(0, 3):
		var t := TrickData.new()
		t.id = StringName(id)
		t.display_name = "TRICK_%s_NAME" % id.to_upper()
		t.description = "TRICK_%s_DESC" % id.to_upper()
		t.icon = load("res://assets/icons/tricks/%s.png" % id)
		options.append(t)
	get_tree().paused = true      # B 線升級時會暫停戰鬥(但不發 game_paused)
	EventBus.trick_offered.emit(options)
	_status("trick_offered(%s)" % ", ".join(ids.slice(0, 3)))


func _on_back() -> void:
	if _screen != null:
		return
	_set_paused(not _paused)


func _set_paused(value: bool) -> void:
	_paused = value
	get_tree().paused = value
	EventBus.game_paused.emit(value)
	_status("game_paused(%s)" % value)


func _toggle_notch() -> void:
	SafeArea.simulate_notch = not SafeArea.simulate_notch
	_status("simulate_notch = %s" % SafeArea.simulate_notch)


func _open_screen(kind: String) -> void:
	if _screen != null:
		_screen.queue_free()
		_screen = null
	var path := "res://ui/screens/%s.tscn" % kind.trim_suffix("_final").trim_suffix("_stars")
	_screen = (load(path) as PackedScene).instantiate() as Control
	screen_layer.add_child(_screen)
	var close := func() -> void:
		if _screen != null:
			_screen.queue_free()
			_screen = null
	match kind:
		"title":
			_screen.call("setup", true)
			for s: String in ["new_game_pressed", "continue_pressed"]:
				_screen.connect(s, func() -> void:
					_status(s)
					close.call())
			_screen.connect("credits_pressed", func() -> void: _open_screen("credits"))
		"results", "results_final":
			var final := kind == "results_final"
			_screen.call("setup", {
				"level_id": &"1-6" if final else &"1-2", "level_name": "LEVEL_1_6" if final else "LEVEL_1_2",
				"victory": true, "time_sec": 141.0 if final else 83.4, "kills": 9 if final else 27,
				"tricks": [] if final else [&"sit", &"spin"], "hero_level": _level,
				"next_is_camp": not final, "is_final": final})
			_screen.connect("continue_pressed", func() -> void:
				_status("continue_pressed")
				close.call())
		"results_stars":
			_screen.call("setup", {
				"level_id": &"1-3", "level_name": "LEVEL_1_3", "victory": true, "time_sec": 58.0, "kills": 27,
				"tricks": [&"wag"], "hero_level": _level, "next_is_camp": false, "is_final": false,
				"stars": 3, "best_stars": 3, "new_best": true, "level_index": 2, "level_count": 6,
				"star_goals": [{"key": "STAR_CLEAR", "met": true, "text": "過關"},
					{"key": "STAR_TIME", "met": true, "text": "70 秒內過關"},
					{"key": "STAR_NO_DAMAGE", "met": true, "text": "受到的傷害不超過 25"}]})
			_screen.connect("continue_pressed", func() -> void:
				_status("continue_pressed")
				close.call())
		"failure":
			_screen.call("setup", {"level_id": &"1-3", "level_name": "LEVEL_1_3", "victory": false,
				"time_sec": 47.0, "kills": 12, "tricks": [], "hero_level": _level, "next_is_camp": false, "is_final": false})
			for s: String in ["retry_pressed", "title_pressed"]:
				_screen.connect(s, func() -> void:
					_status(s)
					close.call())
		"credits":
			_screen.connect("closed", func() -> void:
				_status("closed")
				close.call())
	_status("open %s" % kind)
