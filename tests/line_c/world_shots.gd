extends Node
## C 世界截圖工具(v2.6、v2.7,不是自動化測試):把背景(放幾個角色)與標題畫面截成 3 倍大的 PNG。
##
## 執行(需要畫面,雲端用 Xvfb):
##   xvfb-run -a godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##     res://tests/line_c/world_shots.tscn -- --out=/tmp/shots [--bgs=meadow,bridge|all] [--titles=0,1,2,3] [--tall]
## --tall 把畫面設成 180×390(長手機),看延伸出來的背景。

const ALL_BGS: Array[String] = ["sword_stone", "wheat_field", "meadow", "farm_fence", "crow_forest", "bridge",
		"castle_town", "castle_courtyard", "royal_library", "castle_wall", "magic_garden", "green_chapel",
		"misty_lake", "fairy_forest", "stone_circle", "crystal_cave", "morgana_tower", "tower_top",
		"golden_beach", "sea_cliffs", "pirate_ship", "coral_reef", "sunken_city", "sunken_palace",
		"snowfield", "ice_cave", "hot_springs", "avalanche_pass", "volcano", "dragon_nest",
		"camlann_field", "shadow_camp", "occupied_town", "throne_hall", "avalon_gate", "avalon_hill"]

var out_dir: String = "/tmp/world_shots"
var bgs: Array[String] = []
var titles: Array[int] = []
var screen: Vector2i = Vector2i(180, 320)


func _ready() -> void:
	var any_bg := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--bgs="):
			any_bg = true
			var v := arg.trim_prefix("--bgs=")
			if v == "all":
				bgs.assign(ALL_BGS)
			else:
				for b in v.split(","):
					bgs.append(b)
		elif arg.begins_with("--titles="):
			for t in arg.trim_prefix("--titles=").split(","):
				titles.append(int(t))
		elif arg == "--tall":
			screen = Vector2i(180, 390)
	if not any_bg and titles.is_empty():
		bgs.assign(ALL_BGS)
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = screen * 3
	get_tree().root.size = screen * 3
	await _frames(3)
	for bg in bgs:
		await _shoot_background(bg)
	for t in titles:
		await _shoot_title(t)
	get_tree().quit()


func _shoot_background(bg: String) -> void:
	var holder := Node2D.new()
	add_child(holder)
	var cam := Camera2D.new()
	cam.position = SafeArea.GAME_CENTER
	holder.add_child(cam)
	cam.make_current()
	holder.add_child((load("res://assets/backgrounds/%s.tscn" % bg) as PackedScene).instantiate())
	var cast: Array = [["goldie", &"idle", Vector2(90, 232)], ["bulldog", &"idle", Vector2(62, 240)],
			["scarecrow", &"run", Vector2(48, 140)], ["crow", &"run", Vector2(150, 190)],
			["scarecrow_archer", &"aim", Vector2(140, 250)], ["armored_husk", &"idle", Vector2(120, 110)]]
	for c: Array in cast:
		var body := Node2D.new()
		body.position = c[2]
		body.add_to_group(&"player" if c[0] == "goldie" else (&"companion" if c[0] == "bulldog" else &"enemy"))
		var s := AnimatedSprite2D.new()
		s.name = "Sprite"
		s.sprite_frames = load("res://assets/sprites/%s/%s_frames.tres" % [c[0], c[0]]) as SpriteFrames
		s.flip_h = (c[2] as Vector2).x > 100.0
		body.add_child(s)
		holder.add_child(body)
		s.play(c[1])
	await _frames(20)
	await _save("bg_%s.png" % bg)
	holder.queue_free()
	await _frames(2)


func _shoot_title(cleared: int) -> void:
	GameState.chapters_cleared = cleared
	GameState.chapter_cleared = cleared >= 1
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var title := (load("res://ui/screens/title.tscn") as PackedScene).instantiate() as Control
	layer.add_child(title)
	title.call(&"setup", cleared >= 1)
	await _frames(90)
	await _save("title_%d.png" % cleared)
	layer.queue_free()
	await _frames(2)


func _save(file: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.resize(image.get_width() * 3, image.get_height() * 3, Image.INTERPOLATE_NEAREST)
	image.save_png(out_dir.path_join(file))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
