extends "res://tests/landscape_ui_test.gd"
const G=preload("res://scripts/evolution_geometry.gd")
const Marks=preload("res://scripts/puzzle_marks.gd")
const OldSession=preload("res://scripts/mutation_session.gd")
const OldUI=preload("res://scripts/mutation_experiment.gd")
const ClassicLevels=preload("res://scripts/campaign_levels.gd")
const ClassicSolver=preload("res://tests/campaign_solver.gd")
var screen
var classic=false
func point(index: int) -> Vector2: return game.view.cell_center(index) if classic else screen.center(index) if screen.has_method("center") else G.center(index,game.view.portrait_mode)
func target() -> CanvasItem: return game.view if classic else screen
func state(): return game.campaign if classic else screen.session
func selected() -> int: return game.tap_source if classic else screen.selected
func pick(index: int,mouse: bool=false) -> void: tap(target(),point(index),mouse)
func coordinates(label: String) -> void:
	var sprites=game.view.creatures if classic else screen.sprites if screen.get("sprites") is Dictionary else screen.actors
	for index in range(30):
		check(sprites.has(index)==(state().cells[index]!=null),label+" actor occupancy")
		if sprites.has(index):
			var rest=game.view.rest_position(index,sprites[index]) if classic else point(index)
			check(sprites[index].position.distance_to(rest)<.01,label+" authoritative coordinate "+str(index))
func touch(index: int,down: bool,cell: int,canceled: bool=false) -> void:
	var e=InputEventScreenTouch.new()
	e.index=index; e.pressed=down; e.canceled=canceled
	e.position=target().get_global_transform_with_canvas()*point(cell)
	root.push_input(e,true)
func sandbox_drag(source: int,destination: int,canceled: bool=false) -> void:
	var start=InputEventScreenTouch.new()
	start.pressed=true; start.position=game.view.get_global_transform_with_canvas()*game.view.cell_center(source)
	root.push_input(start,true)
	var motion=InputEventScreenDrag.new()
	motion.position=game.view.get_global_transform_with_canvas()*game.view.cell_center(destination)
	root.push_input(motion,true)
	await create_timer(.06).timeout
	check(game.view.creatures[source].position.distance_to(game.view.rest_position(source,game.view.creatures[source]))>1,"sandbox regression really exercises a displaced sprite")
	start=start.duplicate(); start.pressed=false; start.canceled=canceled; start.position=motion.position
	root.push_input(start,true)
	await create_timer(.25).timeout
func regress(label: String,source: int,destination: int,diagonal: int,other: int) -> void:
	var signature=state().signature()
	pick(source)
	check(selected()==source,label+" select on release")
	pick(diagonal)
	check(selected()==source and state().signature()==signature,label+" invalid diagonal keeps selection and costs nothing")
	coordinates(label+" invalid diagonal")
	pick(source)
	check(selected()==-1,label+" second tap deselects")
	for mouse in [false,true]:
		drag(target(),point(source),point(destination),mouse)
		check(state().signature()==signature and selected()==-1,label+" swipe cannot select or move "+str(mouse))
		drag(target(),point(source),point(diagonal),mouse)
		check(state().signature()==signature,label+" diagonal drag cannot move")
		pick(source,mouse)
		drag(target(),point(destination),point(source),mouse)
		check(selected()==source and state().signature()==signature,label+" swipe with selection cannot act")
		pick(source,mouse)
	pick(source)
	touch(0,true,destination)
	await create_timer(.5).timeout
	touch(0,false,destination)
	check(selected()==source and state().signature()==signature,label+" selected target hold cannot act")
	pick(source)
	# Accumulated travel rejects an out-and-back gesture, even with identical endpoints.
	touch(0,true,source)
	var motion=InputEventScreenDrag.new()
	motion.position=target().get_global_transform_with_canvas()*point(destination)
	root.push_input(motion,true)
	motion=motion.duplicate(); motion.position=target().get_global_transform_with_canvas()*point(source); root.push_input(motion,true)
	touch(0,false,source)
	check(selected()==-1 and state().signature()==signature,label+" out-and-back swipe rejected")
	touch(0,true,source)
	await create_timer(.5).timeout
	touch(0,false,source)
	check(selected()==-1 and state().signature()==signature,label+" long hold does nothing")
	touch(0,true,source); touch(1,true,destination); touch(1,false,destination); touch(0,false,source)
	check(selected()==-1 and state().signature()==signature,label+" second finger cancels gesture")
	touch(0,true,source); touch(0,false,destination,true)
	check(selected()==-1 and state().signature()==signature,label+" canceled touch does nothing")
	pick(source); pick(other)
	check(selected()==other and state().signature()==signature,label+" incompatible mutant switches selection")
	pick(other); pick(source); pick(destination)
	var moved=state().signature()
	check(moved!=signature,label+" two taps act")
	for repeat in range(8): pick(destination); pick(source)
	check(state().signature()==moved,label+" rapid taps blocked during animation")
	game.view.set_portrait(not game.view.portrait_mode)
	check(state().signature()==moved,label+" orientation preserves committed action")
	coordinates(label+" orientation interruption")
	# Start a second action, then suspend before its tween finishes.
	pick(destination); pick(source)
	var suspended=state().signature()
	check(suspended!=moved,label+" reverse tap action before suspend")
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(state().signature()==suspended,label+" suspend never rolls back committed model")
	coordinates(label+" paused")
	game._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await create_timer(.43).timeout
	coordinates(label+" resumed")
	if not classic:
		if screen.has_method("undo"): screen.undo()
		else: screen.undo_action()
		await create_timer(.3).timeout
		check(state().signature()==moved,label+" Undo after interruption restores exact state")
		coordinates(label+" Undo")
	touch(0,true,source)
	game.view.set_portrait(not game.view.portrait_mode)
	var oriented=state().signature()
	touch(0,false,source)
	check(state().signature()==oriented and selected()==-1,label+" stale release after orientation ignored")
