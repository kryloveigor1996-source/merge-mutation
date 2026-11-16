extends SceneTree
const Levels = preload("res://scripts/campaign_levels.gd")
const Session = preload("res://scripts/campaign_session.gd")
const Goals = preload("res://scripts/campaign_goals.gd")
const Progress = preload("res://scripts/campaign_progress.gd")
const Catalog = preload("res://scripts/mutant_catalog.gd")
const Codec = preload("res://scripts/save_codec.gd")
const Scene = preload("res://scenes/main.tscn")
const Solver = preload("res://tests/campaign_solver.gd")
var checks := 0
var failures := 0
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:
		failures+=1
		printerr("FAIL: ",label)
func _initialize() -> void:
	call_deferred("run")
func write(path: String,value: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(value)
	file.close()
func config(initial: Array,sequence: Array,limit: int,goal: Dictionary) -> Dictionary:
	var data := Levels.get_level(1)
	data.initial=initial
	data.sequence=sequence
	data.creation_limit=sequence.size()
	data.move_limit=limit
	data.goals=[goal]
	return data
func run() -> void:
	var proofs := {}
	var saved_proofs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/campaign_solutions.json"))
	for number in range(1,11):
		var data := Levels.get_level(number)
		check(not data.is_empty() and Levels.valid(data),"level loads %d" % number)
		if data.is_empty(): continue
		var proof := Solver.solve(data)
		check(proof.won,"solution exists %d" % number)
		check(JSON.stringify(JSON.parse_string(JSON.stringify(proof)),"",true)==JSON.stringify(saved_proofs[str(number)],"",true),"committed solution matches verified configuration")
		proofs[str(number)]=proof
		print("Level %d: solved=%s; creations=%d/%d; moves=%d/%s" % [number,proof.won,proof.creations,data.creation_limit,proof.moves,str(data.move_limit)])
	check(Levels.get_level(0).is_empty() and Levels.get_level(11).is_empty(),"out of range level safe")
	for field in ["sequence","goals","initial","blocked_cells"]:
		var bad_config := Levels.get_level(1)
		bad_config[field]="invalid"
		check(not Levels.valid(bad_config),"malformed configuration rejected")
	var s := Session.new()
	check(s.start(Levels.get_level(7)),"mixed level starts")
	var expected: Array=s.config.sequence
	for index in range(expected.size()):
		var before := s.creations_left()
		var result := s.spawn()
		check(result.ok and result.form==Catalog.make(expected[index]) and s.creations_left()==before-1,"ordered queue consumes one creation")
	check(not s.spawn().ok and s.creations_left()==0,"no negative creations")
	var c := config([{"cell":6,"species_id":"slime","evolution_stage":1}],[],3,{"type":"reach_stage","species_id":"slime","evolution_stage":3})
	# Add an actual pair so the attempt is still playable without new creations.
	c.initial.append({"cell":8,"species_id":"slime","evolution_stage":1})
	s.start(c)
	check(s.status=="active","zero creations does not prevent remaining merges")
	check(s.transfer(6,7).ok and s.moves_left()==2,"empty move costs one move")
	var before := s.cells.duplicate(true)
	var moves := s.moves_left()
	for pair in [[-1,7],[7,7],[7,30],[0,1]]:
		check(not s.transfer(pair[0],pair[1]).ok and s.cells==before and s.moves_left()==moves,"invalid move free")
	s.cells[9]=Catalog.make("eyeball")
	s.cells[10]=Catalog.make("slime",2)
	for destination in [9,10]:
		check(not s.transfer(7,destination).ok and s.moves_left()==moves,"mismatched merge free")
	s.cells[9]=null
	s.cells[10]=null
	check(s.transfer(7,8).ok and s.moves_left()==1 and s.goals.merges==1,"merge costs one move")
	check(s.status=="lost" and not s.transfer(8,7).ok,"exhausted opportunities fail and lock")
	c=config([{"cell":6,"species_id":"slime","evolution_stage":1},{"cell":8,"species_id":"slime","evolution_stage":1}],[],1,{"type":"reach_stage","species_id":"slime","evolution_stage":2})
	s.start(c)
	s.transfer(6,8)
	check(s.status=="won" and s.moves_left()==0,"victory on last move wins")
	check(not s.spawn().ok and not s.transfer(8,9).ok,"victory locks actions")
	c=config([],['slime','slime'],-1,{"type":"reach_stage","species_id":"slime","evolution_stage":2})
	s.start(c)
	s.spawn()
	s.spawn()
	check(s.status=="active" and s.creations_left()==0,"can merge after last creation")
	s.transfer(0,1)
	check(s.status=="won","win after exhausted creations")
	c=config([],['slime'],0,{"type":"reach_stage","species_id":"slime","evolution_stage":1})
	s.start(c)
	check(s.status=="active","no moves still permits goal through creation")
	s.spawn()
	check(s.status=="won","last creation wins with zero moves")
	c=config([],['slime'],-1,{"type":"reach_stage","species_id":"slime","evolution_stage":3})
	s.start(c)
	s.spawn()
	check(s.status=="lost" and not s.reason.is_empty(),"no possible merge or creation fails")
	s.start(Levels.get_level(4))
	for blocked_index in [0,4,25,29]:
		check(s.blocked(blocked_index),"JSON float blocked index normalized")
	check(not s.transfer(0,1).ok and not s.transfer(1,4).ok,"blocked cells reject actions")
	s.spawn()
	check(s.cells[0]==null and s.cells[1]==Catalog.make("slime"),"spawn skips blocked first cell")
	check(not s.transfer(1,4).ok and s.moves_used==0,"occupied source cannot move into blocked cell")
	var count := s.creations_left()
	s.cells.fill(Catalog.make("slime"))
	check(not s.spawn().ok and s.creations_left()==count,"full board does not charge")
	s.cells[1]=null
	var result := s.spawn()
	check(result.ok and result.index==1,"first free unblocked spawn deterministic")
	var tracker := Goals.new()
	var two := {"species_id":"slime","evolution_stage":2,"count":2}
	tracker.record(Catalog.make("slime",2))
	check(not tracker.target_met(two),"one instance not counted twice")
	check(not tracker.met({"type":"collect_forms","forms":[Catalog.make("slime",2),Catalog.make("slime",2)]}),"duplicate collect requirements need distinct production events")
	tracker.record(Catalog.make("slime",2))
	check(tracker.target_met(two),"two production events count")
	check(not tracker.met({"type":"collect_forms","forms":[two,{"species_id":"horn","evolution_stage":2}]}),"all forms required")
	tracker.record(Catalog.make("horn",2))
	check(tracker.met({"type":"collect_forms","forms":[two,{"species_id":"horn","evolution_stage":2}]}),"collect forms goal")
	tracker.merges=4
	check(tracker.all_met([{"type":"merge_count","count":4},{"type":"reach_stage","species_id":"horn","evolution_stage":2}]),"all simultaneous goals")
	c=config([{"cell":6,"species_id":"slime","evolution_stage":2},{"cell":8,"species_id":"slime","evolution_stage":1}],['slime'],10,{"type":"reach_stage","species_id":"slime","evolution_stage":2,"count":2})
	s.start(c)
	s.transfer(6,7)
	s.transfer(7,6)
	check(s.goals.count(two)==1 and s.status=="active","moving same creature never produces another instance")
	var game = Scene.instantiate()
	game.save_path="res://.godot/campaign_test_save.json"
	# Fresh v2 player state, extra independent data preserved.
	var original_cells: Array=[]
	original_cells.resize(30)
	original_cells[6]=Catalog.make("wing",4)
	var original := Codec.encode(original_cells,777,42,"horn",{"wing:4":true},{"custom_settings":{"enabled":false}})
	write(game.save_path,JSON.stringify(original))
	var old_hash := FileAccess.get_sha256(game.save_path)
	root.add_child(game)
	game.view.sound.set_enabled(false)
	check(game.campaign_progress.stars==0 and game.campaign_progress.unlocked()==1,"v2 without campaign loads")
	check(not game.start_level(2),"future level locked")
	var total_reward := 0
	for number in range(1,11):
		check(game.start_level(number),"start unlocked level %d" % number)
		check(game.sandbox_cells==original_cells and game.active_species=="horn" and game.merges==42,"sandbox isolated on entry")
		check(not game.select_species("ultra"),"campaign cannot select arbitrary species")
		var proof: Dictionary=proofs[str(number)]
		for action in proof.actions:
			var coins_before: int=game.coins
			if action.kind=="spawn":
				check(game.campaign.next_species()==action.species_id and game.campaign.spawn_index()==action.index,"witness queue matches actual game")
				game._spawn()
			else:
				game._press(game.view.cell_center(action.source))
				game._release(game.view.cell_center(action.index))
			check(game.coins==coins_before or game.campaign.status=="won","campaign action spends no sandbox coins")
		check(game.campaign.status=="won" and game.campaign.moves_used==proof.moves and game.campaign.creations_used==proof.creations,"actual main replay wins %d" % number)
		check(game.view.panel_kind=="result" and game.view.creatures.size()==game.cells.size()-game.cells.count(null),"results and visuals synchronized")
		var reward: int=150 if number in [5,10] else 100
		total_reward+=reward
		check(game.coins==777+total_reward and game.campaign_progress.stars==number,"first reward exactly once")
		var state: Array=game.cells.duplicate(true)
		game._spawn()
		game._press(game.view.cell_center(1))
		check(game.cells==state and not game.dragging,"terminal main board locked")
		check(game.start_level(number),"replay permitted")
		for action in proof.actions:
			if action.kind=="spawn": game._spawn()
			else:
				game._press(game.view.cell_center(action.source))
				game._release(game.view.cell_center(action.index))
		check(game.coins==777+total_reward and game.campaign_progress.stars==number and game.last_reward.coins==0,"repeat no reward")
		game.leave_campaign()
		check(game.cells==original_cells and game.merges==42 and game.active_species=="horn","exit restores sandbox")
		await process_frame
	check(game.campaign_progress.completed.size()==10 and game.campaign_progress.claimed.size()==10,"all completed and claimed")
	var backup: String=game.save_path+".pre-update-"+old_hash.substr(0,12)+".bak"
	check(FileAccess.get_sha256(backup)==old_hash,"original v2 backup byte identical")
	game.start_level(10)
	game._spawn()
	game._save_game()
	check(game._load_game() and not game.in_campaign() and game.cells==original_cells and game.campaign_progress.stars==10,"reload restores sandbox and progress, no partial attempt")
	check(game.coins==1877 and game.save_extra.custom_settings.enabled==false,"currency and independent fields preserved")
	check(game.campaign_progress.finish(10).coins==0,"reload cannot duplicate award")
	game.start_level(4)
	for blocked_index in [0,4,25,29]:
		check(game._cell_at(game.view.cell_center(blocked_index))==-1,"blocked cells excluded from actual input")
	game._spawn()
	game._spawn()
	game._press(game.view.cell_center(1))
	game._release(game.view.cell_center(2))
	game.view.nav_left.pressed.emit()
	check(game.reset_dialog.visible,"restart asks before abandoning attempt")
	game.reset_dialog.confirmed.emit()
	game.reset_dialog.hide()
	check(game.campaign.creations_used==0 and game.campaign.moves_used==0 and game.campaign_progress.stars==10,"restart resets attempt only")
	game.leave_campaign()
	game.view.show_panel("levels")
	check(game.view.overlay.find_children("*","Button",true,false).size()==11,"ten levels and sandbox exit")
	game.view.overlay.find_children("*","Button",true,false)[3].pressed.emit()
	check(game.in_campaign() and game.campaign.config.number==4,"native level button opens matching configuration")
	game.start_level(1)
	await process_frame
	var balance: int=game.coins
	var touch := InputEventScreenTouch.new()
	touch.index=0
	touch.pressed=true
	touch.position=game.view.to_global(Vector2(180,580))
	root.push_input(touch,true)
	await process_frame
	touch=touch.duplicate()
	touch.pressed=false
	root.push_input(touch,true)
	await process_frame
	check(game.campaign.creations_used==1 and game.coins==balance,"native campaign touch spends creation, not coins")
	game.leave_campaign()
	game.view.close_panel()
	var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
	check(raw.schema_version==2 and raw.cells==JSON.parse_string(JSON.stringify(original_cells)),"v2 schema and sandbox field retained")
	raw.campaign={"version":99}
	write(game.save_path,JSON.stringify(raw))
	var bad_hash := FileAccess.get_sha256(game.save_path)
	check(not game._load_game() and game.write_blocked,"future campaign progress blocks overwrite")
	game._save_game()
	check(FileAccess.get_sha256(game.save_path)==bad_hash,"bad progress file preserved")
	for bad in [{"completed":"bad"},{"claimed":[1]},{"completed":[1,1]},{"stars":-1}]:
		check(not Progress.new().decode(bad),"invalid campaign data rejected")
	var partial := Progress.new()
	check(partial.decode({"completed":[1]}) and partial.finish(1).coins==0,"missing claim list never duplicates an uncertain reward")
	check(not Progress.new().decode({"completed":[1],"claimed":[]}),"inconsistent reward ledger protected")
	await create_timer(0.6).timeout
	game.free()
	write("res://.godot/campaign-solutions.json",JSON.stringify(proofs,"\t"))
	DirAccess.remove_absolute("res://.godot/campaign_test_save.json")
	print("Campaign checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
