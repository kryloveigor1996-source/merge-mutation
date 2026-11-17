extends SceneTree
const Session = preload("res://scripts/mutation_session.gd")
const Search = preload("res://scripts/mutation_search.gd")
const UI = preload("res://scripts/mutation_experiment.gd")
var checks := 0
var failures := 0
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:
		failures+=1
		printerr("FAIL: ",label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	edges()
	var report: Array=[]
	for number in range(1,6):
		var data := UI.config(number)
		check(not data.is_empty(),"valid JSON %d" % number)
		var session := Session.new()
		check(session.start(data),"start %d" % number)
		var proof := Search.solve(session)
		check(proof.won and proof.optimal and not proof.cutoff,"optimal proof %d" % number)
		print("Trial ",number,": ",proof)
		if not proof.won: continue
		var witness := Session.new()
		witness.start(data)
		for action in proof.actions: check(witness.apply_action(action).ok,"engine replay %d %s" % [number,action.kind])
		check(witness.status=="won" and witness.moves_used==proof.moves,"actual victory and optimal cost")
		for id in data.required:
			check(witness.used.has(id),"witness uses "+id)
			var counter := Session.new()
			counter.start(data)
			counter.disabled_abilities=[id]
			var impossible := Search.solve(counter)
			check(not impossible.won and not impossible.cutoff,"cannot bypass "+id)
		var shorter := Session.new()
		var bounded := data.duplicate(true)
		bounded.move_limit=proof.moves-1
		shorter.start(bounded)
		var lower := Search.solve(shorter)
		check(not lower.won and not lower.cutoff,"one fewer move is impossible")
		check(session.moves_used==0 and session.terrain==data.terrain,"search does not mutate original")
		report.append({"number":number,"moves":proof.moves,"visited":proof.visited,"actions":proof.actions})
	var file := FileAccess.open("res://.godot/mutation-solutions.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("Mutation checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
func edges() -> void:
	var ram := Session.new()
	ram.start(UI.config(1))
	check(not ram.transfer(10,11).ok and ram.moves_used==0,"movement never destroys rock")
	check(not ram.break_rock(10,12).ok,"only adjacent stone")
	check(ram.break_rock(10,11).ok and ram.moves_used==1 and ram.ground(11)=="normal","explicit rock action costs one move")
	check(not ram.break_rock(10,11).ok and ram.moves_used==1,"repeated destruction spends nothing")
	check(ram.transfer(10,11).ok,"destroyed cell supports normal movement")
	check(ram.spawn().ok and not ram.spawn().ok,"deterministic creation quota")
	var acid := Session.new()
	acid.start(UI.config(2))
	check(acid.transfer(5,6).ok and acid.transfer(6,7).ok and acid.transfer(7,6).ok and acid.transfer(6,5).ok,"slime remains controllable on acid and can return")
	acid.start(UI.config(2))
	acid.cells[5]={"species_id":"horn","evolution_stage":2}
	var before := acid.signature()
	check(not acid.transfer(5,6).ok and acid.signature()==before,"ordinary form cannot enter acid or lose a turn")
	var flyer := Session.new()
	flyer.start(UI.config(3))
	check(flyer.can_jump(10,12) and not flyer.can_transfer(10,11),"gap is not a landing cell")
	check(not flyer.can_jump(10,13),"no unlimited jump")
	flyer.cells[12]={"species_id":"wing","evolution_stage":1}
	check(not flyer.can_jump(10,12),"no occupied landing, even matching wing")
	flyer.cells[12]=null
	flyer.terrain["12"]="acid"
	check(not flyer.can_jump(10,12),"flight does not grant acid immunity")
	flyer.terrain["12"]="gap"
	check(not flyer.can_jump(10,13),"no two-gap crossing")
	flyer.start(UI.config(3))
	flyer.cells[10]={"species_id":"horn","evolution_stage":1}
	check(not flyer.can_jump(10,12),"ordinary form cannot jump")
	flyer.start(UI.config(3))
	check(flyer.transfer(10,12).kind=="jump" and flyer.moves_used==1,"jump costs exactly one move")
	check(flyer.transfer(12,13).kind=="merge" and flyer.cells[13].evolution_stage==2,"old merge rule evolves same species")
	var final := flyer.signature()
	check(not flyer.transfer(13,12).ok and flyer.signature()==final,"completed attempt cannot spend another move")
	for source in range(30):
		for destination in range(30):
			if flyer.blocked(destination): check(not flyer.can_transfer(source,destination),"absent cell never accepts movement")
	for bad in ["terrain","destination","reward","spawn"]:
		var data := UI.config(1)
		match bad:
			"terrain": data.terrain["99"]="gap"
			"destination": data.destinations[0].cell=0
			"reward": data.reward_coins=1
			"spawn": data.spawn_points=[11]
		check(not Session.valid_experiment(data),"reject invalid "+bad)
