extends SceneTree
## Scripted real-engine capture. Always uses an isolated disposable demonstration profile.
const Scene=preload("res://scenes/main.tscn")
var detail
var room
func _initialize() -> void: call_deferred("record")
func hold(frames: int) -> void:
	for i in range(frames): await process_frame
func add_items(ids: Array) -> void:
	for id in ids:
		if room.points==0: room.grant_test_point()
		room.confirm(id,room.catalog.slots[id].designs[0].design_id)
func record() -> void:
	root.size=Vector2i(960,540)
	var game=Scene.instantiate()
	game.save_path="res://.godot/modular-record-profile.json"
	root.add_child(game)
	game.view.sound.set_enabled(false)
	game.view.open_complex()
	var complex=game.view.complex_ui
	complex.navigate_to_floor("floor_01",false)
	complex.open_living("habitat_horn")
	detail=complex.detail
	room=detail.room_state
	room.reset_demo(true)
	await hold(35)
	detail.toggle_repair()
	detail.open_design("bed")
	for d in room.catalog.slots.bed.designs:
		detail.select_design(d.design_id)
		await hold(22)
	detail.confirm_design()
	detail.toggle_repair()
	await hold(25)
	add_items(["walls","floor"])
	await hold(40)
	add_items(["training","feeder","lighting"])
	await hold(40)
	add_items(["cabinets","plants","toy","water"])
	await hold(45)
	detail.toggle_panorama()
	for frame in range(142):
		detail.environment.set_camera(frame*10)
		await process_frame
	await hold(20)
	detail.find_resident()
	await hold(55)
	complex.exit_complex()
	game.free()
	quit()
