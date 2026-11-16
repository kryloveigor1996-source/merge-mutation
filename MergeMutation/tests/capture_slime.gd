extends SceneTree
## GPU QA with an isolated save; writes PNG previews, never player progress.
const Scene = preload("res://scenes/main.tscn")
const Art = preload("res://scripts/mutant_art.gd")

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("Slime capture requires a graphics device.")
		quit(1)
		return
	root.size = Vector2i(360,720)
	DirAccess.make_dir_recursive_absolute("res://.godot")
	var game = Scene.instantiate()
	game.save_path = "res://.godot/slime_preview_save.json"
	root.add_child(game)
	game.view.sound.set_enabled(false)
	game._new_game()
	game.cells[12]=2
	game.highest=2
	game.view.rebuild()
	var cell := SubViewport.new()
	cell.size = Vector2i(64,64)
	cell.transparent_bg = true
	cell.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(cell)
	var art := Art.new()
	art.setup(1)
	art.position = Vector2(32,32)
	cell.add_child(art)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://.godot/slime-field.png")
	var small := cell.get_texture().get_image()
	var bounds := small.get_used_rect()
	var fits := bounds.position.x>0 and bounds.position.y>0 and bounds.end.x<64 and bounds.end.y<64
	var small_error := small.save_png("res://.godot/slime-cell-64.png")
	# Composite the actual 64px GPU render on contrasting backgrounds for edge QA.
	var proof := Image.create(320,128,false,Image.FORMAT_RGBA8)
	var colors := [Color("fff8de"),Color("25465a"),Color("b5e9ee"),Color("e055b7"),Color("c8c8c8")]
	for y in range(128):
		for x in range(320):
			var color: Color = colors[x>>6]
			if x>=256:
				color = Color("efefef") if ((x>>3)+(y>>3))%2==0 else Color("b0b0b0")
			proof.set_pixel(x,y,color)
	for index in range(5):
		proof.blend_rect(small,Rect2i(0,0,64,64),Vector2i(index*64,32))
	proof.save_png("res://.godot/slime-cell-proof.png")
	game.free()
	cell.free()
	DirAccess.remove_absolute("res://.godot/slime_preview_save.json")
	print("Slime GPU capture: ",error,"; 64px: ",small_error,"; alpha bounds: ",bounds,"; fits: ",fits)
	quit(0 if error==OK and small_error==OK and fits else 1)
