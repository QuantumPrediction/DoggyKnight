extends Node2D
## v2.7 C 角色圖庫(開發工具,不是自動化測試;文字不翻譯)。
## 第 0 頁:五個小敵人的每個動畫;第 1 頁:影子騎士、崔斯坦、高文;第 2 頁:莫德雷德;第 3 頁:章魚王;
## 第 4 頁:紅龍;第 5 頁:白龍;第 6 頁:頭像、投射物、粒子;
## 第 7 頁:章魚王、雙龍、莫德雷德與同伴站在戰鬥區下緣(看得到腳下影子,紅線是下緣)。
## 點畫面換下一頁。
##
## 執行:godot --path . res://tests/line_c/cast_v27_gallery.tscn
## 截圖(雲端用 Xvfb):
##   xvfb-run -a godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##     res://tests/line_c/cast_v27_gallery.tscn -- --shots=/tmp/line_c_shots/v27_cast

const SMALL: Array = [
	["crab", [&"idle", &"run", &"attack", &"hurt", &"guard"]],
	["jellyfish", [&"idle", &"run", &"attack", &"hurt", &"zap"]],
	["snowman", [&"idle", &"run", &"attack", &"hurt", &"throw"]],
	["salamander", [&"idle", &"run", &"attack", &"hurt", &"dash"]],
	["lantern_wisp", [&"idle", &"run", &"attack", &"hurt", &"heal"]],
]
const MEDIUM: Array = [
	["shadow_knight", [&"idle", &"run", &"attack", &"hurt", &"guard", &"down"]],
	["tristan", [&"idle", &"run", &"attack", &"hurt", &"play"]],
]
const GAWAIN: Array[StringName] = [&"idle", &"run", &"attack", &"hurt", &"slam"]
const MORDRED: Array[StringName] = [&"idle", &"run", &"attack", &"hurt", &"dash", &"slash", &"guard", &"summon", &"down"]
const KRAKEN: Array[StringName] = [&"idle", &"run", &"attack", &"hurt", &"slam", &"ink", &"summon", &"down"]
const DRAGON: Array[StringName] = [&"idle", &"run", &"attack", &"hurt", &"breath", &"roar", &"sulk"]
const PORTRAITS: Array = [
	["tristan", ["normal", "happy", "serious", "surprised"]], ["gawain", ["normal", "happy", "serious"]],
	["kraken", ["normal"]], ["red_dragon", ["normal"]], ["white_dragon", ["normal"]],
	["mordred", ["normal", "smirk", "angry", "sad"]],
]
const PROJECTILES: Array[String] = ["bubble", "ink_blob", "music_note", "snowball", "fireball", "ice_shard",
		"shadow_slash", "tentacle"]
const PARTICLES: Array[String] = ["snow_burst", "bubble_pop"]
const PAGES := 8

var page: int = 0
var _root: Node2D


func _ready() -> void:
	var cam := Camera2D.new()
	cam.position = SafeArea.GAME_CENTER
	add_child(cam)
	cam.make_current()
	var shots := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.trim_prefix("--shots=")
	show_page(0)
	if shots != "":
		_take_shots(shots)


func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
		show_page((page + 1) % PAGES)


