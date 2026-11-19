extends "res://scripts/landscape_preview.gd"
func setup(parent_ui: Control,value: Dictionary) -> void:
	super.setup(parent_ui,value)
	reflow()
func reflow() -> void:
	if not owner_ui.game.view.portrait_mode: return
	size=Vector2(540,960)
	var row=0
	for child in get_children():
		if child is Label: L.place(child,Rect2(24,112+row*44,492,44)); row+=1
	L.place(get_node("PreviewDetails"),Rect2(24,226,492,494))
	L.place(get_node("PreviewPlay"),Rect2(24,750,492,60))
	L.place(get_node("PreviewClose"),Rect2(24,832,492,52))
func _draw() -> void:
	if not owner_ui.game.view.portrait_mode: super._draw(); return
	draw_rect(Rect2(0,0,540,960),Color(0.04,0.11,0.15,0.82))
	draw_style_box(W.box(Color("fff8de"),18),Rect2(12,96,516,804))