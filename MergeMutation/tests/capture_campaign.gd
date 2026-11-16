extends SceneTree
const Scene = preload("res://scenes/main.tscn")
const Solver = preload("res://tests/campaign_solver.gd")
const Levels = preload("res://scripts/campaign_levels.gd")
var game: Control
var errors := 0
func _initialize() -> void:
	call_deferred("run")
func snapshot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	errors+=root.get_texture().get_image().save_png("res://.godot/campaign-"+name+".png")
func replay(number: int) -> void:
	game.start_level(number)
	for action in Solver.solve(Levels.get_level(number)).actions:
		if action.kind=="spawn": game._spawn()
		else:
			game._press(game.view.cell_center(action.source))
			game._release(game.view.cell_center(action.index))
func run() -> void:
	if DisplayServer.get_name()=="headless":
		quit(1)
		return
	root.size=Vector2i(360,720)
	game=Scene.instantiate()
	game.save_path="res://.godot/campaign_capture_save.json"
	# Always start a disposable, deterministic demo account.
	if FileAccess.file_exists(game.save_path): DirAccess.remove_absolute(game.save_path)
	root.add_child(game)
	game.view.sound.set_enabled(false)
	for number in range(1,4): replay(number)
	game.leave_campaign()
	game.view.show_panel("levels")
	await snapshot("levels")
	game.start_level(4)
	for index in range(4): game._spawn()
	await create_timer(0.5).timeout
	await snapshot("field")
	replay(4)
	await create_timer(0.5).timeout
	await snapshot("victory")
	game.start_level(4)
	game._spawn()
	game._spawn()
	for index in range(12):
		var source := 1 if index%2==0 else 3
		var destination := 3 if index%2==0 else 1
		game._press(game.view.cell_center(source))
		game._release(game.view.cell_center(destination))
	await create_timer(0.5).timeout
	await snapshot("defeat")
	var lost: bool=game.campaign.status=="lost"
	game.free()
	DirAccess.remove_absolute("res://.godot/campaign_capture_save.json")
	print("Campaign GPU capture: errors=",errors,"; real defeat=",lost)
	quit(0 if errors==0 and lost else 1)
