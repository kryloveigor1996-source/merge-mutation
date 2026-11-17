extends Control
const W=preload("res://scripts/journey_widgets.gd")
const Habitat=preload("res://scripts/habitat_view.gd")
var data: Dictionary={}
var rooms: Dictionary={}
var phase:=0.0
func setup(value: Dictionary,registry,living_models: Dictionary={}) -> void:
	data=value
	position=Vector2(0,data.top)
	size=Vector2(360,data.height)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	for id in data.habitats:
		var room:=Habitat.new()
		var room_data: Dictionary=registry.get_habitat(id)
		if not data.preview_accessible: room_data.preview_accessible=false
		room.setup(room_data,living_models.get(id))
		add_child(room)
		rooms[id]=room
	set_process(false)
func set_active(value: bool,visible_area: Rect2=Rect2()) -> void:
	var unrestricted:=visible_area.size==Vector2.ZERO
	set_process(value and (unrestricted or Rect2(position,size).intersects(visible_area)))
	for room in rooms.values():
		var bounds:=Rect2(room.position+position,room.size)
		room.set_active(value and (unrestricted or bounds.intersects(visible_area)))
func _process(delta: float) -> void:
	phase+=delta
	queue_redraw()
func _draw() -> void:
	if data.is_empty(): return
	draw_rect(Rect2(Vector2.ZERO,size),Color("68707b") if data.depth==0 else Color("6e615d"))
	for index in range(int(size.y/34)):
		draw_circle(Vector2(354,24+index*34),5,Color("938070"))
	draw_rect(Rect2(3,0,22,size.y),Color("273e52"))
	for x in [7,21]: draw_line(Vector2(x,0),Vector2(x,size.y),Color("b0c8cb"),2)
	draw_line(Vector2(14,0),Vector2(14,size.y),Color("d3ac5d"),2)
	draw_rect(Rect2(28,0,320,34),Color("c8ddd9"))
	var title: String="0 · ПОВЕРХНОСТЬ" if data.depth==0 else "−%d · %s" % [data.depth,data.name]
	draw_string(ThemeDB.fallback_font,Vector2(36,23),title,HORIZONTAL_ALIGNMENT_LEFT,300,14,W.INK)
	draw_line(Vector2(28,size.y-8),Vector2(348,size.y-8),Color("354a5c"),10)
	draw_line(Vector2(28,size.y-7),Vector2(348,size.y-7),Color("c2a67a"),3)
	var lit:=sin(phase*2)>-0.5
	var lamp: Color=(Color("ffd16a") if lit else Color("e78362")) if data.theme_id=="secret" else (Color("a7f1b2") if lit else Color("75bb9c"))
	draw_circle(Vector2(338,16),4,lamp)
	if data.theme_id=="surface":
		draw_rect(Rect2(28,34,320,size.y-46),Color("9cd9dd"))
		draw_style_box(W.box(Color("e3eed1"),12),Rect2(45,65,284,117))
		draw_rect(Rect2(42,58,290,20),Color("e2ab62"))
		draw_string(ThemeDB.fallback_font,Vector2(87,101),"ЛАБОРАТОРИЯ",HORIZONTAL_ALIGNMENT_LEFT,-1,18,W.INK)
		draw_style_box(W.box(Color("597d98"),5),Rect2(165,112,47,70))
		draw_string(ThemeDB.fallback_font,Vector2(181,155),"↓",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color.WHITE)
		for x in [82,278]:
			draw_rect(Rect2(x,126,28,40),Color("477486"))
			draw_circle(Vector2(x+14,142),10,Color("a1e5ae"))
			draw_line(Vector2(x+10,120),Vector2(x+10,110),W.INK,3)
		draw_line(Vector2(240,58),Vector2(240,40),W.INK,3)
		draw_circle(Vector2(240,41),5,Color("ffdd7c"))
