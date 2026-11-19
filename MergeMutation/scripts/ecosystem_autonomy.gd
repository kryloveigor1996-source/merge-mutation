extends RefCounted
## Seeded weighted selection; no hunger/health/happiness economy.
static func choose(model) -> bool:
	if model.simulation_time-model.last_player_command<2 or not model.action_slot.is_empty() or not model.rare_event.is_empty(): return false
	if not model.pending_curiosity.is_empty():
		var id: String=model.pending_curiosity
		model.pending_curiosity=""
		if model.auto_slot(id): return true
		model.enter("inspect",1.5)
		model.feedback="Любопытно! Новое оформление."
		model.feedback_left=1.5
		return true
	var candidates: Array=[]
	var total:=0.0
	for rule in model.ecology.autonomy:
		if model.simulation_time-float(model.auto_history.get(rule.action,-1000))<float(rule.repeat_after): continue
		if rule.action in ["walk","idle","rest"]:
			candidates.append({"action":rule.action,"slot":"","weight":float(rule.weight)})
			total+=float(rule.weight)
			continue
		for object in model.objects():
			var slot: Dictionary=model.renovation.catalog.slots[object.slot_id]
			if slot.get("action")!=rule.action: continue
			if rule.action=="ram" and model.stone_broken: continue
			var distance: float=absf(model.position.x-model.renovation.catalog.project_rect(slot,model.registry.world_width).get_center().x)
			var weight: float=float(rule.weight)*(1.5 if object.slot_id in model.ecology.preferred_objects else 1.0)/(1.0+distance/600)
			candidates.append({"action":rule.action,"slot":object.slot_id,"weight":weight})
			total+=weight
	if candidates.is_empty(): return false
	var sample: float=model.rng.randf()*total
	var picked: Dictionary=candidates.back()
	for option in candidates:
		sample-=option.weight
		if sample<=0:
			picked=option
			break
	model.auto_history[picked.action]=model.simulation_time
	model.autonomous_log.append(picked.action)
	if model.autonomous_log.size()>80: model.autonomous_log.pop_front()
	if not picked.slot.is_empty(): return model.auto_slot(picked.slot)
	if picked.action=="walk":
		return model.walk_to(clampf(model.position.x+model.rng.randf_range(-280,280),model.profile.walk_range[0],model.profile.walk_range[1]))
	if picked.action=="rest":
		model.rest_variant=model.ecology.habits[model.rng.randi_range(0,model.ecology.habits.size()-1)]
		return model.enter("inspect",model.rng.randf_range(1.4,2.8))
	return model.enter("idle",model.rng.randf_range(0.8,1.8))
