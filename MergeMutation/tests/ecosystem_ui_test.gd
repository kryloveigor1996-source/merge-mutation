extends "res://tests/landscape_ui_test.gd"
var ui
var detail
var room
func shot(id: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://.godot/ecosystem-"+id+".png")==OK,"screenshot "+id)
func bounds(node: Node) -> void:
	if node is Control and not node.is_visible_in_tree(): return
	if node is Button:
		var rect:=Rect2(node.get_global_transform_with_canvas()*Vector2.ZERO,node.size*node.get_global_transform_with_canvas().get_scale())
		check(Rect2(Vector2.ZERO,Vector2(root.size)).grow(2).encloses(rect),"ecosystem control fits "+str(node.name))
	if node is ScrollContainer: return
	for child in node.get_children(): bounds(child)
func fresh(path: String) -> void:
	if is_instance_valid(game): game.free()
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path+".habitat-demo-v1.json")
	game=Scene.instantiate()
	game.save_path=path
	root.add_child(game)
	game.view.sound.set_enabled(false)
func target(id: String) -> Vector2:
	var point: Vector2=room.catalog.marker(room.catalog.slots[id],detail.model.registry.world_width)
	detail.environment.set_camera(clampf(point.x-470,0,maxf(0,detail.model.registry.world_width-940)))
	return point*detail.environment.world.scale+detail.environment.world.position
func open_offer(id: String) -> void:
	tap(detail.environment,target(id))
	check(is_instance_valid(detail.design_panel) and detail.chosen_slot==id and not detail.repair_mode,"construction opens picker without repair")
func grant(count: int) -> void:
	press_button(detail.get_node("HabitatTest"))
	for i in range(count): press_button(detail.stage_menu.get_node("GrantPoint"))
	press_button(detail.get_node("HabitatTest"))
func install_all() -> void:
	var attempts:=0
	while room.installed.size()<room.catalog.slots.size():
		attempts+=1
		if attempts>room.catalog.slots.size()+1:
			printerr("INSTALL DIAGNOSTIC ",room.points," ",room.error," ",detail.chosen_slot," ",detail.chosen_design," ",room.installed)
			return
		var options: Array=room.offered()
		if options.is_empty():
			check(false,"available world construction")
			return
		if room.points==0: grant(1)
		var id: String=options[0]
		open_offer(id)
		press_button(detail.confirm_button,true)
		check(room.installed.has(id),"world installation saved")
		if not room.installed.has(id):
			printerr("INSTALL DIAGNOSTIC ",room.catalog.habitat_id," ",room.points," ",room.error," ",detail.chosen_slot," ",detail.chosen_design," ",detail.confirm_button.disabled," ",detail.confirm_button.get_global_rect()," ",detail.panel_feedback.text)
			return
func open_room(id: String) -> void:
	if is_instance_valid(ui.detail): ui.close_living()
	ui.navigate_to_floor(ui.registry.get_floor_for_habitat(id).floor_id,false)
	ui.open_living(id)
	detail=ui.detail
	room=detail.room_state
func wheel(target_node: CanvasItem,point: Vector2,direction: int) -> void:
	var e:=InputEventMouseButton.new()
	e.position=target_node.get_global_transform_with_canvas()*point
	e.button_index=direction
	e.pressed=true
	root.push_input(e,true)
	e=e.duplicate()
	e.pressed=false
	root.push_input(e,true)
