extends Control
const Registry=preload("res://scripts/complex_registry.gd")
const Floor=preload("res://scripts/complex_floor.gd")
const Art=preload("res://scripts/mutant_art.gd")
const Catalog=preload("res://scripts/mutant_catalog.gd")
const W=preload("res://scripts/journey_widgets.gd")
const LivingRegistry=preload("res://scripts/living_registry.gd")
const HabitatState=preload("res://scripts/habitat_state.gd")
const LivingScene=preload("res://scenes/living_habitat.tscn")
const VIEW:=Rect2(0,102,360,538)
signal habitat_inspect_requested(habitat_id: String)
var game: Control
var registry
var scroll: ScrollContainer
var canvas: Control
var active_floors: Dictionary={}
var current_floor_id:=""
var offset:=0.0
var velocity:=0.0
var pressed:=false
var start_point:=Vector2.ZERO
var last_point:=Vector2.ZERO
var travel:=0.0
var last_motion:=0
var navigation: Tween
var navigation_target:=0.0
var indicator: Label
var toast: Label
var toast_left:=0.0
var modal: Control
var modal_kind:=""
var details_habitat_id:=""
var menu_scroll: ScrollContainer
var menu_pressed:=false
var menu_last:=Vector2.ZERO
var menu_start:=Vector2.ZERO
var menu_travel:=0.0
var pending_highlight:=""
var living_registry:=LivingRegistry.new()
var living_models: Dictionary={}
var detail: Control
var detail_offset:=0.0
var exiting:=false
func setup(value: Control,model=null) -> void:
	game=value
	size=Vector2(360,720)
	z_index=30
	mouse_filter=Control.MOUSE_FILTER_STOP
	registry=model if model!=null else Registry.new()
	if model==null and not registry.load_files():
		W.label(self,"Комплекс недоступен\n"+registry.error,Rect2(22,180,316,160),18)
		W.button(self,"ComplexBack","НАЗАД",Rect2(24,644,312,54),back)
		return
	# Stress/custom registries may contain no supported living assignment at all.
	create_living_models()
	W.label(self,"ПОДЗЕМНЫЙ КОМПЛЕКС",Rect2(16,16,328,36),22,Color("ecf7ee"),true)
	indicator=W.label(self,"",Rect2(16,57,328,32),14,Color("b8e9db"),true)
	scroll=ScrollContainer.new()
	scroll.name="ComplexScroll"
	scroll.position=viewport_rect().position
	scroll.size=viewport_rect().size
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(scroll)
	canvas=Control.new()
	canvas.custom_minimum_size=Vector2(registry.width,viewport_rect().size.y+max_offset())
	canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(func():
		canvas.draw_rect(Rect2(Vector2.ZERO,canvas.size),Color("504d55"))
		if canvas.size.y>registry.extent+32:
			canvas.draw_string(ThemeDB.fallback_font,Vector2(35,registry.extent+40),"НИЖЕ — ТОЛЬКО БЕЗУМНАЯ НАУКА",HORIZONTAL_ALIGNMENT_LEFT,305,11,Color("b6b2a9"))
	)
	scroll.add_child(canvas)
	for item in [["ComplexTop","НАВЕРХ",8,go_top],["ComplexBottom","ВНИЗ",96,go_bottom],["ComplexLift","ЛИФТ",184,show_lift],["ComplexBack","НАЗАД",272,back]]:
		W.button(self,item[0],item[1],Rect2(item[2],654,80,52),item[3],Color("b6e2db"))
	toast=W.label(self,"",Rect2(20,601,320,37),13,Color("fff2b0"),true)
	toast.z_index=5
	toast.add_theme_stylebox_override("normal",W.box(Color("304c62"),8))
	toast.hide()
	set_scroll_position(0)
func viewport_rect() -> Rect2: return VIEW
func lift_rect() -> Rect2: return Rect2(30,202,300,320)
func make_floor(): return Floor.new()
func make_living_detail(): return LivingScene.instantiate()
func create_living_models() -> void:
	if registry.habitats.has("habitat_horn") and living_registry.load_files(registry):
		for id in living_registry.assignments:
			var state:=HabitatState.new()
			state.setup(id,living_registry)
			living_models[id]=state
