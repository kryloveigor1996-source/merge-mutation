extends RefCounted
signal stage_changed
var registry
var profile: Dictionary={}
var motion_driver
var habitat_id:=""
var stage:=2
var behavior:="idle"
var position:=Vector2(165,354)
var facing:=1.0
var elapsed:=0.0
var remaining:=0.0
var cooldown:=0.0
var target:=Vector2(165,354)
var intent:=""
var stone_broken:=false
var restore_left:=0.0
var hit_count:=0
var transitions:=0
var rng:=RandomNumberGenerator.new()
func setup(id: String,config,seed_value: int=-1) -> void:
	registry=config
	habitat_id=id
	var assignment: Dictionary=config.assignments[id]
	profile=config.profiles[assignment.behavior_profile]
	motion_driver=config.MOTION_DRIVERS[profile.movement_type]
	if seed_value<0: rng.randomize()
	else: rng.seed=seed_value
	set_stage(int(assignment.default_stage))
func inhabited() -> bool: return registry.stages[stage].resident
func objects() -> Array: return registry.stage_objects(stage)
func enter(state: String,duration: float=-1) -> bool:
	if not inhabited() or state not in profile.allowed_behaviors or state=="ram" and stage<3: return false
	behavior=state
	elapsed=0
	transitions+=1
	if duration>=0: remaining=duration
	elif state=="sleep": remaining=rng.randf_range(profile.sleep_duration_range[0],profile.sleep_duration_range[1])
	else: remaining=rng.randf_range(profile.idle_duration_range[0],profile.idle_duration_range[1])
	return true
func set_stage(value: int) -> bool:
	if registry==null or not registry.stages.has(value): return false
	stage=value
	position=motion_driver.initial_position(profile,objects())
	target=position
	behavior="idle"
	elapsed=0
	remaining=rng.randf_range(profile.idle_duration_range[0],profile.idle_duration_range[1])
	cooldown=0
	intent=""
	stone_broken=false
	restore_left=0
	stage_changed.emit()
	return true
func walk_to(x: float,after: String="") -> bool:
	return move_to_point(Vector2(x,position.y),after)
func move_to_point(requested: Vector2,after: String="") -> bool:
	if not inhabited() or "walk" not in profile.allowed_behaviors: return false
	target=motion_driver.constrain_target(position,requested,profile,objects())
	intent=after
	facing=1 if target.x>=position.x else -1
	return enter("walk",10)
func react() -> bool:
	if not inhabited() or cooldown>0 or behavior=="ram" or intent=="ram" or "react" not in profile.allowed_behaviors: return false
	intent=""
	cooldown=profile.interaction_cooldown
	return enter("react",0.8)
func training_object() -> Dictionary:
	for object in objects():
		if object.type=="training": return object
	return {}
func request_ram() -> bool:
	if stage<3 or not inhabited() or stone_broken or cooldown>0 or behavior=="ram" or intent=="ram" or "ram" not in profile.allowed_behaviors: return false
	var rock:=training_object()
	if rock.is_empty(): return false
	var approach: float=rock.rect[0]-profile.body_radius-3
	var requested:=Vector2(approach,position.y)
	if motion_driver.constrain_target(position,requested,profile,objects()).distance_to(requested)>0.01: return false
	cooldown=profile.interaction_cooldown
	return walk_to(approach,"ram")
func choose_next() -> void:
	intent=""
	var choice:=rng.randi_range(0,8)
	if choice==0 and "sleep" in profile.allowed_behaviors: enter("sleep")
	elif choice==1 and stage>=3 and request_ram(): pass
	elif choice<=4 and "walk" in profile.allowed_behaviors:
		move_to_point(motion_driver.random_target(position,rng,profile,objects()))
	elif choice<=6 and "inspect" in profile.allowed_behaviors:
		var available: Array=[]
		for object in objects():
			if object.object_id in profile.preferred_objects: available.append(object)
		if available.is_empty(): enter("idle")
		else:
			var object: Dictionary=available[rng.randi_range(0,available.size()-1)]
			walk_to(object.rect[0],"inspect")
	else: enter("idle")
func tick(delta: float) -> void:
	if not inhabited(): return
	# Bounded substeps make behavior consistent under a slow frame or deterministic tests.
	var left:=minf(delta,0.25)
	while left>0:
		var step:=minf(left,0.025)
		advance(step)
		left-=step
func advance(delta: float) -> void:
	elapsed+=delta
	cooldown=maxf(0,cooldown-delta)
	if stone_broken:
		restore_left=maxf(0,restore_left-delta)
		if restore_left==0: stone_broken=false
	if behavior=="walk":
		position=motion_driver.advance_position(position,target,delta,profile,objects())
		if position.distance_to(target)<0.01:
			var next:=intent
			intent=""
			if next=="ram": enter("ram",1.05)
			elif next=="inspect": enter("inspect",2.0)
			else: enter("idle")
		return
	if behavior=="ram" and elapsed>=0.55 and not stone_broken:
		stone_broken=true
		restore_left=4.0
		hit_count+=1
	remaining-=delta
	if remaining<=0:
		if behavior in ["react","ram","sleep","inspect"]: enter("idle")
		else: choose_next()
