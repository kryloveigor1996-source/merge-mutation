extends "res://scripts/landscape_habitat.gd"
const Confirmation=preload("res://scripts/renovation_confirmation.gd")
var room_state
var repair_mode:=false
var design_panel: Panel
var chosen_slot:=""
var chosen_design:=""
var marker_layer: Node2D
var progress_label: Label
var panel_cost: Label
var panel_feedback: Label
var confirm_button: Button
var reset_confirmation: Control
var active_detail:=true
func setup(parent_screen: Control,value,room: Dictionary,floor: Dictionary) -> void:
	room_state=value.renovation
	super.setup(parent_screen,value,room,floor)
	var repair: Button=get_node("HabitatDemo")
	repair.name="HabitatRepair"
	repair.text="РЕМОНТ"
	var info: Button=get_node("HabitatInfo")
	remove_child(info)
	info.free()
	W.button(self,"HabitatTest","ТЕСТ",Rect2(844,12,104,48),toggle_test_menu,Color("b5e9ee"))
	var back: Button=get_node("HabitatBack")
	for connection in back.pressed.get_connections(): back.pressed.disconnect(connection.callable)
	back.pressed.connect(request_back)
	for child in get_children():
		if child is Label and child.position==Vector2(104,40):
			progress_label=child
			break
	marker_layer=Node2D.new()
	marker_layer.z_index=2
	marker_layer.draw.connect(draw_markers)
	environment.add_child(marker_layer)
	reset_confirmation=Confirmation.new()
	reset_confirmation.title="Сброс демонстрационного ремонта"
	reset_confirmation.dialog_text="Удалить установленные предметы и вернуть 3 тестовых очка? Основной профиль не изменится."
	reset_confirmation.get_label().autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	reset_confirmation.get_label().custom_minimum_size=Vector2(420,84)
	reset_confirmation.size=Vector2(960,540)
	reset_confirmation.get_ok_button().text="СБРОСИТЬ ДЕМО"
	reset_confirmation.get_cancel_button().text="ОТМЕНА"
	reset_confirmation.confirmed.connect(func():
		if room_state.reset_demo(true):
			reset_confirmation.hide()
			close_front_panel()
			repair_mode=false
			environment.set_active(active_detail)
		else: status.text=room_state.error
		update_controls()
	)
	add_child(reset_confirmation)
	room_state.changed.connect(update_controls)
	environment.set_camera(model.camera_positions["panorama" if model.panorama else "normal"])
	update_controls()
func update_controls() -> void:
	if room_state==null or not is_instance_valid(status): return
	if is_instance_valid(progress_label): progress_label.text="ДЕМО · %d/%d · %d%% · Очки: %d" % [room_state.installed.size(),room_state.catalog.slots.size(),room_state.progress(),room_state.points]
	get_node("HabitatFind").disabled=false
	get_node("HabitatPanorama").text="ОБЫЧНЫЙ ВИД" if model.panorama else "ПАНОРАМА"
	var repair: Button=get_node_or_null("HabitatRepair")
	if repair!=null: repair.text="НАБЛЮДАТЬ" if repair_mode else "РЕМОНТ"
	status.text=room_state.error if not room_state.error.is_empty() else ("РЕМОНТ · нажмите на маркер предмета" if repair_mode else (model.feedback if model.feedback_left>0 else "Касайтесь Рогача и установленных предметов"))
	if is_instance_valid(marker_layer): marker_layer.queue_redraw()
	if is_instance_valid(confirm_button):
		var cost: int=0 if room_state.installed.has(chosen_slot) else 1
		confirm_button.disabled=room_state.read_only or room_state.points<cost
		panel_cost.text="Смена бесплатно" if cost==0 else "Установка: 1 тестовое очко"
func toggle_stages() -> void: toggle_repair()
func toggle_repair() -> void:
	close_front_panel()
	repair_mode=not repair_mode
	camera_velocity=0
	pressing=false
	environment.set_active(active_detail and not repair_mode)
	update_controls()
func request_back() -> void:
	if close_front_panel(): return
	closed.emit()
func close_front_panel() -> bool:
	if is_instance_valid(reset_confirmation) and reset_confirmation.visible:
		reset_confirmation.hide()
		return true
	if is_instance_valid(design_panel):
		remove_child(design_panel)
		design_panel.queue_free()
		design_panel=null
		confirm_button=null
		chosen_slot=""
		chosen_design=""
		room_state.cancel_preview()
		return true
	if is_instance_valid(stage_menu):
		remove_child(stage_menu)
		stage_menu.queue_free()
		stage_menu=null
		return true
	return false
func toggle_test_menu() -> void:
	if close_front_panel(): return
	stage_menu=Panel.new()
	stage_menu.name="RenovationTestMenu"
	stage_menu.add_theme_stylebox_override("panel",W.box(Color("fff8de")))
	stage_menu.position=Vector2(644,66)
	stage_menu.size=Vector2(304,238)
	stage_menu.z_index=7
	add_child(stage_menu)
	W.label(stage_menu,"ТЕСТОВЫЕ ОЧКИ · отдельно от монет",Rect2(12,6,280,40),13)
	W.button(stage_menu,"GrantPoint","+1 ТЕСТОВОЕ ОЧКО",Rect2(12,50,280,48),func(): room_state.grant_test_point(); update_controls())
	W.button(stage_menu,"ResetRenovation","СБРОС ДЕМО…",Rect2(12,110,280,48),func(): reset_confirmation.popup_centered())
	W.button(stage_menu,"RoomInfo","О ВОЛЬЕРЕ",Rect2(12,170,280,48),func(): close_front_panel(); complex_screen.show_room_info(model.habitat_id))
