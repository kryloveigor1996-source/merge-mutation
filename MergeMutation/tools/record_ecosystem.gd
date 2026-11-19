extends SceneTree
## Real engine/movie capture with scripted commands and isolated demonstration saves.
const Scene=preload("res://scenes/main.tscn")
var detail
var model
func _initialize() -> void: call_deferred("record")
func hold(seconds: float) -> void:
	for i in range(roundi(seconds*60)): await process_frame
func record() -> void:
	root.size=Vector2i(960,540)
	var species:="slime" if "--slime" in OS.get_cmdline_user_args() else "horn"
	var game=Scene.instantiate()
	game.save_path="res://.godot/ecosystem-record-"+species+".json"
	DirAccess.remove_absolute(game.save_path)
	DirAccess.remove_absolute(game.save_path+".habitat-demo-v1.json")
	root.add_child(game)
	game.view.sound.set_enabled(false)
	game.view.open_complex()
	var complex=game.view.complex_ui
	var id:="habitat_"+species
	complex.navigate_to_floor(complex.registry.get_floor_for_habitat(id).floor_id,false)
	complex.open_living(id)
	detail=complex.detail
	model=detail.model
	var room=detail.room_state
	for slot in room.catalog.offers:
		if room.points==0: room.grant_test_point()
		room.confirm(slot,room.catalog.slots[slot].designs[0].design_id)
	model.reset_simulation(123)
	if species=="horn":
		model.rare_next=10000 # Reserve this short clip for explicitly scripted demonstrations.
		model.request_slot("training")
		await hold(6)
		model.cancel_action()
		model.rare_next=0
		model.last_player_command=-100
		assert(model.request_rare("dust_sneeze"))
		await hold(2.5)
		model.cancel_action()
		model.position.x=room.catalog.project_rect(room.catalog.slots.cabinets,940).get_center().x-65
		model.rare_next=0
		assert(model.request_rare("monument_push"))
		await hold(3)
		model.cancel_action()
		model.rare_next=0
		model.last_successful_ram=model.simulation_time
		assert(model.hit_count>0 and model.request_rare("proud_ram"))
		await hold(3)
	else:
		model.rare_next=10000
		model.request_slot("bed")
		await hold(12)
		model.cancel_action()
		model.position.x=1400
		detail.environment.set_camera(940)
		model.request_slot("feeder")
		await hold(4)
		model.cancel_action()
		model.rare_next=0
		model.last_player_command=-100
		assert(model.request_rare("bubble_splat"))
		await hold(3)
	print("Ecosystem movie complete: ",species)
	complex.exit_complex()
	game.free()
	quit()
