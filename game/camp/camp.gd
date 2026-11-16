class_name Camp
extends Node
## 營地(DEV_PLAN 11 D1、4.9、15 DP1)。
##
## 夜裡的圓桌與營火,卸下盔甲的金毛趴在火旁搖尾巴;第 3 關以後鬥牛犬也坐在火旁。三個入口:
## - 小遊戲「拉扯王室卷軸」(玩完回到這裡,獎勵已套用到 GameState)
## - 同伴(預留,按下顯示「即將開放」)
## - 繼續冒險:發出 EventBus.camp_left。營地不會自己消失,由 B 線的流程移除。
## 點金毛可以摸摸頭:冒愛心、播 pet、手機輕震,滿意度小幅增加(每次營地有上限,見 CampConfig)。
##
## 梅林(DEV_PLAN 16 DS2)坐在圓桌後面,偶爾施法冒閃光;點他會說一句 CAMP_MERLIN_XX(對話泡泡)。
##
## 進入時(_ready)發出 EventBus.camp_entered,並播放營地音樂(Music.play(&"camp"))。
## 營地故事(DS1):第一次營地播 camp1、第二次播 camp2(CampConfig.story_paths,依 GameState.level_index),
## 用營地自己的對白框(ui/dialogue/dialogue_box.tscn 的實例,第 40 層)播放;播完選單才滑出來。
## 每次進營地只播一次(玩完小遊戲回來不會再播);對白檔不存在時略過,直接顯示選單。
## 畫面:放在 CanvasLayer(CampConfig.canvas_layer)內,用 SafeArea 排版,
## 填滿任何大小的畫面(180×320 至 196×426 等),畫面大小改變時重新排版。

const DEFAULT_GOLDIE_FRAMES_PATH: String = "res://game/camp/art/camp_goldie_frames.tres"
const FALLBACK_GOLDIE_FRAMES_PATH: String = "res://assets/sprites/goldie/goldie_frames.tres"
const BULLDOG_FRAMES_PATH: String = "res://assets/sprites/bulldog/bulldog_frames.tres"
const DEFAULT_MINIGAME_PATH: String = "res://game/minigames/scroll/scroll_minigame.tscn"
const HEART_PATH: String = "res://assets/fx/particles/heart.tscn"
const SPARKLE_PATH: String = "res://assets/fx/particles/sparkle.tscn"
const DIALOGUE_BOX_PATH: String = "res://ui/dialogue/dialogue_box.tscn"
const MERLIN_FRAMES_PATH: String = "res://assets/sprites/merlin/merlin_frames.tres"

## 小遊戲開始時發出(給沙盒與測試看)。
signal minigame_opened(minigame: MinigameBase)
signal minigame_closed(score: int, grade: int)
## 摸了金毛一下。rewarded:這一下有沒有增加滿意度。
signal goldie_petted(rewarded: bool)
## 營地故事播完(或略過),選單出現。沒有故事時不發出。
signal story_finished()
## 梅林說了一句話(翻譯鍵)。
signal merlin_spoke(key: String)

@export var config: CampConfig

var minigame_plays: int = 0
var last_grade: int = -1
var has_left: bool = false
## 這次營地摸頭的次數,與其中有增加滿意度的次數。
var pet_count: int = 0
var pet_rewards: int = 0
## 測試與沙盒用:指定要播的營地對白(不用 data/story/ 的檔案)。要在加入場景樹之前設定。
var story_override: DialogueScript
## 這次營地有沒有播過故事。
var story_played: bool = false
## 這次營地點梅林的次數(有說話的)。
var merlin_taps: int = 0

var _layer: CanvasLayer
var _root: Control
var _sky: CampScenery
var _ground: CampScenery
var _glow: CampScenery
var _actors: Node2D
var _goldie: CampGoldie
var _bulldog: AnimatedSprite2D
var _embers: CPUParticles2D
var _smoke: CPUParticles2D
var _front: Control
var _stats: Control
var _title: Label
var _vigor_label: Label
var _satisfaction_label: Label
var _bonus_label: Label
var _menu: VBoxContainer
var _minigame_button: Button
var _companion_button: Button
var _continue_button: Button
var _toast: Label
var _toast_left: float = 0.0
var _pet_zone: Control
var _bulldog_zone: Control
var _fade: ColorRect
var _minigame: MinigameBase
var _time: float = 0.0
var _shown_vigor: float = 0.0
var _shown_satisfaction: float = 0.0
var _bar_pulse: Dictionary = {"vigor": 0.0, "satisfaction": 0.0}
var _last_pet_time: float = -100.0
var _bark_left: float = 0.0
var _bulldog_hop: float = 0.0
var _fireflies: Array[Vector4] = []
## 飛向滿意度條的愛心:{"from": Vector2, "age": float}
var _flying_hearts: Array[Dictionary] = []
## 跳起的數字:{"text": String, "pos": Vector2, "age": float, "color": Color}
var _floaters: Array[Dictionary] = []
var _fire_spot: Vector2 = Vector2.ZERO
var _bulldog_spot: Vector2 = Vector2.ZERO
var _menu_rest: Vector2 = Vector2.ZERO
var _intro: float = 0.0
var _rng := RandomNumberGenerator.new()
var _dialogue: CanvasLayer
var _story_playing: bool = false
var _merlin: CampMerlin
var _merlin_zone: Control
var _merlin_bubble: MinigameSpeechBubble
var _last_merlin_tap: float = -100.0
var _merlin_bag: PackedStringArray = []
var _merlin_last_line: String = ""
var _line_rng := RandomNumberGenerator.new()