func max_offset() -> float:
	if registry.floors.is_empty(): return 0
	return maxf(registry.floors.back().top,registry.extent-viewport_rect().size.y)
func set_scroll_position(value: float) -> void:
	offset=clampf(value,0,max_offset())
	scroll.scroll_vertical=int(offset)
	update_visible()
	var current: Dictionary=registry.floor_at(offset+1)
	current_floor_id=current.get("floor_id","")
	indicator.text=("Этаж 0" if current.get("depth",0)==0 else "Этаж −%d" % current.depth)+" · "+current.get("name","")
func update_visible() -> void:
	var ids: Array=registry.visible_floors(offset,viewport_rect().size.y)
	for id in active_floors.keys():
		if id not in ids:
			canvas.remove_child(active_floors[id])
			active_floors[id].queue_free()
			active_floors.erase(id)
	for id in ids:
		if not active_floors.has(id):
			var floor=make_floor()
			floor.setup(registry.get_floor(id),registry,living_models)
			canvas.add_child(floor)
			active_floors[id]=floor
		active_floors[id].set_active(not exiting and detail==null and modal==null,Rect2(0,offset,registry.width,viewport_rect().size.y))
	if not pending_highlight.is_empty():
		var room=room_view(pending_highlight)
		if room!=null and room.active:
			room.highlight()
			pending_highlight=""
func room_view(id: String):
	var data: Dictionary=registry.get_habitat(id)
	if data.is_empty() or not active_floors.has(data.floor_id): return null
	return active_floors[data.floor_id].rooms.get(id)
func stop_motion() -> void:
	if navigation: navigation.kill()
	navigation=null
	navigation_target=offset
	velocity=0
