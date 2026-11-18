extends "res://scripts/habitat_state.gd"
## Interaction targets adapt the existing six-state FSM; no furniture-specific FSMs.
var renovation
var runtime_objects: Array=[]
var action_slot:=""
var action_kind:=""
var feedback:=""
var feedback_left:=0.0
var lighting_on:=true
var panorama:=false
var camera_positions: Dictionary={"normal":0.0,"panorama":0.0}
func renovation_objects() -> Array: return runtime_objects
func attach(value) -> void:
	renovation=value
	profile=profile.duplicate(true)
	stage=3 # Internal compatibility with the existing ram guard, not a room upgrade.
	renovation.changed.connect(rebuild_objects)
	renovation.preview_changed.connect(func(): stage_changed.emit())
	rebuild_objects()
func inhabited() -> bool: return true
func objects() -> Array:
	return runtime_objects if renovation!=null else super.objects()
func rebuild_objects() -> void:
	runtime_objects.clear()
	if renovation==null: return
	var catalog=renovation.catalog
	for id in renovation.installed:
		var slot: Dictionary=catalog.slots[id]
		var rect: Rect2=catalog.project_rect(slot,registry.world_width)
		var object: Dictionary={"object_id":id,"slot_id":id,"type":"training" if slot.interaction=="training" else slot.interaction,"interaction":slot.interaction,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"solid":not slot.collision.is_empty(),"layer":slot.layer}
		if object.solid:
			var collision: Rect2=catalog.project_rect(slot,registry.world_width,"collision")
			object["collision_rect"]=[collision.position.x,collision.position.y,collision.size.x,collision.size.y]
		runtime_objects.append(object)
	cancel_action()
	stone_broken=false
	restore_left=0
	stage_changed.emit()
func cancel_action() -> void:
	action_slot=""
	action_kind=""
	intent=""
	behavior="idle"
	elapsed=0
	remaining=2
	cooldown=0
	target=position
func switch_panorama(value: bool) -> void:
	var fraction: float=position.x/registry.world_width
	panorama=value
	registry.world_width=2350 if value else 940
	profile.walk_range=[48,registry.world_width-48]
	profile.movement_speed=80 if value else 58
	position=Vector2(clampf(fraction*registry.world_width,48,registry.world_width-48),profile.ground_y)
	var broken:=stone_broken
	var restore:=restore_left
	rebuild_objects()
	stone_broken=broken
	restore_left=restore
func react() -> bool:
	return false if not action_slot.is_empty() else super.react()
func request_ram() -> bool:
	if renovation==null: return super.request_ram()
	for object in objects():
		if object.interaction=="training": return request_slot(object.slot_id)
	return false
func request_slot(id: String) -> bool:
	if renovation==null or not renovation.installed.has(id) or not action_slot.is_empty() or cooldown>0 or behavior=="ram" or not intent.is_empty(): return false
	var slot: Dictionary=renovation.catalog.slots[id]
	var kind: String=slot.interaction
	if kind=="none" or kind=="training" and stone_broken: return false
	if kind=="light":
		lighting_on=not lighting_on
		feedback="Свет включён" if lighting_on else "Свет выключен"
		feedback_left=2
		cooldown=profile.interaction_cooldown
		stage_changed.emit()
		return true
	var rect: Rect2=renovation.catalog.project_rect(slot,registry.world_width)
	var approach: float=clampf(rect.position.x-profile.body_radius-3 if kind=="training" else rect.get_center().x,profile.walk_range[0],profile.walk_range[1])
	var requested:=Vector2(approach,profile.ground_y)
	if motion_driver.constrain_target(position,requested,profile,objects()).distance_to(requested)>0.01: return false
	action_slot=id
	action_kind=kind
	cooldown=profile.interaction_cooldown
	return walk_to(approach,"ram" if kind=="training" else "inspect")
func choose_next() -> void:
	if renovation!=null and cooldown==0 and rng.randi_range(0,3)==0:
		var choices: Array=[]
		for object in objects():
			if object.interaction in ["sleep","feed","play","training","storage"]: choices.append(object.slot_id)
		if not choices.is_empty() and request_slot(choices[rng.randi_range(0,choices.size()-1)]): return
	super.choose_next()
func advance(delta: float) -> void:
	var previous:=behavior
	super.advance(delta)
	feedback_left=maxf(0,feedback_left-delta)
	if action_slot.is_empty(): return
	if previous=="walk" and behavior=="inspect":
		match action_kind:
			"sleep": enter("sleep",2.4); feedback="Тихий час"
			"feed": enter("inspect",1.6); feedback="Небольшой перекус"
			"play": enter("react",1.4); feedback="Время поиграть!"
			"storage": enter("inspect",1.2); feedback="Припасы на месте"
		feedback_left=2.4
	elif previous=="walk" and behavior=="ram":
		var rock: Rect2=renovation.catalog.project_rect(renovation.catalog.slots[action_slot],registry.world_width)
		facing=1 if rock.get_center().x>=position.x else -1
		feedback="Проверка на прочность!"
		feedback_left=2
	elif previous in ["inspect","sleep","react","ram"] and behavior=="idle":
		action_slot=""
		action_kind=""
