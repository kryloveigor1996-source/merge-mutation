extends SceneTree
const Art = preload("res://scripts/mutant_art.gd")
const Scene = preload("res://scenes/main.tscn")
var checks := 0
var failures := 0
var levels: Array[int] = [2,3]
var save_filename := "mutant_sprites_test_save.json"
var suite_label := "Level 2/3 sprite checks"
const REWARDS := {2:30,3:45,4:60,5:75,6:90}

func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		printerr("FAIL: ",message)

func fits_cell(bounds: Rect2i,cell_size: int,lifted: bool,level: int) -> bool:
	var visible := Art.Sizes.visible_rect(level,Rect2(bounds))
	# 1.20 exceeds the selection Tween's 1.17 target and covers its back-ease overshoot.
	var transform := Transform2D(-0.09 if lifted else 0.0,Vector2.ONE*(1.20 if lifted else 1.0),0,Vector2.ONE*cell_size*0.5)
	var allowance: float = Art.Sizes.PICK_OVERHANG if lifted else Art.Sizes.IDLE_OVERHANG
	for point in [visible.position,Vector2(visible.end.x,visible.position.y),visible.end,Vector2(visible.position.x,visible.end.y)]:
		if not Rect2(0,0,cell_size,cell_size).grow(allowance).has_point(transform*point):
			return false
	return true

func _initialize() -> void:
	var options := configuration()
	levels.assign(options.get("levels",[2,3]))
	save_filename=options.get("save_filename","mutant_sprites_test_save.json")
	suite_label=options.get("suite_label","Level 2/3 sprite checks")
	call_deferred("_run")

func configuration() -> Dictionary:
	return {}

func _run() -> void:
	var extents: Array[int] = []
	for level in levels:
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
		var probe := Vector2i(128,24) if level<=3 else Vector2i(24,24)
		check(image.get_pixelv(probe).a==0,"space outside the silhouette is transparent, level %d" % level)
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
				check(fits_cell(bounds,cell_size,lifted,level),"%dpx cell overlap budget, level %d lifted=%s" % [cell_size,level,lifted])
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
	check(extents.size()==levels.size() and extents.all(func(value: int) -> bool: return value==216),"species share the same full-silhouette extent")
	DirAccess.make_dir_recursive_absolute("res://.godot")
	var game = Scene.instantiate()
	game.save_path = "res://.godot/"+save_filename
	root.add_child(game)
	game.view.sound.set_enabled(false)
	game._new_game()
	for target in levels:
		game.cells.fill(0)
		game.cells[0]=target-1
		game.cells[1]=target-1
		game.view.rebuild()
		var before_coins: int = game.coins
		game._press(game.view.cell_center(0))
		game._release(game.view.cell_center(1))
		check(game.cells[1]==target and game.coins==before_coins+REWARDS[target],"merge creates level %d with existing reward" % target)
		check(game.view.creatures[1].texture.resource_path==Art.SPRITES[target],"merge result shows level-%d PNG" % target)
	game.view.show_panel("collection")
	check(is_instance_valid(game.view.overlay),"collection opens with new art")
	game.view.close_panel()
	game._save_game()
	var saved_coins: int = game.coins
	game.cells.fill(0)
	game.coins=0
	check(game._load_game() and game.cells[1]==levels.back() and game.coins==saved_coins,"progress remains compatible")
	await create_timer(0.9).timeout
	game.free()
	DirAccess.remove_absolute("res://.godot/"+save_filename)
	print("%s: %d; failures: %d" % [suite_label,checks,failures])
	quit(1 if failures else 0)
