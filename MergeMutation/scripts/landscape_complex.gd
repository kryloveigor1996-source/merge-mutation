extends "res://scripts/underground_complex.gd"
const L=preload("res://scripts/landscape_layout.gd")
const FloorLandscape=preload("res://scripts/landscape_floor.gd")
const DetailLandscape=preload("res://scripts/landscape_habitat.gd")
const LivingLayout=preload("res://scripts/landscape_living_config.gd")
const ModularDetail=preload("res://scripts/modular_habitat.gd")
const ModularState=preload("res://scripts/modular_habitat_state.gd")
const RenovationCatalog=preload("res://scripts/renovation_catalog.gd")
const RenovationState=preload("res://scripts/renovation_state.gd")
func stage_regression() -> bool: return "--habitat-stage-regression" in OS.get_cmdline_user_args()
func viewport_rect() -> Rect2: return Rect2(0,70,804,450)
func lift_rect() -> Rect2: return Rect2(340,96,580,340)
func back() -> void:
	if modal==null and is_instance_valid(detail) and detail.has_method("close_front_panel") and detail.close_front_panel(): return
	if modal==null and is_instance_valid(detail) and is_instance_valid(detail.stage_menu): detail.toggle_stages()
	else: super.back()
func make_floor(): return FloorLandscape.new()
func make_living_detail(): return DetailLandscape.new() if stage_regression() else ModularDetail.new()
func decorate_rooms(rooms: Array) -> void:
	if not stage_regression():
		for room in rooms:
			if room.habitat_id!="habitat_horn": room.preview_accessible=false
func create_living_models() -> void:
	if not registry.habitats.has("habitat_horn"): return
	var base:=LivingRegistry.new()
	if not base.load_files(registry): return
	living_registry=LivingLayout.build(base,registry,"normal")
	if living_registry==null: return
	for id in living_registry.assignments:
		var state=HabitatState.new() if stage_regression() else ModularState.new()
		state.setup(id,living_registry)
		if not stage_regression():
			var catalog:=RenovationCatalog.new()
			var config_path: String=RenovationCatalog.path_for_habitat(id)
			if config_path.is_empty() or not catalog.load_file(config_path) or catalog.habitat_id!=id: continue
			var renovation:=RenovationState.new()
			renovation.setup(catalog,game.save_path+".habitat-demo-v1.json")
			state.attach(renovation)
		living_models[id]=state
func setup(value: Control,model=null) -> void:
	var source=model if model!=null else Registry.new()
	if model==null: source.load_files()
	var floors: Array=source.floors.duplicate(true)
	var rooms: Array=source.habitats.values().duplicate(true)
	decorate_rooms(rooms)
	for floor in floors:
		var ratio: float=1.0 if model!=null else {0:220.0,1:450.0,2:470.0,3:580.0,4:360.0}.get(int(floor.depth),floor.height)/float(floor.height)
		floor.height*=ratio
		for room in rooms:
			if room.floor_id!=floor.floor_id: continue
			room.rect=[28+(room.rect[0]-28)*2.3875,room.rect[1]*ratio,room.rect[2]*2.3875,room.rect[3]*ratio]
			room.erase("interaction_rect")
	var projected:=Registry.new()
	projected.configure({"floors":floors},{"habitats":rooms},804)
	super.setup(value,projected)
	size=L.DESIGN
	for child in get_children():
		if child is Label and child!=indicator and child!=toast: L.place(child,Rect2(20,14,760,44))
	L.place(indicator,Rect2(820,66,126,100))
	L.place(toast,Rect2(20,478,760,38))
	for item in [["ComplexTop",180],["ComplexBottom",248],["ComplexLift",316],["ComplexBack",452]]: L.place(get_node(item[0]),Rect2(820,item[1],126,56))
func new_modal(kind: String) -> Control:
	close_modal()
	stop_motion()
	pressed=false
	modal=Control.new()
	modal.name="Complex"+kind
	modal.size=L.DESIGN
	modal.z_index=40
	modal_kind=kind
	var panel:=modal
	panel.draw.connect(func():
		panel.draw_rect(Rect2(0,0,960,540),Color(0.05,0.12,0.2,0.8))
		panel.draw_style_box(W.box(Color("eef2d9"),18),Rect2(140,16,804,508))
	)
	add_child(panel)
	refresh_activity()
	return panel
func show_room_info(id: String) -> bool:
	if not super.show_room_info(id): return false
	for child in modal.get_children():
		if child is Label:
			var y: float={108:60,156:122,316:180,363:236,409:292}.get(int(child.position.y),292)
			L.place(child,Rect2(480,y,440,110 if y==292 else 50))
		elif child is Node2D:
			child.position=Vector2(300,250)
			child.scale=Vector2.ONE*2.6
	L.place(modal.get_node("ComplexInfoClose"),Rect2(480,444,440,58))
	return true
func show_lift() -> void:
	super.show_lift()
	for child in modal.get_children():
		if child is Label: L.place(child,Rect2(160,60 if child.position.y<150 else 150,160,110))
	L.place(modal.get_node("ComplexLiftClose"),Rect2(160,422,160,60))
func _draw() -> void:
	draw_rect(Rect2(0,0,960,540),Color("243e54"))
	draw_style_box(W.box(Color("365668")),Rect2(812,8,140,524))
