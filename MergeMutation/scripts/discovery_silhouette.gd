extends Control
## Reusable unknown-form frame. It promises no reward or undeclared unlock.
const W = preload("res://scripts/journey_widgets.gd")
func _ready() -> void:
	custom_minimum_size=Vector2(64,64)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	draw_circle(Vector2(32,32),29,W.INK)
	draw_circle(Vector2(32,32),26,Color("d6ded5"))
	draw_circle(Vector2(32,34),17,Color("526b72"))
	draw_circle(Vector2(22,25),7,Color("526b72"))
	draw_circle(Vector2(42,25),7,Color("526b72"))
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(26,41),"?",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("fff6cd"))