func _ready() -> void:
	if config == null:
		config = CampConfig.new()
	_load_defaults()
	_rng.seed = 2026
	_line_rng.randomize()
	_build()
	_shown_vigor = _vigor_ratio()
	_shown_satisfaction = _satisfaction_ratio()
	_refresh_stats()
	_layout()
	_fade_in()
	if config.music_track != &"":
		Music.play(config.music_track)
	EventBus.camp_entered.emit()
	_start_story()


func _load_defaults() -> void:
	# 用 duplicate:補上預設圖時不改到共用的 .tres。
	if config.goldie_frames == null or config.bulldog_frames == null or config.minigame_scene == null or config.heart_particles == null \
			or config.dialogue_box_scene == null or config.merlin_frames == null or config.merlin_sparkle_particles == null:
		config = config.duplicate() as CampConfig
	if config.goldie_frames == null:
		if ResourceLoader.exists(DEFAULT_GOLDIE_FRAMES_PATH):
			config.goldie_frames = load(DEFAULT_GOLDIE_FRAMES_PATH) as SpriteFrames
		elif ResourceLoader.exists(FALLBACK_GOLDIE_FRAMES_PATH):
			config.goldie_frames = load(FALLBACK_GOLDIE_FRAMES_PATH) as SpriteFrames
			config.goldie_animation = &"sleep"
			config.goldie_flip = false
	if config.bulldog_frames == null and ResourceLoader.exists(BULLDOG_FRAMES_PATH):
		config.bulldog_frames = load(BULLDOG_FRAMES_PATH) as SpriteFrames
	if config.minigame_scene == null and ResourceLoader.exists(DEFAULT_MINIGAME_PATH):
		config.minigame_scene = load(DEFAULT_MINIGAME_PATH) as PackedScene
	if config.heart_particles == null and ResourceLoader.exists(HEART_PATH):
		config.heart_particles = load(HEART_PATH) as PackedScene
	if config.dialogue_box_scene == null and ResourceLoader.exists(DIALOGUE_BOX_PATH):
		config.dialogue_box_scene = load(DIALOGUE_BOX_PATH) as PackedScene
	if config.merlin_frames == null and ResourceLoader.exists(MERLIN_FRAMES_PATH):
		config.merlin_frames = load(MERLIN_FRAMES_PATH) as SpriteFrames
	if config.merlin_sparkle_particles == null and ResourceLoader.exists(SPARKLE_PATH):
		config.merlin_sparkle_particles = load(SPARKLE_PATH) as PackedScene


func _process(delta: float) -> void:
	_time += delta
	_intro += delta
	if _toast_left > 0.0:
		_toast_left -= delta
		_toast.visible = _toast_left > 0.0
	if not _sky.visible:
		# 小遊戲中:條保持原樣,回到營地時才看得到它長上去。
		return
	_shown_vigor = move_toward(_shown_vigor, _vigor_ratio(), delta * 0.8)
	_shown_satisfaction = move_toward(_shown_satisfaction, _satisfaction_ratio(), delta * 0.8)
	for key: String in _bar_pulse:
		_bar_pulse[key] = maxf(0.0, float(_bar_pulse[key]) - delta * 2.5)
	var flicker := 1.0 + config.fire_flicker * (0.6 * sin(_time * 9.0) + 0.3 * sin(_time * 23.0 + 1.3) + 0.25 * sin(_time * 3.7))
	for part: CampScenery in [_sky, _ground, _glow]:
		part.flicker = flicker
		part.advance(delta)
	_bark_left = maxf(0.0, _bark_left - delta)
	_bulldog_hop = maxf(0.0, _bulldog_hop - delta)
	if _bulldog != null and _bulldog.visible:
		_bulldog.position = _bulldog_spot + Vector2(0, -roundf(sin(_bulldog_hop / 0.3 * PI) * 3.0) if _bulldog_hop > 0.0 else 0.0)
	_update_effects(delta)
	_animate_menu()
	_front.queue_redraw()
	_stats.queue_redraw()


# --- 公開方法(B 線、沙盒、測試、截圖) ---

## 目前開著的小遊戲(沒有時是 null)。
func get_minigame() -> MinigameBase:
	return _minigame


func is_menu_visible() -> bool:
	return _menu.visible


func get_goldie() -> CampGoldie:
	return _goldie


