extends Control
const W = preload("res://scripts/journey_widgets.gd")
const Dialogue = preload("res://scripts/context_dialogue.gd")
var scene_id := ""
var data: Dictionary={}
var index := 0
var finished: Callable
var phase := 0.0
func setup(id: String,callback: Callable) -> bool:
	data=Dialogue.scene(id)
	if data.is_empty() or data.get("lines",[]).is_empty(): return false
	scene_id=id
	finished=callback
	size=Vector2(360,720)
	mouse_filter=Control.MOUSE_FILTER_STOP
	refresh()
	return true
func clear_children() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
func refresh() -> void:
	clear_children()
	var line: Dictionary=data.lines[index]
	W.label(self,data.title,Rect2(20,32,320,45),23,W.INK,true)
	W.label(self,"%d / %d" % [index+1,data.lines.size()],Rect2(20,80,320,28),12,W.INK,true)
	W.label(self,Dialogue.speaker_name(line.speaker),Rect2(40,363,280,30),17)
	W.label(self,line.text,Rect2(40,408,280,165),19)
	W.button(self,"StoryNext","К ПОРТАЛАМ" if index==data.lines.size()-1 else "ДАЛЕЕ",Rect2(24,610,196,52),advance)
	W.button(self,"StorySkip","ПРОПУСТИТЬ",Rect2(232,610,104,52),complete,Color("ded2fb"))
	queue_redraw()
func advance() -> void:
	if index+1>=data.lines.size(): complete()
	else:
		index+=1
		refresh()
func complete() -> void:
	if finished.is_valid(): finished.call(scene_id)
func _process(delta: float) -> void:
	phase+=delta
	queue_redraw()
func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		complete()
		get_viewport().set_input_as_handled()
func _draw() -> void:
	draw_rect(Rect2(0,0,360,720),Color("c9eae6"))
	for x in range(0,361,45): draw_line(Vector2(x,0),Vector2(x,720),Color("b5d8d7"),1)
	for y in range(0,721,45): draw_line(Vector2(0,y),Vector2(360,y),Color("b5d8d7"),1)
	draw_style_box(W.box(Color("fff8de"),18),Rect2(22,344,316,246))
	draw_cast()
func draw_cast() -> void:
	var speaker: String=data.lines[index].speaker
	if speaker=="scientist":
		draw_style_box(W.box(Color("f8fbf0"),20),Rect2(108,245,144,91))
		for side in [-1,1]:
			draw_line(Vector2(180,267),Vector2(180+side*34,320),Color("67a7ab"),4,true)
		var hair := PackedVector2Array()
		for point in [Vector2(-70,-5),Vector2(-87,-44),Vector2(-48,-35),Vector2(-42,-69),Vector2(-17,-47),Vector2(0,-79),Vector2(23,-44),Vector2(53,-63),Vector2(51,-28),Vector2(83,-29),Vector2(66,4)]: hair.append(point+Vector2(180,198))
		draw_colored_polygon(hair,Color("8cce64"))
		draw_circle(Vector2(180,213),55,W.INK)
		draw_circle(Vector2(180,213),52,Color("ffd7a2"))
		for x in [155,205]:
			draw_circle(Vector2(x,205),23,W.INK)
			draw_circle(Vector2(x,205),19,Color("c1edf1"))
			draw_circle(Vector2(x+2,207),6,W.INK)
			draw_circle(Vector2(x-5,199),4,Color.WHITE)
		draw_line(Vector2(176,205),Vector2(184,205),W.INK,5,true)
		draw_arc(Vector2(180,234),17,0.1,PI-0.1,20,W.INK,3,true)
		draw_line(Vector2(180,192),Vector2(187,228),Color("dca374"),3,true)
	else:
		draw_style_box(W.box(Color("6d9cba"),20),Rect2(88,149,184,143))
		draw_style_box(W.box(Color("1f425c"),12),Rect2(102,164,156,110))
		for x in [142,218]:
			draw_circle(Vector2(x,207),12,Color("85ecc1"))
			draw_line(Vector2(x-14,184),Vector2(x+12,187),Color("85ecc1"),3,true)
		draw_line(Vector2(158,245),Vector2(209,240),Color("85ecc1"),3,true)
		draw_line(Vector2(180,149),Vector2(180,125),W.INK,4,true)
		draw_circle(Vector2(180,119),7,Color("ffdc78"))
	for index in range(5):
		var spark := Vector2(50+index*65,308+sin(phase*1.4+index)*7)
		draw_circle(spark,2,Color("71bdb1"))
