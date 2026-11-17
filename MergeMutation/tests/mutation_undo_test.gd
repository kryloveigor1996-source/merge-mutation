extends SceneTree
const Session=preload("res://scripts/mutation_session.gd")
const History=preload("res://scripts/mutation_history.gd")
const UI=preload("res://scripts/mutation_experiment.gd")
var checks:=0
var failures:=0
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:
		failures+=1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
static func state(session) -> String:
	return JSON.stringify([session.config,session.cells,session.terrain,session.disabled_abilities,session.used,session.creations_used,session.moves_used,session.status,session.reason,session.goals.produced,session.goals.merges,session.boosters.charges],"",true)
static func fixture(species: String="slime") -> Dictionary:
	var data:=UI.config(10)
	data.initial=[{"cell":0,"species_id":species,"evolution_stage":1}]
	data.terrain={}
	data.blocked_cells=range(5,30)
	data.goals=[{"type":"reach_stage","species_id":species,"evolution_stage":2}]
	data.destinations=[{"cell":4,"species_id":species,"evolution_stage":2}]
	data.move_limit=12
	return data
func expect_undo(session,action: Dictionary,label: String) -> void:
	var history:=History.new()
	var before:=state(session)
	check(history.execute(session,action).ok,label+" succeeds")
	check(history.snapshots.size()==1 and history.remaining==2,label+" single snapshot")
	check(history.undo(session) and state(session)==before,label+" restores every mutable field")
	check(history.remaining==1 and not history.can_undo(),label+" charge outside snapshot")
func run() -> void:
	var session:=Session.new()
	check(session.start(fixture()),"fixture valid")
	expect_undo(session,{"kind":"move","source":0,"index":1},"ordinary move")
	session.start(UI.config(1))
	expect_undo(session,{"kind":"spawn"},"free creation")
	expect_undo(session,{"kind":"break","source":10,"index":11},"stone destruction")
	session.start(UI.config(2))
	expect_undo(session,{"kind":"move","source":5,"index":6},"acid movement")
	session.start(UI.config(3))
	expect_undo(session,{"kind":"jump","source":10,"index":12},"flight")
	session.transfer(10,12)
	expect_undo(session,{"kind":"merge","source":12,"index":13},"winning merge")
	var data:=fixture()
	data.move_limit=1
	session.start(data)
	var history:=History.new()
	var before:=state(session)
	history.execute(session,{"kind":"move","source":0,"index":1})
	check(session.status=="lost" and not session.reason.is_empty(),"defeat after last move")
	check(session.fork().status==session.status and session.fork().reason==session.reason,"fork preserves terminal status and reason")
	check(history.undo(session) and state(session)==before and session.status=="active","undo after defeat")
	session.start(fixture())
	history.reset()
	for pair in [[0,1],[1,2]]: check(history.execute(session,{"kind":"move","source":pair[0],"index":pair[1]}).ok,"sequential history")
	check(history.undo(session) and session.cells[1]!=null,"first undo")
	check(history.undo(session) and session.cells[0]!=null and session.moves_used==0,"second undo")
	history.execute(session,{"kind":"move","source":0,"index":1})
	before=state(session)
	check(not history.undo(session) and history.remaining==0 and state(session)==before,"third undo forbidden after a new action too")
	history.reset()
	session.start(fixture())
	check(history.remaining==2 and history.snapshots.is_empty() and not history.undo(session),"new attempt cannot undo previous attempt")
	before=state(session)
	check(not history.execute(session,{"kind":"move","source":0,"index":4}).ok and state(session)==before and history.snapshots.is_empty(),"failed action is not recorded")
	expect_undo(session,{"kind":"corridor","source":0,"index":4},"four-step corridor")
	var single:=Session.new()
	single.start(fixture())
	for index in range(1,5): single.transfer(index-1,index)
	check(session.corridor(0,4).ok and session.moves_used==4 and state(session)==state(single),"full equivalence to four ordinary moves")
	for species in ["slime","horn","wing"]:
		for obstruction in ["rock","gap","absent","occupied","acid","budget","diagonal","merge"]:
			data=fixture(species)
			match obstruction:
				"rock","gap","acid": data.terrain["2"]=obstruction
				"absent": data.blocked_cells.append(2)
				"occupied": data.initial.append({"cell":2,"species_id":species,"evolution_stage":1})
				"budget": data.move_limit=3
				"merge": data.initial.append({"cell":4,"species_id":species,"evolution_stage":1})
				"diagonal": data.blocked_cells.erase(6)
			session.start(data)
			before=state(session)
			var target:=6 if obstruction=="diagonal" else 4
			var result: Dictionary=session.corridor(0,target)
			if obstruction=="acid" and species=="slime":
				check(result.ok and session.used.has("acid"),"slime corridor crosses acid")
			else: check(not result.ok and state(session)==before,"atomic rejection "+species+" "+obstruction)
	# Exact move budget, reverse path and intermediate victory all use the same rules.
	data=fixture()
	data.move_limit=4
	session.start(data)
	check(session.corridor(0,4).ok and session.moves_used==4 and session.status=="lost","exact budget commits then evaluates defeat")
	expect_undo(single,{"kind":"corridor","source":4,"index":0},"reverse corridor")
	data=fixture()
	data.initial[0].evolution_stage=2
	data.destinations[0].cell=2
	session.start(data)
	before=state(session)
	check(not session.corridor(0,4).ok and state(session)==before,"cannot continue through an intermediate victory")
	check(session.corridor(0,2).ok and session.status=="won","can finish at the winning cell")
	data=fixture()
	data.blocked_cells=[]
	for index in range(30):
		if index%5!=0: data.blocked_cells.append(index)
	data.destinations[0].cell=25
	session.start(data)
	check(session.corridor(0,20).ok and session.moves_used==4 and session.cells[20]!=null,"vertical corridor spends exact distance")
	expect_undo(session,{"kind":"corridor","source":20,"index":0},"vertical reverse corridor")
	data=fixture()
	data.terrain["0"]="acid"
	session.start(data)
	check(session.corridor(0,4).ok and session.used.has("acid"),"slime can start a corridor on acid")
	data=fixture()
	data.terrain={"1":"acid","2":"acid"}
	session.start(data)
	expect_undo(session,{"kind":"corridor","source":0,"index":4},"acid corridor")
	single.start(data)
	for index in range(1,5): single.transfer(index-1,index)
	check(session.corridor(0,4).ok and state(session)==state(single),"acid corridor matches sequential steps including ability bookkeeping")
	# Deep snapshot isolation, including fields that do not affect the board signature.
	session.start(fixture())
	history.reset()
	before=state(session)
	history.execute(session,{"kind":"move","source":0,"index":1})
	session.config.tip="changed"
	session.disabled_abilities.append("acid")
	session.boosters.charges.test=99
	check(history.undo(session) and state(session)==before,"deep immutable snapshot restores config, abilities and booster fields")
	for action in session.legal_actions(): check(action.kind not in ["undo","corridor"],"solver uses only primitive actions")
	print("Undo/corridor checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
