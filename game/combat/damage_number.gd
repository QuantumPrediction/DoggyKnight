class_name DamageNumber
extends Node2D
## 傷害數字(AP2):用程式畫的 3×5 像素字,有深色外框,跳起再落下,最後淡出。
## 握手的雙倍傷害(CRIT)用 2 倍大的字、橘色,後面加「!」;必殺技用金色大字。
## 不依賴字型檔,像素永遠清晰。數值與顏色在 data/player/feel_tuning.tres。

enum Style { NORMAL, CRIT, ULTIMATE, ALLY }

const GROUP: StringName = &"damage_number"
## 每個字 3 寬 5 高,一列一個 3 位元的數字(最高位在左)。索引 10 是「!」。
const GLYPHS: Array = [
	[7, 5, 5, 5, 7], [2, 6, 2, 2, 7], [7, 1, 7, 4, 7], [7, 1, 7, 1, 7], [5, 5, 7, 1, 1],
	[7, 4, 7, 1, 7], [7, 4, 7, 5, 7], [7, 1, 1, 2, 2], [7, 5, 7, 5, 7], [7, 5, 7, 1, 7],
	[2, 2, 2, 0, 2],
]
const BANG := 10

var value: int = 0
var style: Style = Style.NORMAL
var feel: FeelTuning

var _glyphs: Array[int] = []
var _velocity: Vector2 = Vector2.ZERO
var _offset: Vector2 = Vector2.ZERO
var _age: float = 0.0
var _lifetime: float = 0.7
var _pixel: int = 1
var _color: Color = Color.WHITE


func _ready() -> void:
	add_to_group(GROUP)
	if feel == null:
		feel = CombatFx.feel()
	z_index = 2
	_glyphs.clear()
	for ch in str(maxi(0, value)):
		_glyphs.append(int(ch))
	var big := style == Style.CRIT or style == Style.ULTIMATE
	if style == Style.CRIT:
		_glyphs.append(BANG)
	_pixel = 2 if big else 1
	_lifetime = feel.crit_lifetime if big else feel.number_lifetime
	match style:
		Style.CRIT:
			_color = feel.crit_color
		Style.ULTIMATE:
			_color = feel.ultimate_number_color
		Style.ALLY:
			_color = feel.ally_number_color
		_:
			_color = feel.number_color
	var jump := feel.number_jump_speed * (1.2 if big else 1.0)
	_velocity = Vector2(randf_range(-feel.number_drift, feel.number_drift), -jump)


func _process(delta: float) -> void:
	delta *= CombatFx.time_scale
	_age += delta
	_velocity.y += feel.number_gravity * delta
	_offset += _velocity * delta
	if _age >= _lifetime:
		queue_free()
		return
	queue_redraw()


func get_age() -> float:
	return _age


func _draw() -> void:
	var t := _age / maxf(_lifetime, 0.001)
	var alpha := clampf((1.0 - t) / 0.3, 0.0, 1.0)
	# 大字一出現時先大一圈(彈出感),然後回到正常大小。
	var px := _pixel + (1 if _pixel > 1 and _age < 0.07 else 0)
	var advance := 4 * px
	var width := _glyphs.size() * advance - px
	var origin := (_offset + Vector2(-width * 0.5, -5.0 * px * 0.5)).round()
	var outline := Color(feel.number_outline, alpha)
	var fill := Color(_color, alpha)
	var shade := Color(_color.darkened(0.3), alpha)
	for pass_index in 2:
		for i in _glyphs.size():
			var rows: Array = GLYPHS[_glyphs[i]]
			var base := origin + Vector2(i * advance, 0)
			for y in 5:
				var bits: int = rows[y]
				for x in 3:
					if bits & (4 >> x) == 0:
						continue
					var p := base + Vector2(x * px, y * px)
					if pass_index == 0:
						draw_rect(Rect2(p - Vector2.ONE, Vector2(px + 2, px + 2)), outline)
					else:
						draw_rect(Rect2(p, Vector2(px, px)), shade if y == 4 else fill)
