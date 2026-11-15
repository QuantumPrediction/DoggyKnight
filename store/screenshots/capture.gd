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

const TARGETS: Array[Dictionary] = [
	{"name": "googleplay_phone_1080x1920", "size": Vector2i(1080, 1920)},
	{"name": "appstore_6.9in_1290x2796", "size": Vector2i(1290, 2796)},
	{"name": "appstore_6.9in_1320x2868", "size": Vector2i(1320, 2868)},
]

const CAMP_SCENE := "res://game/camp/camp.tscn"

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
		for i in _extra_scenes.size():
			var node := (load(_extra_scenes[i]) as PackedScene).instantiate()
			root.add_child(node)
			await _frames(_extra_frames)
			await _save(dir.path_join("%02d_%s.png" % [10 + i, _extra_scenes[i].get_file().get_basename()]), px, scale)
			node.queue_free()
			await _frames(2)
	print("store screenshots written to ", _out_dir)
	quit(0)


func _shot_camp(dir: String, px: Vector2i, scale: int) -> void:
	var game_state := root.get_node("GameState")
	game_state.call("reset_run")
	game_state.set("vigor", 70)
	game_state.set("satisfaction", 40)
	var camp := (load(CAMP_SCENE) as PackedScene).instantiate()
	root.add_child(camp)
	await _frames(40)
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
	game.call("step", float(game.get("config").get("countdown_sec")) + 0.05)
	# 拉到第一個墨水漬快到咬住位置的地方:畫面上看得到墨水漬與金毛頭上的「!」。
	var stop_at: float = game.call("next_ink_stop_at")
	while float(game.get("pulled_px")) < stop_at - 30.0:
		game.call("simulate_swipe", 20.0, 2)
		game.call("step", 0.05)
	game.call("step", 2.0)
	await _frames(3)
	await _save(dir.path_join("02_scroll_minigame.png"), px, scale)
	# 評價畫面(3 顆星)
	var cfg: Object = game.get("config")
	var three_star: int = (cfg.get("grading") as MinigameGrading).grade_thresholds[-1]
	game.set("pulled_px", float(three_star + 12) * float(cfg.get("px_per_score")))
	game.call("step", float(cfg.get("duration_sec")))
	game.call("step", float(cfg.get("results_delay_sec")) + 0.05)
	game.call("step", 1.2)
	await _frames(3)
	await _save(dir.path_join("03_scroll_results.png"), px, scale)
	camp.queue_free()
	await _frames(2)


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
