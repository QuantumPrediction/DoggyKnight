class_name DefeatPose
extends Node2D
## v2.6:被打敗的頭目留在場上的樣子(綠騎士單膝跪下、摩根娜坐在地上)——不是受傷,配合過關後的對白。
## 播一次 anim(預設 down)後停在最後一格,一直留到這一關結束(場地 clear() 時移除)。
## 身邊偶爾冒出小光點(sparkle_color),腳下有影子。在群組 combat_fx,放在地面層(在角色之下)。

var sprite_frames: SpriteFrames
var anim: StringName = &"down"
var flip: bool = false
var tint: Color = Color.WHITE
var sprite_scale: float = 1.0
var sparkle_color: Color = Color(0.85, 0.7, 1.0)
var shadow_width: float = 14.0

var _sprite: AnimatedSprite2D
var _age: float = 0.0
var _sparkle_left: float = 0.4
var _feet: float = 20.0


static func leave(host: Node2D, frames: SpriteFrames, p_flip: bool, p_tint: Color, p_scale: float,
		p_sparkle: Color, p_anim: StringName = &"down") -> DefeatPose:
	if host == null or not host.is_inside_tree() or frames == null:
		return null
	var pose := DefeatPose.new()
	pose.sprite_frames = frames
	pose.anim = p_anim
	pose.flip = p_flip
	pose.tint = p_tint
	pose.sprite_scale = p_scale
	pose.sparkle_color = p_sparkle
	CombatFx.layer_for(host, true).add_child(pose)
	pose.global_position = host.global_position
	return pose


func _ready() -> void:
	add_to_group(&"combat_fx")
	if sprite_frames == null:
		return
	var size := Vector2(48, 48)
	if sprite_frames.has_animation(&"idle") and sprite_frames.get_frame_count(&"idle") > 0:
		size = sprite_frames.get_frame_texture(&"idle", 0).get_size() * sprite_scale
	shadow_width = size.x * 0.3
	_feet = size.y * 0.42
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = sprite_frames
	_sprite.flip_h = flip
	_sprite.modulate = tint
	_sprite.scale = Vector2.ONE * sprite_scale
	add_child(_sprite)
	var a := anim if sprite_frames.has_animation(anim) else &"idle"
	if sprite_frames.get_animation_loop(a):
		# 會循環的動畫:停在最後一格。
		_sprite.animation = a
		_sprite.frame = maxi(0, sprite_frames.get_frame_count(a) - 1)
	else:
		_sprite.play(a)
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	_sparkle_left -= delta
	if _sparkle_left <= 0.0:
		_sparkle_left = 0.7
		var at := global_position + Vector2(randf_range(-shadow_width, shadow_width), randf_range(-_feet, _feet * 0.5))
		CombatFx.spawn(self, &"hit_spark", at, randf() * TAU, Vector2.ONE * 0.5, sparkle_color, false, 0.5)


func _draw() -> void:
	draw_set_transform(Vector2(0, _feet), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, shadow_width, Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2.ZERO)
