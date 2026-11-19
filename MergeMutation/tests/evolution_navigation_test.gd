extends "res://tests/evolution_layout_test.gd"
const ClassicSolver=preload("res://tests/campaign_solver.gd")
const ClassicLevels=preload("res://scripts/campaign_levels.gd")
func run() -> void:
	var path="res://.godot/pr22-nav-"+str(Time.get_ticks_usec())+".json"
	var fixture={"schema_version":2,"coins":777,"merges":42,"cells":[],"discoveries":["slime:1","eyeball:1","horn:1"],"active_species":"slime","campaign":{"version":1,"completed":[1,2,3,4,5,6,7,8,9,10],"claimed":[1,2,3,4,5,6,7,8,9,10],"stars":10}}
	var file=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(fixture)); file.close()
	var old_hash=FileAccess.get_sha256(path)
	game=Scene.instantiate(); game.save_path=path; game.audio_settings_path=path+".cfg"; root.add_child(game)
	game.music.handle_lifecycle=false; game.music.set_volume("master",0)
	game.journey_state.seen.swamp_activation=true
	await process_frame
	await process_frame
	check(not game.write_blocked and game.progression.balance()==63 and game.coins==777,"native game loads and migrates v2")
	check(FileAccess.get_sha256(path+".pre-core-loop-"+old_hash.substr(0,12)+".bak")==old_hash,"native migration keeps original backup")
	for tall in [false,true]:
		game.view.set_portrait(tall); root.size=Vector2i(G.design(tall))
		await process_frame
		await process_frame
		game.view.layout(); game.view.open_complex()
		await process_frame
		var ui=game.view.complex_ui
		check(ui.registry.floors.size()==5 and ui.registry.habitats.size()==7,"complex rooms survive coordinate projection")
		check(ui.open_living("habitat_slime"),"native slime habitat")
		await process_frame
		var detail=ui.detail
		bounds(detail)
		check(is_equal_approx(detail.environment.world.scale.x,detail.environment.world.scale.y),"habitat graphics are not deformed")
		detail.find_resident()
		var marker=detail.room_state.catalog.marker(detail.room_state.catalog.slots.bed,detail.model.registry.world_width)
		detail.environment.set_camera(marker.x-detail.environment.visible_width*.5)
		if not detail.room_state.installed.has("bed"):
			tap(detail.environment,marker*detail.environment.world.scale+detail.environment.world.position)
		else: detail.open_design("bed")
		await process_frame
		check(is_instance_valid(detail.design_panel),"native construction preview")
		bounds(detail.design_panel)
		var balance=game.progression.balance()
		var price=0 if detail.room_state.installed.has("bed") else 3
		await shot(("portrait" if tall else "landscape")+"-construction")
		press_button(detail.confirm_button)
		await process_frame
		check(game.progression.balance()==balance-price,"native installation keeps exact economy")
		await process_frame
		detail.find_resident()
		press_button(detail.get_node("HabitatSettings"))
		await process_frame
		check(is_instance_valid(game.view.overlay),"settings in habitat")
		var elapsed=detail.model.elapsed
		await create_timer(.15).timeout
		check(detail.model.elapsed==elapsed,"settings pauses hidden habitat simulation")
		game.view.handle_back()
		await process_frame
		await process_frame
		check(game.view.complex_ui.detail==detail and detail.environment.is_processing(),"settings preserves and resumes habitat")
		game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		await process_frame
		check(game.music.suspended and not detail.environment.is_processing(),"Android pause handler pauses audio and habitat")
		game._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		await process_frame
		check(not game.music.suspended,"Android resume handler")
		if tall:
			detail.environment.set_camera(0)
			drag(detail.environment,Vector2(400,300),Vector2(150,300))
			check(detail.environment.camera_x>0,"portrait habitat horizontal touch pan")
			detail.find_resident()
		await shot(("portrait" if tall else "landscape")+"-slime-habitat")
		ui.close_living()
		await process_frame
		await process_frame
		check(ui.open_living("habitat_horn"),"native horn habitat")
		await process_frame
		bounds(ui.detail)
		ui.detail.find_resident()
		await shot(("portrait" if tall else "landscape")+"-horn-habitat")
		ui.close_living()
		await process_frame
		await process_frame
		press_button(ui.chrome.get_node("Nav_bestiary"))
		await process_frame
		var archive=game.view.overlay
		archive.show_entry("horn")
		await process_frame
		for child in archive.content.get_children():
			if child is ScrollContainer:
				drag(child,Vector2(180,230),Vector2(180,50))
				await process_frame
				check(child.scroll_vertical>0,"native dossier touch scrolling")
				child.scroll_vertical=0
		bounds(archive)
		await shot(("portrait" if tall else "landscape")+"-known-bestiary")
		var chrome=null
		for child in archive.get_children():
			if child.has_node("AppSettings"): chrome=child
		press_button(chrome.get_node("AppSettings"))
		await process_frame
		press_button(game.view.overlay.get_node("TutorialToggle"))
		await process_frame
		await process_frame
		check(game.view.panel_kind=="settings","rebuilding settings never navigates away")
		game.view.handle_back()
		await process_frame
		await process_frame
		check(game.view.panel_kind=="collection","settings returns to archive")
		game.view.handle_back()
		await process_frame
		# The original campaign still runs with new tap/drag controls.
		game.start_level(10,false)
		var proof=ClassicSolver.solve(ClassicLevels.get_level(10))
		var index=0
		for action in proof.actions:
			if action.kind=="spawn": press_button(game.view.create_button)
			elif index%2==0:
				tap(game.view,game.view.cell_center(action.source))
				tap(game.view,game.view.cell_center(action.index))
			else: drag(game.view,game.view.cell_center(action.source),game.view.cell_center(action.index),true)
			await process_frame
			index+=1
		check(game.campaign.status=="won","old level 10 wins with new controls")
		if game.campaign.status!="won": quit(1); return
		bounds(game.view.overlay)
		var retry=game.view.overlay.get_node("RetryLevel")
		var home=game.view.overlay.get_node("ReturnComplex")
		check(retry.size.y==44 and retry.size.x<home.size.x,"replay is secondary on final victory")
		await shot(("portrait" if tall else "landscape")+"-classic-victory")
		press_button(home)
		await process_frame
		check(game.progression.balance()==60 and game.coins==777,"repeated classic victory has no additional rewards")
	game.view.preferences.hints=true
	game.view.preferences.shown.clear(); game.view.preferences.learned.clear()
	game.view.open_evolution()
	var screen=game.view.experiment_ui
	screen.start_trial(10)
	var hidden_hint={}
	for hint in game.view.tutorial.requests:
		if hint.id=="mechanism_hidden": hidden_hint=hint
	check(not hidden_hint.is_empty() and hidden_hint.target.get_center().is_equal_approx(G.center(10,game.view.portrait_mode)),"hidden-mechanism hint highlights Eyeball, not the secret cell")
	check(hidden_hint.get("scope","")=="evolution_10","mechanism hints are scoped to current attempt")
	await process_frame
	check(game.view.tutorial.active_id!="" or not game.view.tutorial.requests.is_empty(),"context tutorial appears")
	check(screen.session.moves_used==0,"hint does not play a solution")
	game.view.preferences.hints=false
	await process_frame
	check(game.view.tutorial.active_id=="" and game.view.tutorial.requests.is_empty(),"tutorial can be disabled without blocking gameplay")
	game.view.preferences.portrait=true; game.view.preferences.save()
	game.free()
	game=Scene.instantiate(); game.save_path=path; game.audio_settings_path=path+".cfg"; root.add_child(game)
	await process_frame
	check(game.view.portrait_mode and game.progression.balance()==60 and game.coins==777,"portrait restart preserves preferences and profile")
	game.free()
	print("Evolution navigation checks: %d; failures: %d; renderer: %s" % [checks,failures,DisplayServer.get_name()])
	quit(1 if failures else 0)