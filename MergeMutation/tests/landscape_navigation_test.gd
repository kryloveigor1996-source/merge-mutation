extends "res://tests/landscape_ui_test.gd"
const Unit=preload("res://tests/mutation_undo_test.gd")
func bounds(node: Node) -> void:
	if node is Control and not node.is_visible_in_tree(): return
	if node is Button:
		var rect:=Rect2(node.get_global_transform_with_canvas()*Vector2.ZERO,node.size*node.get_global_transform_with_canvas().get_scale())
		check(Rect2(Vector2.ZERO,Vector2(root.size)).grow(2).encloses(rect),"visible button inside viewport: "+str(node.name))
	if node is ScrollContainer: return
	for child in node.get_children(): bounds(child)
func run() -> void:
	game=Scene.instantiate()
	game.save_path="res://.godot/landscape-navigation-save.json"
	DirAccess.remove_absolute(game.save_path)
	root.size=Vector2i(960,540)
	root.add_child(game)
	game.view.sound.set_enabled(false)
	await process_frame
	for ratio in [Vector2i(960,540),Vector2i(1080,540),Vector2i(1170,540),Vector2i(1200,540),Vector2i(960,600)]:
		root.size=ratio
		await process_frame
		game.view.layout()
		bounds(game.view)
		for panel in ["collection","species","settings","levels"]:
			game.view.show_panel(panel)
			await process_frame
			bounds(game.view.overlay)
			game.view.close_panel()
		var hub=game.view.portal_ui
		hub.open_hub("laboratory")
		bounds(hub)
		hub.open_map("laboratory")
		await process_frame
		bounds(hub)
		hub.open_preview("laboratory","lab_01")
		await process_frame
		bounds(hub.preview)
		press_button(hub.preview.get_node("PreviewClose"),true)
		check(hub.preview==null,"preview native close at aspect "+str(ratio))
		hub.close_to_lab()
		game.view.show_story("intro")
		await process_frame
		bounds(game.view.story_screen)
		press_button(game.view.story_screen.get_node("StorySkip"))
		check(game.view.story_screen==null,"story native skip")
		game.view.open_experiment()
		var trial=game.view.experiment_ui
		await process_frame
		bounds(trial)
		trial.start_trial(8)
		await process_frame
		bounds(trial)
		tap(trial,trial.center(0))
		tap(trial,trial.center(10))
		await create_timer(0.3).timeout
		check(trial.session.moves_used==2,"actual corridor at aspect "+str(ratio))
		press_button(trial.get_node("ExperimentUndo"))
		await create_timer(0.3).timeout
		check(trial.session.moves_used==0,"undo at aspect")
		trial.exit_experiment()
		game.view.open_complex()
		var ui=game.view.complex_ui
		await process_frame
		bounds(ui)
		ui.navigate_to_floor("floor_01",false)
		await process_frame
		var room: Rect2=ui.registry.room_rects.habitat_horn
		var point: Vector2=room.get_center()-Vector2(0,ui.scroll.scroll_vertical)+ui.viewport_rect().position
		tap(ui,point)
		check(is_instance_valid(ui.detail),"native room entry at aspect "+str(ratio))
		if is_instance_valid(ui.detail):
			bounds(ui.detail)
			press_button(ui.detail.get_node("HabitatDemo"))
			await process_frame
			bounds(ui.detail.stage_menu)
			ui.back()
			check(ui.detail.stage_menu==null,"back closes compact stage menu first")
			press_button(ui.detail.get_node("HabitatBack"),true)
			check(ui.detail==null,"native habitat return")
		var offset: float=ui.offset
		drag(ui,Vector2(730,400),Vector2(730,220))
		check(ui.offset>offset and ui.detail==null,"touch complex scroll without entering room")
		ui.stop_motion()
		ui.show_lift()
		await process_frame
		bounds(ui.modal)
		press_button(ui.modal.get_node("ComplexLiftClose"))
		check(ui.modal==null,"native lift return")
		ui.show_lift()
		await process_frame
		tap(ui.modal,Vector2(620,262),true)
		await create_timer(0.3).timeout
		check(ui.modal==null and ui.current_floor_id=="floor_02","native lift selects a floor")
		press_button(ui.get_node("ComplexBack"))
		check(not is_instance_valid(ui) or ui.is_queued_for_deletion(),"native complex return")
	root.size=Vector2i(960,540)
	await process_frame
	game.view.layout()
	# The sandbox is isolated from all exhibition and navigation screens.
	# Journey hint flags may be recorded by existing navigation, as before.
	check(game.coins==100 and game.merges==0,"navigation grants no rewards")
	var proofs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/campaign_solutions.json"))
	for number in range(1,11):
		check(game.start_level(number,false),"campaign unlocked")
		await process_frame
		bounds(game.view)
		if number in [1,5,10]: await shot("campaign-%d" % number)
		for action in proofs[str(number)].actions:
			if action.kind=="spawn": press_button(game.view.create_button,number%2==0)
			else: drag(game.view,L.center(int(action.source)),L.center(int(action.index)),number%2==0)
			await create_timer(0.22).timeout
		check(game.campaign.status=="won","native campaign win "+str(number))
		check(game.view.panel_kind=="result","result visible")
		await process_frame
		bounds(game.view.overlay)
		if number==10: await shot("campaign-result")
		game.view.close_panel()
	game.start_level(1,true)
	await process_frame
	press_button(game.view.teleport_button)
	check(game.teleport_mode,"native teleporter toggle")
	drag(game.view,L.center(6),L.center(9))
	check(game.campaign.boosters.remaining("teleporter")==0,"teleporter via landscape board")
	game.leave_campaign()
	var coins: int=game.coins
	game.start_level(1,false)
	await process_frame
	for action in proofs["1"].actions:
		if action.kind=="spawn": press_button(game.view.create_button)
		else: drag(game.view,L.center(int(action.source)),L.center(int(action.index)))
	check(game.coins==coins and game.last_reward.coins==0,"campaign repeat no rewards")
	game.leave_campaign()
	game.view.show_panel("settings")
	await process_frame
	game.reset_dialog.dialog_text="Тест: отмена сброса"
	game.reset_dialog.popup_centered()
	await process_frame
	await shot("reset-dialog")
	check(game.reset_dialog.visible and game.reset_dialog.size.y<=540,"confirmation fits")
	game.reset_dialog.hide()
	game.view.close_panel()
	game._save_game()
	var saved:=FileAccess.get_file_as_string(game.save_path)
	var before:=profile()
	game.free()
	game=Scene.instantiate()
	game.save_path="res://.godot/landscape-navigation-save.json"
	root.add_child(game)
	check(JSON.stringify(JSON.parse_string(profile()),"",true)==JSON.stringify(JSON.parse_string(before),"",true) and FileAccess.get_file_as_string(game.save_path)==saved,"v2 saved progress survives reload")
	game.free()
	print("Landscape navigation checks: %d; failures: %d; renderer: %s" % [checks,failures,DisplayServer.get_name()])
	quit(1 if failures else 0)
