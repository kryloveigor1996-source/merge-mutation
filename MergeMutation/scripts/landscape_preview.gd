extends "res://scripts/level_preview_screen.gd"
const L=preload("res://scripts/landscape_layout.gd")
func setup(parent_ui: Control,value: Dictionary) -> void:
	super.setup(parent_ui,value)
	size=L.DESIGN
	for child in get_children():
		if child is Label: L.place(child,Rect2(64,80 if child.position.y<110 else 140,280,65))
	L.place(get_node("PreviewDetails"),Rect2(380,54,510,358))
	L.place(get_node("PreviewPlay"),Rect2(380,442,240,58))
	L.place(get_node("PreviewClose"),Rect2(642,442,248,58))
func _draw() -> void:
	draw_rect(Rect2(0,0,960,540),Color(0.08,0.2,0.24,0.55))
	draw_style_box(W.box(Color("fff8de"),18),Rect2(36,24,888,492))
