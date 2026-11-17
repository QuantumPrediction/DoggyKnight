class_name LeafHat
extends Node2D
## v2.6 綠騎士半血時掉下來的圓灌木葉子帽(程式畫的,可愛、不是受傷):從頭上彈起、翻一圈、
## 落地彈兩下,之後留在地上(微微晃動),直到這一關結束(場地 clear() 時移除)。在群組 combat_fx。

const LEAF := Color("4f9a34")
const LEAF_DARK := Color("2f6a24")
const LEAF_LIGHT := Color("9fdc62")
const GRAVITY := 240.0

var side: float = 1.0
var landed: bool = false

var _pos: Vector2 = Vector2.ZERO
var _vel: Vector2 = Vector2.ZERO
var _height: float = 0.0
var _vz: float = 70.0
var _rot: float = 0.0
var _spin: float = 9.0
var _bounces: int = 0
var _age: float = 0.0


## 從 host 頭上 head_height 像素的地方掉下來,往 p_side(-1 左、1 右)彈開。
static func drop(host: Node2D, head_height: float, p_side: float) -> LeafHat:
	if host == null or not host.is_inside_tree():
		return null
	var hat := LeafHat.new()
	hat.side = p_side
	hat._height = head_height
	CombatFx.layer_for(host, true).add_child(hat)
	hat.global_position = host.global_position + Vector2(0, 20)
	return hat


func _ready() -> void:
	add_to_group(&"combat_fx")
	_vel = Vector2(side * 28.0, 8.0)
	_spin = side * 9.0


func _process(delta: float) -> void:
	delta *= CombatFx.time_scale
	_age += delta
	if not landed:
		_vz -= GRAVITY * delta
		_height += _vz * delta
		_pos += _vel * delta
		_rot += _spin * delta
		if _height <= 0.0:
			_height = 0.0
			_bounces += 1
			if _bounces >= 3 or absf(_vz) < 30.0:
				landed = true
				_rot = 0.0
				CombatFx.spawn(self, &"dust", global_position + _pos, 0.0, Vector2.ONE * 0.8, Color.WHITE, true)
			else:
				_vz = -_vz * 0.4
				_vel *= 0.5
				_spin *= 0.5
	queue_redraw()


func _draw() -> void:
	draw_set_transform(_pos + Vector2(0, 2), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 6.0, Color(0, 0, 0, 0.2))
	var wobble := sin(_age * 3.0) * 0.08 if landed else 0.0
	draw_set_transform(_pos + Vector2(0, -_height - 3.0), _rot + wobble)
	# 圓圓的灌木帽:深綠底、亮綠葉子、頂上一片小葉。
	draw_circle(Vector2.ZERO, 6.0, LEAF_DARK)
	draw_circle(Vector2(-1, -1), 5.0, LEAF)
	for i in 5:
		var a := -PI * 0.9 + PI * 0.45 * float(i)
		draw_circle(Vector2.from_angle(a) * 4.0 + Vector2(0, -1), 1.6, LEAF_LIGHT if i % 2 == 0 else LEAF)
	draw_line(Vector2(0, -6), Vector2(2, -9), LEAF_DARK, 1.0)
	draw_circle(Vector2(3, -9), 1.5, LEAF_LIGHT)
	draw_set_transform(Vector2.ZERO)
