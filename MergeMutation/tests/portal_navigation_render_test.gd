extends SceneTree
const Scene = preload("res://scenes/main.tscn")
var checks := 0
var failures := 0
var sentinel: ColorRect
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:
		failures+=1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func verify_surface() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var before := root.get_texture().get_image()
	sentinel.color=Color.GREEN
	await process_frame
	await RenderingServer.frame_post_draw
	var after := root.get_texture().get_image()
	for point in [Vector2i(5,5),Vector2i(355,5),Vector2i(5,705),Vector2i(355,705)]:
		var first := before.get_pixelv(point)
		var second := after.get_pixelv(point)
		check(absf(first.r-second.r)<0.01 and absf(first.g-second.g)<0.01 and absf(first.b-second.b)<0.01,"underlying layer color cannot influence portal pixels")
	sentinel.color=Color.MAGENTA
func swipe(ui: Control,direction: int) -> void:
	var start := Vector2(240,290) if direction>0 else Vector2(100,290)
	var end := Vector2(100,290) if direction>0 else Vector2(240,290)
	var down := InputEventScreenTouch.new()
	down.index=0
	down.pressed=true
	down.position=ui.get_global_transform_with_canvas()*start
	root.push_input(down,true)
	var drag := InputEventScreenDrag.new()
	drag.index=0
	drag.position=ui.get_global_transform_with_canvas()*end
	drag.relative=end-start
	root.push_input(drag,true)
	var up := InputEventScreenTouch.new()
	up.index=0
	up.pressed=false
	up.position=drag.position
	root.push_input(up,true)
func shot(name: String) -> void:
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://.godot/portal-"+name+".png")==OK,"screenshot saved")
func run() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("GPU regression requires a renderer")
		quit(1)
		return
	root.size=Vector2i(360,720)
	var game = Scene.instantiate()
	game.save_path="res://.godot/portal_render_test.json"
	if FileAccess.file_exists(game.save_path): DirAccess.remove_absolute(game.save_path)
	root.add_child(game)
	game.view.sound.set_enabled(false)
	game.open_portals()
	game.view.story_screen.complete()
	var ui=game.view.portal_ui
	sentinel=ColorRect.new()
	sentinel.color=Color.MAGENTA
	sentinel.size=Vector2(360,720)
	sentinel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	sentinel.z_index=21
	game.view.add_child(sentinel)
	for index in range(30):
		swipe(ui,1 if index%2 else -1)
		check(ui.page=="hub" and not ui.entering,"rapid real swipes never enter a world")
		await verify_surface()
	for index in range(8):
		if index%2: game.open_world_map("laboratory")
		else: ui.open_hub("laboratory")
		await verify_surface()
	# Positive control: the detector must see the old failure mode if opacity drops.
	ui.modulate.a=0.5
	sentinel.color=Color.MAGENTA
	await process_frame
	await RenderingServer.frame_post_draw
	var magenta := root.get_texture().get_image().get_pixel(5,5)
	sentinel.color=Color.GREEN
	await process_frame
	await RenderingServer.frame_post_draw
	var green := root.get_texture().get_image().get_pixel(5,5)
	check(absf(magenta.r-green.r)>0.1,"positive control detects a deliberately transparent occluder")
	ui.modulate=Color.WHITE
	sentinel.color=Color.MAGENTA
	ui.open_hub("laboratory")
	await shot("hall-lab")
	game.open_world_map("laboratory")
	ui.activate_node(0)
	await verify_surface()
	await shot("level-preview")
	ui.close_preview()
	await shot("lab-map")
	sentinel.queue_free()
	game.free()
	DirAccess.remove_absolute("res://.godot/portal_render_test.json")
	print("Portal GPU regression checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
