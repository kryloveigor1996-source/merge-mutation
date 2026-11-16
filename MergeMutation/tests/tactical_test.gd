extends SceneTree
const Session = preload("res://scripts/campaign_session.gd")
const Levels = preload("res://scripts/campaign_levels.gd")
const Catalog = preload("res://scripts/mutant_catalog.gd")
const Search = preload("res://scripts/tactical_search.gd")
const Scene = preload("res://scenes/main.tscn")
const Art = preload("res://scripts/mutant_art.gd")
const Progress = preload("res://scripts/campaign_progress.gd")
const Codec = preload("res://scripts/save_codec.gd")
var checks := 0
var failures := 0
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:
		failures+=1
		printerr("FAIL: ",label)
func _initialize() -> void:
	call_deferred("run")
func creature(index: int,id: String="slime",stage: int=1) -> Dictionary:
	var form := Catalog.make(id,stage)
	form.cell=index
	return form
func config(initial: Array,limit: int=20) -> Dictionary:
	var data := Levels.get_level(2)
	data.initial=initial
	data.available_species=["slime","eyeball"]
	data.sequence=[]
	data.creation_limit=0
	data.move_limit=limit
	data.blocked_cells=[]
	data.erase("spawn_points")
	data.goals=[{"type":"reach_stage","species_id":"slime","evolution_stage":2}]
	return data
