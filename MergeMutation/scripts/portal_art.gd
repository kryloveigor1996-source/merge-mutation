extends Node2D
const W = preload("res://scripts/journey_widgets.gd")
var style := "science"
var unlocked := false
var phase := 0.0
var flash := 0.0:
	set(value):
		flash=value
		queue_redraw()
func setup(kind: String,available: bool) -> void:
	style=kind
	unlocked=available
	queue_redraw()
func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	phase+=delta
	queue_redraw()
func opening() -> Tween:
	var tween := create_tween()
	tween.tween_property(self,"flash",1.0,0.25)
	tween.tween_property(self,"flash",0.0,0.3)
	return tween
func _draw() -> void:
	draw_set_transform(Vector2(0,128),0,Vector2(1,0.18))
	draw_circle(Vector2.ZERO,83,Color(0.08,0.2,0.27,0.25))
	draw_set_transform(Vector2.ZERO)
	var frame := Rect2(-78,-120,156,244)
	var color: Color={"science":Color("65c9e2"),"swamp":Color("a4d950"),"prehistoric":Color("dcc59c"),"unknown":Color("bb9edb")}.get(style,Color("bb9edb"))
	var points := PackedVector2Array([Vector2(-77,122),Vector2(-81,-65),Vector2(-60,-108),Vector2(0,-128),Vector2(57,-112),Vector2(83,-67),Vector2(79,122)])
	if style=="prehistoric": points=PackedVector2Array([Vector2(-84,122),Vector2(-80,-79),Vector2(-59,-82),Vector2(-51,-123),Vector2(36,-128),Vector2(71,-102),Vector2(84,122)])
	if style=="unknown": points=PackedVector2Array([Vector2(-75,121),Vector2(-86,-58),Vector2(-38,-129),Vector2(36,-117),Vector2(82,-51),Vector2(75,121)])
	if not unlocked:
		draw_colored_polygon(points,Color("274653"))
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline,Color("718d97"),5,true)
		for index in range(8):
			var fog := Vector2(sin(index*2.5+phase*0.12)*66,55+cos(index*1.6)*62)
			draw_circle(fog,24+index%3*6,Color(0.65,0.78,0.79,0.1))
		W.draw_lock(self,Vector2(0,6))
		return
	if style=="science":
		draw_style_box(W.box(Color("ecf6e8"),36),frame)
		draw_style_box(W.box(Color("305c73"),25),frame.grow(-12))
		for side in [-1,1]:
			for y in range(-80,100,32):
				draw_rect(Rect2(side*66-5,y,10,18),Color("ffdc78"))
				draw_circle(Vector2(side*68,y+9),2,Color("25465a"))
	elif style=="swamp":
		draw_colored_polygon(points,Color("456644"))
		draw_polyline(points,Color("294f43"),8,true)
		for side in [-1,1]:
			var vine := PackedVector2Array()
			for index in range(18): vine.append(Vector2(side*(72+sin(index*0.8)*5),-104+index*13))
			draw_polyline(vine,Color("71b34b"),6,true)
			for index in range(6):
				var leaf := Vector2(side*73,-82+index*35)
				draw_colored_polygon(PackedVector2Array([leaf,leaf+Vector2(side*20,-11),leaf+Vector2(side*8,12)]),Color("a0d756"))
	elif style=="prehistoric":
		draw_colored_polygon(points,Color("8b8b81"))
		for side in [-1,1]:
			draw_line(Vector2(side*65,-90),Vector2(side*71,90),Color("e5d9b8"),10,true)
			for y in [-90,90]: draw_circle(Vector2(side*68,y),9,Color("e5d9b8"))
	else:
		draw_colored_polygon(points,Color("5a4e77"))
		draw_polyline(points,Color("b5a0d4"),6,true)
	var inner := Rect2(-56,-99,112,205)
	draw_style_box(W.box(Color("244b3d") if style=="swamp" else Color("293e58"),42),inner)
	for index in range(7):
		var t := phase*(0.22+index*0.02)+index*0.6
		var center := Vector2(sin(t)*12,cos(t)*15)
		draw_arc(center,15+index*5,0,TAU,48,Color(color,0.28+flash*0.5),2.5,true)
	for index in range(12):
		var angle := index*TAU/12+phase*0.25
		var spark := Vector2(cos(angle)*43,sin(angle)*82)
		draw_circle(spark,1.5+sin(phase+index)*0.5,Color("fff5bd"))
	if style=="science":
		draw_style_box(W.box(Color("ffdc78"),6),Rect2(-38,-139,76,29))
		draw_line(Vector2(-20,-125),Vector2(20,-125),Color("4e94b3"),4,true)
	if flash>0: draw_style_box(W.box(Color(0.75,1,0.82,flash*0.6),42),inner)
