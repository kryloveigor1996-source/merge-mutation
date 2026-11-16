extends RefCounted
const Worlds = preload("res://scripts/world_registry.gd")
const Levels = preload("res://scripts/campaign_levels.gd")
const Catalog = preload("res://scripts/mutant_catalog.gd")
const Boosters = preload("res://scripts/booster_system.gd")
static func goals_text(goals: Array) -> String:
	var parts: PackedStringArray=[]
	for goal in goals:
		match goal.type:
			"reach_stage": parts.append(form_text(goal))
			"merge_count": parts.append("Выполнить %d слияний" % int(goal.count))
			"collect_forms":
				for form in goal.forms: parts.append(form_text(form))
	return "\n".join(parts)
static func form_text(form: Dictionary) -> String:
	return Catalog.title(form)+(" ×%d" % int(form.get("count",1)) if int(form.get("count",1))>1 else "")
static func build(world_id: String,level_id: String,game) -> Dictionary:
	if not Worlds.can_launch(world_id,level_id,game.completed_world_level_ids()): return {}
	var route := Worlds.route(level_id)
	var config := Levels.get_level(int(route.get("number",0)))
	if config.is_empty() or config.id!=level_id: return {}
	var targets: Dictionary={}
	for goal in config.goals:
		var forms: Array=[goal] if goal.type=="reach_stage" else goal.get("forms",[])
		for form in forms:
			if Catalog.known_form(form) and not game.is_unlocked(form.species_id,int(form.evolution_stage)):
				targets[Catalog.key(form)]=Catalog.make(form.species_id,int(form.evolution_stage))
	var tools: PackedStringArray=[]
	for id in game.preview_boosters():
		if Boosters.TYPES.has(id) and Boosters.TYPES[id].enabled and int(game.preview_boosters()[id])>0:
			tools.append("%s — %d тестовый заряд" % [Boosters.TYPES[id].name,game.preview_boosters()[id]])
	var difficulty: Variant=config.get("difficulty")
	return {"world_id":world_id,"level_id":level_id,"number":int(config.number),"name":config.name,"goals":goals_text(config.goals),"difficulty":difficulty if difficulty is String and not difficulty.is_empty() else "Пока не указана","boosters":"\n".join(tools) if not tools.is_empty() else "Нет доступных бустеров","discoveries":targets.values(),"best_result":null,"best_text":"Лучший результат пока не сохраняется","completed":level_id in game.completed_world_level_ids(),"creation_limit":int(config.creation_limit),"move_limit":int(config.move_limit)}
