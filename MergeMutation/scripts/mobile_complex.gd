extends "res://scripts/evolution_complex.gd"
const UI=preload("res://scripts/mobile_ui.gd")
const MobileChrome=preload("res://scripts/mobile_chrome.gd")
const MobileFloor=preload("res://scripts/mobile_floor.gd")
const MobileHabitat=preload("res://scripts/mobile_habitat.gd")
const TouchScroll=preload("res://scripts/mobile_scroll.gd")
func make_floor(): return MobileFloor.new()
func make_living_detail(): return MobileHabitat.new()
func setup(value: Control,model=null) -> void:
	super.setup(value,model)
	remove_child(chrome); chrome.queue_free(); chrome=MobileChrome.new(); chrome.setup(game,"complex"); add_child(chrome)
	for connection in canvas.draw.get_connections(): canvas.draw.disconnect(connection.callable)
	canvas.draw.connect(func(): canvas.draw_rect(Rect2(Vector2.ZERO,canvas.size),UI.BG))
	reflow()
func viewport_rect() -> Rect2:
	if game==null: return Rect2(0,112,540,720)
	var layout=game.view.geometry
	return Rect2(0,layout.touch+64,layout.extent.x,maxf(100,layout.extent.y-layout.touch*2-92))
func reflow() -> void:
	if game==null or not is_instance_valid(scroll) or wide_rooms.is_empty(): return
	var layout=game.view.geometry; var width=layout.extent.x
	var rooms=wide_rooms.duplicate(true)
	for room in rooms:
		room.rect[0]=42+(room.rect[0]-28)*(width-54)/764
		room.rect[2]*=(width-54)/764
	if not registry.configure({"floors":wide_floors.duplicate(true)},{"habitats":rooms},width): push_error(registry.error); return
	for floor in active_floors.values(): canvas.remove_child(floor); floor.queue_free()
	active_floors.clear(); size=layout.extent; theme=UI.theme_for(layout)
	scroll.position=viewport_rect().position; scroll.size=viewport_rect().size
	canvas.custom_minimum_size=Vector2(width,viewport_rect().size.y+max_offset()); canvas.size=canvas.custom_minimum_size
	for child in get_children():
		if child is Label or child is Button: child.hide()
	indicator.position=Vector2(20,layout.touch+12); indicator.size=Vector2(width-40,36); indicator.add_theme_color_override("font_color",UI.MUTED)
	toast.position=Vector2(20,layout.touch+12); toast.size=Vector2(width-40,36); toast.add_theme_font_size_override("font_size",16)
	if is_instance_valid(chrome) and chrome.has_method("reflow"): chrome.reflow()
	set_scroll_position(offset)
	if is_instance_valid(detail): detail.reflow()
	if is_instance_valid(modal): close_modal()
	queue_redraw()
func show_lift() -> void:
	close_modal(); stop_motion(); pressed=false
	var card=UI.modal(self,game.view.geometry,"Лифт комплекса"); modal=card.overlay; modal_kind="LiftMenu"; menu_scroll=card.scroll
	for floor in registry.floors:
		var key: String=floor.floor_id
		var row=UI.button(card.content,"Lift_"+key,("0" if floor.depth==0 else "−%d" % floor.depth)+" · "+floor.name,func(): navigate_to_floor(key),game.view.geometry.touch)
		row.disabled=not floor.preview_accessible; row.mouse_filter=Control.MOUSE_FILTER_IGNORE
	TouchScroll.attach(card.scroll,func(): return is_instance_valid(modal),func(point):
		var local=point+Vector2(0,card.scroll.scroll_vertical)
		for row in card.content.get_children():
			if row.get_rect().has_point(local) and not row.disabled: row.pressed.emit(); return
	)
	UI.button(card.footer,"ComplexLiftClose","Закрыть",close_modal,game.view.geometry.touch); refresh_activity()
func show_room_info(id: String) -> bool:
	var room: Dictionary=registry.get_habitat(id)
	if room.is_empty() or not allowed_room(id): return false
	close_modal(); stop_motion()
	var card=UI.modal(self,game.view.geometry,room.name); modal=card.overlay; modal_kind="RoomInfo"
	UI.label(card.content,room.description)
	UI.label(card.content,"Этаж −%d" % registry.get_floor_for_habitat(id).depth)
	UI.button(card.footer,"ComplexInfoClose","Закрыть",close_modal,game.view.geometry.touch); refresh_activity(); return true
func _draw() -> void: draw_rect(Rect2(Vector2.ZERO,size),UI.BG)

func show_hint(text: String) -> void: notify(text)
func _process(delta: float) -> void:
	super._process(delta)
	indicator.visible=toast_left<=0 and detail==null and modal==null
	if game.view.app_suspended or is_instance_valid(game.view.overlay) or is_instance_valid(game.view.story_screen):
		for floor in active_floors.values(): floor.set_active(false)
