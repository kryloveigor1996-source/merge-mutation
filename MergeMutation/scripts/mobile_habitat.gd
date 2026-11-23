extends "res://scripts/core_habitat.gd"
const UI=preload("res://scripts/mobile_ui.gd")
const Camera=preload("res://scripts/mobile_camera.gd")
const MobileEnvironment=preload("res://scripts/mobile_environment.gd")
const TouchScroll=preload("res://scripts/mobile_scroll.gd")
var camera=Camera.new()
var camera_profile: Dictionary={}
var mode="observation"
var hud: Control
var zones: Control
var sheet_content: VBoxContainer
var sheet_actions: HBoxContainer
var zoom_label: Label
var toast_time=0.0
var design_buttons: Dictionary={}
var focus_slot=""
var base_profile: Dictionary={}
func setup(parent_screen: Control,value,room: Dictionary,floor: Dictionary) -> void:
	super.setup(parent_screen,value,room,floor)
	var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/habitat_views.json"))
	base_profile=config.rooms.get(model.habitat_id,{"space_type":"M","axes":["x"],"view_fraction":.8,"zoom_min":.4,"zoom_max":1.5,"world_height":420,"zone_overview":false})
	configure_profile()
	var old=environment; old.remove_child(marker_layer)
	environment=MobileEnvironment.new(); environment.setup(model,Vector2(500,600),500); environment.camera=camera; environment.resident_pixels=float(camera_profile.get("resident_pixels",128)); environment.gui_input.connect(environment_input); environment.mouse_filter=Control.MOUSE_FILTER_STOP; add_child(environment); environment.add_child(marker_layer)
	remove_child(old); old.queue_free()
	for child in get_children():
		if child is Control and child!=environment: child.hide()
	theme=UI.theme_for(complex_screen.game.view.geometry)
	build_hud(); reflow()
	var settings=ConfigFile.new()
	var restored=false
	if settings.load(complex_screen.game.audio_settings_path)==OK:
		var saved: Variant=settings.get_value("habitat_camera_v1",model.habitat_id,{})
		if saved is Dictionary: restored=camera.restore(saved)
	if not restored: camera.focus(initial_focus(),true)
	environment.apply_camera(); set_active(true)
	complex_screen.game.view.tutorial.request("first_habitat","Коснитесь стройплощадки: можно выбрать дизайн, посмотреть его и отменить установку.",Rect2(),"habitat_"+model.habitat_id)
	if room_state.installed.is_empty() and room_state.points>=3: complex_screen.game.view.tutorial.request("first_upgrade","Биокапсулы из экспедиций позволяют обустроить вольер. Предпросмотр бесплатен.",Rect2(),"habitat_"+model.habitat_id)
func initial_focus() -> Vector2:
	var source: Variant=camera_profile.get("initial_focus","resident")
	if source is Dictionary:
		if source.get("slot","") in room_state.catalog.slots: return environment.marker(room_state.catalog.slots[source.slot])
		var point: Variant=source.get("point")
		if point is Array and point.size()==2: return Vector2(float(point[0]),float(point[1]))
	if source is String and source=="room_center": return Vector2(model.registry.world_width*.5,model.profile.ground_y)
	return model.position-Vector2(0,40)
func configure_profile() -> void:
	camera_profile=base_profile.duplicate(true)
	var width: float=model.registry.world_width
	var type="XL" if width>=4700 else ("L" if width>=2820 else ("M" if width>=1880 else "S"))
	camera_profile.space_type=type
	camera_profile.view_fraction=base_profile.get("fractions_by_size",{}).get(type,base_profile.get("view_fraction",.8))
	camera_profile.zone_overview=width>=float(base_profile.get("zone_min_world_width",1400))
