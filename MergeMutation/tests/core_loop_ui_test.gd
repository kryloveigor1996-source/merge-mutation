extends "res://tests/landscape_ui_test.gd"
const Solver=preload("res://tests/campaign_solver.gd")
const Levels=preload("res://scripts/campaign_levels.gd")
func shot(id: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await create_timer(0.8 if "--cycle-video" in OS.get_cmdline_user_args() else 0.15).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://.godot/pr21-"+id+".png")==OK,"capture "+id)
func clean_ui(node: Node) -> void:
	if node is Control and not node.is_visible_in_tree(): return
	if node is Label or node is Button or node is RichTextLabel:
		for token in ["proud_ram","habitat_slime","species_id","ТЕСТОВОЕ ОЧКО","Паспорт и юмористические"]:
			check(not token in node.text,"no internal/demo text "+token)
	for child in node.get_children(): clean_ui(child)
func bounds(node: Node) -> void:
	if node is Control and not node.is_visible_in_tree(): return
	if node is Button or node is HSlider:
		var r:=Rect2(node.get_global_transform_with_canvas()*Vector2.ZERO,node.size*node.get_global_transform_with_canvas().get_scale())
		check(Rect2(Vector2.ZERO,Vector2(root.size)).grow(2).encloses(r),"touch target within viewport "+str(node.name))
		check(node.size.y>=44,"44-unit target "+str(node.name))
	if node is ScrollContainer: return
	for child in node.get_children(): bounds(child)
func run() -> void:
	root.size=Vector2i(960,540)
	game=Scene.instantiate()
	game.save_path="res://.godot/core-ui-"+str(Time.get_ticks_usec())+".json"
	game.audio_settings_path=game.save_path+".cfg"
	root.add_child(game)
	game.view.sound.set_enabled(false)
	game.music.handle_lifecycle=false
	game.music.set_volume("master",0.5 if "--cycle-video" in OS.get_cmdline_user_args() else 0)
	await process_frame
	await process_frame
	check(is_instance_valid(game.view.story_screen),"fresh intro shown above complex")
	check(game.view.story_screen.z_index>game.view.complex_ui.z_index,"intro visible stacking")
	press_button(game.view.story_screen.get_node("StorySkip"),true)
	await process_frame
	check(not game.species_known("slime") and game.progression.balance()==3,"no free discoveries or demo stock")
	check(not game.view.complex_ui.open_living("habitat_slime"),"unknown habitat gated")
	press_button(game.view.complex_ui.chrome.get_node("Nav_portals"))
	await process_frame
	var portal=game.view.portal_ui
	check(portal.visible,"portals reachable by touch")
	check(portal.open_map("laboratory"),"real laboratory expedition map")
	check(portal.open_preview("laboratory","lab_01"),"first level preview")
	await shot("expedition")
	press_button(portal.preview.get_node("PreviewPlay"),true)
	await process_frame
	check(game.in_campaign() and game.campaign.config.number==1,"mouse starts actual level")
	var proof:=Solver.solve(Levels.get_level(1))
	for action in proof.actions:
		if action.kind=="spawn": press_button(game.view.create_button)
		else: drag(game.view,game.view.cell_center(action.source),game.view.cell_center(action.index),true)
		await process_frame
		if "--cycle-video" in OS.get_cmdline_user_args(): await create_timer(0.4).timeout
	check(game.campaign.status=="won" and game.view.panel_kind=="result","real puzzle completes via input")
	check(game.progression.balance()==8 and game.species_known("slime"),"durable reward and first discovery")
	await shot("victory")
	clean_ui(game.view.overlay)
	press_button(game.view.overlay.get_node("ReturnComplex"))
	await process_frame
	var ui=game.view.complex_ui
	check(is_instance_valid(ui),"victory returns home")
	check(ui.navigate_to_habitat("habitat_slime",false) and ui.open_living("habitat_slime"),"new habitat entered")
	await process_frame
	var detail=ui.detail
	check(not detail.get_node("HabitatTest").visible,"no normal free-resource menu")
	var room=detail.room_state
	var marker: Vector2=room.catalog.marker(room.catalog.slots.bed,detail.model.registry.world_width)
	detail.environment.set_camera(0)
	tap(detail.environment,marker*detail.environment.world.scale+detail.environment.world.position)
	await process_frame
	check(is_instance_valid(detail.design_panel),"object construction opens preview")
	check("Цена: 3" in detail.panel_cost.text,"real configured price and wallet")
	await shot("construction")
	press_button(detail.design_panel.get_node("CancelDesign"),true)
	check(game.progression.balance()==8 and room.installed.is_empty(),"preview cancel spends nothing")
	check(detail.open_design("bed"),"reopen object design")
	press_button(detail.confirm_button)
	await process_frame
	check(game.progression.balance()==5 and room.installed.has("bed"),"confirmed item spends exactly three")
	detail.environment.set_active(false)
	detail.model.reset_simulation(2)
	check(detail.model.request_slot("bed"),"real installed object action")
	check(game.progression.data.observations.is_empty(),"request alone does not discover observation")
	for i in range(300): detail.model.advance(0.05)
	check(game.progression.data.observations.has("slime_acid_sleep"),"completed sleep records observation")
	await shot("habitat")
	ui.close_living()
	await process_frame
	await process_frame
	press_button(ui.chrome.get_node("Nav_bestiary"),true)
	await process_frame
	var archive=game.view.overlay
	check(is_instance_valid(archive),"archive opens from habitat return")
	if not is_instance_valid(archive): quit(1); return
	archive.show_entry("slime")
	check(not archive.get_node("BestiaryTest").visible,"no discovery cheat in archive")
	clean_ui(archive)
	await shot("bestiary")
	for child in archive.content.get_children():
		if child is ScrollContainer: child.scroll_vertical=10000
	await shot("observations")
	for ratio in [Vector2i(960,540),Vector2i(1080,540),Vector2i(1170,540),Vector2i(1200,540),Vector2i(960,600)]:
		root.size=ratio
		await process_frame
		game.view.layout()
		bounds(archive)
		await shot("ratio-%d-%d" % [ratio.x,ratio.y])
	root.size=Vector2i(960,540)
	game.view.handle_back()
	await process_frame
	check(is_instance_valid(game.view.complex_ui),"archive Back returns complex")
	press_button(game.view.complex_ui.chrome.get_node("AppSettings"))
	await process_frame
	var starts: int=game.music.starts
	check(game.view.panel_kind=="settings","audio settings reachable")
	for key in ["master","music","sfx"]:
		var slider=game.view.overlay.get_node("Volume_"+key)
		slider.value=0.25
	check(game.music.starts==starts,"settings never restarts music")
	await shot("audio-settings")
	game.view.handle_back()
	await process_frame
	await process_frame
	game.open_portals()
	await process_frame
	check(game.view.portal_ui.open_map("laboratory"),"return to next expedition")
	check(game.view.portal_ui.open_preview("laboratory","lab_02"),"second expedition now unlocked")
	check(game.progression.balance()==5,"full loop never repeats reward")
	clean_ui(game.view.portal_ui.preview)
	game.free()
	print("Core loop UI checks: %d; failures: %d; renderer: %s" % [checks,failures,DisplayServer.get_name()])
	quit(1 if failures else 0)