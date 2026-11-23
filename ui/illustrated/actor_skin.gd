extends Node2D
## Original SpriteFrames still own the timing, completion signal and combat dimensions.
var actor_code: String = ""
var sprite: AnimatedSprite2D
var _tex: Texture2D
var _rect: Rect2

func _ready() -> void:
	sprite = get_parent() as AnimatedSprite2D
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	use_parent_material = true
	if actor_code == "goldie":
		StoryArt.prepare_combat_paint(HeroClasses.valid_id(GameState.hero_class))
	elif actor_code == "bulldog":
		StoryArt.texture("motion/companion_guard")
	_update()

func _process(_delta: float) -> void:
	_update()

func _update() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var count := sprite.sprite_frames.get_frame_count(sprite.animation)
	if count <= 0:
		return
	var original := sprite.sprite_frames.get_frame_texture(sprite.animation, mini(sprite.frame, count - 1))
	if original == null:
		return
	var texture := _drawing(count)
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
	scale = Vector2(-1.0 if sprite.flip_h else 1.0, -breath if sprite.flip_v else breath)
	# Anchor the idle breath at the painted soles rather than bobbing the entire body.
	position.y = (at.y + size.y * StoryArt.HERO_SOLE_Y / StoryArt.HERO_TILE.y) * (1.0 - breath) * (-1.0 if sprite.flip_v else 1.0)
	sprite.self_modulate.a = 0.0 if texture != null else 1.0
	if texture != _tex or rect != _rect:
		_tex = texture
		_rect = rect
		queue_redraw()

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
		draw_texture_rect(_tex, _rect, false)
