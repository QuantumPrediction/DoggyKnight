extends TestCase
## v2.7 C 繪本(DEV_PLAN 第 20 節 CS4):第四至六章的 19 張繪本插畫(docs/STORY.md 第 16 節),
## 由 tools/pixel/art_v27_story.py 產生。(路徑與 160×120 的合約由 tests/core/test_v27_contract.gd 檢查。)

const PAGES: Array[String] = [
	"teaser_3",
	"c4_prologue_1", "c4_prologue_2", "c4_ending_1", "c4_ending_2", "c4_ending_3", "teaser_4",
	"c5_prologue_1", "c5_prologue_2", "c5_ending_1", "c5_ending_2", "c5_ending_3", "teaser_5",
	"c6_prologue_1", "c6_prologue_2", "c6_ending_1", "c6_ending_2", "c6_ending_3", "c6_ending_4",
]
## 夜裡的畫面(月光懸崖、被佔領的城門、山丘上的營火):大部分是暗色。
const NIGHT: Array[String] = ["c4_ending_3", "c6_prologue_1", "c6_prologue_2"]
## 最後兩張(全員圓桌、全劇終的夕陽):暖色調、細節多。
const FINALE: Array[String] = ["c6_ending_3", "c6_ending_4"]
const WARM: Array[String] = ["yellow", "amber", "orange", "peach", "cream", "coral", "gold", "gold_l", "gold_d",
		"brown", "brown_d", "rose", "red", "red_d", "sand", "dirt", "umber", "pink", "white"]
const DARK: Array[String] = ["ink", "navy", "night_d", "night", "plum", "iron", "slate", "deep"]


func _image(id: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path("res://assets/story/%s.png" % id))


## 調色盤的 html 色碼 → 名字(依 ui/theme/palette_colors.gd 的常數)。
func _names() -> Dictionary:
	var out := {}
	var consts: Dictionary = (load("res://ui/theme/palette_colors.gd") as GDScript).get_script_constant_map()
	for k: String in consts:
		if consts[k] is Color:
			out[(consts[k] as Color).to_html(false)] = k.to_lower()
	return out


func _counts(img: Image, names: Dictionary) -> Dictionary:
	var out := {}
	for y in img.get_height():
		for x in img.get_width():
			var n: String = names.get(img.get_pixel(x, y).to_html(false), "?")
			out[n] = int(out.get(n, 0)) + 1
	return out


func _share(counts: Dictionary, group: Array[String]) -> float:
	var n := 0
	var total := 0
	for k: String in counts:
		total += int(counts[k])
		if group.has(k):
			n += int(counts[k])
	return float(n) / max(1, total)


func test_pages_are_opaque_palette_art_and_all_different() -> void:
	var names := _names()
	var seen := {}
	for id in PAGES:
		var img := _image(id)
		assert_eq(Vector2(img.get_width(), img.get_height()), Vector2(160, 120), "%s 是 160×120" % id)
		assert_eq(img.detect_alpha(), Image.ALPHA_NONE, "%s 不透明" % id)
		var counts := _counts(img, names)
		assert_false(counts.has("?"), "%s 只用調色盤" % id)
		assert_true(counts.size() >= 18, "%s 是畫好的插畫(%d 色)" % [id, counts.size()])
		var key := Marshalls.raw_to_base64(img.get_data()).sha256_text()
		assert_false(seen.has(key), "%s 和 %s 一樣" % [id, seen.get(key, "")])
		seen[key] = id


func test_night_pages_are_dark_and_the_finale_is_warm() -> void:
	var names := _names()
	for id in NIGHT:
		var counts := _counts(_image(id), names)
		assert_true(_share(counts, DARK) > 0.5, "%s 是夜景(暗色 %.2f)" % [id, _share(counts, DARK)])
	for id in FINALE:
		var counts := _counts(_image(id), names)
		assert_true(_share(counts, WARM) > 0.45, "%s 是暖色調(%.2f)" % [id, _share(counts, WARM)])
		assert_true(_share(counts, DARK) < 0.2, "%s 明亮(暗色 %.2f)" % [id, _share(counts, DARK)])
		assert_true(counts.size() >= 40, "%s 細節多(%d 色)" % [id, counts.size()])