func move_to(value: float,animate: bool=true) -> void:
	if is_instance_valid(detail): close_living(false)
	stop_motion()
	pressed=false
	close_modal()
	var target:=clampf(value,0,max_offset())
	navigation_target=target
	if not animate or absf(target-offset)>viewport_rect().size.y*6:
		set_scroll_position(target)
		return
	navigation=create_tween()
	navigation.tween_method(set_scroll_position,offset,target,0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
func navigate_to_floor(id: String,animate: bool=true) -> bool:
	var data: Dictionary=registry.get_floor(id)
	if data.is_empty() or not data.preview_accessible: return false
	pending_highlight=""
	move_to(data.top,animate)
	return true
func allowed_room(id: String) -> bool:
	var data: Dictionary=registry.get_habitat(id)
	return not data.is_empty() and data.preview_accessible and registry.get_floor(data.floor_id).preview_accessible
func navigate_to_habitat(id: String,animate: bool=true) -> bool:
	if not allowed_room(id): return false
	pending_highlight=id
	move_to(registry.room_rects[id].position.y-48,animate)
	return true
func highlight_habitat(id: String) -> bool:
	if not allowed_room(id): return false
	var room=room_view(id)
	if room==null: return false
	room.highlight()
	return true
func go_top() -> void:
	for floor in registry.floors:
		if floor.preview_accessible:
			navigate_to_floor(floor.floor_id)
			return
func go_bottom() -> void:
	for index in range(registry.floors.size()-1,-1,-1):
		if registry.floors[index].preview_accessible:
			navigate_to_floor(registry.floors[index].floor_id)
			return
func notify(message: String) -> void:
	toast.text=message
	toast_left=2.2
	toast.show()
func room_at(point: Vector2) -> String:
	if not viewport_rect().has_point(point): return ""
	var world:=point-viewport_rect().position+Vector2(0,scroll.scroll_vertical)
	for id in registry.room_rects:
		if registry.room_rects[id].has_point(world): return id
	return ""
func open_room(id: String) -> bool:
	if not registry.habitats.has(id): return false
	stop_motion()
	if not allowed_room(id):
		notify("Камера пока недоступна")
		return false
	if living_models.has(id): open_living(id)
	else: show_room_info(id)
	habitat_inspect_requested.emit(id)
	return true
func open_living(id: String) -> bool:
	if not allowed_room(id) or not living_models.has(id): return false
	if is_instance_valid(detail): return detail.model.habitat_id==id
	close_modal()
	stop_motion()
	detail_offset=offset
	detail=make_living_detail()
	detail.setup(self,living_models[id],registry.get_habitat(id),registry.get_floor_for_habitat(id))
	detail.closed.connect(close_living)
	add_child(detail)
	refresh_activity()
	return true
func close_living(highlight: bool=true) -> void:
	if not is_instance_valid(detail): return
	var id: String=detail.model.habitat_id
	detail.set_active(false)
	remove_child(detail)
	detail.queue_free()
	detail=null
	if not exiting:
		set_scroll_position(detail_offset)
		if highlight: highlight_habitat(id)
	refresh_activity()
func refresh_activity() -> void:
	if is_instance_valid(detail): detail.set_active(not exiting and modal==null)
	if is_instance_valid(scroll): update_visible()
func new_modal(kind: String) -> Control:
	close_modal()
	stop_motion()
	pressed=false
	modal=Control.new()
	modal.name="Complex"+kind
	modal.size=size
	modal.mouse_filter=Control.MOUSE_FILTER_STOP
	modal.z_index=40
	modal_kind=kind
	var panel:=modal
	panel.draw.connect(func():
		panel.draw_rect(Rect2(Vector2.ZERO,panel.size),Color(0.05,0.12,0.2,0.8))
		panel.draw_style_box(W.box(Color("eef2d9"),18),Rect2(18,90,324,536))
	)
	add_child(modal)
	refresh_activity()
	return modal
func show_room_info(id: String) -> bool:
	if not allowed_room(id): return false
	var data: Dictionary=registry.get_habitat(id)
	var panel:=new_modal("RoomInfo")
	details_habitat_id=id
	W.label(panel,Catalog.species(data.species_id).name if data.has("species_id") else data.name,Rect2(30,108,300,42),24,W.INK,true)
	W.label(panel,"ДЕМОНСТРАЦИОННЫЙ ОБЗОР",Rect2(30,156,300,28),12,W.INK,true)
	if data.has("species_id"):
		var art:=Art.new()
		art.setup_form({"species_id":data.species_id,"evolution_stage":1})
		art.position=Vector2(180,246)
		art.scale=Vector2.ONE*1.8
		panel.add_child(art)
	var floor: Dictionary=registry.get_floor_for_habitat(id)
	W.label(panel,"Этаж −%d · %s" % [floor.depth,floor.name],Rect2(30,316,300,42),14,W.INK,true)
	W.label(panel,"ID: "+id,Rect2(30,363,300,34),12,W.INK,true)
	W.label(panel,data.description,Rect2(30,409,300,120),14,W.INK,true)
	W.button(panel,"ComplexInfoClose","ЗАКРЫТЬ",Rect2(30,554,300,50),close_modal,Color("b6e2db"))
	return true
func show_lift() -> void:
	var panel:=new_modal("LiftMenu")
	W.label(panel,"ЛИФТ",Rect2(30,108,300,36),24,W.INK,true)
	W.label(panel,"Выберите этаж · демо-просмотр",Rect2(30,156,300,34),13,W.INK,true)
	menu_scroll=ScrollContainer.new()
	menu_scroll.position=lift_rect().position
	menu_scroll.size=lift_rect().size
	menu_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	menu_scroll.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.add_child(menu_scroll)
	var body:=VBoxContainer.new()
	body.mouse_filter=Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation",8)
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	menu_scroll.add_child(body)
	for floor in registry.floors:
		var title: String=("0" if floor.depth==0 else "−%d" % floor.depth)+" · "+floor.name+(" ←" if floor.floor_id==current_floor_id else "")
		var row:=W.button(body,"Lift_"+floor.floor_id,title+"\n%d помещений · %s" % [floor.habitats.size(),"просмотр" if floor.preview_accessible else "недоступен"],Rect2(0,0,300,60),func(): navigate_to_floor(floor.floor_id))
		row.clip_text=true
		row.mouse_filter=Control.MOUSE_FILTER_IGNORE
	W.button(panel,"ComplexLiftClose","НАЗАД",Rect2(30,554,300,50),close_modal,Color("b6e2db"))
	panel.gui_input.connect(menu_input)
func close_modal() -> void:
	if is_instance_valid(modal):
		remove_child(modal)
		modal.queue_free()
	modal=null
	modal_kind=""
	details_habitat_id=""
	menu_scroll=null
	menu_pressed=false
	refresh_activity()
func back() -> void:
	if is_instance_valid(modal): close_modal()
	elif is_instance_valid(detail): close_living()
	else: exit_complex()
func exit_complex() -> void:
	if is_queued_for_deletion(): return
	exiting=true
	close_living(false)
	stop_motion()
	close_modal()
	if get_parent()!=null: get_parent().remove_child(self)
	queue_free()
func pointer_event(event: InputEvent) -> Dictionary:
	if event is InputEventScreenTouch:
		if event.index!=0: return {}
		return {"point":event.position,"down":event.pressed,"up":not event.pressed,"motion":false,"cancel":event.canceled}
	if event is InputEventScreenDrag:
		if event.index!=0: return {}
		return {"point":event.position,"down":false,"up":false,"motion":true}
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		return {"point":event.position,"down":event.pressed,"up":not event.pressed,"motion":false}
	if event is InputEventMouseMotion: return {"point":event.position,"down":false,"up":false,"motion":true}
	return {}
func _gui_input(event: InputEvent) -> void:
	if not is_instance_valid(scroll): return
	if event is InputEventMouseButton and event.pressed and viewport_rect().has_point(event.position) and event.button_index in [MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_WHEEL_UP]:
		var origin: float=navigation_target if navigation!=null and navigation.is_running() else offset
		move_to(origin+(90 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -90))
		accept_event()
		return
	var info:=pointer_event(event)
	if info.is_empty(): return
	var point: Vector2=info.point
	if info.get("cancel",false):
		pressed=false
		velocity=0
	elif info.down:
		pending_highlight=""
		stop_motion()
		pressed=viewport_rect().has_point(point)
		start_point=point
		last_point=point
		travel=0
		last_motion=Time.get_ticks_msec()
	elif info.motion and pressed:
		var delta:=point-last_point
		travel+=delta.length()
		var now:=Time.get_ticks_msec()
		velocity=clampf(-delta.y/maxf(0.016,(now-last_motion)/1000.0),-1800,1800)
		set_scroll_position(offset-delta.y)
		last_point=point
		last_motion=now
	elif info.up and pressed:
		pressed=false
		if maxf(travel,point.distance_to(start_point))<=12 and viewport_rect().has_point(point):
			velocity=0
			var id:=room_at(point)
			if not id.is_empty(): open_room(id)
	accept_event()
func menu_input(event: InputEvent) -> void:
	if not is_instance_valid(menu_scroll): return
	var area:=lift_rect()
	if event is InputEventMouseButton and event.pressed and area.has_point(event.position) and event.button_index in [MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_WHEEL_UP]:
		menu_scroll.scroll_vertical+=68 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -68
		return
	var info:=pointer_event(event)
	if info.is_empty(): return
	var point: Vector2=info.point
	if info.get("cancel",false): menu_pressed=false
	elif info.down:
		menu_pressed=area.has_point(point)
		menu_start=point
		menu_last=point
		menu_travel=0
	elif info.motion and menu_pressed:
		menu_travel+=point.distance_to(menu_last)
		menu_scroll.scroll_vertical-=int(point.y-menu_last.y)
		menu_last=point
	elif info.up and menu_pressed:
		menu_pressed=false
		if maxf(menu_travel,point.distance_to(menu_start))<=12 and area.has_point(point):
			var row:=int((point.y-lift_rect().position.y+menu_scroll.scroll_vertical)/68)
			if row>=0 and row<registry.floors.size() and fmod(point.y-lift_rect().position.y+menu_scroll.scroll_vertical,68)<60: navigate_to_floor(registry.floors[row].floor_id)
func _process(delta: float) -> void:
	if not is_instance_valid(scroll): return
	if not pressed and not is_instance_valid(modal) and absf(velocity)>1:
		var next:=offset+velocity*delta
		set_scroll_position(next)
		velocity=move_toward(velocity,0,delta*2500)
		if offset==0 or offset==max_offset(): velocity=0
	scroll.scroll_vertical=int(offset)
	toast_left=maxf(0,toast_left-delta)
	if toast_left==0: toast.hide()
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var viewport:=get_viewport()
		back()
		viewport.set_input_as_handled()
func _draw() -> void:
	draw_rect(Rect2(0,0,360,720),Color("243e54"))
