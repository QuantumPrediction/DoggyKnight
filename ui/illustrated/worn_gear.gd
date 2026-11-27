class_name WornGear
extends RefCounted
## Paints fittings on the actual illustrated shoulder, crossguard, staff head or bow nock.
## The run supplies its saved loadout; an armory can supply a projected inventory instead.
const SOCKETS := preload("res://ui/illustrated/worn_gear_sockets.gd")
const FITTINGS_PATH := "res://assets/illustrated/equipment/worn_gear.png"
const CAPES_PATH := "res://assets/illustrated/equipment/worn_cape.png"
const BLADE_PATH := "res://assets/illustrated/equipment/worn_blade.png"
const RANK_PATH := "res://assets/illustrated/equipment/worn_rank.png"
const BLADE_REGIONS := [Rect2(52, 2, 24, 124), Rect2(179, 2, 26, 124),
	Rect2(303, 2, 34, 124), Rect2(430, 2, 35, 124)]
const CELL := 128
const ARMOR_ROWS := {
	"quilted_vest": 0, "oathplate": 0, "ranger_jacket": 1, "mistcloak": 1,
	"apprentice_robe": 2, "starrobe": 2,
}
const WEAPON_ROWS := {"knight": 3, "mage": 4, "archer": 5}
const ARMOR_SPAN := [0, 32, 40, 49, 57, 67]
const WEAPON_SPAN := {
	"knight": [0, 19, 25, 32, 37, 45],
	"mage": [0, 19, 25, 33, 41, 53],
	"archer": [0, 13, 18, 25, 31, 43],
}

var hero: String = "knight"
var armor_row: int = -1
var armor_grade: int = 0
var weapon_grade: int = 0
var rank: int = 0
var _fittings: Texture2D
var _capes: Texture2D
var _blades: Texture2D
var _insignia: Texture2D

func configure(role: StringName, profile: Dictionary, hero_level: int = 1) -> void:
	hero = String(HeroClasses.valid_id(role))
	# Read rank paint at actor setup, so a level-up never opens an image in combat.
	_insignia = load(RANK_PATH)
	set_hero_level(hero_level)
	armor_row = -1
	armor_grade = 0
	weapon_grade = 0
	var worn := EquipmentInventory.loadout(profile, hero)
	var slots: Dictionary = worn.loadouts.get(hero, {})
	var armor: String = slots.get("armor", "")
	var weapon: String = slots.get("weapon", "")
	if ARMOR_ROWS.has(armor):
		armor_row = ARMOR_ROWS[armor]
		armor_grade = _grade(armor, worn.owned[armor])
	if not weapon.is_empty():
		weapon_grade = _grade(weapon, worn.owned[weapon])
	_fittings = load(FITTINGS_PATH) if armor_grade > 0 or weapon_grade > 0 else null
	_capes = load(CAPES_PATH) if armor_grade == 5 else null
	_blades = load(BLADE_PATH) if hero == "knight" and weapon_grade > 0 else null

static func _grade(id: String, level: int) -> int:
	if EquipmentInventory.item(id).quality == "epic":
		if level >= 9:
			return 5
		return 4 if level >= 6 else 3
	if level >= 5:
		return 3
	return 2 if level >= 3 else 1

func set_hero_level(level: int) -> bool:
	var new_rank := int(level >= 4) + int(level >= 8)
	if new_rank == rank:
		return false
	rank = new_rank
	return true

