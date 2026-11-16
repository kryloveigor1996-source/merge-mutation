extends RefCounted
const Catalog = preload("res://scripts/mutant_catalog.gd")
const COUNT := 10
static func get_level(number: int) -> Dictionary:
	if number<1 or number>COUNT:
		return {}
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://campaign/levels/level_%02d.json" % number))
	return data if valid(data) else {}
static func valid(data: Variant) -> bool:
	if not data is Dictionary or not data.has_all(["id","number","name","available_species","initial","sequence","creation_limit","move_limit","blocked_cells","goals","reward_coins","reward_stars"]):
		return false
	if not data.id is String or not data.name is String or not Catalog.integer(data.number,COUNT) or data.number<1:
		return false
	for field in ["creation_limit","reward_coins","reward_stars"]:
		if not Catalog.integer(data[field],10000): return false
	if not (data.move_limit==-1 or Catalog.integer(data.move_limit,10000)):
		return false
	for field in ["available_species","initial","sequence","blocked_cells","goals"]:
		if not data[field] is Array: return false
	if data.sequence.size()!=int(data.creation_limit) or data.goals.is_empty(): return false
	for id in data.available_species:
		if not id is String or not Catalog.available(id): return false
	for id in data.sequence:
		if not id in data.available_species: return false
	var occupied := {}
	for index in data.blocked_cells:
		if not Catalog.integer(index,29) or occupied.has(int(index)): return false
		occupied[int(index)]=true
	if data.has("spawn_points"):
		if not data.spawn_points is Array: return false
		var points := {}
		for index in data.spawn_points:
			if not Catalog.integer(index,29) or occupied.has(int(index)) or points.has(int(index)): return false
			points[int(index)]=true
	for item in data.initial:
		if not Catalog.known_form(item) or not item.species_id in data.available_species or not Catalog.integer(item.get("cell"),29) or occupied.has(int(item.cell)): return false
		occupied[int(item.cell)]=true
	for goal in data.goals:
		if not goal is Dictionary: return false
		match goal.get("type"):
			"reach_stage":
				if not valid_target(goal): return false
			"merge_count":
				if not Catalog.integer(goal.get("count"),10000) or goal.count<1: return false
			"collect_forms":
				if not goal.get("forms") is Array or goal.forms.is_empty(): return false
				for form in goal.forms:
					if not valid_target(form): return false
			_:
				return false
	return true
static func valid_target(target: Variant) -> bool:
	return Catalog.known_form(target) and Catalog.integer(target.get("count",1),10000) and target.get("count",1)>0