func run() -> void:
	var s := Session.new()
	for destination in [7,11,13,17]:
		check(s.start(config([creature(12),creature(29)])),"movement fixture valid")
		var before := s.creations_used
		check(s.transfer(12,destination).ok and s.cells[destination]==Catalog.make("slime") and s.cells[12]==null,"orthogonal step %d" % destination)
		check(s.moves_used==1 and s.creations_used==before,"one move no creation spent")
	for destination in [6,8,10,14,16,18,27,29,-1,30]:
		s.start(config([creature(12),creature(29)]))
		var before := s.signature()
		check(not s.transfer(12,destination).ok and s.signature()==before,"diagonal/distant/outside has no side effects")
	check(not Session.adjacent(4,5) and not Session.adjacent(9,10),"row wrap rejected")
	for destination in [7,11,13,17]:
		s.start(config([creature(12),creature(destination)],1))
		var result := s.transfer(12,destination)
		check(result.ok and result.kind=="merge" and s.cells[destination]==Catalog.make("slime",2),"adjacent merge retains destination")
		check(s.status=="won" and s.moves_left()==0 and s.goals.merges==1,"last permitted move wins")
	var data := config([creature(12),creature(29)])
	data.blocked_cells=[7.0,13.0]
	s.start(data)
	for destination in [7,13]:
		check(not s.transfer(12,destination).ok and s.moves_used==0,"blocked step free")
	data=config([creature(6),creature(16)],5)
	data.blocked_cells=Array(range(30)).filter(func(index): return not index in [6,7,8,13,18,17,16])
	s.start(data)
	check(s.pair_distance(6,16)==6 and s.status=="lost","real detour exceeds remaining budget despite identical pair")
	data.move_limit=6
	s.start(data)
	check(s.status=="active","exactly enough route budget allowed")
	var proof := Search.solve(s,3000,false)
	check(proof.won and proof.moves==6 and not proof.cutoff,"detour verified by exact BFS")
	data=config([creature(6),creature(16)],20)
	data.blocked_cells=Array(range(30)).filter(func(index): return not index in [6,7,8,16,17,18])
	s.start(data)
	check(s.status=="lost","disconnected identical pair cannot merge")
	s.start(data,1)
	check(s.status=="active","teleporter can rescue disconnected components")
	check(s.use_booster("teleporter",6,17).ok and s.moves_used==0 and s.boosters.remaining("teleporter")==0,"teleporter consumes charge not move")
	check(s.transfer(17,16).ok and s.status=="won","normal merge after teleport")
	data=config([creature(12),creature(28)])
	data.blocked_cells=[26.0]
	s.start(data,1)
	for destination in [12,26,28,-1,30]:
		var before := s.signature()
		check(not s.use_booster("teleporter",12,destination).ok and s.signature()==before,"invalid teleport cannot spend charge or merge")
	check(not s.boosters.grant("evacuator",1) and not s.boosters.grant("evolution_serum",1),"future booster effects remain disabled")
	check(not s.use_booster("evacuator",12,27).ok and s.boosters.remaining("teleporter")==1,"unknown/disabled tool safe")
	check(s.use_booster("teleporter",12,27).ok and s.cells[27]==Catalog.make("slime") and s.goals.merges==0,"teleport moves same form only")
	check(not s.use_booster("teleporter",27,12).ok and s.boosters.remaining("teleporter")==0,"no negative charges")
	data=config([creature(6),creature(18)])
	data.sequence=["eyeball","slime","eyeball"]
	data.creation_limit=3
	data.spawn_points=[6.0,8.0]
	s.start(data)
	check(s.spawn_index()==-1 and s.next_spawn_point()==6,"occupied chosen point never skips to next")
	var before := s.signature()
	check(not s.spawn().ok and s.signature()==before,"blocked queue attempt spends nothing")
	s.transfer(6,7)
	check(s.spawn().form==Catalog.make("eyeball") and s.creations_used==1 and s.next_spawn_point()==8,"first point and queue")
	check(s.spawn().form==Catalog.make("slime") and s.next_spawn_point()==6,"points cycle deterministically")
	before=s.signature()
	check(not s.spawn().ok and s.signature()==before,"occupied cycled point waits without resource loss")
	s.transfer(6,11)
	check(s.spawn().index==6 and s.creations_left()==0,"cycle continues after freeing point")
	var legacy := config([creature(12),creature(29)])
	legacy.sequence=["slime"]
	legacy.creation_limit=1
	s.start(legacy)
	check(s.spawn().index==0,"old configuration falls back to first free cell")
	for bad_points in [null,"bad",[30],[-1],[6,6],[6.5]]:
		data=legacy.duplicate(true)
		data.spawn_points=bad_points
		check(not Levels.valid(data),"invalid spawn points rejected")
	data=legacy.duplicate(true)
	data.blocked_cells=[6]
	data.spawn_points=[6]
	check(not Levels.valid(data),"spawner on blocked cell rejected")
	s.start(config([creature(6),creature(8)],2))
	var limited := Search.solve(s,1,false)
	check(not limited.won and limited.cutoff and not limited.exhaustive,"bounded search uncertainty is not impossibility")
	check(s.status=="active","search has no side effects on source state")
	s.start(config([creature(6),creature(8)],0),1)
	check(s.status=="lost","zero moves cannot be rescued by a teleport when a merge is still required")
	data=config([creature(6)],0)
	data.sequence=["eyeball"]
	data.creation_limit=1
	data.spawn_points=[6]
	data.goals=[{"type":"reach_stage","species_id":"eyeball","evolution_stage":1}]
	s.start(data,1)
	check(s.status=="active","zero moves still permits teleport then base creation goal")
	check(s.use_booster("teleporter",6,29).ok and s.moves_used==0,"tool can free point with no moves")
	check(s.spawn().ok and s.status=="won","creation-only victory after freeing point")
	var witnesses: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/campaign_solutions.json"))
	for number in range(1,11):
		data=Levels.get_level(number)
		check(s.start(data) and s.status=="active","level never wins or loses immediately")
		check(s.boosters.remaining("teleporter")==0,"proof starts without tools")
		var witness: Dictionary=witnesses[str(number)]
		check(witness.won and not witness.cutoff and witness.method=="BFS","BFS solution found before cutoff")
		var used_moves := 0
		var used_merges := 0
		var used_spawns := 0
		for action in witness.actions:
			check(s.status=="active","witness not prematurely defeated")
			if action.kind!="spawn":
				check(Session.adjacent(int(action.source),int(action.index)),"every proof transfer adjacent")
			else:
				check(s.spawn_index()==int(action.index),"proof spawn matches fixed cell")
			var result := s.apply_action(action)
			check(result.ok,"each witness action accepted")
			if action.kind=="move": used_moves+=1
			if action.kind=="merge": used_merges+=1
			if action.kind=="spawn": used_spawns+=1
		check(s.status=="won" and s.boosters.remaining("teleporter")==0,"zero booster victory %d" % number)
		check(used_moves==int(witness.transfers) and used_merges==int(witness.merges) and used_spawns==int(witness.creations) and s.moves_used==used_moves+used_merges,"solution metrics match actual costs")
	var game = Scene.instantiate()
	game.save_path="res://.godot/tactical_test_save.json"
	# Simulate a player who finished all ten OLD levels before updating.
	var progress := Progress.new()
	for number in range(1,11): progress.finish(number)
	var sandbox: Array=[]
	sandbox.resize(30)
	sandbox[6]=Catalog.make("wing",4)
	var encoded := Codec.encode(sandbox,4321,99,"ultra",{"wing:4":true},{"campaign":progress.encode(),"settings":{"keep":true}})
	var file := FileAccess.open(game.save_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(encoded))
	file.close()
	root.add_child(game)
	game.view.sound.set_enabled(false)
	check(game.campaign_progress.stars==10 and game.campaign_progress.unlocked()==10,"old completions remain unlocked")
	for number in [1,5,10]:
		game.start_level(number,false)
		for action in witnesses[str(number)].actions:
			if action.kind=="spawn": game._spawn()
			else:
				game._press(game.view.cell_center(int(action.source)))
				game._release(game.view.cell_center(int(action.index)))
		check(game.campaign.status=="won" and game.coins==4321 and game.campaign_progress.stars==10 and game.last_reward.coins==0,"old-level rewards not issued again after rebalance")
		game.leave_campaign()
		check(game.cells==sandbox and game.merges==99 and game.active_species=="ultra","old sandbox preserved after tactical replay")
	game.start_level(2)
	await process_frame
	check(not game.view.create_button.get_rect().intersects(game.view.teleport_button.get_rect()) and game.view.teleport_button.get_rect().end.x<=342,"mobile create/tool buttons do not overlap and fit width")
	check(game.view.teleport_button.size.y>=48,"tool touch target sufficiently tall")
	game._press(game.view.cell_center(6))
	check(game.view.valid_target(7) and game.view.valid_target(11) and not game.view.valid_target(8),"only legal neighbour highlights")
	game._release(game.view.cell_center(8))
	check(game.campaign.moves_used==0 and game.message_time>0 and game.view.rejection_time>0,"far drop shows hint and feedback free")
	game.view.teleport_button.pressed.emit()
	check(game.teleport_mode,"native tool button arms teleporter")
	game._press(game.view.cell_center(6))
	check(game.view.valid_target(29) and not game.view.valid_target(8),"teleport highlights free cells but never occupied merge target")
	game._release(game.view.cell_center(29))
	check(game.cells[29]==Catalog.make("slime") and game.campaign.moves_used==0 and game.campaign.boosters.remaining("teleporter")==0 and not game.teleport_mode,"UI teleporter actually moves and disarms")
	game.leave_campaign()
	game.toggle_teleporter()
	check(not game.teleport_mode,"booster cannot activate in sandbox")
	game._press(game.view.cell_center(6))
	game._release(game.view.cell_center(29))
	check(game.cells[29]==Catalog.make("wing",4) and game.coins==4321,"sandbox distant movement unchanged")
	game._save_game()
	check(game._load_game() and game.cells[29]==Catalog.make("wing",4) and game.campaign_progress.claimed.size()==10 and game.save_extra.settings.keep,"v2 old progress survives save/load")
	# Native touch creates at the fixed point; then mouse performs a legal merge.
	game.start_level(1)
	await process_frame
	var touch := InputEventScreenTouch.new()
	touch.index=0
	touch.pressed=true
	touch.position=game.view.to_global(Vector2(140,580))
	root.push_input(touch,true)
	await process_frame
	touch=touch.duplicate()
	touch.pressed=false
	root.push_input(touch,true)
	await process_frame
	check(game.campaign.creations_used==1 and game.cells[7]==Catalog.make("slime"),"touch create uses fixed point once")
	for pressed in [true,false]:
		var mouse := InputEventMouseButton.new()
		mouse.button_index=MOUSE_BUTTON_LEFT
		mouse.pressed=pressed
		mouse.position=game.view.to_global(game.view.cell_center(6 if pressed else 7))
		root.push_input(mouse,true)
		await process_frame
	check(game.campaign.status=="won" and game.campaign.moves_used==1,"mouse drag obeys adjacent merge rules")
	game.leave_campaign()
	await create_timer(0.5).timeout
	game.free()
	DirAccess.remove_absolute("res://.godot/tactical_test_save.json")
	print("Tactical checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