func draw_hero(canvas: CanvasItem, painting: Texture2D, bounds: Rect2) -> void:
	if armor_grade == 0 and weapon_grade == 0 and rank == 0:
		canvas.draw_texture_rect(painting, bounds, false)
		return
	var pose := SOCKETS.locate(hero, painting)
	if pose.is_empty():
		canvas.draw_texture_rect(painting, bounds, false)
		return
	var to_canvas := Transform2D(0.0, bounds.size / StoryArt.HERO_TILE, 0.0, bounds.position)
	var shoulder := Vector2(pose[0], pose[1])
	if armor_grade == 5:
		canvas.draw_set_transform_matrix(to_canvas)
		_draw_cape(canvas, painting as AtlasTexture, shoulder)
		canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	canvas.draw_texture_rect(painting, bounds, false)
	canvas.draw_set_transform_matrix(to_canvas)
	if armor_grade > 0:
		_draw_shoulder(canvas, shoulder)
	if rank > 0:
		var ribbon := Vector2.ONE * (26.0 if rank == 1 else 34.0)
		var clasp := shoulder + Vector2(-14.0, 4.0)
		canvas.draw_texture_rect_region(_insignia, Rect2(clasp - ribbon * Vector2(0.5, 0.11), ribbon),
			Rect2((rank - 1) * 96, 0, 96, 96))
	if weapon_grade > 0:
		var socket := Vector2(pose[2], pose[3])
		var angle := deg_to_rad(pose[4])
		if pose.size() == 7:
			var tip := Vector2(pose[5], pose[6])
			var axis := tip - socket
			if hero == "knight":
				angle = Vector2.UP.angle_to(axis)
				canvas.draw_set_transform_matrix(to_canvas * Transform2D(angle, socket))
				var width: float = [0.0, 8.5, 11.0, 14.0, 17.0, 20.0][weapon_grade]
				width = minf(width, axis.length() * 0.35)
				canvas.draw_texture_rect_region(_blades, Rect2(-width * 0.5, -axis.length(), width, axis.length()),
					BLADE_REGIONS[_column(weapon_grade)])
			elif hero == "archer" and weapon_grade >= 3:
				# The other nock only appears on drawings where the lower bow limb is exposed.
				canvas.draw_set_transform_matrix(to_canvas * Transform2D(Vector2.UP.angle_to(axis), tip))
				var length: float = WEAPON_SPAN[hero][weapon_grade] * 0.50
				canvas.draw_texture_rect_region(_fittings, Rect2(-0.5 * length, -0.88 * length, length, length),
					_cell(5, _column(weapon_grade)))
		canvas.draw_set_transform_matrix(to_canvas * Transform2D(angle, socket))
		_draw_fitting(canvas, socket.y)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_cape(canvas: CanvasItem, painting: AtlasTexture, shoulder: Vector2) -> void:
	var sheet := painting.atlas.resource_path.get_file().get_basename()
	var straight := sheet.begins_with("vertical_") or sheet.begins_with("settle_")
	var pin := shoulder + Vector2(0, -3)
	var size := Vector2(104, 76)
	var pivot := Vector2(0.93, 0.13)
	if straight:
		pivot = Vector2(0.5, 0.06)
		size = Vector2(94, 79)
		if painting.region.position.y == 0:
			pin.x += 23.0
	elif sheet == "reactions" and painting.region.position.x == 2 * StoryArt.HERO_TILE.x:
		# The sleeping hero folds the train behind its body, above the ground line.
		size = Vector2(66, 34)
	var cell := Rect2(armor_row * 144, int(straight) * 144, 144, 144)
	canvas.draw_texture_rect_region(_capes, Rect2(pin - size * pivot, size), cell)

func _draw_shoulder(canvas: CanvasItem, shoulder: Vector2) -> void:
	var span: float = ARMOR_SPAN[armor_grade]
	var pivot := Vector2(0.73, 0.36)
	if armor_grade >= 4:
		# A second overlapping quilt/leaf/lappet is secured beneath the outer shoulder.
		var inner := Vector2.ONE * span * 0.72
		var attachment := shoulder + Vector2(-span * 0.12, span * 0.22)
		canvas.draw_texture_rect_region(_fittings, Rect2(attachment - inner * pivot, inner), _cell(armor_row, 1))
	var size := Vector2.ONE * span
	canvas.draw_texture_rect_region(_fittings, Rect2(shoulder - size * pivot, size), _cell(armor_row, _column(armor_grade)))

func _draw_fitting(canvas: CanvasItem, height: float) -> void:
	var row: int = WEAPON_ROWS[hero]
	var span: float = WEAPON_SPAN[hero][weapon_grade]
	var pivot := Vector2(0.5, 0.5)
	if hero == "archer":
		pivot = Vector2(0.5, 0.88)
		# A raised bow is already near the top of the hero cell.
		span = minf(span, (height - 4.0) / pivot.y)
	if weapon_grade >= 4:
		# The gold socket below the main ornament comes from the same painted fitting.
		# Crop the socket alone so a weapon can never acquire a second guard or staff head.
		var collar := Rect2(54, 67, 20, 13)
		var collar_size := Vector2(0.27, 0.14) * span
		var offset := span * 0.18
		if hero == "mage":
			collar = Rect2(39, 96, 50, 23)
			collar_size = Vector2(0.38, 0.23) * span
			offset = span * 0.38
		elif hero == "archer":
			collar = Rect2(51, 99, 26, 21)
			collar_size = Vector2(0.33, 0.22) * span
			offset = span * 0.02
		collar.position += _cell(row, 1).position
		canvas.draw_texture_rect_region(_fittings, Rect2(Vector2(-collar_size.x * 0.5, offset), collar_size), collar)
	var size := Vector2.ONE * span
	canvas.draw_texture_rect_region(_fittings, Rect2(-size * pivot, size), _cell(row, _column(weapon_grade)))

static func _column(grade: int) -> int:
	return 3 if grade == 5 else mini(grade - 1, 2)

static func _cell(row: int, column: int) -> Rect2:
	return Rect2(column * CELL, row * CELL, CELL, CELL)