## 鬥牛犬是否坐在營火旁(第 3 關以後)。
func is_bulldog_visible() -> bool:
	return _bulldog != null and _bulldog.visible


func get_merlin() -> CampMerlin:
	return _merlin


func get_merlin_bubble() -> MinigameSpeechBubble:
	return _merlin_bubble


## 營地自己的對白框(ui/dialogue/dialogue_box.tscn 的實例)。
func get_dialogue_box() -> CanvasLayer:
	return _dialogue


## 營地故事正在播放(選單還沒出現)。
func is_story_playing() -> bool:
	return _story_playing


## 略過營地故事(等同按對白框的「略過」)。測試、沙盒與截圖用。
func skip_story() -> void:
	if _story_playing and _dialogue != null and _dialogue.has_method(&"skip"):
		_dialogue.call(&"skip")


## 這次營地要播的對白:story_override,或 CampConfig.story_paths[GameState.level_index] 的檔案。沒有時傳回 null。
func story_script() -> DialogueScript:
	if story_override != null:
		return story_override
	var path: String = config.story_paths.get(GameState.level_index, "")
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as DialogueScript


## 按下「拉扯王室卷軸」。測試與沙盒也可以直接呼叫。
func open_minigame() -> void:
	if has_left or _minigame != null or _story_playing:
		return
	Sfx.play(&"ui_tap")
	if config.minigame_plays_per_visit > 0 and minigame_plays >= config.minigame_plays_per_visit:
		_show_toast(tr("CAMP_MINIGAME_DONE"))
		return
	if config.minigame_scene == null:
		_show_toast(tr("UI_COMING_SOON"))
		return
	_minigame = config.minigame_scene.instantiate() as MinigameBase
	if _minigame == null:
		push_error("CampConfig.minigame_scene 的根節點必須繼承 MinigameBase")
		return
	_minigame.finished.connect(_on_minigame_finished)
	_minigame.closed.connect(_on_minigame_closed)
	_set_camp_visible(false)
	_floaters.clear()
	_flying_hearts.clear()
	minigame_opened.emit(_minigame)
	_root.add_child(_minigame)
	_root.move_child(_fade, -1)
	_fade_in()


## 按下「同伴」(預留入口)。
func open_companion() -> void:
	if has_left or _story_playing:
		return
	Sfx.play(&"ui_tap")
	_show_toast(tr("UI_COMING_SOON"))


## 按下「繼續冒險」。
func leave_camp() -> void:
	if has_left or _minigame != null or _story_playing:
		return
	has_left = true
	Sfx.play(&"ui_tap")
	for button: Button in [_minigame_button, _companion_button, _continue_button]:
		button.disabled = true
	EventBus.camp_left.emit()


## 摸摸金毛的頭。傳回 true 表示這一下增加了滿意度(每次營地有上限)。
## 太快連點(pet_cooldown_sec 之內)不算。
func pet_goldie() -> bool:
	if has_left or _minigame != null or _goldie == null or _story_playing:
		return false
	if _time - _last_pet_time < config.pet_cooldown_sec:
		return false
	_last_pet_time = _time
	pet_count += 1
	_goldie.pet()
	Sfx.play(&"pet")
	Haptics.play(&"light")
	_spawn_particles(config.heart_particles, _goldie.head_position() + Vector2(0, -6))
	var rewarded := pet_rewards < config.pet_rewards_per_visit and config.pet_satisfaction_gain > 0 \
			and GameState.satisfaction < MinigameGrading.SATISFACTION_MAX
	if rewarded:
		pet_rewards += 1
		GameState.satisfaction = clampi(GameState.satisfaction + config.pet_satisfaction_gain,
				MinigameGrading.SATISFACTION_MIN, MinigameGrading.SATISFACTION_MAX)
		_flying_hearts.append({"from": _goldie.head_position() + Vector2(0, -10), "age": 0.0})
	goldie_petted.emit(rewarded)
	return rewarded


## 點鬥牛犬:「汪!」
func tap_bulldog() -> void:
	if has_left or _minigame != null or not is_bulldog_visible() or _story_playing:
		return
	if _bark_left > config.bulldog_bark_sec * 0.5:
		return
	_bark_left = config.bulldog_bark_sec
	_bulldog_hop = 0.3
	Sfx.play(&"bark")
	Haptics.play(&"light")


## 點梅林:施法、閃光、magic 音效、輕震,對話泡泡說一句 CAMP_MERLIN_XX。
## 傳回說的那一句的翻譯鍵;沒有說話(故事中、小遊戲中、連點太快)時傳回空字串。
func tap_merlin() -> String:
	if has_left or _minigame != null or _story_playing or not is_merlin_visible():
		return ""
	if _time - _last_merlin_tap < config.merlin_tap_cooldown_sec:
		return ""
	var key := _next_merlin_line()
	if key == "":
		return ""
	_last_merlin_tap = _time
	merlin_taps += 1
	_merlin.cast()
	Sfx.play(config.merlin_sfx)
	Haptics.play(&"light")
	_merlin_bubble.show_text(tr(key), _merlin.speech_anchor(), config.merlin_bubble_sec)
	merlin_spoke.emit(key)
	return key


