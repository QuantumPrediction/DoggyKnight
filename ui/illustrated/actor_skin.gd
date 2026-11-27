extends Node2D
## Original SpriteFrames still own the timing, completion signal and combat dimensions.
var actor_code: String = ""
var sprite: AnimatedSprite2D
var _tex: Texture2D
var _rect: Rect2
var _swing_enemy: ScarecrowEnemy
var _archer: ArcherEnemy
var _player: GoldiePlayer
var _worn: WornGear
enum RunView { SIDE, FRONT, REAR }
var _run_view := RunView.SIDE

func _ready() -> void:
	sprite = get_parent() as AnimatedSprite2D
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	use_parent_material = true
	if actor_code == "goldie":
		_player = sprite.get_parent() as GoldiePlayer
		var role := HeroClasses.valid_id(GameState.hero_class)
		StoryArt.prepare_combat_paint(role)
		if _player != null:
			_worn = WornGear.new()
			_worn.configure(role, GameState.run_equipment, GameState.hero_level)
			if _worn.rank > 0 or _worn.armor_grade > 0 or _worn.weapon_grade > 0:
				texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			EventBus.leveled_up.connect(_hero_leveled_up)
			StoryArt.texture("motion/vertical_" + String(role))
			StoryArt.texture("motion/settle_" + String(role))
	elif actor_code == "bulldog":
		StoryArt.texture("motion/companion_guard")
	elif actor_code == "scarecrow_archer":
		_archer = sprite.get_parent() as ArcherEnemy
		if _archer != null:
			StoryArt.texture("motion/archer_draw")
	elif actor_code == "scarecrow":
		var enemy := sprite.get_parent() as ScarecrowEnemy
		if enemy != null and not enemy.elite and enemy.data != null and enemy.data.id == &"scarecrow":
			_swing_enemy = enemy
			StoryArt.texture("motion/scarecrow_swing")
	_update()

func _process(_delta: float) -> void:
	_update()

func _hero_leveled_up(level: int) -> void:
	if _worn.set_hero_level(level):
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		queue_redraw()

func _update() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var count := sprite.sprite_frames.get_frame_count(sprite.animation)
	if count <= 0:
		return
	var original := sprite.sprite_frames.get_frame_texture(sprite.animation, mini(sprite.frame, count - 1))
	if original == null:
		return
	var flip := sprite.flip_h
	var texture: Texture2D
	if _player != null:
		var role := HeroClasses.valid_id(GameState.hero_class)
		if _player.stride_direction != Vector2.ZERO and sprite.animation in [&"run", &"idle"]:
			var heading := _player.stride_direction
			_run_view = _vertical_run_view(heading)
			if _player.stride_moving:
				if _run_view == RunView.SIDE:
					texture = StoryArt.hero_stride(role, floori(_player.stride_cycle * 8.0))
				else:
					texture = StoryArt.cell("motion/vertical_" + String(role), floori(_player.stride_cycle * 4.0), _run_view - 1, 4, 2)
			elif _run_view != RunView.SIDE:
				var settled := int(_player.stride_settle_left <= 0.0)
				texture = StoryArt.cell("motion/settle_" + String(role), settled, _run_view - 1, 2, 2)
			elif _player.stride_settle_left > 0.0:
				var foot := floori(_player.stride_cycle * 2.0 + 0.5) % 2
				texture = StoryArt.hero_stride(role, 4 * foot)
			elif sprite.animation == &"run":
				texture = StoryArt.motion_pose(role, 0)
			flip = _run_view == RunView.SIDE and heading.x < 0.0
		else:
			# A staged animation or a combat action owns its original playback clock.
			_run_view = _vertical_run_view(_player.facing) if sprite.animation == &"run" else RunView.SIDE
		if texture == null and _run_view != RunView.SIDE:
			var phase := StoryArt.stride_phase(sprite, count, 4)
			texture = StoryArt.cell("motion/vertical_" + String(role), phase, _run_view - 1, 4, 2)
			if texture != null:
				flip = false
	elif _swing_enemy != null:
		var beat := _swing_enemy.illustrated_swing_beat()
		if beat >= 0:
			texture = StoryArt.scarecrow_swing(_swing_enemy.facing, beat)
			if texture != null:
				flip = _swing_enemy.facing.x < -0.05
	elif _archer != null:
		var beat := _archer.illustrated_draw_beat()
		if beat >= 0:
			var facing := _archer.facing
			var view := StoryArt.archer_draw_view(facing)
			texture = StoryArt.cell("motion/archer_draw", beat, view, 4, 3)
			if texture != null:
				# Only the side view is mirrored. Vertical tracking keeps its handedness.
				flip = view == 0 and facing.x < 0.0
	if texture == null:
		texture = _drawing(count)
	var size := original.get_size()
	var at := sprite.offset - (size * 0.5 if sprite.centered else Vector2.ZERO)
	size.y -= float(sprite.sprite_frames.get_meta(&"foot_lift", 0))
	var rect := Rect2(at, size)
	if actor_code == "goldie" and texture != null and texture.get_size() == StoryArt.HERO_TILE:
		var units_per_pixel := size.y / StoryArt.HERO_TILE.y
		rect.position.x += size.x * 0.5 - StoryArt.HERO_HIP_X * units_per_pixel
		rect.size.x = StoryArt.HERO_TILE.x * units_per_pixel
	var breath := 1.0
	if actor_code == "goldie" and sprite.animation in [&"idle", &"sleep"]:
		breath += 0.012 * sin(TAU * (sprite.frame + sprite.frame_progress) / count)
	scale = Vector2(-1.0 if flip else 1.0, -breath if sprite.flip_v else breath)
	# Anchor the idle breath at the painted soles rather than bobbing the entire body.
	position.y = (at.y + size.y * StoryArt.HERO_SOLE_Y / StoryArt.HERO_TILE.y) * (1.0 - breath) * (-1.0 if sprite.flip_v else 1.0)
	sprite.self_modulate.a = 0.0 if texture != null else 1.0
	if texture != _tex or rect != _rect:
		_tex = texture
		_rect = rect
		queue_redraw()