func run() -> void:
	game=Scene.instantiate(); game.save_path="res://.godot/pr22-fix-mobile-"+str(Time.get_ticks_usec())+".json"; game.audio_settings_path=game.save_path+".cfg"
	root.add_child(game); game.music.handle_lifecycle=false; game.music.set_volume("master",0)
	await process_frame
	await process_frame
	press_button(game.view.story_screen.get_node("StorySkip")); game.view.preferences.hints=false
	var glyphs={}
	for kind in ["move","merge","ability","mechanism","portal"]: glyphs[Marks.glyph(kind)]=true
	check(glyphs.size()==5,"five action kinds have unique non-colour glyphs")
	for tall in [false,true]:
		game.view.set_portrait(tall); root.size=Vector2i(G.design(tall)); await process_frame; game.view.layout()
		classic=true; game.start_level(1,false)
		# Use an isolated fixture on the existing campaign session; no campaign JSON is modified.
		game.campaign.cells.fill(null); game.campaign.cells[0]=game.Catalog.make("slime"); game.campaign.cells[4]=game.Catalog.make("horn")
		game.campaign.config.blocked_cells=[]; game.campaign.config.move_limit=100; game.campaign.status="active"; game.view.rebuild()
		await regress("classic",0,1,6,4)
		game.leave_campaign(); classic=false
		game.view.open_evolution(); screen=game.view.experiment_ui; screen.start_trial(4)
		screen.session.cells[17]=game.Catalog.make("slime"); screen.refresh()
		await regress("evolution",10,15,16,17)
		screen.leave(); await process_frame
		game.view.open_experiment(); screen=game.view.experiment_ui; screen.start_trial(1)
		screen.session.cells.fill(null); screen.session.cells[0]=game.Catalog.make("slime"); screen.session.cells[4]=game.Catalog.make("horn")
		screen.session.terrain.clear(); screen.session.config.blocked_cells=[]; screen.session.config.move_limit=100; screen.refresh()
		await regress("legacy",0,1,6,4)
		screen.exit_experiment(); await process_frame
	# All classic and old tactical solutions through actual two-tap UI, both orientations.
	var classic_proofs={}; var old_proofs={}
	for number in range(1,11):
		classic_proofs[number]=ClassicSolver.solve(ClassicLevels.get_level(number))
		var old=OldSession.new(); old.start(OldUI.config(number)); old_proofs[number]=Search.solve(old)
	for tall in [false,true]:
		game.view.set_portrait(tall); root.size=Vector2i(G.design(tall)); await process_frame; game.view.layout()
		classic=true
		for number in range(1,11):
			game.start_level(number,false)
			check(classic_proofs[number].won,"classic proof exists")
			for action in classic_proofs[number].actions:
				if action.kind=="spawn": press_button(game.view.create_button)
				else: pick(action.source,number%2==0); pick(action.index,number%2==0)
				await create_timer(.42).timeout
				coordinates("classic solution")
			check(game.campaign.status=="won","classic two-tap victory "+str(number))
			if game.campaign.status!="won": quit(1); return
		game.leave_campaign(); classic=false
		game.view.open_experiment(); screen=game.view.experiment_ui
		var original=FileAccess.get_sha256(game.save_path)
		for number in range(1,11):
			screen.start_trial(number)
			check(old_proofs[number].won,"legacy proof exists")
			for action in old_proofs[number].actions:
				if action.kind=="spawn": press_button(screen.get_node("ExperimentSpawn"))
				else: pick(action.source,number%2==0); pick(action.index,number%2==0)
				await create_timer(.29).timeout
				coordinates("legacy solution")
			check(screen.session.status=="won","legacy two-tap victory "+str(number))
			check(FileAccess.get_sha256(game.save_path)==original,"legacy does not mutate profile")
			if screen.session.status!="won": quit(1); return
		screen.exit_experiment(); await process_frame
	# Sandbox keeps free dragging; test its rollback in both orientations.
	for tall in [false,true]:
		game.view.set_portrait(tall); root.size=Vector2i(G.design(tall)); await process_frame; game.view.layout()
		game.view.close_navigation(); game.leave_campaign(); game.cells.fill(null)
		game.cells[0]=game.Catalog.make("slime"); game.cells[6]=game.Catalog.make("horn"); game.view.rebuild()
		var coins=game.coins
		await sandbox_drag(0,6)
		check(game.cells[0]!=null and game.cells[6].species_id=="horn" and game.coins==coins,"sandbox invalid merge preserves model")
		check(game.view.creatures[0].position.distance_to(game.view.rest_position(0,game.view.creatures[0]))<.01,"sandbox invalid drop returns to model")
		drag(game.view,game.view.cell_center(0),game.view.cell_center(1))
		await create_timer(.25).timeout
		check(game.cells[0]==null and game.cells[1]!=null,"sandbox drag still moves")
		await sandbox_drag(1,7,true)
		check(game.cells[1]!=null and game.cells[7]==null,"sandbox cancellation preserves model")
		check(game.view.creatures[1].position.distance_to(game.view.rest_position(1,game.view.creatures[1]))<.01 and game.tap_source==-1,"sandbox cancellation clears stale selection and restores position")
	game.free()
	print("Mobile control checks: %d; failures: %d; renderer: %s" % [checks,failures,DisplayServer.get_name()])
	quit(1 if failures else 0)
