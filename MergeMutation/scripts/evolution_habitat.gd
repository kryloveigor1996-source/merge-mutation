extends "res://scripts/core_habitat.gd"
var design_shade: ColorRect
func setup(parent_screen: Control,value,room: Dictionary,floor: Dictionary) -> void:
	super.setup(parent_screen,value,room,floor)
	W.button(self,"HabitatSettings","⚙",Rect2(844,12,104,48),func(): complex_screen.game.view.show_panel("settings"),Color("c6e4df"))
	reflow()
	find_resident()
	var highlighted=Rect2(environment.position,environment.size)
	var offered=room_state.offered()
	if not offered.is_empty():
		var slot=room_state.catalog.slots[offered[0]]
		var r=room_state.catalog.project_rect(slot,model.registry.world_width)
		var left=minf(r.position.x,model.position.x-50)
		var right=maxf(r.end.x,model.position.x+50)
		if right-left<=environment.visible_width: environment.set_camera(left-(environment.visible_width-(right-left))*.5)
		var point=environment.position+environment.world.position+room_state.catalog.marker(slot,model.registry.world_width)*environment.world.scale
		if highlighted.has_point(point): highlighted=Rect2(point-Vector2.ONE*28,Vector2.ONE*56)
	complex_screen.game.view.tutorial.request("first_habitat","Коснитесь стройплощадки: можно посмотреть варианты и отменить установку.",highlighted,"habitat_"+model.habitat_id)
	if room_state.installed.is_empty() and room_state.points>=3: complex_screen.game.view.tutorial.request("first_upgrade","Биокапсулы позволяют установить первый предмет. Предпросмотр бесплатен.",highlighted,"habitat_"+model.habitat_id)
func reflow() -> void:
	var tall: bool=complex_screen.game.view.portrait_mode
	size=Vector2(540,960) if tall else Vector2(960,540)
	if tall:
		Layout.place(get_node("HabitatBack"),Rect2(12,14,100,52))
		Layout.place(get_node("HabitatSettings"),Rect2(472,14,56,52))
		Layout.place(get_node("HabitatRepair"),Rect2(270,106,258,48))
		Layout.place(get_node("HabitatFind"),Rect2(12,106,246,48))
		for child in get_children():
			if child is Label and child!=status and child!=progress_label:
				if child.text==Catalog.species(model.profile.species_id).name: Layout.place(child,Rect2(124,14,336,36))
				else: child.hide()
		Layout.place(progress_label,Rect2(124,52,400,34))
		Layout.place(status,Rect2(20,800,500,120))
		status.add_theme_font_size_override("font_size",17)
		environment.position=Vector2(12,165); environment.size=Vector2(516,620)
		var factor=620.0/420.0
		environment.world.scale=Vector2.ONE*factor
		environment.world.position.y=0
		environment.visible_width=516/factor
	else:
		Layout.place(get_node("HabitatBack"),Rect2(10,12,84,48))
		Layout.place(get_node("HabitatSettings"),Rect2(844,12,104,48))
		Layout.place(get_node("HabitatRepair"),Rect2(344,12,146,48))
		Layout.place(get_node("HabitatFind"),Rect2(512,12,160,48))
		for child in get_children():
			if child is Label and child!=status and child!=progress_label and child.position.y<40: Layout.place(child,Rect2(104,10,230,30))
		Layout.place(progress_label,Rect2(104,40,400,25)); Layout.place(status,Rect2(20,516,920,22))
		environment.position=Vector2(10,74); environment.size=Vector2(940,440)
		environment.world.scale=Vector2.ONE
		environment.world.position.y=10
		environment.visible_width=940
	environment.set_camera(environment.camera_x)
	if is_instance_valid(design_panel): place_design()
	update_controls(); queue_redraw()
func find_resident() -> void:
	find_target=false
	camera_velocity=0
	environment.set_camera(model.position.x-environment.visible_width*0.5)
func environment_input(event: InputEvent) -> void:
	var before=environment.camera_x
	super.environment_input(event)
	# Pan distance is measured in world coordinates, independent of portrait zoom.
	if (event is InputEventScreenDrag or event is InputEventMouseMotion) and pressing and touch_travel>=12 and environment.world.scale.x!=1:
		environment.set_camera(before+(environment.camera_x-before)/environment.world.scale.x)
func open_design(id: String) -> bool:
	if not super.open_design(id): return false
	design_shade=ColorRect.new()
	design_shade.name="DesignShade"
	design_shade.size=size
	design_shade.color=Color(0.04,0.11,0.14,0.75)
	design_shade.z_index=5
	design_shade.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(design_shade)
	move_child(design_shade,design_panel.get_index())
	place_design()
	return true
func place_design() -> void:
	if complex_screen.game.view.portrait_mode:
		design_panel.position=Vector2(20,240); design_panel.size=Vector2(500,470)
		for child in design_panel.get_children():
			if child is Control:
				child.size.x=472
				if child is Label: child.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if is_instance_valid(design_shade): design_shade.size=size
func close_front_panel() -> bool:
	var closed=super.close_front_panel()
	if closed and is_instance_valid(design_shade): design_shade.queue_free(); design_shade=null
	return closed
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("293e48"))
	if is_instance_valid(environment): draw_style_box(W.box(Color("c9b99b"),10),Rect2(environment.position-Vector2.ONE*3,environment.size+Vector2.ONE*6))