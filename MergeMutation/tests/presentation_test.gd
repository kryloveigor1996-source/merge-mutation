extends SceneTree

const Scene = preload("res://scenes/main.tscn")
const LabView = preload("res://scripts/lab_view.gd")
const Art = preload("res://scripts/mutant_art.gd")
var failures := 0
var checks := 0

func check(condition: bool,message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ",message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.godot")
	var game = Scene.instantiate()
	game.save_path = "res://.godot/presentation_test_save.json"
	root.add_child(game)
	game.view.sound.set_enabled(false)
	game._new_game()
	await process_frame
	check(game.view.creatures.size()==4,"initial visuals follow model")
	# All layouts stay in bounds, including space reserved for a display cutout.
	for viewport in [Vector2(360,720),Vector2(360,800),Vector2(412,915),Vector2(320,568),Vector2(768,1024)]:
		var available := Rect2(Vector2(0,24),viewport-Vector2(0,48))
		var fitted := LabView.fitted_rect(available)
		check(available.encloses(fitted),"portrait safe bounds %s" % viewport)
		check(is_equal_approx(fitted.size.x/fitted.size.y,0.5),"uniform scaling %s" % viewport)
	var point := Vector2(87,239)
	check(game._design_position(game.view.to_global(point)).is_equal_approx(point),"input uses inverse visual transform")
	game._spawn()
	check(game.coins==90 and game.view.creatures.size()==5,"spawn visual does not change purchase rule")
	var index: int = game.cells.find(1)
	game._press(game.view.cell_center(index))
	check(game.view.drag_index==index,"selection has visual feedback")
	game._cancel_drag()
	check(game.view.drag_index == -1,"cancellation clears visual selection")
	game._press(game.view.cell_center(index))
	game._release(game.view.cell_center(0))
	check(game.cells[0]==1 and game.view.creatures.has(0),"movement updates visual cell immediately")
	await create_timer(0.22).timeout
	check((game.view.creatures[0] as Node2D).position.is_equal_approx(game.view.cell_center(0)),"drop tween settles on destination")
	game.cells.fill(0)
	game.cells[0]=1
	game.cells[1]=1
	game.highest=1
	game.view.rebuild()
	game._press(game.view.cell_center(0))
	game._release(game.view.cell_center(1))
	check(game.cells[1]==2 and game.coins==120,"merge reward stays synchronous")
	check(game.view.creatures.size()==1,"merged source removed from visual map")
	check(game.view.banner_alpha>0,"first discovery shows banner")
	check(game.view.discovery_player.is_playing(),"AnimationPlayer runs discovery sequence")
	check(game.view.effects.get_child_count()>0,"merge creates transient effects")
	await create_timer(0.95).timeout
	check(game.view.effects.get_child_count()==0,"particles and consumed creatures are freed")
	check((game.view.creatures[1] as Node2D).scale.is_equal_approx(Vector2.ONE),"merge pop finishes at normal scale")
	game.cells[0]=1
	game.cells[1]=1
	game.view.rebuild()
	game._press(game.view.cell_center(0))
	game._release(game.view.cell_center(1))
	check(game.view.banner_alpha==0,"repeat discovery does not unlock again")
	game._new_game()
	check(game.view.effects.get_child_count()==0,"reset clears effects during animation")
	check(game.view.creatures.size()==4,"reset rebuilds initial cast")
	# Draw every procedural silhouette, then exercise the PNG replacement branch.
	game.cells.fill(0)
	for level in range(1,11):
		game.cells[level-1]=level
	game.highest=10
	game.view.rebuild()
	await process_frame
	for level in range(1,11):
		check((game.view.creatures[level-1] as Art).level==level,"art slot %d" % level)
	var image := Image.create(256,256,false,Image.FORMAT_RGBA8)
	image.fill(Color("ffda69"))
	(game.view.creatures[0] as Art).texture = ImageTexture.create_from_image(image)
	(game.view.creatures[0] as Art).queue_redraw()
	await process_frame
	check((game.view.creatures[0] as Art).texture.get_size()==Vector2(256,256),"256px replacement texture accepted")
	for kind in ["collection","upgrades","settings"]:
		var before: int = game.coins
		game.view.show_panel(kind)
		await process_frame
		check(game.view.panel_kind==kind and is_instance_valid(game.view.overlay),"panel opens: "+kind)
		check(game.coins==before,"panel does not spend coins: "+kind)
		game.view.close_panel()
		check(not is_instance_valid(game.view.overlay),"panel closes: "+kind)
	for event: String in game.view.sound.EVENTS:
		var stream: AudioStreamWAV = game.view.sound.streams[event]
		check(stream.data.size()>1000 and stream.mix_rate==22050,"generated audio: "+event)
	game.view.sound.set_enabled(false)
	game.view.sound.play_event("merge")
	check(not (game.view.sound.players.merge as AudioStreamPlayer).playing,"muted sound cannot play")
	game._new_game()
	await process_frame
	# Route real touch events through the viewport and native Button, not a signal.
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = game.view.to_global(Vector2(180,580))
	root.push_input(touch,true)
	await process_frame
	touch = touch.duplicate()
	touch.pressed = false
	root.push_input(touch,true)
	await process_frame
	check(game.coins==90,"native button touch spends exactly ten")
	game._press(game.view.cell_center(6))
	game.view.create_button.pressed.emit()
	check(game.coins==90,"create button cannot buy during drag")
	game._cancel_drag()
	game._save_game()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
	check(saved.keys().size()==4 and saved.has_all(["cells","coins","merges","highest"]),"save schema unchanged")
	await create_timer(0.5).timeout
	game.free()
	DirAccess.remove_absolute("res://.godot/presentation_test_save.json")
	print("Presentation checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
