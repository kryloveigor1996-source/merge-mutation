extends "res://scripts/complex_floor.gd"
var display_width:=804.0
func setup(value: Dictionary,registry,living_models: Dictionary={}) -> void:
	super.setup(value,registry,living_models)
	display_width=registry.width
	size.x=display_width
func _draw() -> void:
	if data.is_empty(): return
	draw_rect(Rect2(Vector2.ZERO,size),Color("6e615d"))
	draw_rect(Rect2(3,0,22,size.y),Color("273e52"))
	for x in [7,21]: draw_line(Vector2(x,0),Vector2(x,size.y),Color("b0c8cb"),2)
	draw_line(Vector2(14,0),Vector2(14,size.y),Color("d3ac5d"),2)
	draw_rect(Rect2(28,0,display_width-40,42),Color("c8ddd9"))
	draw_string(ThemeDB.fallback_font,Vector2(42,28),("0" if data.depth==0 else "−%d" % data.depth)+" · "+data.name,HORIZONTAL_ALIGNMENT_LEFT,display_width-80,18,W.INK)
	draw_line(Vector2(28,size.y-8),Vector2(display_width-12,size.y-8),Color("354a5c"),10)
	if data.theme_id=="surface":
		draw_style_box(W.box(Color("b6d7c8")),Rect2(50,62,display_width-90,size.y-85))
		draw_rect(Rect2(44,56,display_width-80,24),Color("e2ab62"))
		draw_string(ThemeDB.fallback_font,Vector2(120,108),"ЛАБОРАТОРИЯ · ВХОД В КОМПЛЕКС",HORIZONTAL_ALIGNMENT_LEFT,-1,23,W.INK)
		draw_style_box(W.box(Color("597d98")),Rect2(display_width*0.5-28,122,56,size.y-145))
		for x in [100,display_width-130]:
			draw_rect(Rect2(x,128,54,52),Color("477486"))
			draw_circle(Vector2(x+27,151),15,Color("b3e6ae"))
