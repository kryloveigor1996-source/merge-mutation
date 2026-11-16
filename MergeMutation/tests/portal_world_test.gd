extends SceneTree
const Scene = preload("res://scenes/main.tscn")
const Worlds = preload("res://scripts/world_registry.gd")
const Model = preload("res://scripts/world_map_model.gd")
const Dialogue = preload("res://scripts/context_dialogue.gd")
const Journey = preload("res://scripts/journey_state.gd")
const Codec = preload("res://scripts/save_codec.gd")
const Progress = preload("res://scripts/campaign_progress.gd")
const Catalog = preload("res://scripts/mutant_catalog.gd")
var checks := 0
var failures := 0
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:
		failures+=1
		printerr("FAIL: ",label)
func _initialize() -> void:
	call_deferred("run")
func touch(position: Vector2,pressed: bool,index: int=0) -> void:
	var event := InputEventScreenTouch.new()
	event.position=position
	event.pressed=pressed
	event.index=index
	root.push_input(event,true)
func drag(position: Vector2,relative: Vector2,index: int=0) -> void:
	var event := InputEventScreenDrag.new()
	event.position=position
	event.relative=relative
	event.index=index
	root.push_input(event,true)
func global(node: CanvasItem,point: Vector2) -> Vector2:
	return node.get_global_transform_with_canvas()*point
