extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const Progress=preload("res://scripts/core_progress.gd")
const Store=preload("res://scripts/profile_store.gd")
const C=preload("res://scripts/mutant_catalog.gd")
const Levels=preload("res://scripts/campaign_levels.gd")
const Solver=preload("res://tests/campaign_solver.gd")
var checks:=0
var failures:=0
var proofs: Dictionary={}
var folder:=""
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("FAIL: ",label)
func write(path: String,data: Variant) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
func load_game(path: String):
	var game=Scene.instantiate()
	game.save_path=path
	game.audio_settings_path=folder+"/audio.cfg"
	root.add_child(game)
	game.view.sound.set_enabled(false)
	return game
func play(game,number: int) -> void:
	check(game.start_level(number,false),"start campaign "+str(number))
	for action in proofs[number].actions:
		if action.kind=="spawn": game._spawn()
		else:
			game._press(game.view.cell_center(action.source))
			game._release(game.view.cell_center(action.index))
	check(game.campaign.status=="won","actual puzzle won "+str(number))
func run() -> void:
	folder="res://.godot/core-tests-"+str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	var ledger:=Progress.new()
	ledger.initial()
	check(ledger.balance()==3,"starting stock")
	var capped=ledger.copy()
	capped.data.bio_capsules=int(capped.config.resource.maximum)
	check(capped.claim("lab_01")==-1 and capped.data.claimed_levels.is_empty(),"overflow never consumes a claim")
	var total:=0
	for number in range(1,11):
		var id:="lab_%02d" % number
		var amount: int=ledger.claim(id)
		check(amount==(10 if number in [5,10] else 5),"configured level award "+id)
		total+=amount
		check(ledger.claim(id)==0,"one claim per level "+id)
	check(total==60 and ledger.balance()==63,"full campaign stock 63")
	for habitat in ledger.config.prices:
		var price:=0
		for amount in ledger.config.prices[habitat].values(): price+=int(amount)
		check(price==(18 if habitat=="habitat_slime" else 36),"habitat price total")
	var negative:=ledger.data.duplicate(true)
	negative.bio_capsules=-1
	check(not Progress.new().decode(negative,range(1,11)),"negative balance rejected")
	var missing:=ledger.data.duplicate(true)
	missing.claimed_levels.pop_back()
	check(not Progress.new().decode(missing,range(1,11)),"incomplete claim history protected")
	for number in range(1,11):
		proofs[number]=Solver.solve(Levels.get_level(number))
		check(proofs[number].won,"existing campaign solvable "+str(number))
	var path:=folder+"/fresh.json"
	var game=load_game(path)
	await process_frame
	await process_frame
	check(game.progression.balance()==3 and game.discoveries.is_empty(),"fresh normal profile: no free species")
	check(not game.developer_mode() and game.view.complex_ui.living_models.is_empty(),"no normal developer rooms")
	check(not game.install_item("habitat_slime","bed","slime_bed_basin").ok,"locked species cannot be bypassed")
	var expected_coins:=100
	for number in range(1,11):
		play(game,number)
		if number==10: check(is_instance_valid(game.view.story_screen),"existing swamp activation story retained")
		expected_coins+=150 if number in [5,10] else 100
		check(game.coins==expected_coins,"coin rewards preserved")
		check(game.progression.balance()==3+number*5+(5 if number>=5 else 0)+(5 if number>=10 else 0),"bio first reward durable")
		var balance: int=game.progression.balance()
		game.settle_campaign_action()
		check(game.progression.balance()==balance,"duplicate result confirmation")
		check(FileAccess.get_file_as_string(path).contains("core_progress"),"award persisted before result dismissal")
		play(game,number)
		check(game.last_reward.bio_capsules==0 and game.coins==expected_coins and game.progression.balance()==balance,"replay gives no one-time reward")
		game.leave_campaign()
		await process_frame
	check(game.species_known("slime") and game.species_known("eyeball") and game.species_known("horn") and not game.species_known("wing"),"actual campaign species order and collection")
	check(game.progression.balance()==63,"no extra resources from restarts")
	game._spawn()
	check(game.progression.balance()==63,"sandbox produces no capsules")
	for habitat in game.habitat_catalogs:
		var cat=game.habitat_catalogs[habitat]
		for id in cat.offers:
			check(game.install_item(habitat,id,cat.slots[id].designs[0].design_id).ok,"real installation "+habitat+" "+id)
	check(game.progression.balance()==9,"all sixteen upgrades affordable; nine left")
	var installed: Dictionary=game.progression.installed("habitat_slime")
	var choice: String=game.habitat_catalogs.habitat_slime.slots.bed.designs[2].design_id
	check(game.install_item("habitat_slime","bed",choice).ok and game.progression.balance()==9,"owned design changes freely")
	check(game.install_item("habitat_slime","bed",choice).ok and game.progression.balance()==9,"same confirmation never double spends")
	var hash:=FileAccess.get_sha256(path)
	var wrong=Store.write(path,{}, "wrong")
	check(not wrong.ok and FileAccess.get_sha256(path)==hash,"stale concurrent write cannot replace profile")
	game.view.open_complex()
	var ui=game.view.complex_ui
	var slime=ui.living_models.habitat_slime
	slime.reset_simulation(2)
	check(slime.request_slot("bed"),"observation triggered by actual object action")
	check(not game.progression.data.observations.has("slime_acid_sleep"),"click alone is not observation")
	for i in range(300): slime.advance(0.05)
	check(game.progression.data.observations.has("slime_acid_sleep"),"completed dissolution observed")
	for spec in [["habitat_slime","feeder","slime_plasma_feed"],["habitat_slime","laboratory","slime_lab_scan"],["habitat_horn","training","horn_training"],["habitat_horn","bed","horn_sleep"],["habitat_horn","feeder","horn_mineral_feed"]]:
		var model=ui.living_models[spec[0]]
		model.reset_simulation(2)
		check(model.request_slot(spec[1]),"request completed observation "+spec[2])
		for step in range(1800):
			model.advance(0.05)
			if game.progression.data.observations.has(spec[2]): break
		check(game.progression.data.observations.has(spec[2]),"actual action completes observation "+spec[2])
	check(game.progression.balance()==9,"six real observations pay no currency")
	var bio_before: int=game.progression.balance()
	var records_before: int=game.progression.data.observations.size()
	game.observe("habitat_slime","acid_sleep")
	check(game.progression.balance()==bio_before and game.progression.data.observations.size()==records_before,"observation is one-time and pays no currency")
	game.free()
	game=load_game(path)
	check(game.progression.balance()==9 and game.progression.installed("habitat_slime").bed==choice,"normal progress reloads")
	game.free()
	# Retroactive migration imports choices, never demo points, and pays each completed level once.
	var old_path:=folder+"/legacy.json"
	var old: Dictionary={"schema_version":2,"coins":777,"merges":42,"cells":[],"discoveries":["slime:1","horn:1"],"active_species":"horn","campaign":{"version":1,"completed":[1,2,3,4,5],"claimed":[1,2,3,4,5],"stars":5},"future_field":{"keep":true}}
	write(old_path,old)
	var old_hash:=FileAccess.get_sha256(old_path)
	var demo: Dictionary={"format":"merge_mutation_demo_renovation","version":2,"habitats":{"habitat_horn":{"points":999999,"installed":{"bed":"stone_nest"}}}}
	write(old_path+".habitat-demo-v1.json",demo)
	var demo_hash:=FileAccess.get_sha256(old_path+".habitat-demo-v1.json")
	game=load_game(old_path)
	check(not game.write_blocked and game.progression.balance()==33,"retroactive five levels plus start; no demo point conversion")
	check(game.coins==777 and game.merges==42 and game.save_extra.future_field.keep,"coins, collection and unknown fields retained")
	check(game.progression.installed("habitat_horn").get("bed")=="stone_nest","legacy design imported free")
	check(FileAccess.get_sha256(old_path+".pre-core-loop-"+old_hash.substr(0,12)+".bak")==old_hash,"main migration backup identical")
	check(FileAccess.get_sha256(old_path+".habitat-demo-v1.json")==demo_hash,"demo source unchanged")
	game.free()
	game=load_game(old_path)
	check(game.progression.balance()==33,"migration idempotent")
	game.free()
	# PR18 design aliases migrate through the existing map, without converting demo points.
	var pr18_path:=folder+"/pr18.json"
	write(pr18_path,old)
	write(pr18_path+".habitat-demo-v1.json",{"format":"merge_mutation_demo_renovation","version":1,"habitats":{"habitat_horn":{"points":800,"installed":{"bed":"stone_cave"}}}})
	game=load_game(pr18_path)
	check(not game.write_blocked and game.progression.installed("habitat_horn").get("bed")=="stone_nest","v1 design aliases migrate")
	check(game.progression.balance()==33,"v1 demo points never convert")
	game.free()
	var invalid_path:=folder+"/unknown-design.json"
	write(invalid_path,old)
	write(invalid_path+".habitat-demo-v1.json",{"format":"merge_mutation_demo_renovation","version":2,"habitats":{"habitat_horn":{"points":100,"installed":{"bed":"unknown_choice"}}}})
	var invalid_hash:=FileAccess.get_sha256(invalid_path)
	game=load_game(invalid_path)
	check(game.write_blocked and FileAccess.get_sha256(invalid_path)==invalid_hash,"unknown legacy choice blocks overwrite")
	game.free()
	# Failed persistence never grants a partial award.
	var failure_path:=folder+"/failed-save.json"
	game=load_game(failure_path)
	var valid_hash: String=game.expected_hash
	game.expected_hash="wrong"
	play(game,1)
	check(game.reward_pending and game.progression.balance()==3 and game.campaign_progress.completed.is_empty(),"write failure gives no partial claim")
	game.leave_campaign()
	check(game.in_campaign(),"uncommitted result cannot be dismissed")
	game.expected_hash=valid_hash
	game.settle_campaign_action()
	check(not game.reward_pending and game.progression.balance()==8,"retry commits one durable award")
	game.free()
	game=load_game(failure_path)
	check(game.progression.balance()==8,"restart after victory never repeats award")
	game.free()
	# Insufficient funds, abort and defeat do not yield capsules.
	game=load_game(folder+"/insufficient.json")
	play(game,1)
	game.leave_campaign()
	for slot in ["bed","feeder"]:
		check(game.install_item("habitat_slime",slot,game.habitat_catalogs.habitat_slime.slots[slot].designs[0].design_id).ok,"early first upgrades affordable")
	var balance: int=game.progression.balance()
	check(not game.install_item("habitat_slime","laboratory","slime_laboratory_centrifuge").ok and game.progression.balance()==balance,"unaffordable item rejected")
	game.start_level(2,false)
	game.leave_campaign()
	check(game.progression.balance()==balance,"abort no reward")
	game.start_level(2,false)
	game.campaign.status="lost"
	game.settle_campaign_action()
	check(game.progression.balance()==balance,"defeat no reward")
	game.free()
	# Corrupt ledger is retained, never silently reset on disk.
	var corrupt_path:=folder+"/corrupt.json"
	var corrupt: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	corrupt.core_progress.bio_capsules=-2
	write(corrupt_path,corrupt)
	var corrupt_hash:=FileAccess.get_sha256(corrupt_path)
	game=load_game(corrupt_path)
	check(game.write_blocked and FileAccess.get_sha256(corrupt_path)==corrupt_hash,"corrupt progress write-protected")
	check(not game.start_level(1,false),"damaged ledger cannot start a rewarding run")
	game.free()
	print("Core loop checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
