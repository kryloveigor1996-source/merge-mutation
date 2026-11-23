extends "res://scripts/core_game.gd"
const MobileView=preload("res://scripts/mobile_lab.gd")
const EvolutionView=preload("res://scripts/evolution_lab.gd")
const Movement=preload("res://scripts/evolution_movement.gd")
var tap_source=-1
var tap_destination=-1
var press_origin=Vector2.ZERO
var previous_bio=0
func make_view():
	var isolated: bool=save_path.begins_with("res://.godot/") or ProjectSettings.globalize_path(save_path).contains("/.godot/")
	if legacy_mode() or (not OS.has_feature("android") and isolated and "--pr21-regression" in OS.get_cmdline_user_args()): return super.make_view()
	return EvolutionView.new() if not OS.has_feature("android") and isolated and "--pr22-regression" in OS.get_cmdline_user_args() else MobileView.new()
func evolved_ui() -> bool: return is_instance_valid(view) and view.has_method("native_design")
func _ready() -> void:
	super._ready()
	if evolved_ui():
		previous_bio=progression.balance()
		progression_changed.connect(func():
			if progression.balance()>previous_bio: view.tutorial.request("first_capsules","Биокапсулы открывают новые предметы вольеров. Найдите стройплощадку в комплексе.",Rect2(18,14,350,42) if view.portrait_mode else Rect2(24,18,310,34),"complex")
			previous_bio=progression.balance()
		)
const Tap=preload("res://scripts/puzzle_tap.gd")
var puzzle_gesture=Tap.new()
var control_busy=false
var control_animation: Tween
func _press(point: Vector2) -> void:
	if not evolved_ui(): super._press(point); return
	if in_campaign(): return # Puzzle commands are exclusively release-qualified taps.
	if view.input_blocked() or dragging: return
	var index=view.cell_index(point)
	if index<0: return
	press_origin=point; tap_destination=-1
	if tap_source>=0 and index!=tap_source and (cells[index]==null or Catalog.can_merge(cells[tap_source],cells[index])):
		selected=tap_source; tap_destination=index
	elif cells[index]!=null: selected=index; tap_source=-1
	else: tap_source=-1; return
	dragging=true; pointer_pos=point; view.pick(selected)
func _release(point: Vector2) -> void:
	if not evolved_ui(): super._release(point); return
	if in_campaign(): return
	if not dragging: return
	if view.cell_index(point)==selected and point.distance_to(press_origin)<12:
		tap_source=selected; _cancel_drag(); view.queue_redraw(); return
	tap_source=-1
	super._release(point)
	view.queue_redraw()
func choose_puzzle(index: int) -> void:
	if control_busy or view.input_blocked() or not in_campaign() or campaign.status!="active" or index<0: return
	if index==tap_source:
		tap_source=-1; selected=-1
	elif tap_source>=0:
		var legal: bool=campaign.can_transfer(tap_source,index) if teleport_mode else Movement.apply(campaign,tap_source,index,false).ok
		if teleport_mode:
			var trial=campaign.fork()
			legal=trial.use_booster("teleporter",tap_source,index).ok
		if legal:
			var result=campaign.use_booster("teleporter",tap_source,index) if teleport_mode else Movement.apply(campaign,tap_source,index)
			if result.ok:
				teleport_mode=false; tap_source=-1; selected=-1
				control_busy=true
				campaign_result(result); view.preferences.master("movement"); view.preferences.master("tap_controls")
				lock_control()
			return
		if cells[index]!=null: tap_source=index; selected=index
	elif cells[index]!=null: tap_source=index; selected=index
	view.queue_redraw()
func lock_control() -> void:
	control_busy=true; puzzle_gesture.cancel()
	if control_animation: control_animation.kill()
	control_animation=create_tween()
	control_animation.tween_interval(0.40)
	control_animation.tween_callback(func(): control_busy=false; view.sync_puzzle_art())
func cancel_control() -> void:
	puzzle_gesture.cancel()
	if control_animation: control_animation.kill()
	control_busy=false; tap_source=-1
	_cancel_drag()
	if evolved_ui():
		if in_campaign(): view.sync_puzzle_art()
		if is_instance_valid(view.experiment_ui) and view.experiment_ui.has_method("cancel_control"): view.experiment_ui.cancel_control()
func _spawn() -> void:
	if evolved_ui() and in_campaign():
		if control_busy or puzzle_gesture.active: return
		super._spawn()
		tap_source=-1; selected=-1; lock_control()
	else: super._spawn()
func toggle_teleporter() -> void:
	if evolved_ui() and in_campaign():
		if control_busy or puzzle_gesture.active: return
		super.toggle_teleporter()
		_notice("Выберите мутанта, затем свободную клетку" if teleport_mode else "Выберите мутанта, затем отмеченную клетку")
		view.target_key=""; view.queue_redraw()
	else: super.toggle_teleporter()
func start_level(number: int,test_boosters: bool=true) -> bool:
	cancel_control()
	var ok=super.start_level(number,test_boosters)
	if ok and evolved_ui(): view.tutorial.request("tap_controls","Нажмите на мутанта, затем на отмеченную клетку. Повторное нажатие снимает выбор. Цифра — цена.",EvolutionView.G.board(view.portrait_mode),"campaign")
	return ok
func leave_campaign() -> void:
	cancel_control()
	super.leave_campaign()
func _notification(what: int) -> void:
	super._notification(what)
	if not evolved_ui(): return
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT]: cancel_control()
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_RESUMED]:
		view.app_suspended=what==NOTIFICATION_APPLICATION_PAUSED
		if is_instance_valid(music): music.suspend(view.app_suspended)
func open_portals() -> void:
	if evolved_ui():
		if reward_pending: return
		view.close_navigation()
	super.open_portals()
func open_world_map(world_id: String) -> bool:
	if evolved_ui():
		if reward_pending or not Worlds.unlocked(world_id,completed_world_level_ids()): return false
		view.close_navigation()
	return super.open_world_map(world_id)
func _gui_input(event: InputEvent) -> void:
	if evolved_ui() and in_campaign():
		if view.input_blocked() or control_busy: puzzle_gesture.cancel(); accept_event(); return
		var click=puzzle_gesture.feed(event)
		if not click.is_empty():
			var from=view.cell_index(_design_position(click.origin))
			var to=view.cell_index(_design_position(click.point))
			if from==to: choose_puzzle(to)
		accept_event(); return
	if evolved_ui() and event is InputEventScreenTouch and event.canceled and event.index==0:
		tap_source=-1; _cancel_drag(); accept_event(); return
	super._gui_input(event)

func _notice(value: String) -> void:
	super._notice(value)
	if is_instance_valid(view) and view.has_method("show_notice"): view.show_notice(value)
