extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const UI=preload("res://scripts/mutation_experiment.gd")
const Session=preload("res://scripts/mutation_session.gd")
const Search=preload("res://scripts/mutation_search.gd")
var checks:=0
var failures:=0
var ui
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:
		failures+=1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func pointer(point: Vector2,down: bool) -> void:
	var event:=InputEventScreenTouch.new()
	event.position=ui.get_global_transform_with_canvas()*point
	event.pressed=down
	root.push_input(event,true)
func swipe(from: Vector2,to: Vector2) -> void:
	pointer(from,true)
	var event:=InputEventScreenDrag.new()
	event.position=ui.get_global_transform_with_canvas()*to
	event.relative=to-from
	root.push_input(event,true)
	pointer(to,false)
func run() -> void:
	root.size=Vector2i(360,720)
	var game=Scene.instantiate()
	game.save_path="res://.godot/challenge-navigation.json"
	root.add_child(game)
	game.view.open_experiment()
	ui=game.view.experiment_ui
	await create_timer(0.1).timeout
	for index in range(1,11):
		var button: Button=ui.find_child("Trial%d" % index,true,false)
		check(button!=null and button.size.y>=68 and button.size.x<=320,"large contained trial button")
	for repeat in range(4): swipe(Vector2(170,560),Vector2(170,250))
	check(ui.session==null and ui.trial_scroll.scroll_vertical>300,"rapid touch scrolling never starts a level")
	var last: Button=ui.find_child("Trial10",true,false)
	await process_frame
	var pos: Vector2=ui.get_global_transform_with_canvas().affine_inverse()*(last.get_global_transform_with_canvas()*Vector2(150,30))
	pointer(pos,true)
	pointer(pos,false)
	check(ui.number==10,"touch selects tenth trial after scroll")
	ui.show_list()
	await create_timer(0.1).timeout
	var wheel:=InputEventMouseButton.new()
	wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed=true
	wheel.position=ui.get_global_transform_with_canvas()*Vector2(170,300)
	root.push_input(wheel,true)
	check(ui.trial_scroll.scroll_vertical>0 and ui.session==null,"mouse wheel scrolls list")
	var mouse:=InputEventMouseButton.new()
	mouse.button_index=MOUSE_BUTTON_LEFT
	mouse.pressed=true
	mouse.position=ui.get_global_transform_with_canvas()*Vector2(180,560)
	root.push_input(mouse,true)
	var motion:=InputEventMouseMotion.new()
	motion.position=ui.get_global_transform_with_canvas()*Vector2(180,260)
	motion.relative=Vector2(0,-300)
	root.push_input(motion,true)
	mouse=mouse.duplicate()
	mouse.pressed=false
	mouse.position=motion.position
	root.push_input(mouse,true)
	check(ui.session==null and ui.trial_scroll.scroll_vertical>300,"mouse drag scrolls without activating a trial")
	for number in range(6,11):
		var data:=UI.config(number)
		for field in ["discovery_id","discovery_type","habitat_id"]:
			var invalid:=data.duplicate(true)
			invalid[field]=42
			check(not Session.valid_experiment(invalid),"metadata rejects invalid type")
			invalid.erase(field)
			check(Session.valid_experiment(invalid),"metadata remains optional")
		var lost:=Session.new()
		data.move_limit=1
		check(lost.start(data),"short attempt starts")
		var actions: Array=lost.legal_actions()
		check(not actions.is_empty() and lost.apply_action(actions[0]).ok and lost.status=="lost","move exhaustion produces understandable defeat")
		check(ui.start_trial(number) and ui.session.status=="active" and ui.session.moves_used==0,"restart after defeat")
		ui.session=lost
		ui.refresh()
		check(ui.message.text==lost.reason,"defeat reason appears in UI")
		await process_frame
		pointer(Vector2(98,624),true)
		pointer(Vector2(98,624),false)
		check(ui.session.status=="active" and ui.session.moves_used==0,"native restart button recovers from defeat")
		var cutoff:=Search.solve(ui.session,1)
		check(cutoff.cutoff and not cutoff.won and not cutoff.optimal,"budget cutoff never claims proof")
	# Deliberately deliver Slime before Wing: the goal at 0 then blocks Wing's route.
	var wrong:=Session.new()
	wrong.start(UI.config(10))
	var prefix: Array=[{"kind":"break","source":0,"index":1}]
	for pair in [[2,1],[1,0],[3,13],[0,1],[1,2],[2,3],[3,4],[13,14],[22,23],[23,18],[18,13],[13,12],[12,7],[7,2],[2,1],[1,0]]:
		prefix.append({"kind":"move","source":pair[0],"index":pair[1]})
	for action in prefix: check(wrong.apply_action(action).ok,"wrong-order branch is a real playable choice")
	var dead_end:=Search.solve(wrong)
	check(not dead_end.won and not dead_end.cutoff,"premature slime delivery exceeds remaining chapter budget")
	game.free()
	print("Challenge navigation checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
