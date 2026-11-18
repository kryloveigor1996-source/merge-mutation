extends "res://scripts/modular_habitat.gd"
func setup(parent_screen: Control,value,room: Dictionary,floor: Dictionary) -> void:
	super.setup(parent_screen,value,room,floor)
	var button: Button=get_node("HabitatPanorama")
	remove_child(button)
	button.free()
	get_node("HabitatFind").position=Vector2(512,12)
	get_node("HabitatFind").size=Vector2(160,48)
	W.label(self,model.ecology.room_size+" · "+model.ecology.origin,Rect2(682,14,150,44),12,Color("e6f1d4"),true)
	mouse_force_pass_scroll_events=false
	environment.set_camera(model.camera_positions.get("ecosystem",0))
	update_controls()
func update_controls() -> void:
	if room_state==null or not is_instance_valid(status): return
	if is_instance_valid(progress_label): progress_label.text="ДЕМО · %d/%d · %d%% · Очки: %d" % [room_state.installed.size(),room_state.catalog.slots.size(),room_state.progress(),room_state.points]
	var find: Button=get_node_or_null("HabitatFind")
	if find!=null: find.visible=model.registry.world_width>environment.visible_width
	var repair: Button=get_node_or_null("HabitatRepair")
	if repair!=null:
		repair.text="НАБЛЮДАТЬ" if repair_mode else "ОФОРМИТЬ"
		repair.disabled=room_state.installed.is_empty()
	var hint:="Коснитесь ящика или накрытой конструкции, чтобы установить предмет" if room_state.progress()<100 else "Коснитесь предмета или мутанта для взаимодействия"
	status.text=room_state.error if not room_state.error.is_empty() else ("ОФОРМЛЕНИЕ · выберите установленный предмет" if repair_mode else (model.feedback if model.feedback_left>0 else hint))
	if is_instance_valid(marker_layer): marker_layer.queue_redraw()
	if is_instance_valid(confirm_button):
		var cost: int=0 if room_state.installed.has(chosen_slot) else 1
		confirm_button.disabled=room_state.read_only or room_state.points<cost
		panel_cost.text="Смена бесплатно" if cost==0 else "Установка: 1 тестовое очко"
func open_design(id: String) -> bool:
	var ok:=super.open_design(id)
	if ok: environment.set_active(false)
	return ok
func close_front_panel() -> bool:
	var handled:=super.close_front_panel()
	if handled and is_instance_valid(environment): environment.set_active(active_detail and not repair_mode and not is_instance_valid(design_panel))
	return handled
func set_active(value: bool) -> void:
	super.set_active(value)
	if is_instance_valid(environment):
		environment.set_active(value and not repair_mode and not is_instance_valid(design_panel))
		if not value: model.camera_positions["ecosystem"]=environment.camera_x
func _process(delta: float) -> void:
	super._process(delta)
	model.camera_positions["ecosystem"]=environment.camera_x
func toggle_panorama() -> void: pass # Automatic room geometry, no player-facing switch.
func environment_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_WHEEL_UP]:
		if event.pressed:
			find_target=false
			camera_velocity=0
			environment.set_camera(environment.camera_x+(110 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -110))
		environment.accept_event()
		return
	super.environment_input(event)
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_WHEEL_UP]: accept_event()
func interact(point: Vector2) -> void:
	if repair_mode:
		for id in room_state.installed:
			if point.distance_to(room_state.catalog.marker(room_state.catalog.slots[id],model.registry.world_width))<=30:
				open_design(id)
				return
		return
	for id in room_state.offered():
		if point.distance_to(room_state.catalog.marker(room_state.catalog.slots[id],model.registry.world_width))<=38:
			open_design(id)
			return
	super.interact(point)
func draw_markers() -> void:
	if not repair_mode: return
	for id in room_state.installed:
		var slot: Dictionary=room_state.catalog.slots[id]
		var p: Vector2=room_state.catalog.marker(slot,model.registry.world_width)*environment.world.scale+environment.world.position
		if not Rect2(Vector2.ZERO,environment.size).has_point(p): continue
		marker_layer.draw_circle(p,22,W.INK)
		marker_layer.draw_circle(p,19,Color("c7e2bf"))
		marker_layer.draw_string(ThemeDB.fallback_font,p+Vector2(-7,7),"↻",HORIZONTAL_ALIGNMENT_LEFT,-1,23,W.INK)
