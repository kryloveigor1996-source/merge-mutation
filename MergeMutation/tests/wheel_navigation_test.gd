extends SceneTree
const Scene=preload("res://scenes/main.tscn")
var checks:=0
var failures:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(960,540)
	var game=Scene.instantiate()
	game.save_path="res://.godot/wheel-navigation-profile.json"
	root.add_child(game)
	game.view.open_complex()
	var ui=game.view.complex_ui
	ui.navigate_to_floor("floor_01",false)
	ui.open_living("habitat_horn")
	await process_frame
	var offset: float=ui.offset
	var point: Vector2=ui.detail.environment.get_global_transform_with_canvas()*Vector2(100,100)
	for direction in [MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_WHEEL_UP]:
		for i in range(12):
			var e:=InputEventMouseButton.new()
			e.position=point
			e.button_index=direction
			e.pressed=true
			root.push_input(e,true)
			e=e.duplicate()
			e.pressed=false
			root.push_input(e,true)
			check(is_instance_valid(ui.detail),"wheel never closes the living habitat")
	check(ui.offset==offset,"wheel does not reach the hidden complex")
	game.free()
	print("Wheel navigation checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