func write(path: String,text: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(text)
	file.close()
func run() -> void:
	check(Worlds.ids().size()==4,"four initial worlds from registry data")
	check(Worlds.unlocked("laboratory",[]) and not Worlds.unlocked("toxic_swamp",[]),"new player lab only")
	check(not Worlds.unlocked("toxic_swamp",["lab_09"]) and Worlds.unlocked("toxic_swamp",["lab_10"]),"swamp depends on actual lab_10 completion")
	for id in ["prehistoric","unknown_dimension","missing"]:
		check(not Worlds.unlocked(id,["lab_10"]) and not Worlds.can_launch(id,"lab_01",["lab_10"]),"future and unknown world safely closed")
	for id in Worlds.ids():
		var entry := Worlds.world(id)
		check(Worlds.valid(entry) and entry.has_all(["world_id","name","description","order","portal_style","levels","map","unlock","expeditions"]),"registry has world contract")
		check(not entry.expeditions.enabled,"expeditions not implemented or rewarded")
	check(not Worlds.status("toxic_swamp",["lab_10"]).cleared,"preview map never counts as completed world")
	var unknown_fields := Progress.new()
	unknown_fields.extra={"world_completed":["lab_10"]}
	check(not Worlds.unlocked("toxic_swamp",Worlds.completed_ids(unknown_fields)),"unknown extra fields cannot fabricate legacy completion")
	var model := Model.new()
	check(model.setup("laboratory",[]) and model.nodes.size()==10,"legacy lab map keeps all ten IDs")
	for index in range(10):
		check(model.nodes[index].id=="lab_%02d" % (index+1),"stable original level id")
		check(model.state(index)==("current" if index==0 else "locked"),"sequential map states")
		check(model.fogged(index)==(index>2),"fog excludes current and nearby nodes")
		check(model.hit(model.point(index))==index,"map node hit geometry")
	check(model.hit(Vector2.ZERO)==-1 and not model.fogged(0),"map outside hit safe")
	check(not Worlds.can_launch("laboratory","lab_02",[]) and Worlds.can_launch("laboratory","lab_02",["lab_01"]),"map launch gating")
	check(not Worlds.can_launch("laboratory","lab_11",[]) and not Worlds.can_launch("toxic_swamp","toxic_swamp_preview_001",["lab_10"]),"no missing or preview level route")
	check(model.setup("toxic_swamp",["lab_10"]) and model.nodes.size()==60,"independent swamp preview map")
	for index in range(model.nodes.size()):
		check(model.state(index)=="preview" and not Worlds.can_launch("toxic_swamp",model.nodes[index].id,["lab_10"]),"every preview node disabled")
	var extension := Worlds.world("toxic_swamp")
	extension.world_id="test_extended_world"
	extension.order=10
	extension.map.preview_nodes=350
	extension.unlock={"type":"always"}
	check(Worlds.register_world(extension) and Worlds.ids().size()==5,"world registry extends beyond four portals")
	check(model.setup(extension.world_id,[]) and model.nodes.size()==350 and model.height()>35000,"map supports hundreds of nodes")
	for offset in [0,1000,10000,model.height()-490]:
		var band := model.visible_range(offset,490)
		check(band.x>=0 and band.y<=350 and band.y-band.x<=10,"visible rendering band stays bounded independent of map length")
	Worlds.entries.erase(extension.world_id)
	var invalid := Worlds.world("laboratory")
	invalid.levels=["lab_01","lab_01"]
	check(not Worlds.valid(invalid),"duplicate level IDs rejected")
	var dialogue := Dialogue.new()
	var first := dialogue.next_line("hub",0)
	check(not first.is_empty() and Dialogue.text(first).contains("Профессор"),"context quote loaded from data")
	check(dialogue.next_line("hub",1000).is_empty() and dialogue.next_line("victory",11000).is_empty(),"global anti-spam cooldown")
	var second := dialogue.next_line("hub",31000)
	check(not second.is_empty() and second.id!=first.id,"nearby repeat avoided")
	check(dialogue.next_line("unknown",50000).is_empty(),"unknown dialogue context safe")
	for id in ["intro","swamp_activation"]:
		var scene := Dialogue.scene(id)
		check(not scene.is_empty() and scene.lines.size()<=4,"short data driven story")
		for line in scene.lines:
			check(line.speaker in ["scientist","ai"] and line.text is String,"original two-character dialogue")
	var meta := Journey.new()
	check(meta.decode({}) and not meta.has_seen("intro"),"old save needs no narrative migration")
	for invalid_data in [null,[],{"version":2},{"seen":[]},{"seen":{"intro":1}}]:
		check(not Journey.new().decode(invalid_data),"malformed narrative metadata protected")
	meta.decode({"seen":{"intro":true},"future":{"keep":true}})
	check(meta.has_seen("intro") and meta.encode().future.keep,"unknown metadata preserved")
	var game = Scene.instantiate()
	game.save_path="res://.godot/portal_test_save.json"
	var original_cells: Array=[]
	original_cells.resize(30)
	original_cells[6]=Catalog.make("wing",4)
	var data := Codec.encode(original_cells,777,42,"horn",{"wing:4":true},{"settings":{"keep":true}})
	write(game.save_path,JSON.stringify(data))
	var original_hash := FileAccess.get_sha256(game.save_path)
	root.add_child(game)
	game.view.sound.set_enabled(false)
	game.open_portals()
	check(is_instance_valid(game.view.story_screen) and game.view.story_screen.scene_id=="intro","fresh campaign gets intro on first portal visit")
	game.view.story_screen.get_node("StoryNext").pressed.emit()
	check(game.view.story_screen.index==1,"story advances without delaying player")
	var skip_point := global(game.view.story_screen,Vector2(284,635))
	touch(skip_point,true)
	touch(skip_point,false)
	check(game.journey_state.has_seen("intro") and not is_instance_valid(game.view.story_screen),"skip marks intro once")
	check(FileAccess.get_sha256(game.save_path+".pre-update-"+original_hash.substr(0,12)+".bak")==original_hash,"existing v2 backed up before narrative extension")
	var ui=game.view.portal_ui
	await create_timer(0.22).timeout
	check(ui.visible and ui.page=="hub" and ui.selected=="laboratory","hub opens over sandbox")
	check(game.coins==777 and game.cells==original_cells and game.campaign_progress.stars==0,"browsing does not mutate player state")
	var covered := global(ui,Vector2(180,580))
	touch(covered,true)
	touch(covered,false)
	check(game.coins==777 and game.cells==original_cells,"portal surface blocks underlying create button")
	var start: Vector2=global(ui,Vector2(250,330))
	var end: Vector2=global(ui,Vector2(100,330))
	touch(start,true)
	drag(end,Vector2(-150,0))
	touch(end,false)
	await process_frame
	check(ui.selected=="toxic_swamp","real horizontal touch swipe switches portal")
	var selected: String=ui.selected
	touch(global(ui,Vector2(180,250)),true,1)
	drag(global(ui,Vector2(60,250)),Vector2(-120,0),1)
	touch(global(ui,Vector2(60,250)),false,1)
	check(ui.selected==selected,"extra finger does not switch portal")
	ui.enter_portal()
	check(ui.page=="hub" and not ui.entering and not ui.hint.text.is_empty(),"locked portal explains requirement")
	check(not game.open_world_map("toxic_swamp") and not game.start_world_level("laboratory","lab_02"),"locked map/level launch guarded in main")
	ui.open_hub("laboratory")
	var object_point := global(ui,Vector2(180,290))
	touch(object_point,true)
	touch(object_point,false)
	check(ui.entering and ui.last_transition.is_running(),"portal opening uses animation")
	await create_timer(0.65).timeout
	check(ui.page=="map" and ui.selected=="laboratory","enter transition reaches world map")
	await process_frame
	check(ui.map_model.state(0)=="current" and ui.map_model.fogged(3),"map derives current node and fog")
	var old_scroll: int=ui.map_scroll.scroll_vertical
	start=global(ui.map_canvas,Vector2(80,250))
	end=start+Vector2(0,-180)
	touch(start,true)
	drag(end,Vector2(0,-180))
	touch(end,false)
	await create_timer(0.3).timeout
	check(ui.map_scroll.scroll_vertical>old_scroll and not game.in_campaign(),"vertical touch scroll moves map and never launches node")
	check(ui.map_canvas.last_visible_count<=10,"map uses virtual draw band")
	var wheel := InputEventMouseButton.new()
	wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed=true
	wheel.position=global(ui.map_canvas,Vector2(90,ui.map_scroll.scroll_vertical+200))
	var before_wheel: int=ui.map_scroll.scroll_vertical
	root.push_input(wheel,true)
	await create_timer(0.2).timeout
	check(ui.map_scroll.scroll_vertical>before_wheel,"mouse wheel scrolls world map")
	ui.map_scroll.scroll_vertical=0
	await process_frame
	var point: Vector2=global(ui.map_canvas,ui.map_model.point(0))
	touch(point,true)
	touch(point,false)
	await process_frame
	check(not game.in_campaign() and is_instance_valid(ui.preview),"real node touch opens preview before play")
	ui.preview.get_node("PreviewPlay").pressed.emit()
	check(game.in_campaign() and game.campaign.config.id=="lab_01" and not ui.visible,"play starts tested lab level")
	game.leave_campaign()
	game.open_portals()
	check(not is_instance_valid(game.view.story_screen),"intro does not repeat")
	ui.show_collection()
	check(not ui.visible and game.view.panel_kind=="collection","collection accessible from world interface")
	game.view.close_panel()
	check(ui.visible and not ui.collection_return,"collection back restores portal/map context")
	ui.enter_portal()
	ui.show_collection()
	game.view.close_panel()
	check(ui.visible and not ui.entering,"collection during opening cancels animation without locking navigation")
	ui.close_to_lab()
	check(not ui.visible and game.cells==original_cells,"return to lab restores sandbox unchanged")
	# Earn all progress through actual witnessed actions, not simulated completions.
	var proofs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/campaign_solutions.json"))
	for number in range(1,11):
		check(game.start_level(number,false),"existing campaign remains playable")
		for action in proofs[str(number)].actions:
			if action.kind=="spawn": game._spawn()
			else:
				game._press(game.view.cell_center(int(action.source)))
				game._release(game.view.cell_center(int(action.index)))
		check(game.campaign.status=="won","witness victory retained")
	check(game.coins==1877 and game.campaign_progress.stars==10,"original one-time rewards unchanged")
	check(Worlds.unlocked("toxic_swamp",game.completed_world_level_ids()) and Worlds.status("laboratory",game.completed_world_level_ids()).cleared,"real lab completion unlocks swamp")
	check(is_instance_valid(game.view.story_screen) and game.view.story_screen.scene_id=="swamp_activation","lab_10 victory shows activation scene")
	game.view.story_screen.complete()
	check(game.journey_state.has_seen("swamp_activation"),"activation skippable and recorded")
	game.open_world_map("laboratory")
	check(ui.open_preview("laboratory","lab_10"),"multi-goal preview available after real completion")
	await process_frame
	await process_frame
	var details: ScrollContainer=ui.preview.get_node("PreviewDetails")
	var overflow := Control.new() # Exercise future long metadata.
	overflow.custom_minimum_size=Vector2(1,700)
	details.get_child(0).add_child(overflow)
	await create_timer(0.1).timeout
	var card_start := global(ui.preview,Vector2(270,450))
	var card_end := global(ui.preview,Vector2(270,280))
	touch(card_start,true)
	await process_frame
	drag(card_start+Vector2(0,-30),Vector2(0,-30))
	await process_frame
	drag(card_end,Vector2(0,-170))
	touch(card_end,false)
	await create_timer(0.15).timeout
	check(details.scroll_vertical>0,"multi-goal preview scrolls with native touch")
	details.scroll_vertical=0
	var card_wheel := InputEventMouseButton.new()
	card_wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN
	card_wheel.pressed=true
	card_wheel.position=global(ui.preview,Vector2(270,380))
	root.push_input(card_wheel,true)
	await process_frame
	check(details.scroll_vertical>0,"multi-goal preview scrolls with mouse wheel")
	ui.close_preview()
	game.open_portals()
	ui.open_hub("toxic_swamp")
	check(ui.main_door.unlocked,"open swamp door derives from completed lab_10")
	check(game.open_world_map("toxic_swamp") and ui.map_model.nodes.size()==60,"unlocked swamp map separate from lab")
	var balance: int=game.coins
	var stars: int=game.campaign_progress.stars
	for index in [0,1,10,59]: ui.activate_node(index)
	check(not game.in_campaign() and game.coins==balance and game.campaign_progress.stars==stars,"demo nodes never launch or reward")
	check(ui.map_model.state(59)=="preview" and ui.map_model.fogged(59),"distant demo remains fogged and disabled")
	ui.scroll_by(1000)
	await create_timer(0.3).timeout
	check(ui.map_scroll.scroll_vertical>900 and ui.map_canvas.last_visible_count<=10,"long swamp map scrolls without growing node controls")
	check(Worlds.register_world(extension) and game.open_world_map(extension.world_id),"live interface accepts a fifth data-defined world")
	ui.scroll_by(30000)
	await create_timer(0.4).timeout
	check(ui.map_model.nodes.size()==350 and ui.map_scroll.scroll_vertical>29000 and ui.map_canvas.last_visible_count<=10,"hundreds of nodes work in actual scrolling UI")
	Worlds.entries.erase(extension.world_id)
	game.open_world_map("toxic_swamp")
	ui.get_node("MapBack").pressed.emit()
	check(ui.page=="hub" and ui.selected=="toxic_swamp","map back preserves selected world")
	game.leave_campaign()
	game._save_game()
	check(game._load_game() and game.journey_state.has_seen("intro") and game.journey_state.has_seen("swamp_activation"),"story flags persist in v2")
	check(game.cells==original_cells and game.coins==1877 and game.merges==42 and game.save_extra.settings.keep,"all independent fields retained")
	game.open_portals()
	check(not is_instance_valid(game.view.story_screen),"neither story repeats after load")
	game.start_level(10,false)
	for action in proofs["10"].actions:
		if action.kind=="spawn": game._spawn()
		else:
			game._press(game.view.cell_center(int(action.source)))
			game._release(game.view.cell_center(int(action.index)))
	check(game.last_reward.coins==0 and game.coins==balance and not is_instance_valid(game.view.story_screen),"replay has neither repeat reward nor activation")
	game.leave_campaign()
	# Remove new optional metadata to emulate a fully completed pre-PR11 save.
	data=JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
	data.erase("journey")
	write(game.save_path,JSON.stringify(data))
	check(game._load_game() and Worlds.unlocked("toxic_swamp",game.completed_world_level_ids()),"old completed save automatically unlocks swamp with no flags")
	game.open_portals()
	check(is_instance_valid(game.view.story_screen) and game.view.story_screen.scene_id=="swamp_activation","old player gets short activation on portal entry")
	game.view.story_screen.complete()
	game.view.close_navigation()
	data=JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
	data.journey={"version":99}
	write(game.save_path,JSON.stringify(data))
	var bad_hash := FileAccess.get_sha256(game.save_path)
	check(not game._load_game() and game.write_blocked,"unsupported metadata blocks destructive overwrite")
	game._save_game()
	check(FileAccess.get_sha256(game.save_path)==bad_hash,"damaged/future save kept byte-for-byte")
	await create_timer(0.3).timeout
	game.free()
	DirAccess.remove_absolute("res://.godot/portal_test_save.json")
	print("Portal/world checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
