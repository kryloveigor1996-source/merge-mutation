extends "res://scripts/modular_habitat_state.gd"
signal action_completed(habitat: String,event: String)
const Autonomy=preload("res://scripts/ecosystem_autonomy.gd")
const Behaviors=preload("res://scripts/ecosystem_behaviors.gd")
var ecology: Dictionary={}
var species_behavior
var simulation_time:=0.0
var last_player_command:=-10.0
var auto_history: Dictionary={}
var autonomous_log: Array=[]
var current_autonomous:=false
var selecting_auto:=false
var rest_variant:=""
var action_semantic:=""
var pending_curiosity:=""
var known_installed: Dictionary={}
var attaching:=false
var rare_event:=""
var rare_elapsed:=0.0
var rare_duration:=0.0
var rare_next:=18.0
var event_next: Dictionary={}
var rare_log: Array=[]
var action_deadline:=0.0
var sleep_duration:=6.0
var last_successful_ram:=-1000.0
func reset_simulation(seed_value: int) -> void:
	rng.seed=seed_value
	cancel_action()
	position=Vector2(profile.start_x,profile.ground_y)
	target=position
	facing=1
	remaining=1.5
	simulation_time=0
	last_player_command=-10
	auto_history.clear()
	autonomous_log.clear()
	rare_log.clear()
	event_next.clear()
	rare_next=18
	pending_curiosity=""
	stone_broken=false
	restore_left=0
	hit_count=0
	last_successful_ram=-1000
	stage_changed.emit()
func configure_ecology(entry: Dictionary) -> void:
	ecology=entry
	species_behavior=Behaviors.DRIVERS[entry.behavior_driver].new()
	profile.allowed_behaviors=species_behavior.allowed_states()
	camera_positions["ecosystem"]=0.0
	panorama=registry.world_width>940
func attach(value) -> void:
	attaching=true
	super.attach(value)
	known_installed=renovation.installed.duplicate()
	attaching=false
func rebuild_objects() -> void:
	if renovation==null: return
	if not attaching and known_installed==renovation.installed: return
	var fresh:=""
	for id in renovation.installed:
		if not known_installed.has(id): fresh=id
	super.rebuild_objects()
	known_installed=renovation.installed.duplicate()
	if not attaching and not fresh.is_empty(): pending_curiosity=fresh
func request_slot(id: String) -> bool:
	if not selecting_auto:
		if current_autonomous or not rare_event.is_empty(): cancel_action()
		last_player_command=simulation_time
	if not rare_event.is_empty(): return false
	var ok:=super.request_slot(id)
	if ok:
		rest_variant=""
		current_autonomous=selecting_auto
		action_semantic=renovation.catalog.slots[id].get("action","")
		action_deadline=simulation_time+minf(180,absf(target.x-position.x)/maxf(profile.movement_speed,1)*2+6)
	return ok
func auto_slot(id: String) -> bool:
	selecting_auto=true
	var ok:=request_slot(id)
	selecting_auto=false
	return ok
func move_to_point(requested: Vector2,after: String="") -> bool:
	var ok:=super.move_to_point(requested,after)
	if ok: action_deadline=simulation_time+minf(180,absf(target.x-position.x)/maxf(profile.movement_speed,1)*2+6)
	return ok
func react() -> bool:
	if current_autonomous or not rare_event.is_empty(): cancel_action()
	last_player_command=simulation_time
	return super.react()
func cancel_action() -> void:
	super.cancel_action()
	current_autonomous=false
	rare_event=""
	rest_variant=""
	action_semantic=""
func choose_next() -> void:
	if not rare_event.is_empty(): return
	if simulation_time>=rare_next and rng.randf()<0.25:
		var possible: Array=[]
		var total:=0.0
		for event in ecology.rare_events:
			if can_rare(event.event_id):
				possible.append(event)
				total+=event.weight
		var sample: float=rng.randf()*total
		for event in possible:
			sample-=event.weight
			if sample<=0 and request_rare(event.event_id): return
	if not Autonomy.choose(self): enter("idle",0.8)
func can_rare(id: String) -> bool:
	if not action_slot.is_empty() or not rare_event.is_empty() or simulation_time<rare_next or simulation_time-last_player_command<2: return false
	for event in ecology.rare_events:
		if event.event_id!=id or simulation_time<float(event_next.get(id,0)): continue
		var slot: String=event.get("requires_slot","")
		if not slot.is_empty() and not renovation.installed.has(slot): return false
		return species_behavior.can_event(self,id)
	return false
func request_rare(id: String) -> bool:
	if not can_rare(id): return false
	for event in ecology.rare_events:
		if event.event_id!=id: continue
		rare_event=id
		rare_elapsed=0
		rare_duration=event.duration
		rare_next=simulation_time+15
		event_next[id]=simulation_time+event.cooldown
		rare_log.append({"id":id,"time":simulation_time})
		if rare_log.size()>50: rare_log.pop_front()
		enter("react",rare_duration)
		feedback=species_behavior.event_text(id)
		feedback_left=rare_duration
		return true
	return false
func advance(delta: float) -> void:
	simulation_time+=delta
	var previous:=behavior
	var previous_slot:=action_slot
	var semantic:=action_semantic
	super.advance(delta)
	if not rare_event.is_empty():
		rare_elapsed+=delta
		if rare_elapsed>=rare_duration:
			action_completed.emit(habitat_id,rare_event)
			rare_event=""
			enter("idle",1)
	if previous=="walk" and behavior!="walk" and not action_slot.is_empty(): species_behavior.arrived(self,action_semantic)
	if not previous_slot.is_empty() and action_slot.is_empty():
		current_autonomous=false
		action_semantic=semantic
		if semantic=="ram" and stone_broken: last_successful_ram=simulation_time
		species_behavior.completed(self,semantic)
		if semantic!="ram" or stone_broken: action_completed.emit(habitat_id,semantic)
		if rare_event.is_empty(): action_semantic=""
	if behavior=="walk" and simulation_time>action_deadline:
		cancel_action()
		feedback="Попробую другой подход"
		feedback_left=2
