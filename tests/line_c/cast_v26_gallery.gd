extends Node2D
## v2.6 C 角色圖庫(開發工具,不是自動化測試;文字不翻譯)。
## 第 0 頁:六個小角色的每個動畫;第 1 頁:綠騎士;第 2 頁:摩根娜;第 3 頁:頭像、投射物、粒子;
## 第 4 頁:黑騎士(上移 8 像素後)、綠騎士、摩根娜站在戰鬥區下緣,背景是石橋(看得到腳下影子)。
## 點畫面換下一頁。
##
## 執行:godot --path . res://tests/line_c/cast_v26_gallery.tscn
## 截圖(雲端用 Xvfb):
##   xvfb-run -a godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##     res://tests/line_c/cast_v26_gallery.tscn -- --shots=/tmp/line_c_shots/v26_cast

const SMALL: Array = [
	["gargoyle", [&"idle", &"run", &"attack", &"hurt", &"swoop", &"stone"]],
	["spellbook", [&"idle", &"run", &"attack", &"hurt", &"cast"]],
	["foxfire", [&"idle", &"run", &"attack", &"hurt", &"burst"]],
	["shadow_wolf", [&"idle", &"run", &"attack", &"hurt", &"dash", &"down"]],
	["lancelot", [&"idle", &"run", &"attack", &"hurt", &"dash"]],
	["lady_lake", [&"idle", &"run", &"cast"]],
]
const GREEN_KNIGHT: Array[StringName] = [&"idle", &"run", &"attack", &"hurt", &"whip", &"summon", &"hat_off", &"down"]
const MORGANA: Array[StringName] = [&"idle", &"run", &"attack", &"hurt", &"cast", &"teleport", &"down"]
const PORTRAITS: Array = [
	["lancelot", ["normal", "happy", "serious", "surprised"]], ["gargoyle", ["normal"]], ["green_knight", ["normal"]],
	["lady_lake", ["normal", "smile", "worried"]], ["morgana_true", ["normal", "angry", "sad", "smile"]],
]
const PROJECTILES: Array[String] = ["magic_orb", "thorn", "fox_flame", "moon_orb"]
const PARTICLES: Array[String] = ["stone_chips", "shadow_leaves"]
const PAGES := 5

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
	bg.color = Color("7d9a6a") if i != 3 else Color("3b4a80")
	bg.size = Vector2(240, 400)
	bg.position = Vector2(-30, -40)
	bg.z_index = -200
	if i != 4:
		_root.add_child(bg)
	match i:
		0:
			var y := 22.0
			for row: Array in SMALL:
				var x := 18.0
				for anim: StringName in row[1]:
					_sprite(row[0], anim, Vector2(x, y))
					x += 29.0
				y += 40.0
		1:
			for k in GREEN_KNIGHT.size():
				_sprite("green_knight", GREEN_KNIGHT[k], Vector2(50 + (k % 2) * 80, 40 + (k / 2) * 70))
		2:
			for k in MORGANA.size():
				_sprite("morgana", MORGANA[k], Vector2(50 + (k % 2) * 80, 40 + (k / 2) * 70))
		3:
			var n := 0
			for entry: Array in PORTRAITS:
				for expr: String in entry[1]:
					var s := Sprite2D.new()
					s.texture = load("res://assets/portraits/%s/%s.png" % [entry[0], expr])
					s.position = Vector2(30 + (n % 3) * 60, 28 + (n / 3) * 50)
					_root.add_child(s)
					n += 1
			for k in PROJECTILES.size():
				var p := AnimatedSprite2D.new()
				p.sprite_frames = load("res://assets/fx/%s/%s_frames.tres" % [PROJECTILES[k], PROJECTILES[k]])
				p.position = Vector2(30 + k * 40, 296)
				p.play(&"default")
				_root.add_child(p)
			for k in PARTICLES.size():
				_burst_forever(PARTICLES[k], Vector2(60 + k * 60, 276))
		4:
			var arena := (load("res://assets/backgrounds/bridge.tscn") as PackedScene).instantiate()
			_root.add_child(arena)
			var bottom := Layout.ARENA_RECT.end.y
			# 和 A 線一樣:角色中心最低到「下緣 - (格子一半 - 2)」
			_actor("black_knight", &"idle", Vector2(40, bottom - 30), &"enemy")
			_actor("green_knight", &"idle", Vector2(100, bottom - 30), &"enemy")
			_actor("morgana", &"idle", Vector2(150, bottom - 30), &"enemy")
			_actor("goldie", &"idle", Vector2(90, bottom - 60), &"player")
			_actor("lancelot", &"idle", Vector2(60, bottom - 70), &"companion")
			_actor("shadow_wolf", &"idle", Vector2(130, bottom - 70), &"enemy")
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
		image.save_png(dir.path_join("v26_cast_%d.png" % i))
	get_tree().quit()
