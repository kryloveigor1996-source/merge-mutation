extends RefCounted
## World/map metadata is independent of the legacy campaign's numeric save ledger.
const Catalog = preload("res://scripts/mutant_catalog.gd")
const LegacyLevels = preload("res://scripts/campaign_levels.gd")
static var entries: Dictionary={}
static var routes: Dictionary={}
static var loaded := false
static var available_routes: Dictionary={}
static func ensure() -> void:
	if loaded: return
	loaded=true
	var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/worlds.json"))
	if not raw is Dictionary: return
	for entry in raw.get("worlds",[]): register_world(entry)
	routes=raw.get("level_routes",{}).duplicate(true)
static func valid(entry: Variant) -> bool:
	if not entry is Dictionary or not entry.has_all(["world_id","name","description","order","portal_style","levels","map","unlock","expeditions"]): return false
	if not Catalog.valid_id(entry.world_id): return false
	for key in ["name","description","portal_style"]:
		if not entry[key] is String: return false
	if not Catalog.integer(entry.order) or not entry.levels is Array: return false
	var seen := {}
	for id in entry.levels:
		if not Catalog.valid_id(id) or seen.has(id): return false
		seen[id]=true
	if not entry.map is Dictionary or not Catalog.integer(entry.map.get("preview_nodes",0),100000) or not entry.map.get("theme","") is String: return false
	if not Catalog.integer(entry.map.get("spacing",112),1000) or entry.map.get("spacing",112)<80: return false
	if not entry.unlock is Dictionary or not entry.unlock.get("type","") in ["always","level_completed","world_completed","unavailable"]: return false
	if entry.unlock.type=="level_completed" and not Catalog.valid_id(entry.unlock.get("level_id")): return false
	if entry.unlock.type=="world_completed" and not Catalog.valid_id(entry.unlock.get("world_id")): return false
	return entry.expeditions is Dictionary and entry.expeditions.get("enabled",false) is bool
static func register_world(entry: Dictionary) -> bool:
	if not loaded: ensure()
	if not valid(entry) or entries.has(entry.world_id): return false
	entries[entry.world_id]=entry.duplicate(true)
	return true
static func ids() -> Array[String]:
	ensure()
	var values := entries.values()
	values.sort_custom(func(a,b): return a.order<b.order if a.order!=b.order else a.world_id<b.world_id)
	var result: Array[String]=[]
	for entry in values: result.append(entry.world_id)
	return result
static func world(id: String) -> Dictionary:
	ensure()
	return entries.get(id,{}).duplicate(true)
static func route(id: String) -> Dictionary:
	ensure()
	return routes.get(id,{}).duplicate(true)
static func legacy_id(number: int) -> String:
	ensure()
	for id in routes:
		if routes[id].get("kind")=="legacy_campaign" and int(routes[id].get("number",0))==number: return id
	return ""
static func completed_ids(progress) -> Array[String]:
	var result: Array[String]=[]
	for number in progress.completed:
		var id := legacy_id(number)
		if not id.is_empty(): result.append(id)
	return result
static func route_available(id: String) -> bool:
	var target := route(id)
	if target.get("kind")!="legacy_campaign": return false
	var number: Variant=target.get("number",0)
	if not Catalog.integer(number): return false
	var key := JSON.stringify([id,target],"",true)
	if available_routes.has(key): return available_routes[key]
	var config := LegacyLevels.get_level(int(number))
	var available: bool=not config.is_empty() and config.id==id
	available_routes[key]=available
	return available
static func status(id: String,completed: Array) -> Dictionary:
	var entry := world(id)
	var levels: Array=entry.get("levels",[])
	var done := 0
	var next := ""
	for level in levels:
		if level in completed: done+=1
		elif next.is_empty(): next=level
	return {"completed":done,"total":levels.size(),"cleared":not levels.is_empty() and done==levels.size(),"next_id":next}
static func unlocked(id: String,completed: Array) -> bool:
	var entry := world(id)
	if entry.is_empty(): return false
	var rule: Dictionary=entry.unlock
	match rule.type:
		"always": return true
		"level_completed": return rule.level_id in completed
		"world_completed": return status(rule.world_id,completed).cleared
	return false
static func locked_reason(id: String,completed: Array) -> String:
	if unlocked(id,completed): return ""
	return world(id).get("unlock",{}).get("reason","Координаты этого мира пока недоступны.")
static func can_launch(world_id: String,level_id: String,completed: Array) -> bool:
	var entry := world(world_id)
	if entry.is_empty() or not unlocked(world_id,completed) or not level_id in entry.levels or not route_available(level_id): return false
	if level_id in completed: return true
	for id in entry.levels:
		if id==level_id: return true
		if not id in completed: return false
	return false
