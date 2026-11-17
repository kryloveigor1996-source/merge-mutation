extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const L=preload("res://scripts/landscape_layout.gd")
const Complex=preload("res://scripts/landscape_complex.gd")
const Registry=preload("res://scripts/complex_registry.gd")
const Search=preload("res://scripts/mutation_search.gd")
var checks:=0
var failures:=0
var game
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:
		failures+=1
		printerr("FAIL: ",label)
func tap(target: CanvasItem,point: Vector2,mouse: bool=false) -> void:
	for down in [true,false]:
		var e: InputEvent
		if mouse:
			e=InputEventMouseButton.new()
			e.button_index=MOUSE_BUTTON_LEFT
		else: e=InputEventScreenTouch.new()
		e.position=target.get_global_transform_with_canvas()*point
		e.pressed=down
		root.push_input(e,true)
func press_button(button: Button,mouse: bool=false) -> void: tap(button,button.size*0.5,mouse)
func drag(target: CanvasItem,from: Vector2,to: Vector2,mouse: bool=false) -> void:
	var start: InputEvent
	var motion: InputEvent
	if mouse:
		start=InputEventMouseButton.new()
		start.button_index=MOUSE_BUTTON_LEFT
		motion=InputEventMouseMotion.new()
	else:
		start=InputEventScreenTouch.new()
		motion=InputEventScreenDrag.new()
	start.position=target.get_global_transform_with_canvas()*from
	start.pressed=true
	root.push_input(start,true)
	motion.position=target.get_global_transform_with_canvas()*to
	motion.relative=to-from
	root.push_input(motion,true)
	start=start.duplicate()
	start.position=motion.position
	start.pressed=false
	root.push_input(start,true)