func build_hud() -> void:
	if is_instance_valid(hud): remove_child(hud); hud.queue_free()
	hud=Control.new(); hud.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(hud)
	var row=UI.row(hud); row.position=Vector2(12,12); row.size=Vector2(size.x-24,complex_screen.game.view.geometry.touch); row.mouse_filter=Control.MOUSE_FILTER_IGNORE
	UI.button(row,"HabitatBack","‹",request_back,complex_screen.game.view.geometry.touch).size_flags_horizontal=0
	var heading=UI.column(row); heading.mouse_filter=Control.MOUSE_FILTER_IGNORE; heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	UI.label(heading,Catalog.species(model.profile.species_id).name,26)
	progress_label=UI.label(heading,"",18)
	if not camera_profile.get("zone_overview",false): UI.button(row,"HabitatFind","◎",find_resident,complex_screen.game.view.geometry.touch).size_flags_horizontal=0
	if camera_profile.get("zone_overview",false): UI.button(row,"HabitatZones","▤",show_zones,complex_screen.game.view.geometry.touch).size_flags_horizontal=0
	UI.button(row,"HabitatSettings","⚙",func(): complex_screen.game.view.show_panel("settings"),complex_screen.game.view.geometry.touch).size_flags_horizontal=0
	if camera_profile.get("zone_overview",false):
		var find=UI.button(hud,"HabitatFind","◎",find_resident,complex_screen.game.view.geometry.touch)
		find.position=Vector2(size.x-complex_screen.game.view.geometry.touch-24,complex_screen.game.view.geometry.touch+44); find.size=Vector2.ONE*complex_screen.game.view.geometry.touch
	status=UI.label(hud,"",18); status.hide()
func reflow() -> void:
	if not is_instance_valid(hud): return
	pressing=false; camera_velocity=0; camera.transitioning=false
	var layout=complex_screen.game.view.geometry
	configure_profile()
	size=layout.extent; theme=UI.theme_for(layout); hud.size=size
	build_hud()
	var sheet_height=clampf(size.y*.42,320,560) if mode!="observation" else 0.0
	var area=Rect2(12,layout.touch+28,size.x-24,maxf(140,size.y-layout.touch-40-sheet_height))
	if not layout.portrait and mode!="observation": area=Rect2(12,layout.touch+28,maxf(200,size.x-384),size.y-layout.touch-40)
	environment.position=area.position; environment.size=area.size
	var bounds=Rect2(0,0,model.registry.world_width,float(camera_profile.get("world_height",420)))
	camera.configure(camera_profile,bounds,area.size,camera.profile.size()>0 and camera.bounds.size.is_equal_approx(bounds.size))
	environment.apply_camera()
	if is_instance_valid(design_panel): place_sheet(design_panel,sheet_height)
	if is_instance_valid(zones): place_sheet(zones,sheet_height)
	status.position=Vector2(24,size.y-62); status.size=Vector2(size.x-48,48)
	update_controls(); queue_redraw()
func place_sheet(panel: Control,height: float) -> void:
	if complex_screen.game.view.geometry.portrait: panel.position=Vector2(12,size.y-height-12); panel.size=Vector2(size.x-24,height)
	else: panel.position=Vector2(size.x-360,complex_screen.game.view.geometry.touch+28); panel.size=Vector2(348,size.y-complex_screen.game.view.geometry.touch-40)
func update_controls() -> void:
	if room_state==null or not is_instance_valid(status): return
	if is_instance_valid(progress_label): progress_label.text="%d / %d · ◈ %d" % [room_state.installed.size(),room_state.catalog.slots.size(),room_state.points]
	if is_instance_valid(confirm_button):
		var amount=0 if room_state.installed.has(chosen_slot) else int(room_state.catalog.slots[chosen_slot].cost)
		panel_cost.text="Смена бесплатно" if amount==0 else "Цена %d · Баланс %d" % [amount,room_state.points]
		confirm_button.disabled=room_state.read_only or room_state.points<amount
	if is_instance_valid(marker_layer): marker_layer.queue_redraw()
func make_sheet(id: String,title: String) -> Dictionary:
	var panel=Panel.new(); panel.name=id; panel.z_index=12; panel.add_theme_stylebox_override("panel",UI.box()); add_child(panel)
	var margin=MarginContainer.new(); UI.fill(margin)
	for key in ["margin_left","margin_right","margin_top","margin_bottom"]: margin.add_theme_constant_override(key,16)
	panel.add_child(margin); var stack=UI.column(margin); UI.label(stack,title,24)
	var scroll=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; stack.add_child(scroll)
	var column=UI.column(scroll); column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var actions=UI.row(stack)
	TouchScroll.attach(scroll,func(): return mode!="observation" and active_detail)
	return {"panel":panel,"content":column,"actions":actions}
