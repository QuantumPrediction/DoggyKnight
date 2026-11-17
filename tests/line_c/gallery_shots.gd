extends Node
## C 線截圖工具(v2.5 CR6,不是自動化測試):把圖庫的每一頁截成 3 倍大的 PNG,方便重畫前後比較。
##
## 執行(需要畫面,雲端用 Xvfb):
##   xvfb-run -a godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##     res://tests/line_c/gallery_shots.tscn -- --out=/tmp/line_c_shots/v25/after_gallery [--pages=0,1,2]

var out_dir: String = "/tmp/line_c_shots/gallery"
var only: PackedInt32Array = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--pages="):
			for p in arg.trim_prefix("--pages=").split(","):
				only.append(int(p))
	DirAccess.make_dir_recursive_absolute(out_dir)
	var gallery := (load("res://tests/line_c/gallery.tscn") as PackedScene).instantiate()
	add_child(gallery)
	await _frames(5)
	var count: int = gallery.page_count()
	for i in count:
		if not only.is_empty() and not only.has(i):
			continue
		gallery.show_page(i)
		await _frames(18)
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.resize(image.get_width() * 3, image.get_height() * 3, Image.INTERPOLATE_NEAREST)
		image.save_png(out_dir.path_join("page_%02d.png" % i))
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
