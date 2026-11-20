extends Node2D
## Render authored high-resolution poses over the existing timing/physics rig.
## The original SpriteFrames still control animation_finished, durations and hitboxes.
var actor_code: String = ""
var sprite: AnimatedSprite2D
var _last_key: String = ""
var _tex: Texture2D
var _size: Vector2

func _ready() -> void:
	sprite = get_parent() as AnimatedSprite2D
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	use_parent_material = true
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
	_size = original.get_size()
	var code := actor_code
	var anim: StringName = &"rest" if actor_code == "camp_goldie" and sprite.animation != &"happy" else sprite.animation
	var pose := StoryArt.pose(code, anim, sprite.frame)
	if actor_code == "camp_goldie":
		pose = 3 if sprite.animation == &"happy" else (1 if sprite.animation == &"blink" else 0)
	if code in ["goldie", "camp_goldie"] and GameState.hero_class != &"knight":
		pose = StoryArt.pose("goldie", anim, sprite.frame)
		_tex = StoryArt.hero(GameState.hero_class, pose)
	else:
		_tex = StoryArt.actor(code, pose)
	if _tex == null:
		return
	sprite.self_modulate.a = 0.0
	scale = Vector2(-1 if sprite.flip_h else 1, -1 if sprite.flip_v else 1)
	var key := "%s/%d/%s/%s" % [String(anim) + String(GameState.hero_class), pose, sprite.centered, sprite.offset]
	if key != _last_key:
		_last_key = key
		queue_redraw()

func _draw() -> void:
	if _tex == null or sprite == null:
		return
	var at := sprite.offset - (_size * 0.5 if sprite.centered else Vector2.ZERO)
	var lift := float(sprite.sprite_frames.get_meta(&"foot_lift", 0))
	var height := _size.y - lift
	var dest := Rect2(at, Vector2(_size.x, height))
	# Keep the feet on the original shadow row, including lifted boss sprites.
	draw_texture_rect(_tex, dest, false)
