extends SceneTree
const Scene = preload("res://scenes/main.tscn")
var game: Control
var errors := 0
func _initialize() -> void:
	call_deferred("run")
func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	errors+=root.get_texture().get_image().save_png("res://.godot/tactical-"+name+".png")
func run() -> void:
	if DisplayServer.get_name()=="headless":
		quit(1)
		return
	root.size=Vector2i(360,720)
	game=Scene.instantiate()
	game.save_path="res://.godot/tactical_capture_save.json"
	if FileAccess.file_exists(game.save_path): DirAccess.remove_absolute(game.save_path)
	root.add_child(game)
	game.view.sound.set_enabled(false)
	# Disposable illustrative account; never the user's campaign/save.
	for number in range(1,10): game.campaign_progress.finish(number)
	game.start_level(2)
	game._press(game.view.cell_center(6))
	await create_timer(0.22).timeout
	await shot("neighbours")
	game._release(game.view.cell_center(8))
	await shot("forbidden")
	game.start_level(6)
	await shot("level-06")
	game.start_level(8)
	await shot("level-08")
	game.toggle_teleporter()
	game._press(game.view.cell_center(6))
	await create_timer(0.22).timeout
	await shot("teleporter")
	game._cancel_drag()
	game.start_level(9)
	game._spawn()
	game._spawn()
	await create_timer(0.48).timeout
	await shot("level-09")
	game.start_level(10,false)
	await shot("level-10")
	var solutions: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/campaign_solutions.json"))
	for action in solutions["10"].actions:
		if action.kind=="spawn": game._spawn()
		else:
			game._press(game.view.cell_center(int(action.source)))
			game._release(game.view.cell_center(int(action.index)))
	await create_timer(0.5).timeout
	await shot("victory")
	var won: bool=game.campaign.status=="won"
	game.free()
	DirAccess.remove_absolute("res://.godot/tactical_capture_save.json")
	print("Tactical GPU captures: errors=",errors,"; zero-tool level 10 victory=",won)
	quit(0 if errors==0 and won else 1)