func is_merlin_visible() -> bool:
	return _merlin != null and _merlin.visible


## 跳過進場動畫(選單滑入、淡入)。測試與截圖用。
func finish_intro() -> void:
	_intro = 10.0
	_animate_menu()
	if _fade != null:
		_fade.visible = false


## 立刻放一顆流星(截圖用)。
func spawn_shooting_star() -> void:
	_sky.spawn_meteor()


# --- 營地故事(DS1)與梅林(DS2) ---

func _start_story() -> void:
	var script := story_script()
	if script == null or script.lines.is_empty() or _dialogue == null or not _dialogue.has_method(&"play"):
		return
	_story_playing = true
	story_played = true
	_menu.visible = false
	_refresh_stats()
	# 對白框(C 線)的 play() 播完才返回;它沒有 class_name,所以用 call()。
	await _dialogue.call(&"play", script)
	_end_story()


func _end_story() -> void:
	if not _story_playing:
		return
	_story_playing = false
	_menu.visible = _minigame == null
	_intro = 0.0      # 選單從下面滑出來
	_animate_menu()
	_refresh_stats()
	story_finished.emit()


## 隨機取一句,一輪說完才重複,而且不會連續兩次說同一句。
func _next_merlin_line() -> String:
	var lines := config.merlin_lines
	if lines.is_empty():
		return ""
	if _merlin_bag.is_empty():
		var bag := lines.duplicate()
		for i in range(bag.size() - 1, 0, -1):
			var j := _line_rng.randi_range(0, i)
			var tmp := bag[i]
			bag[i] = bag[j]
			bag[j] = tmp
		if bag.size() > 1 and bag[0] == _merlin_last_line:
			var first := bag[0]
			bag[0] = bag[bag.size() - 1]
			bag[bag.size() - 1] = first
		_merlin_bag = bag
	var key := _merlin_bag[0]
	_merlin_bag.remove_at(0)
	_merlin_last_line = key
	return key


# --- 小遊戲 ---

func _on_minigame_finished(_score: int, grade: int) -> void:
	minigame_plays += 1
	last_grade = grade


func _on_minigame_closed() -> void:
	var finished_score := _minigame.score
	var finished_grade := _minigame.grade
	var rewards := _minigame.rewards
	_minigame.queue_free()
	_minigame = null
	_set_camp_visible(true)
	_refresh_stats()
	_layout()
	_fade_in()
	_intro = 0.0
	# 獎勵回到營地時才「入帳」:條慢慢長、冒閃光和數字。
	var sparkle: PackedScene = load(SPARKLE_PATH) if ResourceLoader.exists(SPARKLE_PATH) else null
	if int(rewards.get("vigor", 0)) > 0:
		_bar_pulse["vigor"] = 1.0
		_add_floater("+%d" % int(rewards["vigor"]), _bar_tag(_vigor_label), config.vigor_bar_color)
		_spawn_particles(sparkle, _bar_end(_vigor_label, _vigor_ratio()), _stats)
	if int(rewards.get("satisfaction", 0)) > 0:
		_bar_pulse["satisfaction"] = 1.0
		_add_floater("+%d" % int(rewards["satisfaction"]), _bar_tag(_satisfaction_label), config.satisfaction_bar_color)
		_spawn_particles(sparkle, _bar_end(_satisfaction_label, _satisfaction_ratio()), _stats)
	if finished_grade >= 2:
		_goldie.pet()
	minigame_closed.emit(finished_score, finished_grade)


func _set_camp_visible(value: bool) -> void:
	for node: CanvasItem in [_sky, _ground, _glow, _actors, _front, _stats, _title, _vigor_label, _satisfaction_label, _bonus_label, _menu]:
		node.visible = value
	_pet_zone.visible = value
	_bulldog_zone.visible = value and is_bulldog_visible()
	if _merlin != null:
		_merlin.visible = value and config.merlin_frames != null
	_merlin_zone.visible = value and is_merlin_visible()
	if not value:
		_toast.visible = false
		_merlin_bubble.hide_bubble()
	_refresh_stats()


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast_left = config.toast_sec
	_toast.visible = true


func _vigor_ratio() -> float:
	var stats := GameState.player_stats
	if stats == null or stats.max_vigor <= 0:
		return 0.0
	return clampf(float(GameState.vigor) / stats.max_vigor, 0.0, 1.0)


func _satisfaction_ratio() -> float:
	return clampf(GameState.satisfaction / 100.0, 0.0, 1.0)


func _refresh_stats() -> void:
	if _vigor_label == null:
		return
	_bonus_label.visible = _menu.visible and GameState.next_level_bonus > 0.0
	_bonus_label.text = tr("CAMP_BONUS") % roundi(GameState.next_level_bonus * 100.0)


# --- 特效 ---

