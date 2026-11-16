extends SceneTree
const Scene = preload("res://scenes/main.tscn")
const Catalog = preload("res://scripts/mutant_catalog.gd")
const Art = preload("res://scripts/mutant_art.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless":
		quit(1)
		return
	root.size=Vector2i(360,720)
	var game = Scene.instantiate()
	game.save_path="res://.godot/species_capture_save.json"
	root.add_child(game)
	game.view.sound.set_enabled(false)
	game._new_game()
	game.cells.fill(null)
	var ids := Catalog.ids()
	for index in range(30):
		game.cells[index]=Catalog.make(ids[index%10],index/10+1)
	for id in ids:
		for stage in range(1,6):
			game.unlock(Catalog.make(id,stage))
	game.active_species="wing"
	game.coins=420
	game.view.rebuild()
	var viewports: Array[SubViewport]=[]
	for id in ids:
		for stage in range(1,6):
			var viewport := SubViewport.new()
			viewport.size=Vector2i(112,112)
			viewport.transparent_bg=true
			viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
			root.add_child(viewport)
			var art := Art.new()
			art.setup_form(Catalog.make(id,stage))
			art.position=Vector2(56,56)
			viewport.add_child(art)
			viewports.append(viewport)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var errors := root.get_texture().get_image().save_png("res://.godot/species-field.png")
	var sheet := Image.create(560,1120,false,Image.FORMAT_RGBA8)
	sheet.fill(Color("d2e9e5"))
	var unclipped := true
	for index in range(50):
		var image := viewports[index].get_texture().get_image()
		var bounds := image.get_used_rect()
		unclipped=unclipped and bounds.position.x>0 and bounds.position.y>0 and bounds.end.x<112 and bounds.end.y<112
		sheet.blend_rect(image,Rect2i(0,0,112,112),Vector2i(index%5*112,index/5*112))
	errors+=sheet.save_png("res://.godot/species-50-forms.png")
	game.view.collection_species="eyeball"
	game.view.show_panel("collection")
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	errors+=root.get_texture().get_image().save_png("res://.godot/species-collection.png")
	game.view.close_panel()
	game.view.show_panel("species")
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	errors+=root.get_texture().get_image().save_png("res://.godot/species-selector.png")
	game.free()
	for viewport in viewports:
		viewport.free()
	DirAccess.remove_absolute("res://.godot/species_capture_save.json")
	print("GPU capture: errors=",errors,"; 50 silhouettes unclipped=",unclipped)
	quit(0 if errors==0 and unclipped else 1)
