extends Node
## Presentation integration; does not mutate progression, combat data, or saves.
const ACTOR_SKIN := preload("res://ui/illustrated/actor_skin.gd")
const WORLD_SKIN := preload("res://ui/illustrated/world_skin.gd")
const SURFACE := preload("res://ui/illustrated/texture_surface.gd")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	StoryTheme.install()
	get_tree().node_added.connect(_added)
	# Draw high-resolution assets at physical resolution while retaining world units.
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS

func _added(node: Node) -> void:
	if node is AnimatedSprite2D or node is TextureRect or node is TextureButton or node is NinePatchRect or (node is Node2D and node.scene_file_path.begins_with("res://assets/backgrounds/")):
		_install.call_deferred(weakref(node))

func _install(ref: WeakRef) -> void:
	var node := ref.get_ref() as Node
	if node == null or not node.is_inside_tree() or node.is_queued_for_deletion():
		return
	if node.has_meta(&"illustrated"):
		return
	node.set_meta(&"illustrated", true)
	if node is AnimatedSprite2D:
		var spr := node as AnimatedSprite2D
		var code := StoryArt.actor_id(spr.sprite_frames)
		if code == "hide_tail":
			spr.self_modulate.a = 0.0
		elif code == "goldie" or code == "camp_goldie" or code.begins_with("fx:") or StoryArt.CAST.has(code):
			var skin := Node2D.new()
			skin.set_script(ACTOR_SKIN)
			skin.name = "IllustratedActor"
			skin.set("actor_code", code)
			spr.add_child(skin)
	elif node is TextureRect or node is TextureButton or node is NinePatchRect:
		var skin := Control.new()
		skin.set_script(SURFACE)
		skin.name = "IllustratedSurface"
		skin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(skin)
		# Panels contain dialogue labels and arrows: their new surface belongs behind those children.
		node.move_child(skin, 0)
	elif node is Node2D:
		var id := StoryArt.world_id(node.scene_file_path.get_file().get_basename())
		if id.x == 0:
			return
		for child in node.get_children():
			if child is CanvasItem and child.name != &"ActorShadows" and child.name != &"Shadows":
				(child as CanvasItem).hide()
		var skin := Node2D.new()
		skin.name = "IllustratedWorld"
		skin.set_script(WORLD_SKIN)
		skin.set("chapter", id.x)
		skin.set("level", id.y)
		node.add_child(skin)
		node.move_child(skin, 0)

func _exit_tree() -> void:
	StoryArt._cells.clear()
	StoryArt._textures.clear()
