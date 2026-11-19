extends "res://scripts/core_complex.gd"
const ChromeAdaptive=preload("res://scripts/evolution_chrome.gd")
const DetailAdaptive=preload("res://scripts/evolution_habitat.gd")
const FloorAdaptive=preload("res://scripts/evolution_floor.gd")
var wide_rooms: Array=[]
var wide_floors: Array=[]
func make_floor(): return FloorAdaptive.new()
func make_living_detail(): return DetailAdaptive.new()
func viewport_rect() -> Rect2:
	return Rect2(0,188,540,684) if game!=null and game.view.portrait_mode else super.viewport_rect()
func setup(value: Control,model=null) -> void:
	super.setup(value,model)
	wide_rooms=registry.habitats.values().duplicate(true)
	wide_floors=registry.floors.duplicate(true)
	chrome=ChromeAdaptive.replace(self,game,"complex")
	reflow()
func reflow() -> void:
	var tall: bool=game.view.portrait_mode
	var rooms=wide_rooms.duplicate(true)
	var width=540.0 if tall else 804.0
	for room in rooms:
		room.rect[0]=28+(room.rect[0]-28)*(width-40)/764
		room.rect[2]*=(width-40)/764
	if not registry.configure({"floors":wide_floors.duplicate(true)},{"habitats":rooms},width): push_error(registry.error); return
	for floor in active_floors.values(): canvas.remove_child(floor); floor.queue_free()
	active_floors.clear()
	size=Vector2(540,960) if tall else Vector2(960,540)
	scroll.position=viewport_rect().position; scroll.size=viewport_rect().size
	canvas.custom_minimum_size=Vector2(width,viewport_rect().size.y+max_offset())
	canvas.size=canvas.custom_minimum_size
	for child in get_children():
		if child is Label and child!=indicator and child!=toast: child.visible=not tall
	if tall:
		L.place(indicator,Rect2(18,126,290,48))
		get_node("ComplexTop").text="↑"; L.place(get_node("ComplexTop"),Rect2(320,126,64,48))
		get_node("ComplexBottom").text="↓"; L.place(get_node("ComplexBottom"),Rect2(392,126,64,48))
		L.place(get_node("ComplexLift"),Rect2(464,126,64,48)); get_node("ComplexLift").text="ЛИФТ"
		L.place(toast,Rect2(20,830,500,42))
	else:
		L.place(indicator,Rect2(820,66,126,100))
		for item in [["ComplexTop",180,"НАВЕРХ"],["ComplexBottom",248,"ВНИЗ"],["ComplexLift",316,"ЛИФТ"]]: L.place(get_node(item[0]),Rect2(820,item[1],126,56)); get_node(item[0]).text=item[2]
		L.place(toast,Rect2(20,435,760,38))
	set_scroll_position(offset)
	if is_instance_valid(detail): detail.reflow()
	if is_instance_valid(modal): close_modal()
	queue_redraw()
func new_modal(kind: String) -> Control:
	var panel=super.new_modal(kind)
	for connection in panel.draw.get_connections(): panel.draw.disconnect(connection.callable)
	panel.mouse_filter=Control.MOUSE_FILTER_STOP
	panel.size=Vector2(540,960) if game.view.portrait_mode else Vector2(960,540)
	panel.draw.connect(func():
		panel.draw_rect(Rect2(Vector2.ZERO,panel.size),Color(0.04,0.1,0.15,0.82))
		panel.draw_style_box(W.box(Color("eef2d9"),18),Rect2(12,150,516,680) if game.view.portrait_mode else Rect2(140,16,804,508))
	)
	return panel
func show_room_info(id: String) -> bool:
	if not super.show_room_info(id): return false
	var row=0
	for child in modal.get_children():
		if child is Label:
			if child.text.begins_with("ID:"): child.text="Исследовательский комплекс"
			if child.text=="ДЕМОНСТРАЦИОННЫЙ ОБЗОР": child.text="ОБИТАТЕЛЬ КОМПЛЕКСА"
			if game.view.portrait_mode:
				L.place(child,Rect2(24,170+row*60 if row<2 else 440+(row-2)*74,492,68 if row!=4 else 120))
			row+=1
		elif child is Node2D and game.view.portrait_mode: child.position=Vector2(270,360); child.scale=Vector2.ONE*2
	if game.view.portrait_mode: L.place(modal.get_node("ComplexInfoClose"),Rect2(24,754,492,54))
	return true
func show_lift() -> void:
	super.show_lift()
	if not game.view.portrait_mode: return
	var index=0
	for child in modal.get_children():
		if child is Label: L.place(child,Rect2(24,174+index*48,492,44)); index+=1
	L.place(menu_scroll,Rect2(24,280,492,440))
	L.place(modal.get_node("ComplexLiftClose"),Rect2(24,752,492,54))
func _draw() -> void:
	if not game.view.portrait_mode: super._draw(); return
	draw_rect(Rect2(0,0,540,960),Color("243e54"))