func open_design(id: String) -> bool:
	if not room_state.available(id): return false
	close_front_panel()
	chosen_slot=id
	var slot: Dictionary=room_state.catalog.slots[id]
	chosen_design=room_state.installed.get(id,slot.designs[0].design_id)
	if not room_state.preview(id,chosen_design): return false
	design_panel=Panel.new()
	design_panel.name="DesignPanel"
	design_panel.add_theme_stylebox_override("panel",W.box(Color("fff8de")))
	var anchor: Vector2=room_state.catalog.marker(slot,model.registry.world_width)
	var x: float=(anchor.x-environment.camera_x)
	design_panel.position=Vector2(644 if x<470 else 12,80)
	design_panel.size=Vector2(304,434)
	design_panel.z_index=6
	add_child(design_panel)
	W.label(design_panel,slot.name,Rect2(14,8,276,34),22)
	W.label(design_panel,slot.description,Rect2(14,46,276,47),13)
	for index in range(slot.designs.size()):
		var d: Dictionary=slot.designs[index]
		W.button(design_panel,"Design_"+d.design_id,d.name,Rect2(14,100+index*60,276,52),func(): select_design(d.design_id),Color("c7e7de"))
	panel_cost=W.label(design_panel,"",Rect2(14,284,276,24),14)
	panel_feedback=W.label(design_panel,"Предпросмотр · пока не сохранено",Rect2(14,309,276,24),12)
	confirm_button=W.button(design_panel,"ConfirmDesign","УСТАНОВИТЬ",Rect2(14,338,276,44),confirm_design)
	W.button(design_panel,"CancelDesign","ОТМЕНА",Rect2(14,386,276,44),func(): close_front_panel(),Color("b5e9ee"))
	select_design(chosen_design)
	return true
func select_design(id: String) -> void:
	if not room_state.preview(chosen_slot,id): return
	chosen_design=id
	for d in room_state.catalog.slots[chosen_slot].designs:
		var button: Button=design_panel.get_node("Design_"+d.design_id)
		button.text=("✓ " if d.design_id==id else "")+d.name
	update_controls()
func confirm_design() -> void:
	var result: Dictionary=room_state.confirm(chosen_slot,chosen_design)
	if result.ok: close_front_panel()
	else: panel_feedback.text=result.reason
	update_controls()
func interact(point: Vector2) -> void:
	if repair_mode:
		for id in room_state.catalog.slots:
			var slot: Dictionary=room_state.catalog.slots[id]
			if point.distance_to(room_state.catalog.marker(slot,model.registry.world_width))<=30:
				open_design(id)
				return
		return
	# Installed objects precede the resident. Background surfaces are not actions.
	for object in model.objects():
		var slot: Dictionary=room_state.catalog.slots[object.slot_id]
		if slot.interaction=="none": continue
		if room_state.catalog.project_rect(slot,model.registry.world_width,"touch").has_point(point):
			model.request_slot(object.slot_id)
			return
	if point.distance_to(model.position-Vector2(0,35))<46: model.react()
func draw_markers() -> void:
	if not repair_mode: return
	for id in room_state.catalog.slots:
		var slot: Dictionary=room_state.catalog.slots[id]
		var p: Vector2=room_state.catalog.marker(slot,model.registry.world_width)
		p=p*environment.world.scale+environment.world.position
		if not Rect2(Vector2.ZERO,environment.size).grow(30).has_point(p): continue
		var color:=Color("a6d99d") if room_state.installed.has(id) else Color("ffe39b")
		if not room_state.available(id): color=Color("9caaa8")
		marker_layer.draw_circle(p,24,W.INK)
		marker_layer.draw_circle(p,21,color)
		marker_layer.draw_string(ThemeDB.fallback_font,p+Vector2(-6,7),"✓" if room_state.installed.has(id) else "+",HORIZONTAL_ALIGNMENT_LEFT,-1,22,W.INK)
		var words: PackedStringArray=slot.name.split(" ")
		if words.size()>1:
			marker_layer.draw_string(ThemeDB.fallback_font,p+Vector2(-80,-46),words[0],HORIZONTAL_ALIGNMENT_CENTER,160,12,Color("fff9df"))
			marker_layer.draw_string(ThemeDB.fallback_font,p+Vector2(-80,-31)," ".join(words.slice(1)),HORIZONTAL_ALIGNMENT_CENTER,160,12,Color("fff9df"))
		else: marker_layer.draw_string(ThemeDB.fallback_font,p+Vector2(-80,-31),slot.name,HORIZONTAL_ALIGNMENT_CENTER,160,12,Color("fff9df"))
func toggle_panorama() -> void:
	close_front_panel()
	model.camera_positions["panorama" if model.panorama else "normal"]=environment.camera_x
	model.switch_panorama(not model.panorama)
	environment.set_camera(model.camera_positions["panorama" if model.panorama else "normal"])
	camera_velocity=0
	find_target=false
	update_controls()
func _process(delta: float) -> void:
	super._process(delta)
	model.camera_positions["panorama" if model.panorama else "normal"]=environment.camera_x
	if repair_mode: marker_layer.queue_redraw()
func set_active(value: bool) -> void:
	active_detail=value
	super.set_active(value)
	if is_instance_valid(environment): environment.set_active(value and not repair_mode)
	if not value and is_instance_valid(environment):
		model.camera_positions["panorama" if model.panorama else "normal"]=environment.camera_x
func _exit_tree() -> void:
	if room_state!=null: room_state.cancel_preview()