func open_design(id: String) -> bool:
	if not room_state.available(id): return false
	close_front_panel(); pressing=false; camera.transitioning=false
	chosen_slot=id; chosen_design=room_state.installed.get(id,room_state.catalog.slots[id].designs[0].design_id)
	if not room_state.preview(id,chosen_design): return false
	mode="arrangement"; var slot: Dictionary=room_state.catalog.slots[id]
	var card=make_sheet("DesignPanel",slot.name); design_panel=card.panel; sheet_content=card.content; sheet_actions=card.actions; design_buttons.clear()
	var picker=OptionButton.new(); picker.name="ObjectPicker"; picker.custom_minimum_size.y=complex_screen.game.view.geometry.touch
	var choices: Array=[]
	for key in room_state.catalog.slots:
		if room_state.available(key): picker.add_item(room_state.catalog.slots[key].name); choices.append(key)
	picker.select(choices.find(id)); picker.item_selected.connect(func(index):
		if choices[index]!=chosen_slot: open_design(choices[index])
	)
	sheet_content.add_child(picker)
	if room_state.installed.has(id) and slot.interaction!="none": UI.button(sheet_content,"InteractObject","Взаимодействовать",func(): var key=chosen_slot; close_front_panel(); model.request_slot(key),complex_screen.game.view.geometry.touch)
	for design in slot.designs:
		design_buttons[design.design_id]=UI.button(sheet_content,"Design_"+design.design_id,design.name,func(): select_design(design.design_id),complex_screen.game.view.geometry.touch)
	panel_cost=UI.label(sheet_content,""); panel_feedback=UI.label(sheet_content,"Предпросмотр · пока не сохранено",18)
	confirm_button=UI.button(sheet_actions,"ConfirmDesign","Установить",confirm_design,complex_screen.game.view.geometry.touch)
	UI.button(sheet_actions,"CancelDesign","Отмена",close_front_panel,complex_screen.game.view.geometry.touch)
	select_design(chosen_design); reflow(); camera.focus(environment.marker(slot)); environment.set_active(false); return true
func select_design(id: String) -> void:
	if not room_state.preview(chosen_slot,id): return
	chosen_design=id
	for key in design_buttons: design_buttons[key].text=("✓ " if key==id else "")+room_state.catalog.design(chosen_slot,key).name
	update_controls()
func close_front_panel() -> bool:
	var handled=false
	if is_instance_valid(design_panel):
		remove_child(design_panel); design_panel.queue_free(); design_panel=null; confirm_button=null; chosen_slot=""; chosen_design=""; room_state.cancel_preview(); handled=true
	if is_instance_valid(zones): remove_child(zones); zones.queue_free(); zones=null; handled=true
	if handled:
		mode="observation"; reflow(); environment.set_active(active_detail)
	return handled
func show_zones() -> void:
	if not camera_profile.get("zone_overview",false): return
	close_front_panel(); mode="zones"; pressing=false
	var card=make_sheet("RoomZones","Обзор зон"); zones=card.panel
	var row=UI.row(card.content)
	for point in camera_profile.get("focus_points",[]):
		var fraction=float(point.get("x_fraction",.5))
		UI.button(row,"Zone_"+point.id,point.name,func(): close_front_panel(); camera.focus(Vector2(model.registry.world_width*fraction,model.profile.ground_y)),complex_screen.game.view.geometry.touch)
	for id in room_state.catalog.slots:
		var key=id; var slot: Dictionary=room_state.catalog.slots[id]
		var button=UI.button(card.content,"Focus_"+id,slot.name+(" ✓" if room_state.installed.has(id) else ""),func(): close_front_panel(); focus_object(key),complex_screen.game.view.geometry.touch)
		button.disabled=not room_state.available(id)
	var zoom_row=UI.row(card.content)
	UI.button(zoom_row,"ZoomOut","−",func(): camera.set_zoom(camera.zoom*.85); environment.apply_camera(),complex_screen.game.view.geometry.touch)
	UI.button(zoom_row,"ZoomIn","+",func(): camera.set_zoom(camera.zoom*1.15); environment.apply_camera(),complex_screen.game.view.geometry.touch)
	UI.button(card.actions,"FindResident","Найти мутанта",func(): close_front_panel(); find_resident(),complex_screen.game.view.geometry.touch)
	UI.button(card.actions,"CloseZones","Закрыть",close_front_panel,complex_screen.game.view.geometry.touch)
	reflow(); environment.set_active(false)
