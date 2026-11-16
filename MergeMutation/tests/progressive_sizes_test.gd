extends SceneTree
const Catalog = preload("res://scripts/mutant_catalog.gd")
const Scene = preload("res://scenes/main.tscn")
const Art = preload("res://scripts/mutant_art.gd")
const Sizes = preload("res://scripts/mutant_sizes.gd")
var checks := 0
var failures := 0

func check(condition: bool,label: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		printerr("FAIL: ",label)

func inside_ui_safe(node: Art) -> bool:
	return Sizes.PLAY_AREA.grow(0.01).encloses(node.transform*node.render_bounds())

func collect_art(node: Node,result: Array[Art]) -> void:
	if node is Art:
		result.append(node)
	for child in node.get_children():
		collect_art(child,result)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var previous_size := 0.0
	for level in range(1,11):
		var art := Art.new()
		art.setup(level)
		check(Sizes.pixels(level)>previous_size and Sizes.pixels(level)<=86,"progressive size within neighbour budget %d" % level)
		previous_size=Sizes.pixels(level)
		var rect := art.visible_rect()
		check(is_equal_approx(maxf(rect.size.x,rect.size.y),Sizes.pixels(level)),"visible edge includes alpha bounds %d" % level)
		check((art.texture!=null)==(level<=6),"PNG/procedural routing %d" % level)
		check(Rect2(-31,-31,62,62).grow(Sizes.IDLE_OVERHANG).encloses(rect),"idle neighbour overlap budget %d" % level)
		if level<=6:
			check(art.source_bounds.size!=Vector2(256,256),"transparent padding excluded %d" % level)
		art.setup(level,true)
		check(is_equal_approx(maxf(art.visible_rect().size.x,art.visible_rect().size.y),Sizes.COLLECTION_PX),"independent collection size %d" % level)
		check(Rect2(0,0,66,68).encloses(Transform2D(0,Vector2(33,34))*art.render_bounds()),"collection art fits card %d" % level)
		art.free()
	DirAccess.make_dir_recursive_absolute("res://.godot")
	var game = Scene.instantiate()
	game.save_path="res://.godot/progressive_sizes_test_save.json"
	root.add_child(game)
	game.view.sound.set_enabled(false)
	game._new_game()
	check(game.COLS==5 and game.ROWS==6 and game.CELL==62,"board geometry unchanged")
	game.cells.fill(null)
	for index in range(30):
		game.cells[index]=Catalog.make(Catalog.legacy_id(index%10+1))
	game.view.rebuild()
	for index in range(30):
		check(inside_ui_safe(game.view.creatures[index]),"resting sprite clear of UI in cell %d" % index)
	for level in range(1,11):
		game.cells.fill(null)
		game.cells[0]=Catalog.make(Catalog.legacy_id(level))
		game.view.rebuild()
		game.view.creatures[0].pop()
		game._press(game.view.cell_center(0))
		var active: Art = game.view.creatures[0]
		check(active.z_index==Sizes.ACTIVE_Z,"picked sprite above ordinary/ghost sprites %d" % level)
		for point in [Vector2(-100,-100),Vector2(500,-100),Vector2(500,900),Vector2(-100,900)]:
			game.pointer_pos=point
			game.view._process(1.0)
			check(Sizes.PLAY_AREA.grow(0.01).encloses(Rect2(active.position+active.guarded_bounds(true).position,active.guarded_bounds(true).size)),"drag guard clear of UI %d at %s" % [level,point])
		var sampled_inside := true
		for frame in range(12):
			await create_timer(0.01).timeout
			sampled_inside=sampled_inside and inside_ui_safe(active)
		check(sampled_inside,"rapid selection during spawn remains UI-safe %d" % level)
		check(inside_ui_safe(active),"lifted sprite clear of UI %d" % level)
		check(game.pointer_pos==Vector2(-100,900),"logical pointer is not clamped %d" % level)
		game._release(game.pointer_pos)
		check(game.cells[0]==Catalog.make(Catalog.legacy_id(level)) and not game.dragging,"outside drop cancels without moving %d" % level)
		var cancel_inside := true
		for frame in range(20):
			await create_timer(0.01).timeout
			cancel_inside=cancel_inside and inside_ui_safe(active)
		check(cancel_inside,"cancellation stays UI-safe throughout Tween %d" % level)
		check(active.position.is_equal_approx(game.view.rest_position(0,active)) and active.z_index==0,"cancel settles and restores stacking %d" % level)
	game.cells.fill(null)
	game.cells[6]=Catalog.make(Catalog.legacy_id(6))
	game.cells[7]=Catalog.make(Catalog.legacy_id(1))
	game.view.rebuild()
	var wing: Art = game.view.creatures[6]
	var offset := Vector2.ZERO
	var found := false
	var image := wing.texture.get_image()
	for y in range(256):
		for x in range(256):
			var candidate := (Vector2(x+0.5,y+0.5)-wing.source_bounds.get_center())*(Sizes.pixels(6)/maxf(wing.source_bounds.size.x,wing.source_bounds.size.y))
			if candidate.x>31.5 and absf(candidate.y)<30 and image.get_pixel(x,y).a>0.5:
				offset=candidate
				found=true
				break
		if found:
			break
	check(found,"spill probe is on visible wing pixels")
	var spill: Vector2 = game.view.cell_center(6)+offset
	check(game._cell_at(spill)==7,"wing overlap does not change cell hit test")
	var touch := InputEventScreenTouch.new()
	touch.index=0
	touch.pressed=true
	touch.position=game.view.to_global(spill)
	game._gui_input(touch)
	check(game.selected==7,"touch selects actual neighbour under finger")
	game._cancel_drag()
	game.cells[7]=null
	game.view.rebuild()
	game._press(spill)
	check(not game.dragging,"wing over an empty cell is not a new hit target")
	game.cells.fill(null)
	game.cells[6]=Catalog.make(Catalog.legacy_id(10))
	game.view.rebuild()
	var old_coins: int=game.coins
	game._press(game.view.cell_center(6))
	game._release(game.view.cell_center(7))
	await create_timer(0.22).timeout
	check(game.cells[6]==null and game.cells[7]==Catalog.make("ultra") and game.coins==old_coins,"large sprite movement preserves model/economy")
	check(game.view.creatures[7].position.is_equal_approx(game.view.rest_position(7,game.view.creatures[7])),"drop settles at bounded visual position")
	game.cells.fill(null)
	game.cells[6]=Catalog.make(Catalog.legacy_id(5))
	game.cells[7]=Catalog.make(Catalog.legacy_id(5))
	game.view.rebuild()
	game._press(game.view.cell_center(6))
	game._release(game.view.cell_center(7))
	check(game.cells[7]==Catalog.make("shell",2) and game.coins==old_coins+30,"merge rule/reward unchanged")
	check(is_equal_approx(maxf(game.view.creatures[7].visible_rect().size.x,game.view.creatures[7].visible_rect().size.y),Sizes.pixels(5,false,2)),"merge result uses configured size")
	game._press(game.view.cell_center(7))
	var above_effects := true
	for effect: Node2D in game.view.effects.get_children():
		above_effects=above_effects and game.view.creatures[7].z_index>game.view.effects.z_index+effect.z_index
	check(above_effects and game.view.creatures[7].z_index==Sizes.ACTIVE_Z,"selection above live merge ghosts and particles")
	for id in Catalog.ids(): game.unlock(Catalog.make(id))
	game.view.show_panel("collection")
	await process_frame
	await process_frame
	var portraits: Array[Art]=[]
	collect_art(game.view.overlay,portraits)
	check(portraits.size()==5,"collection contains five stages")
	for portrait in portraits:
		check(portrait.collection_mode and Rect2(Vector2.ZERO,portrait.get_parent().size).encloses(portrait.transform*portrait.render_bounds()),"actual collection card contains level %d" % portrait.level)
	check(game.view.overlay.z_index>Sizes.ACTIVE_Z and game.view.discovery_layer.z_index>Sizes.ACTIVE_Z,"UI and discovery banner above selection")
	game.view.close_panel()
	game._save_game()
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
	check(saved.schema_version==2 and saved.has_all(["cells","coins","merges","discoveries","active_species"]),"versioned species save")
	await create_timer(0.5).timeout
	game.free()
	DirAccess.remove_absolute("res://.godot/progressive_sizes_test_save.json")
	print("Progressive size checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
