extends RefCounted
const W=preload("res://scripts/journey_widgets.gd")
static func box(n: CanvasItem,r: Rect2,c: Color,radius: int=10) -> void: n.draw_style_box(W.box(c,radius),r)
static func poly(n: CanvasItem,points: Array,c: Color) -> void: n.draw_colored_polygon(PackedVector2Array(points),c)
static func oval(n: CanvasItem,r: Rect2,c: Color) -> void:
	var points:=PackedVector2Array()
	for i in range(32): points.append(r.get_center()+Vector2.from_angle(i*TAU/32)*r.size*0.5)
	n.draw_colored_polygon(points,c)
