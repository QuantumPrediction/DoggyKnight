extends SceneTree
## 商店截圖產生器(DEV_PLAN 11 D11)。
##
## 做法:把遊戲畫面以「手機實際會用的邏輯解析度」算繪(和 ScreenFit 的算法相同),
## 再用最近鄰(nearest)整數倍放大到商店要求的像素,像素不會模糊。
## 放大後不足一個倍數的幾個像素,用邊緣的像素補滿(真機上這裡是不到一個邏輯像素的黑邊)。
##
## 用法(需要有畫面的環境;雲端用 Xvfb):
##   xvfb-run -a godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##     --script res://store/screenshots/capture.gd -- --out=$HOME/doggyknight_store_screenshots
## 在自己的電腦上(Windows / macOS)把 xvfb-run -a 拿掉即可。
##
## 參數(放在 -- 之後):
##   --out=<資料夾>       輸出位置(預設 ~/doggyknight_store_screenshots;請放在 repo 以外)
##   --scene=<res://路徑>  另外截取任何場景(可重複;例如整合後的 res://game/flow/main.tscn)
##   --frames=<數字>       截取 --scene 之前等待的格數(預設 90)
##
## 截取的畫面:01 營地(摸摸頭)、02 小遊戲「完美!」、03 小遊戲評價、
## 04 對白(石中劍之丘,梅林登場)、05 繪本頁(開場插畫)、06 營地的梅林(對話泡泡)。
## 04、05 用 C 線的對白框(ui/dialogue/dialogue_box.tscn)播放用程式建立的 DialogueScript,
## 文字、頭像、插畫都是遊戲裡真正的素材(docs/STORY.md)。

const TARGETS: Array[Dictionary] = [
	{"name": "googleplay_phone_1080x1920", "size": Vector2i(1080, 1920)},
	{"name": "appstore_6.9in_1290x2796", "size": Vector2i(1290, 2796)},
	{"name": "appstore_6.9in_1320x2868", "size": Vector2i(1320, 2868)},
]

const CAMP_SCENE := "res://game/camp/camp.tscn"
const DIALOGUE_BOX := "res://ui/dialogue/dialogue_box.tscn"
const DIALOGUE_BACKGROUND := "res://assets/backgrounds/sword_stone.tscn"
const GOLDIE_FRAMES := "res://assets/sprites/goldie/goldie_frames.tres"
const MERLIN_FRAMES := "res://assets/sprites/merlin/merlin_frames.tres"
## 對白框逐字顯示完一整句需要的格數(C 線的正式版有打字效果)。
const DIALOGUE_SETTLE_FRAMES: int = 150

var _out_dir: String = ""
var _extra_scenes: PackedStringArray = []
var _extra_frames: int = 90


func _initialize() -> void:
	_out_dir = OS.get_environment("HOME").path_join("doggyknight_store_screenshots")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--scene="):
			_extra_scenes.append(arg.trim_prefix("--scene="))
		elif arg.begins_with("--frames="):
			_extra_frames = int(arg.trim_prefix("--frames="))
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("商店截圖需要算繪畫面:不要用 --headless(雲端請用 xvfb-run)。")
		quit(1)
		return
	var screen_fit := root.get_node("ScreenFit")
	for target: Dictionary in TARGETS:
		var px: Vector2i = target["size"]
		var scale: int = screen_fit.call("compute_scale", px)
		var logical: Vector2i = screen_fit.call("compute_viewport_size", px)
		var dir := _out_dir.path_join(target["name"])
		DirAccess.make_dir_recursive_absolute(dir)
		await _set_window(logical)
		print("%s: logical %s × %d → %s" % [target["name"], logical, scale, px])
		await _shot_camp(dir, px, scale)
		await _shot_scroll(dir, px, scale)
		await _shot_dialogue(dir, px, scale)
		await _shot_storybook(dir, px, scale)
		await _shot_camp_merlin(dir, px, scale)
		for i in _extra_scenes.size():
			var node := (load(_extra_scenes[i]) as PackedScene).instantiate()
			root.add_child(node)
			await _frames(_extra_frames)
			await _save(dir.path_join("%02d_%s.png" % [10 + i, _extra_scenes[i].get_file().get_basename()]), px, scale)
			node.queue_free()
			await _frames(2)
	print("store screenshots written to ", _out_dir)
	quit(0)


