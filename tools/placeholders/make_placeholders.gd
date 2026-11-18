extends SceneTree
## Phase 0 佔位圖產生器(擁有者:Phase 0 / 整合)。
##
## 為每個角色產生純色方塊的 PNG 與 SpriteFrames,路徑與動畫名稱依 DEV_PLAN 4.6。
## C 線之後會用 tools/pixel/ 的正式工具原地覆蓋這些檔案;之後不要再執行這個腳本,
## 否則會蓋掉正式美術。
##
## 執行:godot --headless --path . --script res://tools/placeholders/make_placeholders.gd
## 然後:godot --headless --path . --import

const OUTLINE := Color("2b1d2e")
const EYE := Color("1a1020")

## 每個動畫:[名稱, 格數, 每秒格數, 是否循環, 標記顏色]
## 標記顏色畫在方塊頂部,讓動畫在圖庫與試玩中容易分辨。
const CHARACTERS: Dictionary = {
	"goldie": {
		"size": 24, "color": Color("e8c170"),
		"anims": [
			["idle", 2, 4.0, true, Color("fff1c9")],
			["run", 4, 10.0, true, Color("7ec850")],
			["attack", 3, 12.0, false, Color("ffffff")],
			["hurt", 1, 1.0, false, Color("ffd34d")],
			["sleep", 2, 2.0, true, Color("8fb8ff")],
		],
	},
	"bulldog": {
		"size": 24, "color": Color("b9875a"),
		"anims": [
			["idle", 2, 4.0, true, Color("fff1c9")],
			["run", 4, 10.0, true, Color("7ec850")],
			["attack", 3, 12.0, false, Color("ffffff")],
			["hurt", 1, 1.0, false, Color("ffd34d")],
			["guard", 2, 4.0, true, Color("6fa8dc")],
		],
	},
	"scarecrow": {
		"size": 24, "color": Color("8db255"),
		"anims": [
			["idle", 2, 4.0, true, Color("f2d16b")],
			["run", 4, 8.0, true, Color("c98f3c")],
			["attack", 3, 10.0, false, Color("ffffff")],
			["hurt", 1, 1.0, false, Color("ffd34d")],
		],
	},
	"crow": {
		"size": 16, "color": Color("4d4373"),
		"anims": [
			["idle", 2, 6.0, true, Color("a99bd9")],
			["run", 4, 12.0, true, Color("7ec850")],
			["attack", 3, 12.0, false, Color("ffffff")],
			["hurt", 1, 1.0, false, Color("ffd34d")],
		],
	},
	"black_knight": {
		"size": 48, "color": Color("4a4e69"),
		"anims": [
			["idle", 2, 3.0, true, Color("9a8c98")],
			["run", 4, 8.0, true, Color("7ec850")],
			["attack", 3, 10.0, false, Color("ffffff")],
			["hurt", 1, 1.0, false, Color("ffd34d")],
			["charge", 2, 10.0, true, Color("ff7b54")],
			["slam", 3, 10.0, false, Color("f25f5c")],
			["down", 1, 1.0, false, Color("c9ada7")],
		],
	},
	# v2.7 第四至六章(只用 --only 產生)
	"crab": {"size": 24, "color": Color("d9573b"), "anims": [
			["idle", 2, 4.0, true, Color("fff1c9")],
			["run", 4, 10.0, true, Color("7ec850")],
			["attack", 3, 12.0, false, Color("ffffff")],
			["hurt", 1, 1.0, false, Color("ffd34d")],
			["guard", 2, 4.0, true, Color("8a8f98")]]},
	"jellyfish": {"size": 24, "color": Color("c58fe6"), "anims": [
			["idle", 2, 4.0, true, Color("fff1c9")],
			["run", 4, 10.0, true, Color("7ec850")],
			["attack", 3, 12.0, false, Color("ffffff")],
			["hurt", 1, 1.0, false, Color("ffd34d")],
			["zap", 3, 12.0, false, Color("fff36b")]]},
	"kraken": {"size": 64, "color": Color("d9604f"), "anims": [
			["idle", 2, 4.0, true, Color("fff1c9")],
			["run", 4, 10.0, true, Color("7ec850")],
			["attack", 3, 12.0, false, Color("ffffff")],
			["hurt", 1, 1.0, false, Color("ffd34d")],
			["slam", 3, 10.0, false, Color("ff7b54")],
			["ink", 3, 8.0, false, Color("3b3556")],
			["summon", 3, 8.0, false, Color("b58cff")],
			["down", 1, 1.0, false, Color("c9ada7")]]},
	"snowman": {"size": 24, "color": Color("eef3f8"), "anims": [
			["idle", 2, 4.0, true, Color("fff1c9")],
			["run", 4, 10.0, true, Color("7ec850")],
			["attack", 3, 12.0, false, Color("ffffff")],
			["hurt", 1, 1.0, false, Color("ffd34d")],
			["throw", 3, 10.0, false, Color("8fd3ff")]]},
	"salamander": {"size": 24, "color": Color("f08a2c"), "anims": [
			["idle", 2, 4.0, true, Color("fff1c9")],
			["run", 4, 10.0, true, Color("7ec850")],
			["attack", 3, 12.0, false, Color("ffffff")],
			["hurt", 1, 1.0, false, Color("ffd34d")],
			["dash", 2, 12.0, true, Color("ff3d2e")]]},
	"red_dragon": {"size": 64, "color": Color("c8323c"), "anims": [
			["idle", 2, 4.0, true, Color("fff1c9")],
			["run", 4, 10.0, true, Color("7ec850")],
			["attack", 3, 12.0, false, Color("ffffff")],
			["hurt", 1, 1.0, false, Color("ffd34d")],
			["breath", 3, 10.0, false, Color("ff9f1c")],
			["roar", 3, 8.0, false, Color("ffd34d")],
			["sulk", 2, 3.0, true, Color("c9ada7")]]},
	"white_dragon": {"size": 64, "color": Color("e6eef5"), "anims": [
			["idle", 2, 4.0, true, Color("fff1c9")],
			["run", 4, 10.0, true, Color("7ec850")],
			["attack", 3, 12.0, false, Color("ffffff")],
			["hurt", 1, 1.0, false, Color("ffd34d")],
			["breath", 3, 10.0, false, Color("8fd3ff")],
			["roar", 3, 8.0, false, Color("b8f0ff")],
			["sulk", 2, 3.0, true, Color("c9ada7")]]},
	"shadow_knight": {"size": 32, "color": Color("2f2a45"), "anims": [
			["idle", 2, 4.0, true, Color("fff1c9")],
			["run", 4, 10.0, true, Color("7ec850")],
			["attack", 3, 12.0, false, Color("ffffff")],
			["hurt", 1, 1.0, false, Color("ffd34d")],
			["guard", 2, 4.0, true, Color("6b6390")],
			["down", 1, 1.0, false, Color("c9ada7")]]},
	"lantern_wisp": {"size": 16, "color": Color("7fe0c4"), "anims": [
			["idle", 2, 4.0, true, Color("fff1c9")],
			["run", 4, 10.0, true, Color("7ec850")],
			["attack", 3, 12.0, false, Color("ffffff")],
			["hurt", 1, 1.0, false, Color("ffd34d")],
			["heal", 3, 8.0, false, Color("b8ffd0")]]},
	"mordred": {"size": 48, "color": Color("3a2a24"), "anims": [
			["idle", 2, 4.0, true, Color("fff1c9")],
			["run", 4, 10.0, true, Color("7ec850")],
			["attack", 3, 12.0, false, Color("ffffff")],
			["hurt", 1, 1.0, false, Color("ffd34d")],
			["dash", 2, 12.0, true, Color("ff7b54")],
			["slash", 3, 12.0, false, Color("b58cff")],
			["guard", 2, 6.0, true, Color("9a6bff")],
			["summon", 3, 8.0, false, Color("6b6390")],
			["down", 1, 1.0, false, Color("c9ada7")]]},
	"tristan": {"size": 32, "color": Color("e0a050"), "anims": [
			["idle", 2, 4.0, true, Color("fff1c9")],
			["run", 4, 10.0, true, Color("7ec850")],
			["attack", 3, 12.0, false, Color("ffffff")],
			["hurt", 1, 1.0, false, Color("ffd34d")],
			["play", 3, 8.0, true, Color("8fd3ff")]]},
	"gawain": {"size": 32, "color": Color("a0683a"), "anims": [
			["idle", 2, 4.0, true, Color("fff1c9")],
			["run", 4, 10.0, true, Color("7ec850")],
			["attack", 3, 12.0, false, Color("ffffff")],
			["hurt", 1, 1.0, false, Color("ffd34d")],
			["slam", 3, 10.0, false, Color("ff9f1c")]]},
	# v2.6 第二、三章(只用 --only 產生,不會蓋掉已有的正式美術)
	"gargoyle": {"size": 32, "color": Color("8a8f98"), "anims": [
			["idle", 2, 4.0, true, Color("c9ced6")], ["run", 4, 10.0, true, Color("7ec850")],
			["attack", 3, 12.0, false, Color("ffffff")], ["hurt", 1, 1.0, false, Color("ffd34d")],
			["swoop", 2, 12.0, true, Color("ff7b54")], ["stone", 2, 4.0, true, Color("5d6168")]]},
	"spellbook": {"size": 24, "color": Color("7b4fa0"), "anims": [
			["idle", 2, 6.0, true, Color("e6c36a")], ["run", 4, 10.0, true, Color("7ec850")],
			["attack", 3, 12.0, false, Color("ffffff")], ["hurt", 1, 1.0, false, Color("ffd34d")],
			["cast", 3, 10.0, false, Color("b58cff")]]},
	"foxfire": {"size": 16, "color": Color("9a6bff"), "anims": [
			["idle", 2, 8.0, true, Color("e3d3ff")], ["run", 4, 12.0, true, Color("7ec850")],
			["attack", 3, 12.0, false, Color("ffffff")], ["hurt", 1, 1.0, false, Color("ffd34d")],
			["burst", 3, 14.0, false, Color("ff7bd5")]]},
	"shadow_wolf": {"size": 32, "color": Color("3b3556"), "anims": [
			["idle", 2, 4.0, true, Color("8a7fc0")], ["run", 4, 12.0, true, Color("7ec850")],
			["attack", 3, 12.0, false, Color("ffffff")], ["hurt", 1, 1.0, false, Color("ffd34d")],
			["dash", 2, 12.0, true, Color("ff7b54")], ["down", 1, 1.0, false, Color("c9ada7")]]},
	"green_knight": {"size": 64, "color": Color("3f8f4a"), "anims": [
			["idle", 2, 3.0, true, Color("a6e07a")], ["run", 4, 8.0, true, Color("7ec850")],
			["attack", 3, 10.0, false, Color("ffffff")], ["hurt", 1, 1.0, false, Color("ffd34d")],
			["whip", 3, 10.0, false, Color("ff7b54")], ["summon", 3, 8.0, false, Color("b58cff")],
			["hat_off", 3, 8.0, false, Color("f2d16b")], ["down", 1, 1.0, false, Color("c9ada7")]]},
	"morgana": {"size": 64, "color": Color("b8562f"), "anims": [
			["idle", 2, 4.0, true, Color("b58cff")], ["run", 4, 8.0, true, Color("7ec850")],
			["attack", 3, 10.0, false, Color("ffffff")], ["hurt", 1, 1.0, false, Color("ffd34d")],
			["cast", 3, 10.0, false, Color("9a6bff")], ["teleport", 3, 12.0, false, Color("e3d3ff")],
			["down", 1, 1.0, false, Color("c9ada7")]]},
	"lancelot": {"size": 32, "color": Color("d9893f"), "anims": [
			["idle", 2, 4.0, true, Color("fff1c9")], ["run", 4, 10.0, true, Color("7ec850")],
			["attack", 3, 12.0, false, Color("ffffff")], ["hurt", 1, 1.0, false, Color("ffd34d")],
			["dash", 2, 12.0, true, Color("6fa8dc")]]},
	"lady_lake": {"size": 32, "color": Color("f2f4f8"), "anims": [
			["idle", 2, 3.0, true, Color("8fd3ff")], ["run", 4, 8.0, true, Color("7ec850")],
			["cast", 3, 8.0, false, Color("b8f0ff")]]},
}

