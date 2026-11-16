extends SceneTree
## Real GPU cell captures on five backgrounds; disposable save only.
const Scene = preload("res://scenes/main.tscn")
const Art = preload("res://scripts/mutant_art.gd")

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("Capture needs a graphics device.")
		quit(1)
		return
	root.size = Vector2i(360,720)
	DirAccess.make_dir_recursive_absolute("res://.godot")
	var game = Scene.instantiate()
	game.save_path = "res://.godot/mutants_capture_save.json"
	root.add_child(game)
	game.view.sound.set_enabled(false)
	game._new_game()
	game.cells.fill(0)
	for row in [1,3,5]:
		for level in [1,2,3]:
			game.cells[row*5+level]=level
	game.highest=3
	game.view.rebuild()
	var viewports: Array[SubViewport] = []
	for level in [1,2,3]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(64,64)
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		viewports.append(viewport)
		var art := Art.new()
		art.setup(level)
		art.position = Vector2(32,32)
		viewport.add_child(art)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var field_error := root.get_texture().get_image().save_png("res://.godot/mutants-field.png")
	var proof := Image.create(320,192,false,Image.FORMAT_RGBA8)
	var colors := [Color("fff8de"),Color("25465a"),Color("b5e9ee"),Color("e055b7"),Color("c8c8c8")]
	for y in range(192):
		for x in range(320):
			var color: Color = colors[x>>6]
			if x>=256:
				color = Color("efefef") if ((x>>3)+(y>>3))%2==0 else Color("b0b0b0")
			proof.set_pixel(x,y,color)
	var fits := true
	for index in range(3):
		var image := viewports[index].get_texture().get_image()
		var bounds := image.get_used_rect()
		var cell_fits := bounds.position.x>0 and bounds.position.y>0 and bounds.end.x<64 and bounds.end.y<64
		fits = fits and cell_fits
		print("Level ",index+1," 64px alpha bounds=",bounds," fits=",cell_fits)
		for column in range(5):
			proof.blend_rect(image,Rect2i(0,0,64,64),Vector2i(column*64,index*64))
	var proof_error := proof.save_png("res://.godot/mutants-cell-proof.png")
	game.free()
	for viewport in viewports:
		viewport.free()
	DirAccess.remove_absolute("res://.godot/mutants_capture_save.json")
	print("Mutant GPU capture: ",field_error,"; proof: ",proof_error)
	quit(0 if field_error==OK and proof_error==OK and fits else 1)