func show_page(i: int) -> void:
	page = i
	if _root != null:
		_root.queue_free()
	_root = Node2D.new()
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color("7d9a6a") if i != 6 else Color("3b4a80")
	bg.size = Vector2(240, 400)
	bg.position = Vector2(-30, -40)
	bg.z_index = -200
	if i != 7:
		_root.add_child(bg)
	match i:
		0:
			var y := 22.0
			for row: Array in SMALL:
				var x := 16.0
				for anim: StringName in row[1]:
					_sprite(row[0], anim, Vector2(x, y))
					x += 36.0
				y += 34.0
		1:
			var y := 24.0
			for row: Array in MEDIUM:
				var x := 18.0
				for anim: StringName in row[1]:
					_sprite(row[0], anim, Vector2(x, y))
					x += 29.0
				y += 40.0
			for k in GAWAIN.size():
				_sprite("gawain", GAWAIN[k], Vector2(26 + (k % 3) * 56, 128 + (k / 3) * 48))
		2:
			for k in MORDRED.size():
				_sprite("mordred", MORDRED[k], Vector2(30 + (k % 3) * 58, 34 + (k / 3) * 56))
		3:
			for k in KRAKEN.size():
				_sprite("kraken", KRAKEN[k], Vector2(50 + (k % 2) * 80, 36 + (k / 2) * 66))
		4, 5:
			var code := "red_dragon" if i == 4 else "white_dragon"
			for k in DRAGON.size():
				_sprite(code, DRAGON[k], Vector2(50 + (k % 2) * 80, 36 + (k / 2) * 66))
		6:
			var n := 0
			for entry: Array in PORTRAITS:
				for expr: String in entry[1]:
					var s := Sprite2D.new()
					s.texture = load("res://assets/portraits/%s/%s.png" % [entry[0], expr])
					s.position = Vector2(30 + (n % 3) * 60, 26 + (n / 3) * 50)
					_root.add_child(s)
					n += 1
			for k in PROJECTILES.size():
				var p := AnimatedSprite2D.new()
				p.sprite_frames = load("res://assets/fx/%s/%s_frames.tres" % [PROJECTILES[k], PROJECTILES[k]])
				p.position = Vector2(14 + k * 20, 298) if PROJECTILES[k] != "tentacle" else Vector2(166, 270)
				p.play(&"default")
				_root.add_child(p)
			for k in PARTICLES.size():
				_burst_forever(PARTICLES[k], Vector2(40 + k * 60, 278))
		7:
			var arena := (load("res://assets/backgrounds/bridge.tscn") as PackedScene).instantiate()
			_root.add_child(arena)
			var bottom := Layout.ARENA_RECT.end.y
			# 和 A 線一樣:角色中心最低到「下緣 - (格子一半 - 2)」
			_actor("kraken", &"idle", Vector2(40, bottom - 30), &"enemy")
			_actor("red_dragon", &"idle", Vector2(100, bottom - 30), &"enemy")
			_actor("white_dragon", &"idle", Vector2(150, bottom - 30), &"enemy")
			_actor("mordred", &"idle", Vector2(60, bottom - 86), &"enemy")
			_actor("goldie", &"idle", Vector2(110, bottom - 84), &"player")
			_actor("tristan", &"idle", Vector2(140, bottom - 84), &"companion")
			_actor("gawain", &"idle", Vector2(30, bottom - 130), &"companion")
			_actor("shadow_knight", &"idle", Vector2(80, bottom - 132), &"enemy")
			_actor("crab", &"idle", Vector2(120, bottom - 130), &"enemy")
			_actor("snowman", &"idle", Vector2(150, bottom - 130), &"enemy")
			_actor("salamander", &"idle", Vector2(100, bottom - 160), &"enemy")
			var edge := Line2D.new()
			edge.points = PackedVector2Array([Vector2(Layout.ARENA_RECT.position.x, bottom),
					Vector2(Layout.ARENA_RECT.end.x, bottom)])
			edge.width = 1.0
			edge.default_color = Color(1, 0.3, 0.3, 0.8)
			edge.z_index = 50
			_root.add_child(edge)


func _sprite(code: String, anim: StringName, pos: Vector2) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = load("res://assets/sprites/%s/%s_frames.tres" % [code, code])
	s.position = pos
	s.play(anim)
	s.animation_finished.connect(func() -> void: s.play(anim))
	_root.add_child(s)
	return s


func _actor(code: String, anim: StringName, pos: Vector2, group: StringName) -> void:
	var body := Node2D.new()
	body.position = pos
	body.add_to_group(group)
	body.z_index = 10
	_root.add_child(body)
	var s := AnimatedSprite2D.new()
	s.name = "Sprite"
	s.sprite_frames = load("res://assets/sprites/%s/%s_frames.tres" % [code, code])
	s.play(anim)
	body.add_child(s)


func _burst_forever(effect: String, pos: Vector2) -> void:
	var holder := Node2D.new()
	holder.position = pos
	_root.add_child(holder)
	var spawn := func() -> void:
		var fx := (load("res://assets/fx/particles/%s.tscn" % effect) as PackedScene).instantiate()
		holder.add_child(fx)
	spawn.call()
	var t := Timer.new()
	t.wait_time = 1.4
	t.autostart = true
	t.timeout.connect(spawn)
	holder.add_child(t)


func _take_shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for i in PAGES:
		show_page(i)
		for f in 14:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.resize(image.get_width() * 3, image.get_height() * 3, Image.INTERPOLATE_NEAREST)
		image.save_png(dir.path_join("v27_cast_%d.png" % i))
	get_tree().quit()
