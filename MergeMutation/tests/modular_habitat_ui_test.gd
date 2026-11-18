extends "res://tests/landscape_ui_test.gd"
const ModularCatalog=preload("res://scripts/renovation_catalog.gd")
var ui
var detail
var room
func shot(id: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await create_timer(0.08).timeout
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://.godot/modular-"+id+".png")==OK,"screenshot "+id)
func bounds(node: Node) -> void:
	if node is Control and not node.is_visible_in_tree(): return
	if node is Button:
		var rect:=Rect2(node.get_global_transform_with_canvas()*Vector2.ZERO,node.size*node.get_global_transform_with_canvas().get_scale())
		check(Rect2(Vector2.ZERO,Vector2(root.size)).grow(2).encloses(rect),"modular button fits "+str(node.name))
		check(node.size.y>=44,"touch target at least 44")
	if node is ScrollContainer: return
	for child in node.get_children(): bounds(child)
func open_slot(id: String,mouse: bool=false) -> void:
	if not detail.repair_mode: press_button(detail.get_node("HabitatRepair"))
	var p: Vector2=room.catalog.marker(room.catalog.slots[id],detail.model.registry.world_width)
	if detail.model.panorama: detail.environment.set_camera(clampf(p.x-470,0,1410))
	p=p*detail.environment.world.scale+detail.environment.world.position
	tap(detail.environment,p,mouse)
	check(is_instance_valid(detail.design_panel) and detail.chosen_slot==id,"native marker selects "+id)
func install(id: String,choice: String="") -> void:
	open_slot(id)
	if choice.is_empty(): choice=room.catalog.slots[id].designs[0].design_id
	press_button(detail.design_panel.get_node("Design_"+choice),true)
	press_button(detail.confirm_button)
	check(room.installed.get(id)==choice,"native design confirm "+id)
func grant(count: int) -> void:
	press_button(detail.get_node("HabitatTest"))
	for i in range(count): press_button(detail.stage_menu.get_node("GrantPoint"))
	press_button(detail.get_node("HabitatTest"))
func dialog_button(_dialog: Control,button: Button) -> void:
	press_button(button,true)
func run() -> void:
	root.gui_embed_subwindows=true
	root.size=Vector2i(960,540)
	game=Scene.instantiate()
	game.save_path="res://.godot/modular-ui-profile.json"
	DirAccess.remove_absolute(game.save_path)
	DirAccess.remove_absolute(game.save_path+".habitat-demo-v1.json")
	root.add_child(game)
	game.view.sound.set_enabled(false)
	game.coins=777
	game.save_extra["future_feature"]={"preserve":true}
	game._save_game()
	var main_save:=FileAccess.get_file_as_string(game.save_path)
	var before:=profile()
	game.view.open_complex()
	ui=game.view.complex_ui
	ui.navigate_to_floor("floor_01",false)
	await process_frame
	check(ui.living_models.size()==1,"only one live habitat")
	for id in ui.registry.habitats:
		check(ui.registry.habitats[id].preview_accessible==(id=="habitat_horn"),"other habitats closed")
	check(ui.open_living("habitat_horn"),"open modular detail")
	detail=ui.detail
	room=detail.room_state
	var resident=detail.model
	check(room.points==3 and room.progress()==0,"initial three demo points")
	check(not detail.has_node("HabitatDemo") and detail.has_node("HabitatRepair"),"global stages removed from regular UI")
	check(detail.environment.actor.visible and detail.environment.layers.mutant.get_child_count()==1,"one resident in poor room")
	await shot("empty")
	open_slot("bed")
	var collision_before: Array=resident.objects().duplicate(true)
	await shot("design-panel")
	for d in room.catalog.slots.bed.designs:
		press_button(detail.design_panel.get_node("Design_"+d.design_id))
		check(room.installed.is_empty() and room.points==3 and resident.objects()==collision_before,"UI preview no state, currency or collisions")
		await shot("bed-preview-"+d.visual)
	press_button(detail.design_panel.get_node("CancelDesign"),true)
	check(room.visual_choice("bed").is_empty() and not FileAccess.file_exists(room.path),"native cancel rolls back")
	install("bed")
	tap(detail,Vector2(796,440),true)
	check(room.points==2 and room.installed.size()==1,"rapid repeat tap cannot charge twice")
	for d in room.catalog.slots.bed.designs:
		install("bed",d.design_id)
		check(room.points==2 and room.progress()==10,"native free design changes")
		await shot("bed-"+d.visual)
	install("walls")
	install("floor")
	check(room.progress()==30 and room.points==0,"thirty percent")
	press_button(detail.get_node("HabitatRepair"))
	await shot("progress-30")
	open_slot("training")
	check(detail.confirm_button.disabled,"insufficient funds disables confirm")
	press_button(detail.design_panel.get_node("CancelDesign"))
	grant(3)
	for id in ["training","feeder","lighting"]: install(id)
	check(room.progress()==60 and room.points==0,"sixty percent")
	press_button(detail.get_node("HabitatRepair"))
	await shot("progress-60")
	grant(4)
	for id in ["cabinets","plants","toy","water"]: install(id)
	check(room.progress()==100 and room.points==0,"all ten slots installed")
	press_button(detail.get_node("HabitatRepair"))
	resident.cancel_action()
	detail.environment.set_active(false)
	await shot("progress-100")
	bounds(detail)
	# All variants must differ in the room, beyond the label in the picker.
	for id in room.catalog.slots:
		var images: Array=[]
		for d in room.catalog.slots[id].designs:
			room.preview(id,d.design_id)
			if DisplayServer.get_name()!="headless":
				await process_frame
				await RenderingServer.frame_post_draw
				images.append(root.get_texture().get_image().get_region(Rect2i(10,74,940,440)).get_data().hex_encode().sha256_text())
		if not images.is_empty(): check(images[0]!=images[1] and images[1]!=images[2] and images[0]!=images[2],"three visually different variants "+id)
		room.cancel_preview()
	var actual: Dictionary=room.installed.duplicate()
	var sidecar:=FileAccess.get_file_as_string(room.path)
	open_slot("bed")
	press_button(detail.design_panel.get_node("Design_soft_bed"))
	ui.back()
	check(detail.design_panel==null and room.installed==actual and FileAccess.get_file_as_string(room.path)==sidecar,"system back cancels picker before exit")
	press_button(detail.get_node("HabitatRepair"))
	resident.cancel_action()
	detail.environment.set_active(false)
	for id in ["bed","feeder","toy","cabinets","training"]:
		var slot: Dictionary=room.catalog.slots[id]
		var r: Rect2=room.catalog.project_rect(slot,940)
		resident.cancel_action()
		resident.position=Vector2(maxf(48,r.position.x-70),354)
		resident.profile.movement_speed=400
		tap(detail.environment,room.catalog.project_rect(slot,940,"touch").get_center(),id in ["training","cabinets"])
		check(resident.action_slot==id,"native installed interaction "+id)
		var seen: Dictionary={}
		for i in range(300):
			seen[resident.behavior]=true
			resident.advance(0.05)
			if resident.behavior=="ram" and resident.elapsed>=0.6:
				detail.environment.refresh()
				await shot("training-hit")
			if resident.action_slot.is_empty(): break
		check(seen.has({"bed":"sleep","feeder":"inspect","toy":"react","cabinets":"inspect","training":"ram"}[id]),"native interaction reaches FSM action")
	resident.cancel_action()
	tap(detail.environment,room.catalog.project_rect(room.catalog.slots.lighting,940,"touch").get_center())
	check(not resident.lighting_on,"native light toggle")
	resident.cancel_action()
	var actor_point: Vector2=resident.position-Vector2(0,35)
	tap(detail.environment,actor_point)
	check(resident.behavior=="react","native resident tap")
	resident.cancel_action()
	press_button(detail.get_node("HabitatPanorama"),true)
	detail.environment.set_active(false)
	check(resident.registry.world_width==2350 and room.installed==actual,"same state in panorama")
	for x in [0,705,1410]:
		detail.environment.set_camera(x)
		await shot("panorama-%d" % x)
		check(detail.environment.layers.mutant.get_child_count()==1,"panorama never clones resident")
	var signature:=JSON.stringify([room.installed,room.points,resident.hit_count,resident.lighting_on])
	detail.environment.set_camera(400)
	drag(detail.environment,Vector2(800,200),Vector2(100,200))
	check(detail.environment.camera_x>400 and JSON.stringify([room.installed,room.points,resident.hit_count,resident.lighting_on])==signature and resident.action_slot.is_empty(),"swipe does not activate object")
	detail.environment.set_camera(790)
	var light_point: Vector2=room.catalog.project_rect(room.catalog.slots.lighting,2350,"touch").get_center()
	light_point=light_point*detail.environment.world.scale+detail.environment.world.position
	var touch:=InputEventScreenTouch.new()
	touch.position=light_point
	touch.pressed=true
	detail.environment_input(touch)
	for p in [light_point+Vector2(70,0),light_point]:
		var motion:=InputEventScreenDrag.new()
		motion.position=p
		detail.environment_input(motion)
	touch.pressed=false
	detail.environment_input(touch)
	check(not resident.lighting_on and resident.action_slot.is_empty(),"out-and-back swipe over light never toggles it")
	touch.pressed=true
	detail.environment_input(touch)
	touch.pressed=false
	touch.canceled=true
	detail.environment_input(touch)
	check(not detail.pressing and detail.camera_velocity==0 and not resident.lighting_on,"canceled touch never activates object")
	press_button(detail.get_node("HabitatFind"))
	for i in range(100): detail._process(0.02)
	check(absf(detail.environment.camera_x-clampf(resident.position.x-470,0,1410))<1,"find resident after inertial swipe")
	detail.environment.set_camera(840)
	detail.camera_velocity=0
	await process_frame
	var offset: float=ui.offset
	ui.close_living()
	check(ui.offset==offset and ui.living_models.habitat_horn==resident,"same model, scroll retained")
	await process_frame
	var overview=ui.room_view("habitat_horn").environment
	check(overview.model.renovation==room,"overview uses same renovation source")
	await shot("complex-overview")
	ui.open_living("habitat_horn")
	detail=ui.detail
	check(detail.environment.camera_x==840 and detail.model==resident,"camera restored on reentry")
	press_button(detail.get_node("HabitatPanorama"))
	check(detail.model.registry.world_width==940 and room.installed==actual,"normal projection retains installation")
	ui.close_living()
	ui.navigate_to_floor("floor_04",false)
	var frozen: Vector2=resident.position
	await create_timer(0.15).timeout
	check(resident.position==frozen,"hidden resident paused")
	ui.exit_complex()
	check(profile()==before and FileAccess.get_file_as_string(game.save_path)==main_save,"all renovation activity leaves main v2 byte-identical")
	for repeat in range(4):
		game.view.open_complex()
		ui=game.view.complex_ui
		ui.navigate_to_floor("floor_01",false)
		ui.open_living("habitat_horn")
		detail=ui.detail
		room=detail.room_state
		check(room.progress()==100 and room.points==0 and room.installed==actual,"saved renovation after reentry")
		check(detail.environment.layers.mutant.get_child_count()==1,"no duplicate simulation on reopen")
		ui.exit_complex()
		await process_frame
	game.free()
	game=Scene.instantiate()
	game.save_path="res://.godot/modular-ui-profile.json"
	root.add_child(game)
	game.view.sound.set_enabled(false)
	check(JSON.stringify(JSON.parse_string(profile()),"",true)==JSON.stringify(JSON.parse_string(before),"",true) and FileAccess.get_file_as_string(game.save_path)==main_save,"old v2 and unknown fields survive full game reload")
	game.view.open_complex()
	ui=game.view.complex_ui
	ui.open_living("habitat_horn")
	check(ui.detail.room_state.progress()==100 and ui.detail.room_state.installed==actual,"renovation survives full game reload")
	ui.exit_complex()
	# Real default UI at every supported aspect ratio.
	for ratio in [Vector2i(960,540),Vector2i(1080,540),Vector2i(1170,540),Vector2i(1200,540),Vector2i(960,600)]:
		root.size=ratio
		await process_frame
		game.view.layout()
		game.view.open_complex()
		ui=game.view.complex_ui
		ui.navigate_to_floor("floor_01",false)
		ui.open_living("habitat_horn")
		detail=ui.detail
		room=detail.room_state
		await process_frame
		open_slot("bed",true)
		bounds(detail)
		press_button(detail.design_panel.get_node("CancelDesign"))
		check(room.progress()==100,"aspect cancel preserves progress")
		press_button(detail.get_node("HabitatTest"))
		press_button(detail.stage_menu.get_node("ResetRenovation"))
		bounds(detail.reset_confirmation)
		press_button(detail.reset_confirmation.get_cancel_button(),true)
		check(room.progress()==100 and not detail.reset_confirmation.visible,"embedded confirmation safe at every aspect")
		ui.exit_complex()
	root.size=Vector2i(960,540)
	await process_frame
	game.view.layout()
	game.view.open_complex()
	ui=game.view.complex_ui
	ui.open_living("habitat_horn")
	detail=ui.detail
	room=detail.room_state
	press_button(detail.get_node("HabitatTest"))
	press_button(detail.stage_menu.get_node("ResetRenovation"))
	await process_frame
	await process_frame
	check(detail.reset_confirmation.visible and room.progress()==100,"reset confirmation before data change")
	dialog_button(detail.reset_confirmation,detail.reset_confirmation.get_cancel_button())
	check(room.progress()==100,"reset cancel preserves room")
	press_button(detail.stage_menu.get_node("ResetRenovation"))
	await process_frame
	await process_frame
	dialog_button(detail.reset_confirmation,detail.reset_confirmation.get_ok_button())
	check(room.progress()==0 and room.points==3,"confirmed isolated reset")
	check(profile()==before and FileAccess.get_file_as_string(game.save_path)==main_save,"reset leaves main profile byte-identical")
	ui.exit_complex()
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/complex_50.json"))
	var registry:=Registry.new()
	registry.configure(fixture,fixture)
	ui=Complex.new()
	ui.setup(game,registry)
	game.view.add_child(ui)
	for floor in ui.registry.floors:
		ui.navigate_to_floor(floor.floor_id,false)
		await process_frame
		check(ui.current_floor_id==floor.floor_id and ui.active_floors.size()<=4,"modular default keeps 50-floor virtualization")
	ui.exit_complex()
	game.free()
	print("Modular UI checks: %d; failures: %d; renderer: %s" % [checks,failures,DisplayServer.get_name()])
	quit(1 if failures else 0)
