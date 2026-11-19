extends "res://scripts/landscape_floor.gd"
func _draw() -> void:
	if display_width>600: super._draw(); return
	draw_rect(Rect2(Vector2.ZERO,size),Color("6e615d"))
	draw_rect(Rect2(3,0,22,size.y),Color("273e52"))
	for x in [7,21]: draw_line(Vector2(x,0),Vector2(x,size.y),Color("b0c8cb"),2)
	draw_line(Vector2(14,0),Vector2(14,size.y),Color("d3ac5d"),2)
	draw_rect(Rect2(28,0,display_width-40,42),Color("c8ddd9"))
	draw_string(ThemeDB.fallback_font,Vector2(42,28),("0" if data.depth==0 else "−%d" % data.depth)+" · "+data.name,HORIZONTAL_ALIGNMENT_LEFT,display_width-80,16,W.INK)
	draw_line(Vector2(28,size.y-8),Vector2(display_width-12,size.y-8),Color("354a5c"),10)
	if data.theme_id=="surface":
		draw_style_box(W.box(Color("b6d7c8")),Rect2(50,62,display_width-90,size.y-85))
		draw_rect(Rect2(44,56,display_width-80,24),Color("e2ab62"))
		draw_string(ThemeDB.fallback_font,Vector2(130,108),"ЛАБОРАТОРИЯ",HORIZONTAL_ALIGNMENT_LEFT,-1,18,W.INK)
		draw_style_box(W.box(Color("597d98")),Rect2(display_width*.5-28,122,56,size.y-145))