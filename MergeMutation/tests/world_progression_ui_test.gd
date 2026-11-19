extends "res://tests/landscape_ui_test.gd"
const Archive=preload("res://scripts/bestiary_model.gd")
const Factory=preload("res://scripts/ecosystem_factory.gd")
const Progression=preload("res://scripts/environment_progression.gd")
const C=preload("res://scripts/mutant_catalog.gd")
func shot(id: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://.godot/pr20-"+id+".png")==OK,"capture "+id)
func bounds(node: Node) -> void:
	if node is Control and not node.is_visible_in_tree(): return
	if node is Button or node is LineEdit or node is OptionButton:
		var r:=Rect2(node.get_global_transform_with_canvas()*Vector2.ZERO,node.size*node.get_global_transform_with_canvas().get_scale())
		check(Rect2(Vector2.ZERO,Vector2(root.size)).grow(2).encloses(r),"world UI bounds "+str(node.name))
	if node is ScrollContainer: return
	for child in node.get_children(): bounds(child)
func run() -> void:
	root.size=Vector2i(960,540)
	var path:="res://.godot/pr20-ui-profile.json"
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path+".habitat-demo-v1.json")
	game=Scene.instantiate()
	game.save_path=path
	root.add_child(game)
	game.view.sound.set_enabled(false)
	await process_frame
	await process_frame
	check(is_instance_valid(game.view.complex_ui),"fresh startup opens complex")
	check(is_instance_valid(game.view.story_screen),"fresh intro retained")
	press_button(game.view.story_screen.get_node("StorySkip"))
	await process_frame
	var ui=game.view.complex_ui
	check(ui.registry.get_habitat("habitat_slime").floor_id=="floor_01" and ui.registry.get_habitat("habitat_horn").floor_id=="floor_01","both first basement")
	check(ui.registry.room_rects.habitat_slime.position.x<ui.registry.room_rects.habitat_horn.position.x,"slime precedes horn with stable IDs")
	check(ui.living_models.size()==2,"existing two models")
	check(not ui.chrome.has_node("Nav_lab") and ui.chrome.has_node("Nav_bestiary"),"three main sections")
	ui.navigate_to_floor("floor_01",false)
	await shot("startup")
	press_button(ui.chrome.get_node("AppSettings"))
	check(game.view.panel_kind=="settings","settings opens from complex")
	game.view.close_panel()
	await process_frame
	await process_frame
	ui=game.view.complex_ui
	check(is_instance_valid(ui),"settings returns complex")
	press_button(ui.chrome.get_node("Nav_portals"),true)
	await process_frame
	var portal=game.view.portal_ui
	check(portal.has_node("SandboxZone"),"sandbox lives in portal zone")
	await shot("portal-sandbox")
	press_button(portal.chrome.get_node("AppSettings"))
	game.view.close_panel()
	await process_frame
	await process_frame
	check(portal.visible,"settings returns portal zone")
	press_button(portal.get_node("SandboxZone"))
	await process_frame
	check(not portal.visible and not is_instance_valid(game.view.complex_ui),"sandbox route opens existing board")
	press_button(game.view.create_button)
	drag(game.view,L.center(6),L.center(8))
	check(game.coins==120 and game.merges==1,"sandbox economy and merge retained")
	check(is_instance_valid(game.view.experiment_button),"tactical experiment entry retained")
	game.view.open_complex()
	await process_frame
	ui=game.view.complex_ui
	press_button(ui.chrome.get_node("Nav_bestiary"))
	await process_frame
	var screen=game.view.overlay
	check(screen.archive.entries.size()==10,"archive reuses ten species")
	var before:=profile()
	var unknown: Dictionary=screen.archive.dossier(game,"horn")
	check(unknown.hidden and not unknown.has("origin") and not unknown.has("abilities"),"unknown dossier conceals future data")
	check(screen.archive.filtered(game,"РОГАЧ").is_empty(),"search cannot leak unknown name")
	check(screen.archive.filtered(game,"СлИз",1)==["slime"],"case insensitive known search")
	check(screen.archive.filtered(game,"",2).size()==9,"unknown filter")
	screen.show_entry("horn")
	check(screen.content.get_node("VisitHabitat").disabled,"unknown species cannot open via dossier")
	await shot("unknown")
	screen.set_preview(true)
	check(profile()==before and not game.is_unlocked("horn",1),"explicit test preview never unlocks")
	await shot("horn-dossier-test")
	screen.set_preview(false)
	for id in ["horn","wing"]: game.unlock(C.make(id))
	game._save_game()
	before=profile()
	var bytes:=FileAccess.get_file_as_string(path)
	for id in ["slime","horn","wing"]:
		screen.show_entry(id)
		await shot(id+"-dossier")
		check(screen.content.has_node("Form_5"),"five existing forms "+id)
		var data: Dictionary=screen.archive.dossier(game,id)
		check(not data.hidden and data.abilities.size()==1,"abilities from actual tactical rules "+id)
		check(screen.archive.entries[id].notes.split("\n").size()>=3,"three research notes "+id)
	screen.show_entry("wing")
	check(screen.content.get_node("VisitHabitat").disabled,"closed wing remains closed")
	screen.query.text="Рог"
	screen.refresh_list()
	check(screen.list.get_child_count()==1,"visible search results")
	screen.query.text=""
	screen.refresh_list()
	await shot("bestiary")
	var chrome: Control
	# The shared component is located by its script rather than child ordering.
	for child in screen.get_children():
		if child.get_script()!=null and child.get_script().resource_path=="res://scripts/app_chrome.gd": chrome=child
	press_button(chrome.get_node("AppSettings"))
	game.view.close_panel()
	await process_frame
	await process_frame
	screen=game.view.overlay
	check(screen!=null and game.view.panel_kind=="collection","settings returns archive")
	var cancel:=InputEventKey.new()
	cancel.keycode=KEY_ESCAPE
	cancel.pressed=true
	root.push_input(cancel,true)
	cancel=cancel.duplicate()
	cancel.pressed=false
	root.push_input(cancel,true)
	await process_frame
	await process_frame
	check(is_instance_valid(game.view.complex_ui) and game.view.overlay==null,"archive Back returns complex, not sandbox")
	press_button(game.view.complex_ui.chrome.get_node("Nav_bestiary"))
	await process_frame
	screen=game.view.overlay
	for id in ["slime","horn"]:
		screen.show_entry(id)
		press_button(screen.content.get_node("VisitHabitat"),true)
		await process_frame
		ui=game.view.complex_ui
		check(ui.detail.model.habitat_id=="habitat_"+id,"addressed habitat after reorder "+id)
		check(ui.detail.model.registry.world_width==940 and not ui.detail.get_node("HabitatFind").visible,"S fixed camera "+id)
		var detail=ui.detail
		var room=detail.room_state
		await shot(id+"-empty")
		for slot in room.catalog.offers:
			if room.points==0: room.grant_test_point()
			var old_points: int=room.points
			check(room.confirm(slot,room.catalog.slots[slot].designs[0].design_id).ok,"install "+id+" "+slot)
			check(room.points==old_points-1,"only modular item costs point")
			var layers: Array=Progression.layers(room)
			for item in layers: check(item.threshold<=room.progress(),"threshold derived from installed count")
			detail.environment.refresh()
			if room.progress()%20==0 or id=="slime": await shot(id+"-"+str(room.progress()))
		var layers_before:=Progression.layers(room)
		var balance: int=room.points
		var slot: String=room.catalog.slots.keys()[0]
		room.preview(slot,room.catalog.slots[slot].designs[1].design_id)
		check(Progression.layers(room)==layers_before and room.points==balance,"preview never advances environment")
		room.cancel_preview()
		room.confirm(slot,room.catalog.slots[slot].designs[2].design_id)
		check(Progression.layers(room)==layers_before and room.points==balance,"free design change never advances environment")
		check(Progression.layers(room).size()==6,"all six thresholds cumulative")
		await shot(id+"-complete")
		ui.back()
		await process_frame
		await process_frame
		screen=game.view.overlay
		check(screen!=null and game.view.panel_kind=="collection","habitat Back returns to bestiary")
	check(profile()==before and FileAccess.get_file_as_string(path)==bytes,"rooms and archive preserve main v2 exactly")
	# Multiple custom thresholds can activate on a single first install.
	var source:=Registry.new()
	source.load_files()
	var custom: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/environment_progression.json"))
	custom.habitats.habitat_slime[1].threshold=10
	custom.habitats.habitat_slime[2].threshold=15
	check(Progression.validate(custom),"configurable threshold schema")
	var models:=Factory.create(source,"res://.godot/pr20-threshold-profile.json")
	var target_room=models.habitat_slime.renovation
	target_room.reset_demo(true)
	target_room.confirm("bed",target_room.catalog.slots.bed.designs[0].design_id)
	check(Progression.layers(target_room,custom).size()==3,"one install crosses all matching thresholds")
	var snapshot: String=FileAccess.get_file_as_string(target_room.path)
	var reload:=Factory.create(source,"res://.godot/pr20-threshold-profile.json")
	check(reload.habitat_slime.renovation.installed==target_room.installed and FileAccess.get_file_as_string(target_room.path)==snapshot,"new geometry keeps stored IDs without migration")
	for ratio in [Vector2i(960,540),Vector2i(1080,540),Vector2i(1170,540),Vector2i(1200,540),Vector2i(960,600)]:
		root.size=ratio
		await process_frame
		game.view.layout()
		game.view.show_panel("collection")
		await process_frame
		bounds(game.view.overlay)
		game.view.open_complex()
		ui=game.view.complex_ui
		await process_frame
		bounds(ui.chrome)
		for room_id in ["habitat_slime","habitat_horn"]:
			ui.navigate_to_habitat(room_id,false)
			ui.open_living(room_id)
			bounds(ui.detail)
			check(ui.detail.environment.layers.mutant.get_child_count()==1,"single resident at all ratios")
			ui.close_living()
		game.view.close_navigation()
	root.size=Vector2i(960,540)
	await process_frame
	game.view.layout()
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/complex_50.json"))
	var registry:=Registry.new()
	registry.configure(fixture,fixture)
	var large=load("res://scripts/ecosystem_complex.gd").new()
	large.setup(game,registry)
	game.view.add_child(large)
	for floor in large.registry.floors:
		large.navigate_to_floor(floor.floor_id,false)
		await process_frame
		check(large.current_floor_id==floor.floor_id and large.active_floors.size()<=4,"default UI virtualizes 50 floors")
	large.exit_complex()
	game.free()
	# Existing profile returns to complex with completed intro flag.
	game=Scene.instantiate()
	game.save_path=path
	root.add_child(game)
	await process_frame
	await process_frame
	check(is_instance_valid(game.view.complex_ui) and not is_instance_valid(game.view.story_screen),"existing profile starts complex without replay intro")
	game.free()
	print("World progression UI checks: %d; failures: %d; renderer: %s" % [checks,failures,DisplayServer.get_name()])
	quit(1 if failures else 0)
