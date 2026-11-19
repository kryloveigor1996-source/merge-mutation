extends "res://tests/landscape_ui_test.gd"
const G=preload("res://scripts/evolution_geometry.gd")
func shot(id: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await create_timer(0.15).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://.godot/pr22-"+id+".png")==OK,"capture "+id)
func bounds(node: Node) -> void:
	if node is Control and not node.is_visible_in_tree(): return
	if node is Button or node is HSlider or node is LineEdit:
		var r=Rect2(node.get_global_transform_with_canvas()*Vector2.ZERO,node.size*node.get_global_transform_with_canvas().get_scale())
		var canvas=Rect2(Vector2.ZERO,game.size)
		check(canvas.grow(2).encloses(r),"native bounds "+str(node.name))
	if node is ScrollContainer: return
	for child in node.get_children(): bounds(child)
func verify_portals(portal,tall: bool) -> void:
	for repeat in range(20):
		drag(portal,Vector2(380,380),Vector2(150,380),repeat%2==0)
		check(portal.page=="hub" and not portal.entering,"rapid swipe never enters world")
	portal.open_hub("laboratory")
	var touch=InputEventScreenTouch.new()
	touch.position=portal.get_global_transform_with_canvas()*Vector2(270,380); touch.pressed=true
	root.push_input(touch,true)
	touch=touch.duplicate(); touch.pressed=false; touch.canceled=true
	root.push_input(touch,true)
	check(not portal.entering,"canceled portal touch cannot enter world")
	if DisplayServer.get_name()=="headless": return
	var sentinel=ColorRect.new()
	sentinel.size=G.design(tall); sentinel.z_index=21; sentinel.color=Color.MAGENTA
	sentinel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	game.view.add_child(sentinel)
	await process_frame
	await RenderingServer.frame_post_draw
	var before=root.get_texture().get_image()
	sentinel.color=Color.GREEN
	await process_frame
	await RenderingServer.frame_post_draw
	var after=root.get_texture().get_image()
	for p in [Vector2i(3,3),Vector2i(root.size.x-4,3),Vector2i(3,root.size.y-4),root.size-Vector2i(4,4)]:
		check(before.get_pixelv(p).is_equal_approx(after.get_pixelv(p)),"portal surface stays opaque during animation")
	sentinel.queue_free()
func run() -> void:
	root.size=Vector2i(960,540)
	game=Scene.instantiate()
	game.save_path="res://.godot/pr22-ui-"+str(Time.get_ticks_usec())+".json"
	game.audio_settings_path=game.save_path+".cfg"
	root.add_child(game)
	game.music.handle_lifecycle=false
	game.music.set_volume("master",0)
	await process_frame
	await process_frame
	press_button(game.view.story_screen.get_node("StorySkip"))
	await process_frame
	for tall in [false,true,false]:
		game.view.set_portrait(tall)
		root.size=Vector2i(G.design(tall))
		await process_frame
		await process_frame
		game.view.layout()
		var suffix="portrait" if tall else "landscape"
		game.view.open_complex()
		await process_frame
		var ui=game.view.complex_ui
		check(is_instance_valid(ui),"native complex "+suffix)
		bounds(ui)
		check(ui.registry.floors.size()==5 and ui.registry.habitats.size()==7,"all projected floors/rooms remain valid")
		check(not ui.get_node("ComplexTop").get_rect().intersects(ui.get_node("ComplexBottom").get_rect()),"floor controls do not overlap")
		await shot(suffix+"-complex")
		press_button(ui.chrome.get_node("Nav_portals"))
		await process_frame
		var portal=game.view.portal_ui
		bounds(portal)
		await verify_portals(portal,tall)
		await shot(suffix+"-portals")
		check(portal.open_map("laboratory"),"native laboratory map")
		await process_frame
		bounds(portal)
		await shot(suffix+"-map")
		check(portal.open_preview("laboratory","lab_01"),"native preview")
		bounds(portal.preview)
		await shot(suffix+"-preview")
		game.view.handle_back()
		portal.open_hub()
		await process_frame
		press_button(portal.get_node("EvolutionEntry"),true)
		await process_frame
		var screen=game.view.experiment_ui
		check(is_instance_valid(screen),"new experiment entry "+suffix)
		if not is_instance_valid(screen): quit(1); return
		bounds(screen)
		check(screen.start_trial(4),"new trial starts")
		await process_frame
		bounds(screen)
		await shot(suffix+"-trial")
		game.view.show_panel("settings")
		await process_frame
		bounds(game.view.overlay)
		var ratios=[Vector2i(540,960),Vector2i(540,1080),Vector2i(540,1170),Vector2i(540,1200),Vector2i(600,960)] if tall else [Vector2i(960,540),Vector2i(1080,540),Vector2i(1170,540),Vector2i(1200,540),Vector2i(960,600)]
		for ratio in ratios:
			root.size=ratio
			await process_frame
			await process_frame
			game.view.layout()
			bounds(game.view.overlay)
			check(G.fit(Rect2(12,18,ratio.x-24,ratio.y-36),tall).size.x>0,"safe-area fit")
		root.size=Vector2i(G.design(tall))
		await process_frame
		await process_frame
		game.view.layout()
		check(game.view.overlay.get_node("OpaqueSettingsBackground").color.a==1,"settings opaque")
		await shot(suffix+"-settings")
		game.view.handle_back()
		await process_frame
		screen.leave()
		await process_frame
		game.open_portals()
		await process_frame
		press_button(game.view.portal_ui.get_node("SandboxZone"))
		await process_frame
		bounds(game.view)
		await shot(suffix+"-sandbox")
		var coins=game.coins
		press_button(game.view.create_button)
		check(game.coins==coins-10,"native sandbox preserves creation price")
		press_button(game.view.experiment_button)
		await process_frame
		var legacy=game.view.experiment_ui
		check(is_instance_valid(legacy) and legacy.start_trial(1),"old tactical experiments retained")
		bounds(legacy)
		await shot(suffix+"-old-tactical")
		game.view.close_navigation()
		game.view.open_complex()
		await process_frame
		press_button(game.view.complex_ui.chrome.get_node("Nav_bestiary"))
		await process_frame
		check(is_instance_valid(game.view.overlay),"native archive")
		bounds(game.view.overlay)
		await shot(suffix+"-bestiary")
		game.view.handle_back()
		await process_frame
	game.free()
	print("Evolution layout checks: %d; failures: %d; renderer: %s" % [checks,failures,DisplayServer.get_name()])
	quit(1 if failures else 0)