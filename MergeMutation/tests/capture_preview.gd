extends SceneTree
const Catalog = preload("res://scripts/mutant_catalog.gd")
## Optional GPU visual QA. Generates an illustrative cast preview, never player data.
const Scene = preload("res://scenes/main.tscn")

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Preview capture requires a display/rendering device.")
		quit(1)
		return
	root.size = Vector2i(360,720)
	DirAccess.make_dir_recursive_absolute("res://.godot")
	var game = Scene.instantiate()
	game.save_path = "res://.godot/preview_save.json"
	root.add_child(game)
	game.view.sound.set_enabled(false)
	game.cells.fill(null)
	for level in range(1,11):
		game.cells[level-1] = Catalog.make(Catalog.legacy_id(level))
	for index in [16,18,26,28]:
		game.cells[index]=Catalog.make(Catalog.legacy_id(1))
	game.coins=420
	for id in Catalog.ids(): game.unlock(Catalog.make(id))
	game.merges=12
	game.view.rebuild()
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://.godot/v02-preview.png")
	game.view.show_panel("collection")
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var panel_error := root.get_texture().get_image().save_png("res://.godot/v02-collection.png")
	game.free()
	DirAccess.remove_absolute("res://.godot/preview_save.json")
	print("Preview capture: ",error,"; collection: ",panel_error)
	quit(0 if error==OK and panel_error==OK else 1)
