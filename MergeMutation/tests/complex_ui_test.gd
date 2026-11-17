extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const Complex=preload("res://scripts/underground_complex.gd")
const Registry=preload("res://scripts/complex_registry.gd")
const Art=preload("res://scripts/mutant_art.gd")
var checks:=0
var failures:=0
var ui
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:
		failures+=1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func touch(target: CanvasItem,point: Vector2,down: bool) -> void:
	var event:=InputEventScreenTouch.new()
	event.position=target.get_global_transform_with_canvas()*point
	event.pressed=down
	root.push_input(event,true)
func tap(point: Vector2,mouse: bool=false) -> void:
	for down in [true,false]:
		if not mouse: touch(ui,point,down)
		else:
			var event:=InputEventMouseButton.new()
			event.button_index=MOUSE_BUTTON_LEFT
			event.position=ui.get_global_transform_with_canvas()*point
			event.pressed=down
			root.push_input(event,true)
func drag(from: Vector2,to: Vector2) -> void:
	touch(ui,from,true)
	var event:=InputEventScreenDrag.new()
	event.position=ui.get_global_transform_with_canvas()*to
	event.relative=to-from
	root.push_input(event,true)
	touch(ui,to,false)
func room_point(id: String) -> Vector2:
	return ui.registry.room_rects[id].get_center()-Vector2(0,ui.scroll.scroll_vertical)+ui.VIEW.position
func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://.godot/complex-"+name+".png")==OK,"screenshot "+name)
func profile(game) -> String:
	return JSON.stringify([game.cells,game.coins,game.merges,game.discoveries,game.campaign_progress.encode(),game.save_extra,game.active_species],"",true)
