extends SceneTree
const Art = preload("res://scripts/mutant_art.gd")
const Scene = preload("res://scenes/main.tscn")
var checks := 0
var failures := 0

func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		printerr("FAIL: ",message)

func fits_cell(bounds: Rect2i,cell_size: int,lifted: bool) -> bool:
	var visible := Rect2(Vector2(bounds.position)/256*56-Vector2(28,28),Vector2(bounds.size)/256*56)
	# 1.20 exceeds the selection Tween's 1.17 target and covers its back-ease overshoot.
	var transform := Transform2D(-0.09 if lifted else 0.0,Vector2.ONE*(1.20 if lifted else 1.0),0,Vector2.ONE*cell_size*0.5)
	for point in [visible.position,Vector2(visible.end.x,visible.position.y),visible.end,Vector2(visible.position.x,visible.end.y)]:
		if not Rect2(0,0,cell_size,cell_size).has_point(transform*point):
			return false
	return true

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var extents: Array[int] = []
	for level in [2,3]:
		var path := "res://assets/mutants/mutant_lv%d.png" % level
		var bytes := FileAccess.get_file_as_bytes(path)
		check(bytes.size()>1000,"PNG present for level %d" % level)
		if bytes.size()<26:
			continue
		check(bytes[24]==8 and bytes[25]==6,"8-bit RGBA PNG, level %d" % level)
		var image := Image.new()
		check(image.load_png_from_buffer(bytes)==OK,"PNG decodes, level %d" % level)
		check(image.get_size()==Vector2i(256,256) and image.get_format()==Image.FORMAT_RGBA8,"256x256 RGBA8, level %d" % level)
		var bounds := image.get_used_rect()
		extents.append(maxi(bounds.size.x,bounds.size.y))
		check(bounds.position.x>=16 and bounds.position.y>=16 and bounds.end.x<=240 and bounds.end.y<=240,"safe transparent padding, level %d" % level)
		var empty_border := true
		var transparent := 0
		var partial := 0
		for y in range(256):
			for x in range(256):
				var alpha := image.get_pixel(x,y).a
				if alpha==0:
					transparent+=1
				elif alpha<1:
					partial+=1
				if (x<16 or y<16 or x>=240 or y>=240) and alpha!=0:
					empty_border = false
		check(empty_border,"real alpha-zero border, level %d" % level)
		check(transparent>25000 and partial>100,"transparent exterior/antialiasing, level %d" % level)
		check(image.get_pixel(128,24).a==0,"space between horns/antennae is transparent, level %d" % level)
		var art := Art.new()
		art.setup(level)
		root.add_child(art)
		check(art.texture!=null and art.texture.resource_path==path,"correct texture selected, level %d" % level)
		check(art.texture.get_image().has_mipmaps(),"imported mipmaps, level %d" % level)
		check(art.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,"same filtering as slime, level %d" % level)
		var settings := ConfigFile.new()
		check(settings.load(path+".import")==OK and settings.get_value("params","compress/mode")==0,"lossless import, level %d" % level)
		for cell_size in [62,64]:
			for lifted in [false,true]:
				check(fits_cell(bounds,cell_size,lifted),"%dpx cell, level %d lifted=%s" % [cell_size,level,lifted])
		art.pop()
		await create_timer(0.48).timeout
		check(art.scale.is_equal_approx(Vector2.ONE),"spawn animation retained, level %d" % level)
		art.lift()
		await create_timer(0.22).timeout
		check(art.scale.x>1.1,"selection animation retained, level %d" % level)
		art.settle()
		await create_timer(0.22).timeout
		check(art.scale.is_equal_approx(Vector2.ONE),"settle animation retained, level %d" % level)
		art.free()
	check(extents==[216,216],"both species have the same full-silhouette extent")
	DirAccess.make_dir_recursive_absolute("res://.godot")
	var game = Scene.instantiate()
	game.save_path = "res://.godot/mutant_sprites_test_save.json"
	root.add_child(game)
	game.view.sound.set_enabled(false)
	game._new_game()
	game.cells.fill(0)
	game.cells[0]=1
	game.cells[1]=1
	game.view.rebuild()
	game._press(game.view.cell_center(0))
	game._release(game.view.cell_center(1))
	check(game.cells[1]==2 and game.coins==130,"1+1 makes level 2, existing reward")
	check(game.view.creatures[1].texture.resource_path==Art.SPRITES[2],"merge result shows level-2 PNG")
	game.cells[0]=2
	game.view.rebuild()
	game._press(game.view.cell_center(0))
	game._release(game.view.cell_center(1))
	check(game.cells[1]==3 and game.coins==175,"2+2 makes level 3, existing reward")
	check(game.view.creatures[1].texture.resource_path==Art.SPRITES[3],"merge result shows level-3 PNG")
	game.view.show_panel("collection")
	check(is_instance_valid(game.view.overlay),"collection opens with new art")
	game.view.close_panel()
	game._save_game()
	check(game._load_game() and game.cells[1]==3 and game.coins==175,"progress remains compatible")
	await create_timer(0.9).timeout
	game.free()
	DirAccess.remove_absolute("res://.godot/mutant_sprites_test_save.json")
	print("Level 2/3 sprite checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