## 營地:第二次營地(鬥牛犬在火旁),正在摸金毛的頭,天上剛好有流星。
func _shot_camp(dir: String, px: Vector2i, scale: int) -> void:
	var game_state := root.get_node("GameState")
	game_state.call("reset_run")
	game_state.set("vigor", 70)
	game_state.set("satisfaction", 40)
	game_state.set("level_index", 3)
	var camp := (load(CAMP_SCENE) as PackedScene).instantiate()
	root.add_child(camp)
	await _frames(2)
	await _skip_camp_story(camp)
	await _frames(28)
	camp.call("finish_intro")
	camp.call("spawn_shooting_star")
	await _frames(8)
	camp.call("pet_goldie")
	await _frames(14)
	await _save(dir.path_join("01_camp.png"), px, scale)
	camp.queue_free()
	await _frames(2)


func _shot_scroll(dir: String, px: Vector2i, scale: int) -> void:
	root.get_node("GameState").call("reset_run")
	var camp := (load(CAMP_SCENE) as PackedScene).instantiate()
	root.add_child(camp)
	await _frames(2)
	camp.call("open_minigame")
	await _frames(2)
	var game: Object = camp.call("get_minigame")
	game.call("set_process", false)
	camp.call("finish_intro")
	var cfg: Object = game.get("config")
	game.call("step", float(cfg.get("countdown_sec")) + 0.8)
	# 拉到第一個墨水漬,一到就停手:畫面上是「完美!」、閃光與加分。
	var stop_at: float = game.call("next_ink_stop_at")
	while float(game.get("pulled_px")) < stop_at:
		game.call("simulate_swipe", 20.0, 2)
		game.call("step", 0.05)
	game.call("step", float(cfg.get("ink_still_sec")) + 0.02)
	game.call("step", 0.1)
	await _frames(3)
	await _save(dir.path_join("02_scroll_minigame.png"), px, scale)
	# 評價畫面(3 顆星,全部亮起)。先等墨水漬滑過去,不然設定的長度會被蓋掉。
	game.call("step", float(cfg.get("ink_pass_sec")) + 0.1)
	var three_star: int = (cfg.get("grading") as MinigameGrading).grade_thresholds[-1]
	game.set("pulled_px", float(three_star + 12) * float(cfg.get("px_per_score")))
	game.call("step", float(cfg.get("duration_sec")))
	game.call("step", float(cfg.get("results_delay_sec")) + 0.05)
	for i in 8:
		game.call("step", 0.25)
	await _frames(3)
	await _save(dir.path_join("03_scroll_results.png"), px, scale)
	camp.queue_free()
	await _frames(2)


## 對白:1-1 石中劍之丘,金毛與梅林站在場地上,梅林自我介紹(STORY_L1_BEFORE_03)。
func _shot_dialogue(dir: String, px: Vector2i, scale: int) -> void:
	var stage := _make_stage(true)
	root.add_child(stage)
	var box := _make_dialogue_box()
	if box == null:
		stage.queue_free()
		return
	await _frames(2)
	box.call("play", _script(&"store_dialogue", [["STORY_L1_BEFORE_03", &"merlin", &"proud", ""],
			["STORY_L1_BEFORE_04", &"goldie", &"surprised", ""]]))
	await _frames(DIALOGUE_SETTLE_FRAMES)
	await _save(dir.path_join("04_dialogue.png"), px, scale)
	box.queue_free()
	stage.queue_free()
	await _frames(2)


## 繪本頁:開場第三頁(石上刻著「拔出此劍者,即為卡美洛之王。」,插畫 prologue_2)。
func _shot_storybook(dir: String, px: Vector2i, scale: int) -> void:
	var stage := _make_stage(false)
	root.add_child(stage)
	var box := _make_dialogue_box()
	if box == null:
		stage.queue_free()
		return
	await _frames(2)
	box.call("play", _script(&"store_storybook", [["STORY_PROLOGUE_03", &"narrator", &"normal", "res://assets/story/prologue_2.png"],
			["STORY_PROLOGUE_04", &"narrator", &"normal", "res://assets/story/prologue_3.png"]]))
	await _frames(DIALOGUE_SETTLE_FRAMES)
	await _save(dir.path_join("05_storybook.png"), px, scale)
	box.queue_free()
	stage.queue_free()
	await _frames(2)