func _spawn_particles(scene: PackedScene, at: Vector2, parent: Control = null) -> void:
	if scene == null:
		return
	var fx := scene.instantiate()
	if fx is Node2D:
		(fx as Node2D).position = at.round()
	(parent if parent != null else _front).add_child(fx)


func _add_floater(text: String, at: Vector2, color: Color) -> void:
	_floaters.append({"text": text, "pos": at, "age": 0.0, "color": color})


func _bar_end(label: Label, ratio: float) -> Vector2:
	return label.position + Vector2(42.0 + roundf(80.0 * ratio), 5.0)


## 條右邊放「+N」的地方(文字的基線)。
func _bar_tag(label: Label) -> Vector2:
	return label.position + Vector2(126.0, 11.0)


func _update_effects(delta: float) -> void:
	for f: Dictionary in _floaters:
		f["age"] = float(f["age"]) + delta
		f["pos"] = (f["pos"] as Vector2) + Vector2(0, -8.0 * delta if float(f["age"]) < 0.5 else 0.0)
	_floaters = _floaters.filter(func(f: Dictionary) -> bool: return float(f["age"]) < 1.1)
	var arrived := 0
	for h: Dictionary in _flying_hearts:
		h["age"] = float(h["age"]) + delta
		if float(h["age"]) >= 0.6 and not h.has("done"):
			h["done"] = true
			arrived += 1
	_flying_hearts = _flying_hearts.filter(func(h: Dictionary) -> bool: return float(h["age"]) < 0.6)
	for i in arrived:
		_bar_pulse["satisfaction"] = 1.0
		_add_floater("+%d" % config.pet_satisfaction_gain, _bar_tag(_satisfaction_label), config.satisfaction_bar_color)
	# 還沒摸過時,金毛頭上冒「想被摸」的泡泡
	_goldie.show_hint = pet_count == 0 and _intro >= config.pet_hint_delay_sec and _menu.visible


func _animate_menu() -> void:
	# 選單從下面彈上來、淡入
	var t := clampf(_intro / 0.45, 0.0, 1.0)
	var ease_t := 1.0 - pow(1.0 - t, 3.0)
	_menu.position = _menu_rest + Vector2(0, roundf((1.0 - ease_t) * 24.0))
	_menu.modulate.a = ease_t


func _fade_in() -> void:
	_fade.color = Color(0.05, 0.03, 0.1, 1.0)
	_fade.visible = true
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 0.0, maxf(config.fade_sec, 0.01))
	tween.tween_callback(func() -> void: _fade.visible = false)


# --- 建立畫面 ---