func run() -> void:
	root.size=Vector2i(360,720)
	var game=Scene.instantiate()
	game.save_path="res://.godot/complex-ui-save.json"
	root.add_child(game)
	game.view.sound.set_enabled(false)
	game._save_game()
	var before:=profile(game)
	var file:=FileAccess.get_file_as_string(game.save_path)
	await process_frame
	ui=game.view
	await shot("entry")
	check(game.view.complex_button.size.x>=100 and game.view.complex_button.size.y>=44,"large lab entry without removing bottom navigation")
	touch(game.view,Vector2(285,37),true)
	touch(game.view,Vector2(285,37),false)
	await process_frame
	ui=game.view.complex_ui
	check(is_instance_valid(ui) and not game.in_campaign(),"native touch entry into separate screen")
	check(profile(game)==before,"opening leaves sandbox intact")
	for id in ["floor_surface","floor_01","floor_02","floor_03"]:
		check(ui.navigate_to_floor(id,false),"floor navigation "+id)
		await process_frame
		check(ui.current_floor_id==id,"current floor indicator "+id)
		await shot(id)
	check(ui.active_floors.size()<=4,"only visible sections are created")
	ui.set_scroll_position(-999)
	check(ui.offset==0,"upper scroll boundary")
	ui.set_scroll_position(99999)
	check(ui.offset==ui.max_offset(),"lower scroll boundary")
	tap(Vector2(48,680))
	await create_timer(0.3).timeout
	check(ui.current_floor_id=="floor_surface" and ui.offset==0,"native top button animates to surface")
	tap(Vector2(136,680),true)
	await create_timer(0.3).timeout
	check(ui.current_floor_id=="floor_03","mouse bottom button reaches deepest demo floor")
	tap(Vector2(224,680))
	await process_frame
	check(ui.modal_kind=="LiftMenu" and ui.modal.find_child("Lift_floor_03",true,false)!=null,"lift lists all floors")
	await shot("lift")
	tap(Vector2(180,368))
	await create_timer(0.3).timeout
	check(ui.modal==null and ui.current_floor_id=="floor_02","lift touch selects floor and closes menu")
	ui.navigate_to_floor("floor_01",false)
	await process_frame
	tap(room_point("habitat_slime"))
	check(ui.modal==null and ui.toast.text=="Камера пока недоступна","locked room explains without opening")
	check(ui.room_view("habitat_slime").get_child_count()==0 and ui.room_view("habitat_wing").get_child_count()==0,"locked rooms do not load species graphics")
	tap(room_point("habitat_horn"),true)
	check(ui.modal_kind=="RoomInfo" and ui.details_habitat_id=="habitat_horn","mouse opens horn information")
	var known_sprite:=false
	for child in ui.modal.get_children():
		if child.get_script()==Art: known_sprite=child.species_id=="horn" and child.texture!=null
	check(known_sprite,"info uses existing catalog PNG")
	await shot("horn-info")
	check(profile(game)==before and FileAccess.get_file_as_string(game.save_path)==file,"demo room never unlocks real species or writes profile")
	tap(Vector2(180,579))
	check(ui.modal==null,"info closes by native button")
	ui.show_lift()
	ui.back()
	check(ui.modal==null and ui.is_inside_tree(),"back from nested menu stays in complex")
	check(ui.navigate_to_habitat("habitat_horn"),"future bestiary habitat API")
	await create_timer(0.3).timeout
	check(ui.room_view("habitat_horn").highlight_left>0,"requested habitat highlights")
	await shot("highlight")
	await create_timer(1.5).timeout
	check(not ui.room_view("habitat_horn").is_processing(),"highlight processing stops after feedback")
	var position_before: float=ui.offset
	check(not ui.navigate_to_floor("missing") and not ui.navigate_to_habitat("missing") and not ui.highlight_habitat("missing") and ui.offset==position_before,"invalid navigation does not change screen")
	check(not ui.navigate_to_habitat("habitat_slime"),"locked habitat API does not reveal details")
	check(not ui.show_room_info("habitat_slime") and not ui.show_room_info("missing") and ui.modal==null,"direct info API guards locked and unknown IDs")
	var start:=room_point("habitat_horn")
	drag(start,start+Vector2(0,-90))
	check(ui.modal==null and ui.offset>position_before,"swipe over available room scrolls without opening")
	for index in range(12):
		drag(Vector2(90,430),Vector2(90,220) if index%2==0 else Vector2(90,580))
		check(ui.modal==null and ui.offset>=0 and ui.offset<=ui.max_offset(),"rapid repeated swipes remain bounded and never inspect room")
	ui.stop_motion()
	ui.set_scroll_position(200)
	var down:=Vector2(81,237)
	touch(ui,down,true)
	for point in [down+Vector2(0,-80),down]:
		var motion:=InputEventScreenDrag.new()
		motion.position=ui.get_global_transform_with_canvas()*point
		root.push_input(motion,true)
	touch(ui,down,false)
	check(ui.modal==null,"out-and-back gesture is not a tap")
	ui.stop_motion()
	ui.set_scroll_position(0)
	var wheel:=InputEventMouseButton.new()
	wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed=true
	wheel.position=ui.get_global_transform_with_canvas()*Vector2(180,400)
	root.push_input(wheel,true)
	await create_timer(0.3).timeout
	check(ui.offset>0,"mouse wheel smooth scroll")
	ui.stop_motion()
	ui.set_scroll_position(0)
	for repeat in range(4): root.push_input(wheel,true)
	await create_timer(0.3).timeout
	check(is_equal_approx(ui.offset,360),"rapid wheel events accumulate a smooth bounded target")
	ui.stop_motion()
	ui.set_scroll_position(90)
	var mouse:=InputEventMouseButton.new()
	mouse.button_index=MOUSE_BUTTON_LEFT
	mouse.pressed=true
	mouse.position=ui.get_global_transform_with_canvas()*Vector2(180,500)
	root.push_input(mouse,true)
	var motion:=InputEventMouseMotion.new()
	motion.position=ui.get_global_transform_with_canvas()*Vector2(180,350)
	root.push_input(motion,true)
	mouse=mouse.duplicate()
	mouse.pressed=false
	mouse.position=motion.position
	root.push_input(mouse,true)
	check(ui.offset>=240 and ui.modal==null,"mouse drag preserves room tap separation")
	ui.exit_complex()
	await process_frame
	for repeat in range(6):
		game.view.open_complex()
		ui=game.view.complex_ui
		ui.navigate_to_floor("floor_03",false)
		ui.show_lift()
		ui.exit_complex()
		ui.exit_complex()
		await process_frame
		check(profile(game)==before and FileAccess.get_file_as_string(game.save_path)==file,"reopening never mutates sandbox or save")
	root.size=Vector2i(400,800)
	game.view.layout()
	game.view.open_complex()
	ui=game.view.complex_ui
	ui.navigate_to_floor("floor_01",false)
	await process_frame
	tap(room_point("habitat_horn"))
	check(ui.modal_kind=="RoomInfo","touch coordinates remain correct in scaled portrait layout")
	ui.exit_complex()
	root.size=Vector2i(360,720)
	game.view.layout()
	await process_frame
	# Test-only 50 floor config; never used by normal entry.
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/complex_50.json"))
	var model:=Registry.new()
	check(model.configure(fixture,fixture),"50 floor model")
	ui=Complex.new()
	ui.setup(game,model)
	game.view.add_child(ui)
	game.view.complex_ui=ui
	await process_frame
	for floor in model.floors:
		check(ui.navigate_to_floor(floor.floor_id,false),"50 floor navigation")
		await process_frame
		check(ui.current_floor_id==floor.floor_id and ui.active_floors.size()<=4 and ui.canvas.get_child_count()<=4,"bounded active nodes in 50 floor stress fixture")
		for id in ui.active_floors:
			var floor_data: Dictionary=model.get_floor(id)
			var visible_now:=Rect2(0,floor_data.top,360,floor_data.height).intersects(Rect2(0,ui.offset,360,ui.VIEW.size.y))
			check(ui.active_floors[id].is_processing()==visible_now,"only visible decorations process")
	ui.go_top()
	check(ui.offset==0,"very long trip to surface is immediate")
	ui.go_bottom()
	check(ui.current_floor_id=="stress_floor_49","very long trip to depth is immediate")
	ui.show_lift()
	await process_frame
	await process_frame
	ui.menu_scroll.scroll_vertical=100000
	await process_frame
	var last: Button=ui.modal.find_child("Lift_stress_floor_49",true,false)
	var local: Vector2=ui.get_global_transform_with_canvas().affine_inverse()*(last.get_global_transform_with_canvas()*Vector2(140,30))
	tap(local)
	await create_timer(0.3).timeout
	check(ui.modal==null and ui.current_floor_id=="stress_floor_49","large lift menu selects last floor")
	model.floor_by_id.stress_floor_48.preview_accessible=false
	check(not ui.navigate_to_floor("stress_floor_48"),"unavailable floor API safe")
	check(profile(game)==before and FileAccess.get_file_as_string(game.save_path)==file,"stress mode does not save demonstration progress")
	var key:=InputEventKey.new()
	key.keycode=KEY_ESCAPE
	key.pressed=true
	root.push_input(key,true)
	await process_frame
	check(not is_instance_valid(ui) and not game.in_campaign(),"escape exits to laboratory safely")
	game.free()
	print("Complex UI checks: %d; failures: %d; renderer: %s" % [checks,failures,DisplayServer.get_name()])
	quit(1 if failures else 0)
