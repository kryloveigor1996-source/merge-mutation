extends "res://scripts/core_game.gd"
const EvolutionView=preload("res://scripts/evolution_lab.gd")
const Movement=preload("res://scripts/evolution_movement.gd")
var tap_source=-1
var tap_destination=-1
var press_origin=Vector2.ZERO
var previous_bio=0
func make_view():
	var isolated: bool=save_path.begins_with("res://.godot/") or ProjectSettings.globalize_path(save_path).contains("/.godot/")
	if legacy_mode() or (not OS.has_feature("android") and isolated and "--pr21-regression" in OS.get_cmdline_user_args()): return super.make_view()
	return EvolutionView.new()
func evolved_ui() -> bool: return is_instance_valid(view) and view.has_method("native_design")
func _ready() -> void:
	super._ready()
	if evolved_ui():
		previous_bio=progression.balance()
		progression_changed.connect(func():
			if progression.balance()>previous_bio: view.tutorial.request("first_capsules","Биокапсулы открывают новые предметы вольеров. Найдите стройплощадку в комплексе.",Rect2(18,14,350,42) if view.portrait_mode else Rect2(24,18,310,34),"complex")
			previous_bio=progression.balance()
		)
func _press(point: Vector2) -> void:
	if not evolved_ui(): super._press(point); return
	if view.input_blocked() or dragging or in_campaign() and campaign.status!="active": return
	var index=view.cell_index(point)
	if index<0 or in_campaign() and campaign.blocked(index): return
	press_origin=point; tap_destination=-1
	if tap_source>=0 and index!=tap_source and (cells[index]==null or Catalog.can_merge(cells[tap_source],cells[index])):
		selected=tap_source; tap_destination=index
	elif cells[index]!=null: selected=index; tap_source=-1
	else: tap_source=-1; return
	dragging=true; pointer_pos=point
	view.pick(selected)
func _release(point: Vector2) -> void:
	if not evolved_ui(): super._release(point); return
	if not dragging: return
	var destination=tap_destination if tap_destination>=0 and point.distance_to(press_origin)<12 else view.cell_index(point)
	if destination==selected and point.distance_to(press_origin)<12:
		tap_source=selected
		_cancel_drag()
		view.queue_redraw()
		return
	tap_source=-1
	if in_campaign():
		var result=campaign.use_booster("teleporter",selected,destination) if teleport_mode else Movement.apply(campaign,selected,destination)
		if result.ok: teleport_mode=false; campaign_result(result); view.preferences.master("movement")
		else: _notice(result.get("reason","Действие недоступно")); view.reject_drop(destination)
		_cancel_drag()
	else: super._release(point)
	view.queue_redraw()
func start_level(number: int,test_boosters: bool=true) -> bool:
	tap_source=-1
	return super.start_level(number,test_boosters)
func leave_campaign() -> void:
	tap_source=-1
	super.leave_campaign()
func _notification(what: int) -> void:
	super._notification(what)
	if not evolved_ui(): return
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT]: tap_source=-1
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
	if evolved_ui() and event is InputEventScreenTouch and event.canceled and event.index==0:
		tap_source=-1; _cancel_drag(); accept_event(); return
	super._gui_input(event)