func shot(id: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await create_timer(0.2).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://.godot/landscape-"+id+".png")==OK,"screenshot "+id)
func profile() -> String: return JSON.stringify([game.cells,game.coins,game.discoveries,game.merges,game.campaign_progress.encode(),game.save_extra],"",true)
func verify_opaque() -> void:
	if DisplayServer.get_name()=="headless": return
	var sentinel:=ColorRect.new()
	sentinel.size=L.DESIGN
	sentinel.z_index=21
	sentinel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	sentinel.color=Color.MAGENTA
	game.view.add_child(sentinel)
	await process_frame
	await RenderingServer.frame_post_draw
	var before:=root.get_texture().get_image()
	sentinel.color=Color.GREEN
	await process_frame
	await RenderingServer.frame_post_draw
	var after:=root.get_texture().get_image()
	for point in [Vector2i(4,4),Vector2i(954,4),Vector2i(4,534),Vector2i(954,534)]:
		check(before.get_pixelv(point).is_equal_approx(after.get_pixelv(point)),"opaque landscape portal GPU corner")
	sentinel.queue_free()
func run() -> void:
	root.size=Vector2i(960,540)
	game=Scene.instantiate()
	game.save_path="res://.godot/landscape-test-save.json"
	DirAccess.remove_absolute(game.save_path)
	root.add_child(game)
	game.view.sound.set_enabled(false)
	await process_frame
	check(game.view.get_script().resource_path.ends_with("landscape_lab.gd"),"default landscape factory")
	for ratio in [Vector2(960,540),Vector2(1080,540),Vector2(1170,540),Vector2(1200,540),Vector2(960,600)]:
		var fit:=L.fit(Rect2(Vector2(20,10),ratio-Vector2(40,20)))
		check(Rect2(Vector2.ZERO,ratio).encloses(fit),"safe area fit "+str(ratio))
		check(is_equal_approx(fit.size.x/960,fit.size.y/540),"isotropic scale")
		root.size=Vector2i(ratio)
		await process_frame
		game.view.layout()
		for i in range(30): check(game._cell_at(L.center(i))==i,"board coordinate "+str(i))
		press_button(game.view.create_button)
		await process_frame
		check(not game.dragging,"native touch button does not start drag")
		await shot("aspect-%d-%d" % [ratio.x,ratio.y])
	root.size=Vector2i(960,540)
	await process_frame
	game.view.layout()
	game.cells.fill(null)
	game.cells[0]=game.Catalog.make("slime",1)
	game.cells[1]=game.Catalog.make("slime",1)
	game.view.rebuild()
	var coins: int=game.coins
	drag(game.view,L.center(0),L.center(1),true)
	await create_timer(0.35).timeout
	check(game.cells[1].get("evolution_stage")==2 and game.cells[0]==null,"mouse drag merge same species")
	check(game.coins==coins+30,"same merge reward")
	await shot("laboratory")
	for kind in ["collection","settings","species"]:
		game.view.show_panel(kind)
		await process_frame
		await shot(kind)
		var panel: Control=game.view.overlay.get_child(1)
		check(Rect2(Vector2.ZERO,L.DESIGN).encloses(panel.get_rect()),"panel fits "+kind)
		game.view.close_panel()
	game.view.portal_ui.open_hub("laboratory")
	await process_frame
	await shot("portals")
	var hub=game.view.portal_ui
	for i in range(12):
		drag(hub,Vector2(470,290),Vector2(180,290),i%2==0)
		check(hub.visible and hub.modulate.a==1 and hub.page=="hub","rapid swipe remains opaque, never enters")
		if i in [0,5,11]: await verify_opaque()
	hub.open_hub("laboratory")
	tap(hub,Vector2(330,270))
	await create_timer(0.4).timeout
	check(hub.page=="map","center stand opens map")
	await shot("map")
	check(hub.open_preview("laboratory","lab_01"),"preview actual level")
	await process_frame
	await shot("preview")
	hub.close_preview()
	hub.close_to_lab()
	game.view.show_story("intro")
	await process_frame
	await shot("story")
	game.view.close_story()
	game.view.open_experiment()
	var ui=game.view.experiment_ui
	await process_frame
	await shot("trials")
	tap(ui,Vector2(850,106),true)
	check(ui.number==1,"right edge list entry mouse")
	var before:=profile()
	var witnesses: Array=JSON.parse_string(FileAccess.get_file_as_string("res://.godot/mutation-solutions.json")) if FileAccess.file_exists("res://.godot/mutation-solutions.json") else []
	for number in range(1,11):
		check(ui.start_trial(number),"start tactical "+str(number))
		await process_frame
		var proof: Dictionary={}
		for witness in witnesses:
			if int(witness.number)==number and witness.get("config_hash")==JSON.stringify(ui.config(number),"",true).sha256_text(): proof={"won":true,"actions":witness.actions}
		if proof.is_empty(): proof=Search.solve(ui.session)
		check(proof.won,"tactical solution")
		if number in [1,6,10]: await shot("tactical-%02d" % number)
		for action in proof.actions:
			if action.kind=="spawn": press_button(ui.get_node("ExperimentSpawn"),number%2==0)
			else:
				tap(ui,ui.center(int(action.source)),number%2==0)
				check(ui.selected==int(action.source),"actual source coordinate")
				tap(ui,ui.center(int(action.index)),number%2==0)
			await create_timer(0.3).timeout
		check(ui.session.status=="won","landscape tactical victory "+str(number))
		check(profile()==before,"no tactical rewards or save changes")
	ui.start_trial(1)
	await process_frame
	press_button(ui.get_node("ExperimentSpawn"))
	await create_timer(0.3).timeout
	press_button(ui.get_node("ExperimentUndo"),true)
	await create_timer(0.3).timeout
	check(ui.session.moves_used==0,"native landscape undo")
	ui.exit_experiment()
	game.view.open_complex()
	ui=game.view.complex_ui
	await process_frame
	for id in ["floor_surface","floor_01","floor_02","floor_03","floor_04"]:
		check(ui.navigate_to_floor(id,false),"wide floor "+id)
		await process_frame
		await shot(id)
		check(ui.active_floors.size()<=4,"visible floor budget")
	ui.show_lift()
	await process_frame
	await shot("lift")
	ui.close_modal()
	ui.navigate_to_floor("floor_01",false)
	var offset: float=ui.offset
	var state=ui.living_models.habitat_horn
	check(ui.open_living("habitat_horn"),"open large detail")
	await process_frame
	var detail=ui.detail
	check(detail.environment.size==Vector2(940,440),"large useful environment")
	check(detail.environment.layers.mutant.get_child_count()==1,"one resident")
	tap(detail.environment,state.position-Vector2(0,35))
	check(state.behavior=="react","direct resident touch")
	for stage in range(1,5):
		press_button(detail.get_node("HabitatDemo"))
		await process_frame
		if stage==4: await shot("habitat-stages")
		press_button(detail.stage_menu.get_node("Stage%d" % stage),stage%2==0)
		await process_frame
		check(state.stage==stage and detail.environment.actor.visible==(stage>1),"compact demo stages")
		await shot("habitat-stage-%d" % stage)
	var frozen: float=state.elapsed
	ui.show_room_info("habitat_horn")
	await create_timer(0.15).timeout
	check(not detail.environment.is_processing() and state.elapsed==frozen,"landscape info pauses resident")
	await shot("habitat-info")
	ui.close_modal()
	check(detail.environment.is_processing(),"landscape info resumes resident")
	state.set_stage(3)
	tap(detail.environment,Vector2(678,320),true)
	check(state.intent=="ram","direct stone interaction")
	state.set_stage(4)
	press_button(detail.get_node("HabitatPanorama"))
	await process_frame
	check(state.registry.world_width==2350,"world 2.5 viewports")
	check(detail.environment.world.scale==Vector2(1,440.0/420),"panorama retains creature scale")
	var pos: Vector2=state.position
	detail.environment.set_active(false)
	for camera in [0,705,1410]:
		detail.find_target=false
		detail.environment.set_camera(camera)
		await shot("panorama-%d" % camera)
		check(state.position==pos and detail.environment.layers.mutant.get_child_count()==1,"camera independent of resident")
	detail.environment.set_camera(0)
	drag(detail.environment,Vector2(800,210),Vector2(100,210))
	check(detail.environment.camera_x>0 and state.behavior=="idle","touch pan without interaction")
	detail.environment.set_camera(1000)
	drag(detail.environment,Vector2(100,210),Vector2(700,210),true)
	check(detail.environment.camera_x==400 and state.behavior=="idle","mouse camera drag without interaction")
	var actor_point: Vector2=(state.position-Vector2(0,35))*detail.environment.world.scale+detail.environment.world.position
	# Out and back: zero net displacement must still count as a swipe.
	var down:=InputEventScreenTouch.new()
	down.position=actor_point
	down.pressed=true
	detail.environment_input(down)
	for point in [actor_point+Vector2(70,0),actor_point]:
		var move:=InputEventScreenDrag.new()
		move.position=point
		detail.environment_input(move)
	down.pressed=false
	detail.environment_input(down)
	check(state.behavior=="idle" and state.cooldown==0,"out-and-back swipe never reacts")
	detail.camera_velocity=0
	detail.environment.set_camera(100000)
	check(detail.environment.camera_x==1410,"right camera bound")
	detail.environment.set_camera(-100)
	check(detail.environment.camera_x==0,"left camera bound")
	press_button(detail.get_node("HabitatFind"),true)
	for frame in range(80): detail._process(0.02)
	check(absf(detail.environment.camera_x-clampf(state.position.x-470,0,1410))<1,"find resident")
	ui.close_living()
	check(ui.offset==offset and ui.living_models.habitat_horn==state,"return keeps scroll and same resident")
	check(profile()==before,"demonstrations preserve profile")
	ui.exit_complex()
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/complex_50.json"))
	var registry:=Registry.new()
	check(registry.configure(fixture,fixture),"stress fixture")
	ui=Complex.new()
	ui.setup(game,registry)
	game.view.add_child(ui)
	for floor in ui.registry.floors:
		check(ui.navigate_to_floor(floor.floor_id,false),"stress floor navigation")
		await process_frame
		check(ui.current_floor_id==floor.floor_id and ui.active_floors.size()<=4,"50 floor bounded processing")
	ui.exit_complex()
	game.free()
	print("Landscape checks: %d; failures: %d; renderer: %s" % [checks,failures,DisplayServer.get_name()])
	quit(1 if failures else 0)