## 營地的梅林:第一次營地,點梅林,他在圓桌後面說一句話(對話泡泡)。
func _shot_camp_merlin(dir: String, px: Vector2i, scale: int) -> void:
	var game_state := root.get_node("GameState")
	game_state.call("reset_run")
	game_state.set("vigor", 60)
	game_state.set("satisfaction", 20)
	game_state.set("level_index", 1)
	var camp := (load(CAMP_SCENE) as PackedScene).instantiate()
	var cfg := (camp.get("config") as CampConfig).duplicate() as CampConfig
	# 固定說「營火、星星和好朋友,就是最好的魔法。」
	cfg.merlin_lines = PackedStringArray(["CAMP_MERLIN_04"])
	camp.set("config", cfg)
	root.add_child(camp)
	await _frames(2)
	await _skip_camp_story(camp)
	await _frames(28)
	camp.call("finish_intro")
	camp.call("tap_merlin")
	await _frames(40)
	await _save(dir.path_join("06_camp_merlin.png"), px, scale)
	camp.queue_free()
	await _frames(2)


func _skip_camp_story(camp: Node) -> void:
	for i in 60:
		if not camp.call("is_story_playing"):
			return
		camp.call("skip_story")
		await _frames(1)


## 場地背景(加上金毛與梅林),用 Camera2D 把遊戲區置中(DEV_PLAN 4.8)。
func _make_stage(with_actors: bool) -> Node2D:
	var stage := Node2D.new()
	stage.name = "StoreStage"
	var camera := Camera2D.new()
	camera.position = SafeArea.GAME_CENTER
	stage.add_child(camera)
	if ResourceLoader.exists(DIALOGUE_BACKGROUND):
		stage.add_child((load(DIALOGUE_BACKGROUND) as PackedScene).instantiate())
	if with_actors:
		for actor: Array in [[GOLDIE_FRAMES, Vector2(72, 112), false], [MERLIN_FRAMES, Vector2(110, 108), true]]:
			if not ResourceLoader.exists(actor[0]):
				continue
			var sprite := AnimatedSprite2D.new()
			sprite.sprite_frames = load(actor[0]) as SpriteFrames
			sprite.position = actor[1]
			sprite.flip_h = actor[2]
			if sprite.sprite_frames.has_animation(&"idle"):
				sprite.play(&"idle")
			stage.add_child(sprite)
	camera.ready.connect(camera.make_current)
	return stage


func _make_dialogue_box() -> Node:
	if not ResourceLoader.exists(DIALOGUE_BOX):
		push_warning("沒有對白框:略過對白截圖")
		return null
	var box := (load(DIALOGUE_BOX) as PackedScene).instantiate()
	root.add_child(box)
	return box


## [翻譯鍵, speaker, 表情, 插畫路徑(可空白)]
static func _script(id: StringName, rows: Array) -> DialogueScript:
	var script := DialogueScript.new()
	script.id = id
	var lines: Array[DialogueLine] = []
	for row: Array in rows:
		var line := DialogueLine.new()
		line.text_key = row[0]
		line.speaker = row[1]
		line.expression = row[2]
		if String(row[3]) != "" and ResourceLoader.exists(row[3]):
			line.illustration = load(row[3]) as Texture2D
		lines.append(line)
	script.lines = lines
	return script


func _set_window(logical: Vector2i) -> void:
	DisplayServer.window_set_size(logical)
	root.size = logical
	await _frames(3)
	root.get_node("ScreenFit").call("_refit")
	await _frames(3)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(path: String, px: Vector2i, scale: int) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	var final := _pad_to(img, px)
	final.save_png(path)
	print("  ", path, " ", final.get_size())


## 置中貼上,四周不足的幾個像素用最靠近的邊緣像素補上。
static func _pad_to(img: Image, size: Vector2i) -> Image:
	if img.get_size() == size:
		return img
	var out := Image.create(size.x, size.y, false, img.get_format())
	var offset := (size - img.get_size()) / 2
	out.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), offset)
	var src := Rect2i(offset, img.get_size())
	for y in size.y:
		var cy := clampi(y, src.position.y, src.end.y - 1)
		if y == cy:
			# 中間的列:只補左右兩邊
			for x in range(0, src.position.x):
				out.set_pixel(x, y, out.get_pixel(src.position.x, y))
			for x in range(src.end.x, size.x):
				out.set_pixel(x, y, out.get_pixel(src.end.x - 1, y))
		else:
			# 上下多出的列:整列複製最近的一列
			for x in size.x:
				out.set_pixel(x, y, out.get_pixel(clampi(x, src.position.x, src.end.x - 1), cy))
	return out
