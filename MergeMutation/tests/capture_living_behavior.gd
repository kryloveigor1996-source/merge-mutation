extends SceneTree
const Scene=preload("res://scenes/main.tscn")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(360,720)
	var game=Scene.instantiate()
	game.save_path="res://.godot/living-movie-save.json"
	root.add_child(game)
	game.view.sound.set_enabled(false)
	game.view.open_complex()
	var ui=game.view.complex_ui
	ui.navigate_to_floor("floor_01",false)
	ui.open_living("habitat_horn")
	var state=ui.detail.model
	state.rng.seed=26
	state.set_stage(3)
	state.request_ram()
	await create_timer(3.4).timeout
	if state.hit_count<1:
		printerr("Movie training did not complete")
		quit(1)
		return
	state.react()
	await create_timer(1.1).timeout
	state.walk_to(110)
	await create_timer(1.2).timeout
	game.free()
	quit()
