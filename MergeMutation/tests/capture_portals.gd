extends SceneTree
const Scene = preload("res://scenes/main.tscn")
var game: Control
var errors := 0
func _initialize() -> void:
	call_deferred("run")
func shot(name: String) -> void:
	await create_timer(0.25).timeout
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	errors+=root.get_texture().get_image().save_png("res://.godot/portal-"+name+".png")
func run() -> void:
	if DisplayServer.get_name()=="headless":
		quit(1)
		return
	root.size=Vector2i(360,720)
	game=Scene.instantiate()
	game.save_path="res://.godot/portal_capture_save.json"
	if FileAccess.file_exists(game.save_path): DirAccess.remove_absolute(game.save_path)
	root.add_child(game)
	game.view.sound.set_enabled(false)
	game.open_portals()
	await shot("intro")
	game.view.story_screen.complete()
	await shot("hall-lab")
	game.view.portal_ui.open_hub("toxic_swamp")
	await shot("locked")
	game.open_world_map("laboratory")
	await shot("lab-map")
	# Real witness playback earns the unlock: no synthetic completions or stars.
	var proofs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/campaign_solutions.json"))
	for number in range(1,11):
		game.start_level(number,false)
		for action in proofs[str(number)].actions:
			if action.kind=="spawn": game._spawn()
			else:
				game._press(game.view.cell_center(int(action.source)))
				game._release(game.view.cell_center(int(action.index)))
	await shot("activation")
	game.view.story_screen.complete()
	game.open_portals()
	game.view.portal_ui.open_hub("toxic_swamp")
	await shot("open")
	game.view.portal_ui.enter_portal()
	await create_timer(0.65).timeout
	await shot("swamp-map")
	game.view.portal_ui.scroll_by(850)
	await create_timer(0.5).timeout
	await shot("swamp-fog")
	game.open_world_map("laboratory")
	await create_timer(0.2).timeout
	await shot("lab-complete")
	var won: bool=game.campaign_progress.completed.size()==10 and game.campaign_progress.stars==10
	game.free()
	DirAccess.remove_absolute("res://.godot/portal_capture_save.json")
	print("Portal GPU captures: errors=",errors,"; real ten-level completion=",won)
	quit(0 if errors==0 and won else 1)
