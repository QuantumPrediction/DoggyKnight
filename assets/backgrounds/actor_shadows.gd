extends Node2D
## 角色投影(C 線,v2.3 CS5)。掛在每個場地背景裡(背景圖層 z -100,永遠在預警與角色之下)。
##
## 每一格在群組 player、companion、enemy 的節點腳下畫一個像素橢圓影子,大小依角色的動畫格子
## (子節點 "Sprite" 的目前格)。A 線不用改任何東西;敵人倒下時立即離開 enemy 群組,影子也跟著消失。
## 會飛的(烏鴉,v2.6 加石像鬼、魔法書、狐火)影子落在下方的地面,比較淡。
## v2.6:SpriteFrames 有 metadata foot_lift(每格往上移的像素,例如黑騎士 8)時,影子也往上移同樣多,
## 仍然在腳底。
## v2.7:會飛的加上電電水母與提燈鬼火;章魚王與紅龍、白龍的 foot_lift = 8 也照上面的規則讀取。

const GROUPS: Array[StringName] = [&"player", &"companion", &"enemy"]
const FLYERS: PackedStringArray = ["/crow/", "/gargoyle/", "/spellbook/", "/foxfire/", "/jellyfish/",
		"/lantern_wisp/"]

@export var color: Color = Color(0.165, 0.106, 0.176, 0.4)
@export var width_ratio: float = 0.66
@export var height_ratio: float = 0.32
@export var flyer_drop: float = 7.0

var _frame_size: Dictionary = {}   # SpriteFrames 的 instance id -> 第一格大小
var _foot_lift: Dictionary = {}    # SpriteFrames 的 instance id -> metadata foot_lift(像素)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for group in GROUPS:
		for node in tree.get_nodes_in_group(group):
			var body := node as Node2D
			if body == null or not body.is_visible_in_tree():
				continue
			_shadow_for(body)


func _shadow_for(body: Node2D) -> void:
	var pos := body.global_position
	var size := Vector2(20, 24)
	var scale_abs := Vector2.ONE
	var alpha := color.a
	var flyer := false
	var lift := 0.0
	var spr := body.get_node_or_null(^"Sprite") as AnimatedSprite2D
	if spr != null and spr.sprite_frames != null:
		if not spr.visible:
			return
		var key := spr.sprite_frames.get_instance_id()
		if not _frame_size.has(key):
			var tex := spr.sprite_frames.get_frame_texture(&"idle", 0) if spr.sprite_frames.has_animation(&"idle") else null
			_frame_size[key] = tex.get_size() if tex != null else size
			_foot_lift[key] = float(spr.sprite_frames.get_meta(&"foot_lift", 0.0))
		size = _frame_size[key]
		lift = _foot_lift[key]
		pos = spr.global_position
		scale_abs = spr.global_scale.abs()
		alpha *= clampf(spr.modulate.a * body.modulate.a, 0.0, 1.0)
		for f in FLYERS:
			if spr.sprite_frames.resource_path.contains(f):
				flyer = true
	var feet := pos + Vector2(0, (size.y * 0.5 - lift) * scale_abs.y - 2.0)
	var w := maxi(4, roundi(size.x * scale_abs.x * width_ratio))
	if flyer:
		feet.y += flyer_drop
		w = maxi(4, roundi(w * 0.7))
		alpha *= 0.6
	var h := maxi(2, roundi(w * height_ratio))
	_ellipse(to_local(feet).round(), w, h, Color(color, alpha))


## 像素橢圓:一行一個矩形,邊緣對齊整數像素。
func _ellipse(center: Vector2, w: int, h: int, col: Color) -> void:
	var half_h := h * 0.5
	for row in h:
		var dy := (row + 0.5 - half_h) / half_h
		var half_w := floorf(w * 0.5 * sqrt(maxf(0.0, 1.0 - dy * dy)) + 0.35)
		if half_w <= 0.0:
			continue
		draw_rect(Rect2(center.x - half_w, center.y - floorf(half_h) + row, half_w * 2.0, 1.0), col)
