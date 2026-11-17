extends "res://scripts/campaign_session.gd"
## Isolated experiment: no save/economy calls; base transfers and merges are reused.
var terrain: Dictionary={}
var disabled_abilities: Array=[]
var used: Dictionary={}
static func ability(form: Variant) -> String:
	if form==null: return ""
	return {"horn":"ram","slime":"acid","wing":"flight"}.get(form.species_id,"")
func has_ability(source: int,id: String) -> bool:
	return source>=0 and source<30 and ability(cells[source])==id and id not in disabled_abilities
func start(data: Dictionary,charges: int=0) -> bool:
	if not valid_experiment(data): return false
	terrain=data.terrain.duplicate(true)
	used={}
	return super.start(data,0)
static func valid_experiment(data: Dictionary) -> bool:
	if not Levels.valid(data) or not data.get("terrain") is Dictionary or not data.get("destinations") is Array or data.destinations.is_empty(): return false
	if not data.get("tip") is String or not data.get("required") is Array or data.required.is_empty(): return false
	for id in data.required:
		if id not in ["ram","acid","flight"]: return false
	for field in ["discovery_id","discovery_type","habitat_id"]:
		if data.has(field) and (not data[field] is String or not Catalog.valid_id(data[field])): return false
	if data.reward_coins!=0 or data.reward_stars!=0 or data.move_limit<1: return false
	var absent: Array=data.blocked_cells.map(func(index): return int(index))
	for key in data.terrain:
		if not key is String or not key.is_valid_int() or not Catalog.integer(int(key),29) or int(key) in absent or data.terrain[key] not in ["rock","acid","gap"]: return false
	for item in data.initial:
		var type: String=data.terrain.get(str(int(item.cell)),"normal")
		if type in ["rock","gap"] or type=="acid" and ability(item)!="acid": return false
	for target in data.destinations:
		if not Catalog.known_form(target) or not Catalog.integer(target.get("cell"),29) or int(target.cell) in absent or data.terrain.get(str(int(target.cell)),"") in ["rock","gap"]: return false
	for point in data.get("spawn_points",[]):
		if data.terrain.has(str(int(point))): return false
	return true
func ground(index: int) -> String:
	return terrain.get(str(index),"normal")
func blocked(index: int) -> bool:
	return super.blocked(index) or ground(index) in ["rock","gap"]
func can_land(source: int,destination: int) -> bool:
	return not blocked(destination) and (ground(destination)!="acid" or has_ability(source,"acid"))
func can_jump(source: int,destination: int) -> bool:
	if source<0 or source>=30 or destination<0 or destination>=30: return false
	if not has_ability(source,"flight") or not can_land(source,destination) or cells[destination]!=null: return false
	var dx := destination%5-source%5
	var dy := floori(float(destination)/5)-floori(float(source)/5)
	return (absi(dx)==2 and dy==0 or dx==0 and absi(dy)==2) and ground(int((source+destination)/2.0))=="gap"
func can_transfer(source: int,destination: int) -> bool:
	if source<0 or source>=30 or destination<0 or destination>=30 or status!="active" or cells[source]==null or moves_left()==0: return false
	return can_land(source,destination) and (super.can_transfer(source,destination) or can_jump(source,destination))
func can_break(source: int,destination: int) -> bool:
	return status=="active" and moves_left()!=0 and adjacent(source,destination) and ground(destination)=="rock" and has_ability(source,"ram")
func transfer(source: int,destination: int,assess: bool=true) -> Dictionary:
	if not can_transfer(source,destination): return {"ok":false,"reason":"Камень — Таран; кислота — Слизик; один разрыв — Крылатик. Нужна соседняя допустимая клетка."}
	if can_jump(source,destination):
		cells[destination]=cells[source]
		cells[source]=null
		moves_used+=1
		used.flight=true
		if assess: evaluate()
		return {"ok":true,"kind":"jump","source":source,"index":destination,"form":cells[destination]}
	if ground(source)=="acid" or ground(destination)=="acid": used.acid=true
	return super.transfer(source,destination,assess)
func break_rock(source: int,destination: int,assess: bool=true) -> Dictionary:
	if not can_break(source,destination): return {"ok":false,"reason":"Выберите Рогача рядом с камнем и нажмите на камень."}
	terrain.erase(str(destination))
	moves_used+=1
	used.ram=true
	if assess: evaluate()
	return {"ok":true,"kind":"break","source":source,"index":destination}
func spawn_index() -> int:
	var index := super.spawn_index()
	return index if index<0 or ground(index)=="normal" else -1
func legal_actions(_include_boosters: bool=false) -> Array:
	var actions: Array=[]
	if status!="active": return actions
	if creations_left()>0 and spawn_index()>=0: actions.append({"kind":"spawn","index":spawn_index()})
	for source in range(30):
		if cells[source]==null: continue
		for destination in range(30):
			if can_break(source,destination): actions.append({"kind":"break","source":source,"index":destination})
			elif can_transfer(source,destination): actions.append({"kind":"jump" if can_jump(source,destination) else ("merge" if cells[destination]!=null else "move"),"source":source,"index":destination})
	return actions
func apply_action(action: Dictionary,assess: bool=true) -> Dictionary:
	if action.kind=="break": return break_rock(int(action.source),int(action.index),assess)
	if action.kind=="jump": return transfer(int(action.source),int(action.index),assess)
	return super.apply_action(action,assess)
func won() -> bool:
	if not goals.all_met(config.goals): return false
	for target in config.destinations:
		if cells[int(target.cell)]==null or Catalog.key(cells[int(target.cell)])!=Catalog.key(target): return false
	return true
func evaluate() -> void:
	if won(): status="won"
	elif moves_left()==0: lose("Ходы закончились. Попробуйте другую последовательность.")
	elif legal_actions().is_empty(): lose("Нет доступных действий. Перезапустите испытание.")
func fork():
	var copy = super.fork()
	copy.terrain=terrain.duplicate(true)
	copy.disabled_abilities=disabled_abilities.duplicate()
	copy.used=used.duplicate()
	return copy
func signature() -> String:
	return super.signature()+JSON.stringify(terrain,"",true)
func search_key() -> String:
	# Dijkstra dominates a later arrival at the identical state with fewer moves left.
	# Keep all goal counters and terrain; only the spent-move budget is excluded.
	return JSON.stringify([cells,creations_used,goals.produced,goals.merges,boosters.charges,terrain],"",true)
