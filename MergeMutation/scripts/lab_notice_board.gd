extends Node2D
## The lab is home: an ordinary notice board, never a portal.
const W = preload("res://scripts/journey_widgets.gd")
var unlocked := true
var flash := 0.0:
	set(value):
		flash=value
		queue_redraw()
func setup(_kind: String,_available: bool) -> void:
	unlocked=true
func opening() -> Tween:
	var tween := create_tween()
	tween.tween_property(self,"flash",1.0,0.1)
	tween.tween_property(self,"flash",0.0,0.12)
	return tween
func _draw() -> void:
	for side in [-1,1]:
		draw_line(Vector2(side*65,85),Vector2(side*74,127),W.INK,9,true)
		draw_line(Vector2(side*65,85),Vector2(side*74,127),Color("91aaa5"),5,true)
	draw_style_box(W.box(Color("a87d56"),9),Rect2(-98,-115,196,224))
	draw_style_box(W.box(Color("dbc097"),5),Rect2(-89,-105,178,203))
	# Blueprint and hand-drawn winding route.
	draw_style_box(W.box(Color("d7eef0"),3),Rect2(-77,-81,100,113))
	for y in range(-72,22,15): draw_line(Vector2(-70,y),Vector2(16,y),Color("b2d4dc"),1)
	for x in range(-70,17,15): draw_line(Vector2(x,-74),Vector2(x,25),Color("b2d4dc"),1)
	var route := PackedVector2Array([Vector2(-59,15),Vector2(-26,-6),Vector2(-52,-33),Vector2(-9,-60)])
	draw_polyline(route,Color("568595"),2,true)
	for index in range(route.size()):
		draw_circle(route[index],7,W.INK)
		draw_circle(route[index],5,Color("ffdc79"))
	# Pinned photographs, specimen snapshot and scribbled notes.
	draw_style_box(W.box(Color("fffae9"),2),Rect2(34,-84,43,51))
	draw_rect(Rect2(39,-78,33,32),Color("7fbba4"))
	draw_circle(Vector2(56,-60),11,Color("8cce61"))
	for x in [52,60]: draw_circle(Vector2(x,-63),2,W.INK)
	draw_style_box(W.box(Color("fff0b2"),2),Rect2(28,-16,51,55))
	for y in range(-5,27,8): draw_line(Vector2(35,y),Vector2(70,y+2),Color("a79d72"),1.5,true)
	draw_style_box(W.box(Color("fff7df"),2),Rect2(-65,49,125,37))
	draw_line(Vector2(-54,62),Vector2(48,62),Color("9aaf9e"),2,true)
	draw_line(Vector2(-54,71),Vector2(28,71),Color("9aaf9e"),2,true)
	for pin in [Vector2(-72,-80),Vector2(54,-83),Vector2(51,-15),Vector2(-3,49)]:
		draw_circle(pin+Vector2(1,2),4,W.INK)
		draw_circle(pin,3,Color("da7566"))
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(-62,-93),"ПЛАН ЛАБОРАТОРИИ",HORIZONTAL_ALIGNMENT_LEFT,-1,10,W.INK)
	if flash>0: draw_rect(Rect2(-101,-118,202,230),Color(1,0.87,0.45,flash),false,4)