## 16×16 的佔位 App 圖示,放大 16 倍成 256×256。不透明(iOS 規定圖示不可透明)。
const ICON_ROWS: Array[String] = [
	"................",
	"..oo........oo..",
	".oooo......oooo.",
	".ooGGGGGGGGGGoo.",
	".ooGGGGGGGGGGoo.",
	".oGGGGGGGGGGGGo.",
	"..GGKKGGGGKKGG..",
	"..GGKKGGGGKKGG..",
	"..GGGGGGGGGGGG..",
	"..GGGGGKKGGGGG..",
	"...GGGGKKGGGG...",
	"....GGGGGGGG....",
	"...RRRRRRRRRR...",
	"..RRRRRRRRRRRR..",
	".RRRRRRRRRRRRRR.",
	"................",
]
const ICON_COLORS: Dictionary = {
	".": Color("2e2138"), "o": Color("c08a3e"), "G": Color("e8c170"),
	"K": Color("1a1020"), "R": Color("c8323c"),
}


## 特效佔位(DEV_PLAN 4.9):[格子大小, 格數, 每秒格數, 是否循環, 顏色, 形狀]
const FX: Dictionary = {
	"slash": [24, 3, 18.0, false, Color(1, 1, 1, 0.85), "arc"],
	"hit_spark": [12, 3, 18.0, false, Color("fff3a0"), "star"],
	"exp_orb": [8, 2, 4.0, true, Color("7fe0ff"), "circle"],
	"ultimate_slash": [64, 4, 14.0, false, Color(1, 0.95, 0.6, 0.8), "arc"],
	"dizzy_stars": [12, 4, 8.0, true, Color("ffe066"), "star"],
	"dust": [8, 3, 12.0, false, Color(0.9, 0.85, 0.7, 0.8), "circle"],
}