func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "Layer"
	_layer.layer = config.canvas_layer
	add_child(_layer)

	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	MinigameUi.apply_shared_theme(_root)
	_layer.add_child(_root)
	_root.resized.connect(_layout)

	_sky = CampScenery.new(CampScenery.Part.SKY, config)
	_root.add_child(_sky)
	# 梅林畫在夜空與地面之間:地面上的圓桌會蓋住他的下半身,看起來就是坐在桌子後面。
	_merlin = CampMerlin.new(config)
	_merlin.visible = config.merlin_frames != null
	_root.add_child(_merlin)
	_ground = CampScenery.new(CampScenery.Part.GROUND, config)
	_root.add_child(_ground)

	_actors = Node2D.new()
	_actors.name = "Actors"
	_root.add_child(_actors)
	if config.fire_frames != null:
		var fire := AnimatedSprite2D.new()
		fire.name = "Fire"
		fire.sprite_frames = config.fire_frames
		if config.fire_frames.has_animation(config.fire_animation):
			fire.play(config.fire_animation)
		_actors.add_child(fire)
	_bulldog = AnimatedSprite2D.new()
	_bulldog.name = "Bulldog"
	_bulldog.sprite_frames = config.bulldog_frames
	_bulldog.scale = Vector2.ONE * config.bulldog_scale
	_bulldog.visible = config.bulldog_frames != null and GameState.level_index >= config.bulldog_from_level_index
	if config.bulldog_frames != null:
		for anim: StringName in [config.bulldog_animation, &"idle"]:
			if config.bulldog_frames.has_animation(anim):
				_bulldog.play(anim)
				break
	_actors.add_child(_bulldog)
	_goldie = CampGoldie.new(config)
	_actors.add_child(_goldie)
	_embers = _make_embers()
	_actors.add_child(_embers)
	_smoke = _make_smoke()
	_actors.add_child(_smoke)

	_glow = CampScenery.new(CampScenery.Part.GLOW, config)
	_root.add_child(_glow)

	_front = Control.new()
	_front.name = "Front"
	_front.set_anchors_preset(Control.PRESET_FULL_RECT)
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.draw.connect(_draw_front)
	_root.add_child(_front)
	_fireflies.clear()
	for i in config.firefly_count:
		# x, y(0 至 1 的相對位置)、相位、速度
		_fireflies.append(Vector4(_rng.randf(), _rng.randf(), _rng.randf() * TAU, _rng.randf_range(0.6, 1.2)))

	_stats = Control.new()
	_stats.name = "Stats"
	_stats.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats.draw.connect(_draw_stats)
	_root.add_child(_stats)

	_title = MinigameUi.make_title(tr("UI_CAMP"))
	_title.name = "Title"
	_root.add_child(_title)
	_vigor_label = MinigameUi.make_label(tr("CAMP_VIGOR"), config.small_font_size)
	_vigor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_root.add_child(_vigor_label)
	_satisfaction_label = MinigameUi.make_label(tr("CAMP_SATISFACTION"), config.small_font_size)
	_satisfaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_root.add_child(_satisfaction_label)
	_bonus_label = MinigameUi.make_label("", config.small_font_size, Color("ffe066"))
	_root.add_child(_bonus_label)

	_merlin_bubble = MinigameSpeechBubble.new()
	_merlin_bubble.name = "MerlinBubble"
	_merlin_bubble.max_width = config.merlin_bubble_width
	_root.add_child(_merlin_bubble)

	_pet_zone = _make_touch_zone("PetZone", pet_goldie)
	_bulldog_zone = _make_touch_zone("BulldogZone", tap_bulldog)
	_bulldog_zone.visible = is_bulldog_visible()
	_merlin_zone = _make_touch_zone("MerlinZone", tap_merlin)
	_merlin_zone.visible = is_merlin_visible()

	_menu = VBoxContainer.new()
	_menu.name = "Menu"
	_menu.add_theme_constant_override(&"separation", config.button_gap)
	_root.add_child(_menu)
	_minigame_button = _make_menu_button("MinigameButton", tr("UI_CAMP_MINIGAME"), Color("c0603a"), Color("3a1a10"), open_minigame)
	_companion_button = _make_menu_button("CompanionButton", tr("UI_CAMP_COMPANION"), Color("5a5670"), Color("24203a"), open_companion)
	if MinigameUi.has_shared_theme():
		_companion_button.theme_type_variation = &"ButtonAlt"
	_continue_button = _make_menu_button("ContinueButton", tr("UI_CAMP_CONTINUE"), Color("3a8a5a"), Color("123a24"), leave_camp)

	_toast = MinigameUi.make_label("", config.button_font_size, MinigameUi.WHITE)
	_toast.name = "Toast"
	_toast.visible = false
	var toast_box := StyleBoxFlat.new()
	toast_box.bg_color = Color(0.08, 0.06, 0.14, 0.92)
	toast_box.border_color = Color("ffe066")
	toast_box.set_border_width_all(1)
	toast_box.content_margin_left = 6
	toast_box.content_margin_right = 6
	toast_box.content_margin_top = 3
	toast_box.content_margin_bottom = 3
	_toast.add_theme_stylebox_override(&"normal", toast_box)
	_root.add_child(_toast)

	_fade = ColorRect.new()
	_fade.name = "Fade"
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0, 0, 0, 0)
	_fade.visible = false
	_root.add_child(_fade)

	# 營地自己的對白框(DS1):C 線的 ui/dialogue/dialogue_box.tscn(第 40 層,蓋在營地上面,擋住全部觸控)。
	if config.dialogue_box_scene != null:
		_dialogue = config.dialogue_box_scene.instantiate() as CanvasLayer
		if _dialogue != null:
			_dialogue.name = "DialogueBox"
			add_child(_dialogue)


func _make_menu_button(node_name: String, text: String, fill: Color, border: Color, action: Callable) -> Button:
	var button := MinigameUi.make_button(text, config.button_size, config.button_font_size, fill, border)
	button.name = node_name
	button.pressed.connect(action)
	# 按下時壓扁一下、放開時彈回來
	button.button_down.connect(func() -> void: _squash(button, 0.92))
	button.button_up.connect(func() -> void: _squash(button, 1.0))
	_menu.add_child(button)
	return button


func _squash(button: Button, to: float) -> void:
	button.pivot_offset = button.size * 0.5
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2(to, to), 0.08 if to < 1.0 else 0.18) \
			.set_trans(Tween.TRANS_BACK if to >= 1.0 else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _make_touch_zone(node_name: String, action: Callable) -> Control:
	var zone := Control.new()
	zone.name = node_name
	zone.mouse_filter = Control.MOUSE_FILTER_STOP
	zone.gui_input.connect(func(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			action.call()
			zone.accept_event())
	_root.add_child(zone)
	return zone


func _make_embers() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "Embers"
	p.amount = maxi(1, config.ember_amount)
	p.lifetime = 1.6
	p.preprocess = 1.6
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(7, 2)
	p.direction = Vector2(0, -1)
	p.spread = 18.0
	p.gravity = Vector2(0, -6)
	p.initial_velocity_min = 14.0
	p.initial_velocity_max = 28.0
	p.angular_velocity_min = 0.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.0
	p.tangential_accel_min = -8.0
	p.tangential_accel_max = 8.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 0.95, 0.55, 1))
	ramp.set_color(1, Color(1, 0.35, 0.15, 0))
	ramp.add_point(0.5, Color(1, 0.6, 0.2, 0.9))
	p.color_ramp = ramp
	p.emitting = config.ember_amount > 0
	return p