func focus_object(id: String,immediate: bool=false) -> void:
	if not room_state.catalog.slots.has(id): return
	focus_slot=id; camera.focus(environment.marker(room_state.catalog.slots[id]),immediate); environment.apply_camera()
func find_resident() -> void:
	if not is_instance_valid(environment): return
	camera.focus(model.position-Vector2(0,40)); pressing=false
func environment_input(event: InputEvent) -> void:
	if mode!="observation" or not active_detail or complex_screen.game.view.overlay!=null: return
	if (event is InputEventScreenTouch or event is InputEventScreenDrag) and event.index!=0: pressing=false; environment.accept_event(); return
	var info: Dictionary=complex_screen.pointer_event(event)
	if info.is_empty(): return
	if info.get("cancel",false) or (event is InputEventScreenTouch or event is InputEventScreenDrag) and event.index!=0: pressing=false; environment.accept_event(); return
	var point: Vector2=info.point
	if info.down: pressing=true; touch_start=point; touch_last=point; touch_travel=0; camera.transitioning=false
	elif info.motion and pressing:
		touch_travel+=point.distance_to(touch_last)
		if touch_travel>=12: camera.pan(point-touch_last); environment.apply_camera()
		touch_last=point
	elif info.up and pressing:
		pressing=false
		if maxf(touch_travel,point.distance_to(touch_start))<12: interact(camera.view_to_world(point))
	environment.accept_event()
func interact(point: Vector2) -> void:
	var nearest=""; var distance=INF
	for id in room_state.catalog.slots:
		if not room_state.available(id): continue
		var marker=environment.marker(room_state.catalog.slots[id])
		var d=point.distance_to(marker)*camera.zoom
		if d<complex_screen.game.view.geometry.touch*.55 and d<distance: nearest=id; distance=d
	if nearest!="": open_design(nearest); return
	if camera.world_to_view(point).distance_to(camera.world_to_view(model.position+Vector2(0,environment.floor_offset()-35)))<maxf(46,environment.resident_pixels*.5): model.react()
func draw_markers() -> void:
	if not is_instance_valid(environment) or camera.profile.is_empty(): return
	if focus_slot!="" and room_state.catalog.slots.has(focus_slot):
		var p=camera.world_to_view(environment.marker(room_state.catalog.slots[focus_slot]))
		marker_layer.draw_arc(p,complex_screen.game.view.geometry.touch*.45,0,TAU,40,UI.BIO,2)
func set_active(value: bool) -> void:
	active_detail=value; set_process(value)
	if is_instance_valid(environment): environment.set_active(value and mode=="observation")
	if not value: pressing=false; camera.transitioning=false
func _process(delta: float) -> void:
	camera.tick(delta); environment.apply_camera(); update_controls()
	toast_time=maxf(0,toast_time-delta); status.visible=toast_time>0
func show_hint(text: String) -> void:
	status.text=text; status.show(); toast_time=5
func _exit_tree() -> void:
	if room_state!=null: room_state.cancel_preview()
	if not camera.profile.is_empty():
		var config=ConfigFile.new(); config.load(complex_screen.game.audio_settings_path)
		config.set_value("habitat_camera_v1",model.habitat_id,camera.snapshot()); config.save(complex_screen.game.audio_settings_path)
func _draw() -> void: draw_rect(Rect2(Vector2.ZERO,size),UI.BG)
