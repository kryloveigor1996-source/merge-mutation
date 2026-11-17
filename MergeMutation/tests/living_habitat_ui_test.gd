extends SceneTree
const Scene=preload("res://scenes/main.tscn")
var checks:=0
var failures:=0
var ui
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:
		failures+=1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func tap(target: CanvasItem,point: Vector2,mouse: bool=false) -> void:
	for down in [true,false]:
		var event: InputEvent
		if mouse:
			event=InputEventMouseButton.new()
			event.button_index=MOUSE_BUTTON_LEFT
		else: event=InputEventScreenTouch.new()
		event.position=target.get_global_transform_with_canvas()*point
		event.pressed=down
		root.push_input(event,true)
func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://.godot/living-"+name+".png")==OK,"screenshot "+name)
func profile(game) -> String: return JSON.stringify([game.cells,game.coins,game.discoveries,game.merges,game.campaign_progress.encode(),game.save_extra],"",true)
func run() -> void:
	root.size=Vector2i(360,720)
	var game=Scene.instantiate()
	game.save_path="res://.godot/living-ui-save.json"
	root.add_child(game)
	game.view.sound.set_enabled(false)
	game._save_game()
	var original:=FileAccess.get_file_as_string(game.save_path)
	var before:=profile(game)
	game.view.open_complex()
	ui=game.view.complex_ui
	await process_frame
	for id in ["floor_surface","floor_01","floor_02","floor_03","floor_04"]:
		check(ui.navigate_to_floor(id,false),"resized floor navigation")
		await shot(id)
	ui.navigate_to_floor("floor_01",false)
	ui.set_scroll_position(ui.offset+23)
	await process_frame
	var offset_before: float=ui.offset
	var floor_before: String=ui.current_floor_id
	var state=ui.living_models.habitat_horn
	var overview=ui.room_view("habitat_horn").environment
	check(state.stage==2 and overview.model==state and overview.is_processing(),"shared default model in visible overview")
	check(ui.open_living("habitat_horn") and ui.detail.model==state,"detail opens by stable habitat ID")
	await process_frame
	check(not overview.is_processing() and ui.detail.environment.is_processing(),"overview simulation pauses while detail is active")
	check(ui.detail.environment.size==Vector2(340,420),"large habitat occupies most useful screen area")
	var images: Dictionary={}
	for stage in range(1,5):
		tap(ui.detail,Vector2(51+(stage-1)*86,643),stage%2==0)
		await process_frame
		check(state.stage==stage and overview.model.stage==stage,"stage panel changes a single shared state")
		check(ui.detail.environment.actor.visible==(stage>1),"resident visibility by stage")
		check(ui.detail.environment.layers.size()==7,"independent visual layers")
		await shot("stage-%d" % stage)
		if DisplayServer.get_name()!="headless":
			var picture:=root.get_texture().get_image()
			images[stage]=picture.get_region(Rect2i(10,102,340,420)).get_data().hex_encode().sha256_text()
	if not images.is_empty(): check(images.values().size()==4 and images.values()[0]!=images.values()[1] and images.values()[1]!=images.values()[2] and images.values()[2]!=images.values()[3],"all four environment images differ beyond labels")
	state.set_stage(2)
	state.enter("sleep",5)
	await process_frame
	var environment=ui.detail.environment
	tap(environment,state.position-Vector2(0,35))
	tap(environment,state.position-Vector2(0,35))
	check(state.behavior=="react" and state.cooldown>0,"touch wakes resident and cooldown guards repeated input")
	var elapsed: float=state.elapsed
	ui.detail.complex_screen.show_room_info("habitat_horn")
	await create_timer(0.15).timeout
	check(not environment.is_processing() and state.elapsed==elapsed,"information overlay pauses hidden simulation")
	ui.close_modal()
	check(environment.is_processing(),"closing information resumes detail")
	state.set_stage(3)
	tap(environment,Vector2(278,320),true)
	check(state.intent=="ram" and not state.request_ram(),"mouse training object queues one approach only")
	# Fast deterministic clock replay, using the same model transition method as rendering.
	environment.set_active(false)
	for step in range(80): state.tick(0.05)
	check(state.hit_count>=1 and state.stone_broken,"training breaks stone without rewards")
	state.enter("sleep",10) # Isolate stone recovery from later autonomous training choices.
	for step in range(80): state.tick(0.05)
	check(not state.stone_broken,"training stone regenerates")
	environment.set_active(true)
	state.set_stage(4)
	tap(ui.detail,Vector2(52,36))
	await process_frame
	check(ui.detail==null and is_equal_approx(ui.offset,offset_before) and ui.current_floor_id==floor_before,"return restores exact scroll offset and floor")
	check(ui.room_view("habitat_horn").highlight_left>0 and ui.room_view("habitat_horn").environment.model==state and state.stage==4,"return highlights shared updated biome")
	await shot("overview-stage-4")
	ui.set_scroll_position(505)
	var partially_hidden: float=state.elapsed
	await create_timer(0.15).timeout
	check(ui.room_view("habitat_horn")!=null and not ui.room_view("habitat_horn").environment.is_processing() and state.elapsed==partially_hidden,"offscreen room pauses even when its floor is partially visible")
	ui.navigate_to_floor("floor_04",false)
	var frozen: float=state.elapsed
	await create_timer(0.2).timeout
	check(state.elapsed==frozen and ui.room_view("habitat_horn")==null,"unloaded habitat does not simulate")
	ui.navigate_to_floor("floor_01",false)
	await process_frame
	check(ui.room_view("habitat_horn").environment.model==state and state.stage==4,"reloaded overview reuses same model")
	var connections: int=state.stage_changed.get_connections().size()
	for repeat in range(8):
		check(ui.open_living("habitat_horn"),"repeat open")
		check(ui.detail.environment.layers.mutant.get_child_count()==1,"single actor presenter in detail")
		ui.close_living()
		await process_frame
		check(state.stage_changed.get_connections().size()==connections,"detail signals released on close")
	check(not ui.open_living("habitat_slime") and not ui.open_living("missing"),"unavailable living IDs safe")
	check(profile(game)==before and FileAccess.get_file_as_string(game.save_path)==original,"stages, behavior and training never touch permanent progress")
	ui.exit_complex()
	await process_frame
	game.view.open_complex()
	ui=game.view.complex_ui
	check(ui.living_models.habitat_horn.stage==2,"new complex defaults to stage 2 without persisted demo stage")
	game.free()
	print("Living UI checks: %d; failures: %d; renderer: %s" % [checks,failures,DisplayServer.get_name()])
	quit(1 if failures else 0)