func _make_smoke() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "Smoke"
	p.amount = maxi(1, config.smoke_amount)
	p.lifetime = 2.6
	p.preprocess = 2.6
	p.direction = Vector2(0, -1)
	p.spread = 10.0
	p.gravity = Vector2(3, -2)
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 12.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.55, 0.5, 0.65, 0.0))
	ramp.set_color(1, Color(0.55, 0.5, 0.65, 0.0))
	ramp.add_point(0.25, Color(0.55, 0.5, 0.65, 0.22))
	p.color_ramp = ramp
	p.emitting = config.smoke_amount > 0
	return p


func _layout() -> void:
	if _root == null:
		return
	var safe := SafeArea.get_safe_rect()
	var game := SafeArea.get_game_rect()
	var screen := SafeArea.get_screen_size()
	var cx := roundf(safe.get_center().x)

	_title.size = Vector2(safe.size.x, 28)
	_title.position = Vector2(safe.position.x, safe.position.y + 2)
	var stats_y := safe.position.y + 30.0
	_vigor_label.size = Vector2(40, 12)
	_vigor_label.position = Vector2(cx - 64, stats_y)
	_satisfaction_label.size = Vector2(40, 12)
	_satisfaction_label.position = Vector2(cx - 64, stats_y + 13)
	_bonus_label.size = Vector2(safe.size.x, 12)
	_bonus_label.position = Vector2(safe.position.x, stats_y + 27)

	var menu_size := Vector2(config.button_size.x, config.button_size.y * 3 + config.button_gap * 2)
	var menu_bottom := safe.end.y - config.menu_bottom_margin
	_menu.size = menu_size
	_menu_rest = Vector2(cx - roundf(menu_size.x * 0.5), roundf(menu_bottom - menu_size.y))
	_menu.position = _menu_rest

	# 場景放在標題與選單之間;長螢幕時置中於遊戲區附近。
	var scene_top := maxf(stats_y + 40.0, game.position.y + 80.0)
	var scene_bottom := _menu_rest.y - 6.0
	var mid := roundf(lerpf(scene_top, scene_bottom, 0.5))
	var table_spot := Vector2(cx, mid - 22.0)
	_fire_spot = Vector2(cx - 16.0, mid + 24.0)
	_bulldog_spot = Vector2(cx - 58.0, mid + 18.0)
	var goldie_spot := Vector2(cx + 34.0, mid + 28.0)
	for part: CampScenery in [_sky, _ground, _glow]:
		part.horizon_y = table_spot.y + 4.0
		part.fire_spot = _fire_spot
		part.table_spot = table_spot
		part.log_spot = _bulldog_spot + Vector2(0, 22)
		part.moon_spot = Vector2(screen.x - 28.0, roundf(lerpf(stats_y + 36.0, table_spot.y, 0.3)))
		part.queue_redraw()
	_goldie.position = goldie_spot
	_bulldog.position = _bulldog_spot
	_embers.position = _fire_spot + Vector2(0, -6)
	_smoke.position = _fire_spot + Vector2(0, -22)
	var fire := _actors.get_node_or_null(^"Fire") as Node2D
	if fire != null:
		fire.position = _fire_spot
	var pet_rect := _goldie.touch_rect()
	_pet_zone.position = pet_rect.position
	_pet_zone.size = pet_rect.size
	_merlin.position = table_spot + config.merlin_offset
	var merlin_rect := _merlin.sprite_rect()
	# 只有桌面以上看得到的部分可以點(桌面約在圓桌中心上方 12 像素)
	var merlin_bottom := minf(merlin_rect.end.y, table_spot.y - 4.0)
	var merlin_zone := Rect2(merlin_rect.position, Vector2(merlin_rect.size.x, merlin_bottom - merlin_rect.position.y)).grow(config.merlin_touch_margin)
	_merlin_zone.position = merlin_zone.position
	_merlin_zone.size = merlin_zone.size
	_merlin_bubble.move_to(_merlin.speech_anchor())
	var bulldog_size := Vector2(24, 24) * config.bulldog_scale
	var bulldog_rect := Rect2(_bulldog_spot - bulldog_size * 0.5, bulldog_size).grow(2.0)
	_bulldog_zone.position = bulldog_rect.position
	_bulldog_zone.size = bulldog_rect.size

	_toast.size = Vector2(minf(156.0, safe.size.x - 16.0), 20)
	_toast.position = Vector2(cx - roundf(_toast.size.x * 0.5), _menu_rest.y - 26.0)
	_front.queue_redraw()
	_stats.queue_redraw()


# --- 繪圖 ---

