extends SceneTree
const Scene = preload("res://scenes/main.tscn")
const Worlds = preload("res://scripts/world_registry.gd")
const Model = preload("res://scripts/world_map_model.gd")
const Preview = preload("res://scripts/level_preview_model.gd")
const Board = preload("res://scripts/lab_notice_board.gd")
var checks := 0
var failures := 0
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:
		failures+=1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func global(node: CanvasItem,point: Vector2) -> Vector2: return node.get_global_transform_with_canvas()*point
func touch(point: Vector2,down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index=0
	event.position=point
	event.pressed=down
	root.push_input(event,true)
func drag(point: Vector2,relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index=0
	event.position=point
	event.relative=relative
	root.push_input(event,true)
func run() -> void:
	var game = Scene.instantiate()
	game.save_path="res://.godot/portal_revision_test.json"
	if FileAccess.file_exists(game.save_path): DirAccess.remove_absolute(game.save_path)
	root.add_child(game)
	game.view.sound.set_enabled(false)
	game.open_portals()
	game.view.story_screen.complete()
	var ui=game.view.portal_ui
	check(ui.main_door is Board and ui.selected=="laboratory","lab is a board, stable world id")
	check(not ui.has_node("PortalEnter"),"redundant enter button removed")
	check(ui.object_hint_left>0 and game.journey_state.has_seen("hub_board_hint"),"first object visit is highlighted and hint recorded")
	for index in range(36):
		ui.shift(1 if index%3 else -1)
		check(ui.modulate.a==1 and ui.visible and ui.page=="hub","rapid switching never fades the occluding surface")
		await process_frame
	ui.open_hub("laboratory")
	check(ui.object_hint_left==0,"board hint does not repeat")
	ui.open_hub("toxic_swamp")
	check(game.journey_state.has_seen("hub_portal_hint") and not ui.main_door.unlocked,"door hint independent of board and real lock retained")
	ui.open_hub("laboratory")
	var a := global(ui,Vector2(220,290))
	var b := global(ui,Vector2(130,290))
	touch(a,true)
	drag(b,Vector2(-90,0))
	drag(a,Vector2(90,0))
	touch(a,false)
	check(ui.page=="hub" and not ui.entering,"out-and-back swipe is not interpreted as a tap")
	# Mouse drag through the object also cannot enter it.
	for down in [true,false]:
		var mouse := InputEventMouseButton.new()
		mouse.button_index=MOUSE_BUTTON_LEFT
		mouse.pressed=down
		mouse.position=a if down else b
		root.push_input(mouse,true)
	check(not ui.entering,"mouse swipe cannot enter central object")
	ui.open_hub("laboratory")
	var center := global(ui,Vector2(180,290))
	touch(center,true)
	touch(center,false)
	check(ui.entering,"touching the board opens map without an extra button")
	await create_timer(0.35).timeout
	check(ui.page=="map" and ui.modulate.a==1,"board transition reaches opaque map")
	var coins: int=game.coins
	var stars: int=game.campaign_progress.stars
	var before := FileAccess.get_sha256(game.save_path)
	ui.activate_node(0)
	check(is_instance_valid(ui.preview) and not game.in_campaign(),"node opens preview, not gameplay")
	var data: Dictionary=ui.preview.data
	check(data.number==1 and data.name=="Соседи" and data.goals.contains("Слизик II"),"preview uses real level identity and goals")
	check(data.difficulty=="Пока не указана" and data.best_result==null and data.best_text.contains("не сохраняется"),"no invented difficulty or best score")
	check(data.boosters.contains("Телепортатор") and data.boosters.contains("1"),"booster offer matches real test charge")
	check(data.discoveries.size()==1 and data.discoveries[0].species_id=="slime" and data.discoveries[0].evolution_stage==2,"only undeclared-to-player target forms are previewed")
	check(game.coins==coins and game.campaign_progress.stars==stars and FileAccess.get_sha256(game.save_path)==before,"preview is read-only and grants no rewards")
	await process_frame
	var close_point := global(ui.preview,Vector2(180,660))
	touch(close_point,true)
	touch(close_point,false)
	check(not is_instance_valid(ui.preview) and ui.page=="map" and not game.in_campaign(),"close returns to same map without launch")
	check(not ui.open_preview("laboratory","lab_02") and not ui.open_preview("laboratory","missing"),"locked and nonexistent levels cannot open actionable preview")
	check(not ui.open_preview("toxic_swamp","toxic_swamp_preview_001"),"demo route cannot open play card")
	game.unlock({"species_id":"slime","evolution_stage":2})
	check(Preview.build("laboratory","lab_01",game).discoveries.is_empty(),"known forms are not falsely promised as new")
	ui.activate_node(0)
	await process_frame
	var play_point := global(ui.preview,Vector2(180,596))
	touch(play_point,true)
	touch(play_point,false)
	await process_frame
	check(game.in_campaign() and game.campaign.config.id=="lab_01" and not ui.visible,"native play touch starts exactly the previewed level")
	check(game.campaign.boosters.remaining("teleporter")==1 and game.coins==coins,"actual booster count matches preview, no entry charge")
	game._spawn()
	game._press(game.view.cell_center(6))
	game._release(game.view.cell_center(7))
	check(game.campaign.status=="won" and game.campaign_progress.stars==stars+1 and game.coins==coins+100,"existing single-star reward unchanged")
	game.open_world_map("laboratory")
	check(ui.open_preview("laboratory","lab_01") and ui.preview.data.completed and ui.preview.data.best_result==null,"completed level has honest neutral best-result state")
	ui.play_preview()
	game._spawn()
	game._press(game.view.cell_center(6))
	game._release(game.view.cell_center(7))
	check(game.last_reward.coins==0 and game.campaign_progress.stars==stars+1,"preview replay never duplicates stars or coins")
	game.leave_campaign()
	game._save_game()
	check(game._load_game() and game.journey_state.has_seen("hub_board_hint") and game.journey_state.has_seen("hub_portal_hint"),"hint flags reuse v2 optional metadata")
	# Arbitrary positions, non-monotonic level order and an authored detour.
	var extension := Worlds.world("laboratory")
	extension.world_id="test_authored_map"
	extension.levels=["lab_01","lab_02","lab_03"]
	extension.map.layout={"canvas_size":[900,2200],"nodes":{"lab_01":[700,1400],"lab_02":[100,100],"lab_03":[600,700]},"routes":[{"from":"lab_01","to":"lab_02","points":[[780,1900],[240,1800]]},{"from":"lab_02","to":"lab_03","points":[[80,400],[500,450]]}],"background_texture":"res://missing_map_background.png"}
	check(Worlds.register_world(extension),"authored layout accepted without hardcoded node rows")
	var model := Model.new()
	check(model.setup(extension.world_id,["lab_01"]) and model.point(0)==Vector2(700,1400) and model.point(1)==Vector2(100,100),"positions can be non-monotonic and wider than phone")
	check(model.width()==900 and model.height()==2200 and model.routes.size()==2,"canvas extent and explicit routes independent of level count")
	for index in range(3): check(model.hit(model.point(index))==index,"spatial hit test uses actual coordinates")
	check(model.visible_indices(0,490)==[1] and model.visible_indices(1200,490)==[0],"virtualisation does not assume story index follows y")
	check(not model.visible_routes(Rect2(0,1700,900,300)).is_empty(),"winding route visible even with both end nodes offscreen")
	check(model.state(0)=="completed" and model.state(1)=="current" and model.state(2)=="locked","layout does not change unlock sequence or progress")
	check(game.open_world_map(extension.world_id),"authored map renders through existing screen")
	ui.pan_by(Vector2(400,1000))
	await create_timer(0.4).timeout
	check(ui.map_scroll.scroll_horizontal>350 and ui.map_scroll.scroll_vertical>900,"wide map pans smoothly while preserving vertical scrolling")
	ui.close_to_lab()
	Worlds.entries.erase(extension.world_id)
	for layout in [{"nodes":{"lab_01":[1]}},{"nodes":{"lab_01":[-1,5]}},{"routes":"bad"},{"routes":[{"from":"lab_01","to":"lab_02","points":[[1,-1]]}]}]:
		check(not Worlds.valid_layout(layout),"invalid authored geometry rejected")
	game.free()
	DirAccess.remove_absolute("res://.godot/portal_revision_test.json")
	print("Portal revision checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