func _vertical_run_view(facing: Vector2) -> RunView:
	# The stick can hover near the cut between paintings. Keep a small angular
	# margin between entering and leaving a vertical view. Diagonals stay side-on.
	var view := RunView.FRONT if facing.y > 0.0 else RunView.REAR
	var slope := 1.2 if _run_view == view else 1.6
	if absf(facing.y) > slope * absf(facing.x):
		return view
	return RunView.SIDE

func _drawing(count: int) -> Texture2D:
	if actor_code == "goldie":
		return StoryArt.hero_motion(HeroClasses.valid_id(GameState.hero_class), sprite, count)
	if actor_code == "chest" and sprite.get_parent() is TreasureChest:
		var chest := sprite.get_parent() as TreasureChest
		var drawing := StoryArt.field_chest(chest.tier, sprite.animation, sprite.frame)
		if drawing != null:
			return drawing
	if actor_code == "bulldog":
		var companion := sprite.get_parent()
		if companion != null and companion.has_method(&"illustrated_guard_pose"):
			var guard_pose := int(companion.call(&"illustrated_guard_pose"))
			if guard_pose >= 0:
				return StoryArt.companion_guard_pose(guard_pose)
	if actor_code == "camp_goldie":
		if GameState.hero_class != &"knight":
			var anim: StringName = &"happy" if sprite.animation == &"happy" else &"rest"
			return StoryArt.hero(GameState.hero_class, StoryArt.pose("goldie", anim, sprite.frame))
		var pose := 3 if sprite.animation == &"happy" else (1 if sprite.animation == &"blink" else 0)
		return StoryArt.actor(actor_code, pose)
	if sprite is OneShotFx and (sprite as OneShotFx).player_ink:
		return StoryArt.action_effect(0 if actor_code == "fx:slash" else 2, sprite.frame)
	return StoryArt.actor(actor_code, StoryArt.pose(actor_code, sprite.animation, sprite.frame))

func _draw() -> void:
	if _tex != null:
		if _worn != null:
			_worn.draw_hero(self, _tex, _rect)
		else:
			draw_texture_rect(_tex, _rect, false)