func _draw_front() -> void:
	# 螢火蟲:在草地與夜空交界附近慢慢飛,一閃一閃
	var area := Rect2(0, _sky.horizon_y - 50.0, SafeArea.get_screen_size().x, 110.0)
	for f in _fireflies:
		var t := _time * f.w
		var pos := area.position + Vector2(f.x * area.size.x + sin(t + f.z) * 10.0, f.y * area.size.y + cos(t * 1.3 + f.z) * 6.0)
		var glow := 0.5 + 0.5 * sin(_time * 2.2 * f.w + f.z * 3.0)
		if absf(pos.x - _fire_spot.x) < 18.0 and absf(pos.y - _fire_spot.y) < 30.0:
			continue
		var p := pos.round()
		_front.draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), Color(0.85, 1.0, 0.45, 0.18 * glow))
		_front.draw_rect(Rect2(p, Vector2.ONE), Color(0.95, 1.0, 0.6, 0.35 + 0.65 * glow))
	# 鬥牛犬的「汪!」
	if _bark_left > 0.0 and is_bulldog_visible():
		var at := (_bulldog_spot + Vector2(10, -34)).round()
		var box := Rect2(at - Vector2(14, 8), Vector2(28, 15))
		_front.draw_rect(box.grow(1), MinigameUi.INK)
		_front.draw_rect(box, MinigameUi.WHITE)
		_front.draw_rect(Rect2(at + Vector2(-8, 7), Vector2(3, 3)), MinigameUi.INK)
		_front.draw_rect(Rect2(at + Vector2(-7, 7), Vector2(1, 2)), MinigameUi.WHITE)
		var font := _title.get_theme_font(&"font")
		_front.draw_string(font, at + Vector2(-12, 5), tr("CAMP_BULLDOG_BARK"), HORIZONTAL_ALIGNMENT_CENTER, 24, MinigameUi.FONT_S, MinigameUi.INK)


func _draw_stats() -> void:
	if not _stats.visible:
		return
	# 活力與滿意度的條(增加時閃一下、變粗)
	_draw_bar(_vigor_label.position + Vector2(42, 3), _shown_vigor, config.vigor_bar_color, float(_bar_pulse["vigor"]))
	_draw_bar(_satisfaction_label.position + Vector2(42, 3), _shown_satisfaction, config.satisfaction_bar_color, float(_bar_pulse["satisfaction"]))
	MinigameUi.draw_heart(_stats, _satisfaction_label.position + Vector2(130, 6), 1.0)
	# 飛向滿意度條的愛心
	for h: Dictionary in _flying_hearts:
		var t := clampf(float(h["age"]) / 0.6, 0.0, 1.0)
		var from := h["from"] as Vector2
		var to := _bar_end(_satisfaction_label, _shown_satisfaction)
		var ctrl := Vector2(lerpf(from.x, to.x, 0.3), minf(from.y, to.y) - 30.0)
		var a := from.lerp(ctrl, t)
		var b := ctrl.lerp(to, t)
		MinigameUi.draw_heart(_stats, a.lerp(b, t * t), 1.0 + (1.0 if t < 0.5 else 0.0))
	# 跳起的數字
	var font_small := _title.get_theme_font(&"font")
	for f: Dictionary in _floaters:
		var alpha := clampf(1.0 - (float(f["age"]) - 0.6) / 0.5, 0.0, 1.0)
		var pos := (f["pos"] as Vector2).round()
		_stats.draw_string_outline(font_small, pos, f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, MinigameUi.FONT_S, 4, Color(MinigameUi.INK, alpha))
		_stats.draw_string(font_small, pos, f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, MinigameUi.FONT_S, Color(f["color"] as Color, alpha))
	# 玩過小遊戲後,在按鈕旁邊顯示拿到的星星
	if last_grade >= 0 and _menu.visible:
		var button_rect := Rect2(_menu.position + _minigame_button.position, _minigame_button.size)
		for i in 3:
			var star_at := Vector2(button_rect.end.x - 26.0 + i * 10.0, button_rect.position.y - 1.0)
			MinigameUi.draw_star(_stats, star_at, 4.0, i < last_grade)


func _draw_bar(at: Vector2, ratio: float, color: Color, pulse: float) -> void:
	var rect := Rect2(at.round(), Vector2(80, 6))
	var grow := 1.0 if pulse > 0.0 else 0.0
	_stats.draw_rect(rect.grow(1 + grow), MinigameUi.INK)
	_stats.draw_rect(rect.grow(grow), Color("2a2440"))
	var fill := color.lerp(Color.WHITE, pulse * 0.6)
	var fill_rect := Rect2(rect.position - Vector2(grow, grow), Vector2(roundf(rect.size.x * ratio) + grow * 2.0, rect.size.y + grow * 2.0))
	_stats.draw_rect(fill_rect, fill)
	_stats.draw_rect(Rect2(fill_rect.position, Vector2(fill_rect.size.x, 1)), fill.lightened(0.35))
	_stats.draw_rect(Rect2(fill_rect.position + Vector2(0, fill_rect.size.y - 1), Vector2(fill_rect.size.x, 1)), fill.darkened(0.2))