func _initialize() -> void:
	# v2.6:`-- --only=id1,id2` 只產生指定角色(不動特效與圖示)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			for id in arg.trim_prefix("--only=").split(","):
				_make_character(id, CHARACTERS[id])
			print("Placeholders written (only).")
			quit(0)
			return
	for id: String in CHARACTERS:
		_make_character(id, CHARACTERS[id])
	for fx_name: String in FX:
		_make_fx(fx_name, FX[fx_name])
	_make_icon()
	print("Placeholders written.")
	quit(0)


func _make_character(id: String, spec: Dictionary) -> void:
	var size: int = spec["size"]
	var anims: Array = spec["anims"]
	var max_frames := 0
	for anim: Array in anims:
		max_frames = maxi(max_frames, anim[1])
	var sheet := Image.create(size * max_frames, size * anims.size(), false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	for row in anims.size():
		var anim: Array = anims[row]
		for frame in int(anim[1]):
			_draw_frame(sheet, Vector2i(frame * size, row * size), size, spec["color"], anim[4], frame)

	var dir := "res://assets/sprites/%s" % id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var png_path := "%s/%s.png" % [dir, id]
	var err := sheet.save_png(ProjectSettings.globalize_path(png_path))
	assert(err == OK, "Failed to save %s" % png_path)
	_write_frames(id, dir, png_path, size, anims)


## 一格:外框、身體(每格亮度略有不同)、頂部動畫標記、朝右的眼睛、底部格數指示點。
func _draw_frame(img: Image, origin: Vector2i, size: int, body: Color, accent: Color, frame: int) -> void:
	var margin := maxi(1, size / 8)
	var body_rect := Rect2i(origin + Vector2i(margin, margin), Vector2i(size - margin * 2, size - margin * 2))
	img.fill_rect(body_rect.grow(1), OUTLINE)
	img.fill_rect(body_rect, body.lightened(0.06 * frame))
	var band := maxi(2, size / 8)
	img.fill_rect(Rect2i(body_rect.position, Vector2i(body_rect.size.x, band)), accent)
	var eye := maxi(2, size / 8)
	img.fill_rect(Rect2i(body_rect.end.x - eye * 2, body_rect.position.y + band + eye, eye, eye), EYE)
	var dot := maxi(1, size / 12)
	var dot_x := body_rect.position.x + 1 + frame * (dot + 1)
	img.fill_rect(Rect2i(dot_x, body_rect.end.y - dot - 1, dot, dot), EYE)


func _write_frames(id: String, dir: String, png_path: String, size: int, anims: Array) -> void:
	var lines: PackedStringArray = []
	lines.append("[gd_resource type=\"SpriteFrames\" format=3]")
	lines.append("")
	lines.append("[ext_resource type=\"Texture2D\" path=\"%s\" id=\"1_sheet\"]" % png_path)
	var anim_entries: PackedStringArray = []
	for row in anims.size():
		var anim: Array = anims[row]
		var frame_entries: PackedStringArray = []
		for frame in int(anim[1]):
			var sub_id := "AtlasTexture_%s_%d" % [anim[0], frame]
			lines.append("")
			lines.append("[sub_resource type=\"AtlasTexture\" id=\"%s\"]" % sub_id)
			lines.append("atlas = ExtResource(\"1_sheet\")")
			lines.append("region = Rect2(%d, %d, %d, %d)" % [frame * size, row * size, size, size])
			frame_entries.append("{\n\"duration\": 1.0,\n\"texture\": SubResource(\"%s\")\n}" % sub_id)
		anim_entries.append("{\n\"frames\": [%s],\n\"loop\": %s,\n\"name\": &\"%s\",\n\"speed\": %.1f\n}" % [
			", ".join(frame_entries), "true" if anim[3] else "false", anim[0], anim[2]])
	lines.append("")
	lines.append("[resource]")
	lines.append("animations = [%s]" % ", ".join(anim_entries))
	lines.append("")
	var path := "%s/%s_frames.tres" % [dir, id]
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()


func _make_fx(fx_name: String, spec: Array) -> void:
	var size: int = spec[0]
	var frame_count: int = spec[1]
	var color: Color = spec[4]
	var shape: String = spec[5]
	var sheet := Image.create(size * frame_count, size, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	var center := Vector2(size, size) * 0.5
	for frame in frame_count:
		var t := float(frame + 1) / frame_count
		for y in size:
			for x in size:
				var p := Vector2(x + 0.5, y + 0.5) - center
				var r := p.length() / (size * 0.5)
				var on := false
				match shape:
					"circle":
						on = r <= 0.55 + 0.35 * t
					"star":
						on = (absf(p.x) < 1.0 or absf(p.y) < 1.0) and r <= 0.4 + 0.6 * t
					"arc":
						on = r >= 0.55 and r <= 0.95 and p.x >= -size * 0.1 and atan2(p.y, p.x) <= -PI * 0.6 + PI * 1.2 * t
				if on:
					sheet.set_pixel(frame * size + x, y, color)
	var dir := "res://assets/fx/%s" % fx_name
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var png_path := "%s/%s.png" % [dir, fx_name]
	sheet.save_png(ProjectSettings.globalize_path(png_path))
	_write_frames(fx_name, dir, png_path, size, [["default", frame_count, spec[2], spec[3], color]])


func _make_icon() -> void:
	var scale := 16
	var img := Image.create(16 * scale, 16 * scale, false, Image.FORMAT_RGB8)
	for y in ICON_ROWS.size():
		var row: String = ICON_ROWS[y]
		for x in row.length():
			img.fill_rect(Rect2i(x * scale, y * scale, scale, scale), ICON_COLORS[row[x]])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/app_icon"))
	img.save_png(ProjectSettings.globalize_path("res://assets/app_icon/icon.png"))