func run() -> void:
	root.size=Vector2i(960,540)
	fresh("res://.godot/ecosystem-navigation.json")
	await process_frame
	check(is_instance_valid(game.view.app_chrome) and game.view.app_chrome.visible,"shared lab chrome")
	await shot("lab-chrome")
	var nav=game.view.app_chrome
	press_button(nav.get_node("Nav_portals"))
	if is_instance_valid(game.view.story_screen): press_button(game.view.story_screen.get_node("StorySkip"))
	await process_frame
	var portal=game.view.portal_ui
	check(portal.visible and is_instance_valid(portal.chrome),"shared portal chrome")
	tap(portal,Vector2(330,270))
	await create_timer(0.4).timeout
	check(portal.page=="map","notice board still opens map")
	tap(portal.map_canvas,portal.map_model.positions[0])
	await process_frame
	check(is_instance_valid(portal.preview) and not portal.chrome.visible,"specialized preview hides navigation")
	press_button(portal.preview.get_node("PreviewClose"))
	await process_frame
	await shot("map-chrome")
	press_button(portal.chrome.get_node("Nav_complex"))
	await process_frame
	ui=game.view.complex_ui
	check(is_instance_valid(ui.chrome) and ui.living_models.size()==2,"complex chrome and two live species")
	await shot("complex-chrome")
	press_button(ui.chrome.get_node("Nav_bestiary"))
	await process_frame
	check(game.view.panel_kind=="collection","bestiary opens real existing collection")
	await shot("collection-chrome")
	var overlay_chrome=game.view.overlay.get_child(game.view.overlay.get_child_count()-1)
	press_button(overlay_chrome.get_node("Nav_lab"))
	await process_frame
	check(game.view.overlay==null and game.view.app_chrome.visible,"shared return to laboratory")
	game.start_level(1,false)
	await process_frame
	check(not game.view.app_chrome.visible,"puzzle retains specialized interface")
	press_button(game.view.create_button)
	drag(game.view,L.center(6),L.center(7))
	check(game.campaign.status=="won","new main chrome preserves actual puzzle controls")
	game.leave_campaign()
	await process_frame
	# Independent fixture: navigation's existing journey flags/rewards are not room data.
	fresh("res://.godot/ecosystem-ui-profile.json")
	game.coins=777
	game.save_extra["future_feature"]={"keep":true}
	game._save_game()
	var primary:=FileAccess.get_file_as_string(game.save_path)
	var before:=profile()
	game.view.open_complex()
	ui=game.view.complex_ui
	open_room("habitat_horn")
	await process_frame
	check(not detail.has_node("HabitatPanorama") and not detail.get_node("HabitatFind").visible,"S room has no manual panorama or redundant finder")
	check(room.points==3 and room.progress()==0 and room.offered().size()==3,"sparse natural construction, initial points")
	await shot("horn-construction")
	var first: String=room.offered()[0]
	open_offer(first)
	await shot("world-design-picker")
	var body_snapshot: Array=detail.model.objects().duplicate(true)
	for design in room.catalog.slots[first].designs:
		press_button(detail.design_panel.get_node("Design_"+design.design_id))
		check(room.points==3 and room.installed.is_empty() and detail.model.objects()==body_snapshot,"preview does not alter economy or collisions")
	press_button(detail.design_panel.get_node("CancelDesign"))
	check(room.visual_choice(first)=="" and not FileAccess.file_exists(room.path),"cancel restores construction and leaves no save")
	open_offer(first)
	press_button(detail.confirm_button)
	check(room.points==2 and room.progress()==10,"first world installation costs one point")
	press_button(detail.get_node("HabitatRepair"))
	tap(detail.environment,target(first))
	var alternative: String=room.catalog.slots[first].designs[2].design_id
	press_button(detail.design_panel.get_node("Design_"+alternative))
	press_button(detail.confirm_button)
	check(room.points==2 and room.progress()==10 and room.installed[first]==alternative,"repair changes installed design freely")
	press_button(detail.get_node("HabitatRepair"))
	install_all()
	if room.progress()!=100:
		quit(1)
		return
	check(room.progress()==100,"developed canyon")
	detail.model.reset_simulation(12)
	detail.environment.set_active(false)
	await shot("horn-developed")
	for id in room.catalog.slots:
		var images: Array=[]
		for design in room.catalog.slots[id].designs:
			room.preview(id,design.design_id)
			if DisplayServer.get_name()!="headless":
				await process_frame
				await RenderingServer.frame_post_draw
				images.append(root.get_texture().get_image().get_region(Rect2i(10,74,940,440)).get_data().hex_encode().sha256_text())
		if not images.is_empty(): check(images[0]!=images[1] and images[1]!=images[2] and images[0]!=images[2],"canyon visual variants "+id)
		room.cancel_preview()
	var horn_state=detail.model
	var horn_balance: int=room.points
	open_room("habitat_slime")
	await process_frame
	check(room.points==3 and room.progress()==0,"slime independent initial state")
	check(detail.model.registry.world_width==1880 and detail.get_node("HabitatFind").visible and not detail.has_node("HabitatPanorama"),"M scrolling automatic")
	var offset: float=ui.offset
	var identity=detail
	for direction in [MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_WHEEL_UP]:
		for repeat in range(20):
			wheel(detail.environment,Vector2(400,120),direction)
			check(ui.detail==identity and ui.offset==offset,"intense wheel cannot reach hidden complex")
	check(detail.environment.camera_x==0,"wheel reaches both camera bounds")
	wheel(detail.environment,Vector2(400,120),MOUSE_BUTTON_WHEEL_DOWN)
	check(detail.environment.camera_x>0,"wheel pans wide habitat")
	install_all()
	if room.progress()!=100:
		quit(1)
		return
	detail.model.reset_simulation(33)
	detail.environment.set_active(false)
	check(horn_state.renovation.points==horn_balance and horn_state.renovation.progress()==100,"slime development leaves horn state intact")
	await shot("slime-developed")
	for x in [0,470,940]:
		detail.environment.set_camera(x)
		await shot("slime-sector-%d" % x)
		check(detail.environment.layers.mutant.get_child_count()==1,"no duplicated slime")
	for id in room.catalog.slots:
		var images: Array=[]
		target(id)
		for design in room.catalog.slots[id].designs:
			room.preview(id,design.design_id)
			if DisplayServer.get_name()!="headless":
				await process_frame
				await RenderingServer.frame_post_draw
				images.append(root.get_texture().get_image().get_region(Rect2i(10,74,940,440)).get_data().hex_encode().sha256_text())
		if not images.is_empty(): check(images[0]!=images[1] and images[1]!=images[2] and images[0]!=images[2],"acid visual variants "+id)
		room.cancel_preview()
	var model=detail.model
	model.cancel_action()
	model.position=Vector2(200,354)
	detail.environment.set_camera(0)
	check(model.request_slot("bed"),"sleep action uses installed acidic bed")
	for step in range(10): model.advance(0.05)
	# Render the unique phases using the same actor and real pose pipeline.
	for phase in [0.7,2.2,4.8]:
		while model.elapsed<phase: model.advance(0.05)
		detail.environment.refresh()
		await shot("slime-sleep-%d" % int(phase*10))
		if phase==2.2: check(detail.environment.actor.closed_eyes and detail.environment.actor.art.modulate.a<0.01,"only closed eyes remain over acid")
		elif phase==4.8: check(detail.environment.actor.art.modulate.a>0 and detail.environment.actor.art.modulate.a<1,"slime reassembles gradually")
	for step in range(35): model.advance(0.05)
	detail.environment.actor.pose(0.6,detail.environment.world.scale)
	check(not detail.environment.actor.closed_eyes and detail.environment.actor.art.modulate.a==1,"wake restores full body")
	await shot("slime-awake")
	model.cancel_action()
	detail.environment.set_camera(400)
	var light_signature:=JSON.stringify([room.installed,room.points,model.hit_count])
	drag(detail.environment,Vector2(820,120),Vector2(140,120))
	check(JSON.stringify([room.installed,room.points,model.hit_count])==light_signature and model.action_slot.is_empty(),"swipe does not install or activate")
	var id: String=room.installed.keys()[0]
	press_button(detail.get_node("HabitatRepair"))
	tap(detail.environment,target(id))
	var camera: float=detail.environment.camera_x
	for direction in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		wheel(detail.design_panel,Vector2(100,110),direction)
		wheel(detail.get_node("HabitatTest"),Vector2(30,20),direction)
		check(ui.detail==identity and detail.environment.camera_x==camera,"wheel over UI never pans background or exits")
	ui.back()
	check(detail.design_panel==null and is_instance_valid(ui.detail),"Back closes choice before habitat")
	press_button(detail.get_node("HabitatRepair"))
	detail.environment.set_active(false)
	detail.environment.set_camera(640)
	ui.close_living()
	var frozen: float=model.simulation_time
	ui.navigate_to_floor("floor_04",false)
	await create_timer(0.15).timeout
	check(model.simulation_time==frozen,"hidden slime paused")
	open_room("habitat_slime")
	check(detail.environment.camera_x==640 and detail.model==model,"automatic M camera restored on return")
	press_button(detail.get_node("HabitatFind"))
	for step in range(100): detail._process(0.02)
	check(absf(detail.environment.camera_x-clampf(model.position.x-470,0,940))<1,"contextual finder follows current slime")
	ui.close_living()
	await shot("two-habitat-overview")
	ui.exit_complex()
	check(profile()==before and FileAccess.get_file_as_string(game.save_path)==primary,"ecosystems preserve primary v2 byte-for-byte")
	for ratio in [Vector2i(960,540),Vector2i(1080,540),Vector2i(1170,540),Vector2i(1200,540),Vector2i(960,600)]:
		root.size=ratio
		await process_frame
		game.view.layout()
		bounds(game.view.app_chrome)
		game.view.open_complex()
		ui=game.view.complex_ui
		bounds(ui.chrome)
		for room_id in ["habitat_horn","habitat_slime"]:
			open_room(room_id)
			await process_frame
			bounds(detail)
			check(detail.model.renovation.progress()==100,"per-room state at every aspect")
			var selected: String=room.installed.keys()[0]
			press_button(detail.get_node("HabitatRepair"))
			tap(detail.environment,target(selected),true)
			bounds(detail.design_panel)
			wheel(detail.design_panel,Vector2(50,120),MOUSE_BUTTON_WHEEL_DOWN)
			check(is_instance_valid(ui.detail),"panel wheel safe in both room sizes")
			press_button(detail.design_panel.get_node("CancelDesign"))
			var canceled:=InputEventScreenTouch.new()
			canceled.position=Vector2(150,150)
			canceled.pressed=true
			detail.environment_input(canceled)
			canceled.pressed=false
			canceled.canceled=true
			detail.environment_input(canceled)
			check(not detail.pressing and detail.camera_velocity==0,"canceled touch safe")
			ui.close_living()
		ui.exit_complex()
	root.size=Vector2i(960,540)
	await process_frame
	game.view.layout()
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/complex_50.json"))
	var registry:=Registry.new()
	registry.configure(fixture,fixture)
	var EcoComplex=load("res://scripts/ecosystem_complex.gd")
	ui=EcoComplex.new()
	ui.setup(game,registry)
	game.view.add_child(ui)
	for floor in ui.registry.floors:
		ui.navigate_to_floor(floor.floor_id,false)
		await process_frame
		check(ui.current_floor_id==floor.floor_id and ui.active_floors.size()<=4,"ecosystem 50-floor virtualization")
	ui.exit_complex()
	game.free()
	print("Ecosystem UI checks: %d; failures: %d; renderer: %s" % [checks,failures,DisplayServer.get_name()])
	quit(1 if failures else 0)
