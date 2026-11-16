extends SceneTree
const Catalog = preload("res://scripts/mutant_catalog.gd")
## Real GPU cell captures on five backgrounds; disposable save only.
const Scene = preload("res://scenes/main.tscn")
const Art = preload("res://scripts/mutant_art.gd")
var captured_levels: Array[int] = [1,2,3]
var output_prefix := "mutants"
var save_filename := "mutants_capture_save.json"
var tile_size := 64
var dense := false
var capture_collection := false

func _initialize() -> void:
	var options := configuration()
	captured_levels.assign(options.get("levels",[1,2,3]))
	output_prefix=options.get("output_prefix","mutants")
	save_filename=options.get("save_filename","mutants_capture_save.json")
	tile_size=options.get("tile_size",64)
	dense=options.get("dense",false)
	capture_collection=options.get("capture_collection",false)
	call_deferred("_capture")

func configuration() -> Dictionary:
	return {}

func _capture() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("Capture needs a graphics device.")
		quit(1)
		return
	root.size = Vector2i(360,720)
	DirAccess.make_dir_recursive_absolute("res://.godot")
	var game = Scene.instantiate()
	game.save_path = "res://.godot/"+save_filename
	root.add_child(game)
	game.view.sound.set_enabled(false)
	game._new_game()
	game.cells.fill(null)
	for row in [1,3,5]:
		for column in range(3):
			var group_index := floori(float(row)/2)
			game.cells[row*5+column+1]=Catalog.make(Catalog.legacy_id(captured_levels[(group_index*3+column)%captured_levels.size()]))
	if dense:
		for index in range(30):
			game.cells[index]=Catalog.make(Catalog.legacy_id(captured_levels[index%captured_levels.size()]))
	for id in Catalog.ids(): game.unlock(Catalog.make(id))
	game.view.rebuild()
	var viewports: Array[SubViewport] = []
	for level in captured_levels:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(tile_size,tile_size)
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		viewports.append(viewport)
		var art := Art.new()
		art.setup(level)
		art.position = Vector2.ONE*tile_size*0.5
		viewport.add_child(art)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var field_error := root.get_texture().get_image().save_png("res://.godot/"+output_prefix+"-field.png")
	var collection_error := OK
	if capture_collection:
		game.view.show_panel("collection")
		await process_frame
		await process_frame
		for scroll: ScrollContainer in game.view.overlay.find_children("*","ScrollContainer",true,false):
			scroll.scroll_vertical=10000
		await process_frame
		await RenderingServer.frame_post_draw
		collection_error=root.get_texture().get_image().save_png("res://.godot/"+output_prefix+"-collection.png")
	var proof := Image.create(5*tile_size,tile_size*captured_levels.size(),false,Image.FORMAT_RGBA8)
	var colors := [Color("fff8de"),Color("25465a"),Color("b5e9ee"),Color("e055b7"),Color("c8c8c8")]
	for y in range(proof.get_height()):
		for x in range(proof.get_width()):
			var color: Color = colors[floori(float(x)/tile_size)]
			if x>=4*tile_size:
				color = Color("efefef") if ((x>>3)+(y>>3))%2==0 else Color("b0b0b0")
			proof.set_pixel(x,y,color)
	var fits := true
	for index in range(captured_levels.size()):
		var image := viewports[index].get_texture().get_image()
		var bounds := image.get_used_rect()
		var cell_fits := bounds.position.x>0 and bounds.position.y>0 and bounds.end.x<tile_size and bounds.end.y<tile_size
		fits = fits and cell_fits
		print("Level ",captured_levels[index]," capture=",tile_size," alpha bounds=",bounds," unclipped=",cell_fits)
		for column in range(5):
			proof.blend_rect(image,Rect2i(0,0,tile_size,tile_size),Vector2i(column*tile_size,index*tile_size))
	var proof_error := proof.save_png("res://.godot/"+output_prefix+"-cell-proof.png")
	game.free()
	for viewport in viewports:
		viewport.free()
	DirAccess.remove_absolute("res://.godot/"+save_filename)
	print("Mutant GPU capture: ",field_error,"; proof: ",proof_error)
	quit(0 if field_error==OK and proof_error==OK and collection_error==OK and fits else 1)
