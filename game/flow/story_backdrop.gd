class_name StoryBackdrop
extends Control
## 整頁故事(開場繪本、第二章預告)時對白框後面的背景(BS2)。FlowMain 放在第 30 層(ScreenLayer)。
## 只是一片夜色;繪本插畫與文字由對白框(第 40 層)自己畫。不吃觸控(對白框擋住全部觸控)。

const COLOR: Color = Color("1b1424")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = COLOR
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)
