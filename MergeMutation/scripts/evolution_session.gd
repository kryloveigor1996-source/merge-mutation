extends "res://scripts/campaign_session.gd"
## Attempt-only rules. No profile, currency or collection references.
const TYPES=["plate","gate","crate","portal","sample","equipment","hidden","anomaly"]
var terrain: Dictionary={}
var fixed_objects: Dictionary={}
var crates: Dictionary={}
var activated: Dictionary={}
var revealed: Dictionary={}
var collected: Dictionary={}
var cleared: Dictionary={}
var made: Dictionary={}
var evacuations: Array=[]
var preview_cache_key=""
var preview_cache: Dictionary={}
var preview_builds=0
static func valid(data: Dictionary) -> bool:
	if not Levels.valid(data) or data.get("schema")!="tactical_evolution_v1": return false
	if data.reward_coins!=0 or data.reward_stars!=0 or data.move_limit<1: return false
	if not data.get("terrain") is Dictionary or not data.get("objects") is Array or not data.get("objectives") is Array or data.objectives.is_empty(): return false
	if not data.get("circuits",[]) is Array: return false
	if data.available_species.any(func(id): return id not in ["slime","horn","wing","eyeball"]): return false
	var circuit_ids: Dictionary={}
	var ids: Dictionary={}
	var occupied: Array=[]
	for object in data.objects:
		if not object is Dictionary or not Catalog.valid_id(object.get("id")) or ids.has(object.id) or object.get("type") not in TYPES or not Catalog.integer(object.get("cell"),29) or int(object.cell) in data.blocked_cells: return false
		if int(object.cell) in occupied: return false
		if object.has("species_id") and object.species_id not in ["slime","horn","wing","eyeball"]: return false
		if object.has("stage") and (not Catalog.integer(object.stage,5) or object.stage<1): return false
		ids[object.id]=object.type
		occupied.append(int(object.cell))
	for circuit in data.get("circuits",[]):
		if not circuit is Dictionary: return false
		if not Catalog.valid_id(circuit.get("id")) or circuit.get("mode") not in ["any","all"] or not circuit.get("inputs") is Array or circuit.inputs.is_empty(): return false
		if circuit_ids.has(circuit.id): return false
		circuit_ids[circuit.id]=true
		for id in circuit.inputs:
			if not ids.has(id) or ids[id] not in ["plate","equipment","hidden"]: return false
	for object in data.objects:
		if object.get("channel","")!="" and not data.get("circuits",[]).any(func(c): return c.id==object.channel): return false
	for objective in data.objectives:
		if not objective is Dictionary or objective.get("type") not in ["create","evacuate","collect","activate","neutralize"]: return false
		if not objective.get("text") is String or objective.text.is_empty(): return false
		if not Catalog.integer(objective.get("count",1),30) or objective.get("count",1)<1: return false
		if objective.has("ids"):
			if not objective.ids is Array or objective.ids.is_empty(): return false
			for id in objective.ids:
				if not ids.has(id): return false
		if objective.has("species_id") and objective.species_id not in ["slime","horn","wing","eyeball"]: return false
		if objective.has("stage") and (not Catalog.integer(objective.stage,5) or objective.stage<1): return false
	for key in data.terrain:
		if not key is String or not key.is_valid_int() or not Catalog.integer(int(key),29) or data.terrain[key] not in ["acid","gap","rock"] or int(key) in data.blocked_cells: return false
	for form in data.initial:
		if form.species_id not in ["slime","horn","wing","eyeball"] or data.terrain.get(str(int(form.cell)),"") in ["rock","gap"]: return false
		if data.terrain.get(str(int(form.cell)),"")=="acid" and form.species_id!="slime": return false
		for object in data.objects:
			if int(object.cell)==int(form.cell) and object.type in ["crate","gate","anomaly","portal"]: return false
	return true
func start(data: Dictionary,charges: int=0) -> bool:
	if not valid(data): return false
	terrain=data.terrain.duplicate(true)
	fixed_objects.clear()
	crates.clear(); activated.clear(); revealed.clear(); collected.clear(); cleared.clear(); made.clear(); evacuations.clear()
	for object in data.objects:
		if object.type=="crate": crates[object.id]=int(object.cell)
		else: fixed_objects[int(object.cell)]=object
	return super.start(data,0)
func object_at(index: int) -> Dictionary:
	for id in crates:
		if crates[id]==index: return {"id":id,"type":"crate","cell":index}
	return fixed_objects.get(index,{})
func ground(index: int) -> String: return terrain.get(str(index),"normal")
func has_ability(index: int,id: String) -> bool:
	return index>=0 and index<30 and cells[index]!=null and {"slime":"acid","horn":"ram","wing":"flight","eyeball":"reveal"}.get(cells[index].species_id,"")==id
func circuit_on_for_plate(id: String) -> bool:
	for object in config.objects:
		if object.id==id: return cells[int(object.cell)]!=null or int(object.cell) in crates.values()
	return false
func circuit_on(id: String) -> bool:
	if id.is_empty(): return true
	for circuit in config.get("circuits",[]):
		if circuit.id!=id: continue
		var values: Array=[]
		for input_id in circuit.inputs:
			var object: Dictionary={}
			for candidate in config.objects:
				if candidate.id==input_id: object=candidate; break
			var active: bool=activated.has(input_id)
			if object.type=="plate": active=cells[int(object.cell)]!=null or int(object.cell) in crates.values()
			values.append(active)
		return values.all(func(v): return v) if circuit.mode=="all" else values.any(func(v): return v)
	return false
func matches(form: Dictionary,requirement: Dictionary) -> bool:
	return (requirement.get("species_id","")=="" or form.species_id==requirement.species_id) and form.evolution_stage>=int(requirement.get("stage",1))
func traversable(source: int,index: int) -> bool:
	if super.blocked(index) or ground(index) in ["rock","gap"] or ground(index)=="acid" and not has_ability(source,"acid"): return false
	var object=object_at(index)
	if object.is_empty(): return true
	match object.type:
		"crate": return false
		"gate": return circuit_on(object.get("channel",""))
		"anomaly": return cleared.has(object.id)
		"portal": return matches(cells[source],object) and circuit_on(object.get("channel",""))
	return true
func can_jump(source: int,destination: int) -> bool:
	if not has_ability(source,"flight") or cells[destination]!=null or not traversable(source,destination): return false
	var dx=absi(source%5-destination%5)
	var dy=absi(floori(source/5.0)-floori(destination/5.0))
	return (dx==2 and dy==0 or dx==0 and dy==2) and ground(int((source+destination)/2.0))=="gap"
func can_transfer(source: int,destination: int) -> bool:
	if status!="active" or source<0 or source>=30 or destination<0 or destination>=30 or source==destination or cells[source]==null or moves_left()==0: return false
	return traversable(source,destination) and (super.can_transfer(source,destination) or can_jump(source,destination))
func arrive(index: int) -> void:
	var object=object_at(index)
	if object.is_empty() or cells[index]==null: return
	if object.type=="sample": collected[object.id]=true
	elif object.type=="portal":
		evacuations.append({"species_id":cells[index].species_id,"stage":cells[index].evolution_stage,"portal_id":object.id})
		cells[index]=null
func transfer(source: int,destination: int,assess: bool=true) -> Dictionary:
	if not can_transfer(source,destination): return {"ok":false,"reason":"Нужна допустимая соседняя клетка или свободная прямая траектория."}
	var result: Dictionary
	if can_jump(source,destination):
		cells[destination]=cells[source]; cells[source]=null; moves_used+=1
		result={"ok":true,"kind":"jump","source":source,"index":destination}
	else: result=super.transfer(source,destination,false)
	if result.kind=="merge":
		var key=Catalog.key(cells[destination])
		made[key]=int(made.get(key,0))+1
	arrive(destination)
	if assess: evaluate()
	return result
func can_interact(source: int,destination: int) -> bool:
	if status!="active" or moves_left()==0 or not adjacent(source,destination) or cells[source]==null: return false
	if ground(destination)=="rock": return has_ability(source,"ram")
	var object=object_at(destination)
	if object.is_empty(): return false
	match object.type:
		"crate":
			var beyond=destination+(destination-source)
			return has_ability(source,"ram") and adjacent(destination,beyond) and cells[beyond]==null and not super.blocked(beyond) and ground(beyond)=="normal" and (object_at(beyond).is_empty() or object_at(beyond).type in ["plate","sample"])
		"hidden": return has_ability(source,"reveal") and not revealed.has(object.id) or revealed.has(object.id) and not activated.has(object.id) and matches(cells[source],object) and circuit_on(object.get("channel",""))
		"equipment": return not activated.has(object.id) and matches(cells[source],object) and circuit_on(object.get("channel",""))
		"anomaly": return not cleared.has(object.id) and matches(cells[source],object) and circuit_on(object.get("channel",""))
	return false
func interact(source: int,destination: int,assess: bool=true) -> Dictionary:
	if not can_interact(source,destination): return {"ok":false,"reason":"Подойдите подходящим мутантом к объекту. Проверьте шлюз и требования."}
	var kind="break"
	if ground(destination)=="rock": terrain.erase(str(destination))
	else:
		var object=object_at(destination)
		match object.type:
			"crate":
				crates[object.id]=destination+(destination-source)
				cells[destination]=cells[source]; cells[source]=null
				kind="push"
				arrive(destination)
			"hidden":
				if not revealed.has(object.id): revealed[object.id]=true; kind="reveal"
				else: activated[object.id]=true; kind="activate"
			"equipment": activated[object.id]=true; kind="activate"
			"anomaly": cleared[object.id]=true; kind="neutralize"
	moves_used+=1
	if assess: evaluate()
	return {"ok":true,"kind":kind,"source":source,"index":destination}
func spawn_index() -> int:
	var index=super.spawn_index()
	if index<0: return -1
	var object=object_at(index)
	return index if ground(index)=="normal" and (object.is_empty() or object.type in ["plate","sample"]) else -1
func spawn(assess: bool=true) -> Dictionary:
	var result=super.spawn(false)
	if result.ok:
		made[Catalog.key(cells[result.index])]=int(made.get(Catalog.key(cells[result.index]),0))+1
		arrive(result.index)
		if assess: evaluate()
	return result
func objective_status() -> Array:
	var result: Array=[]
	for objective in config.objectives:
		var count=0
		match objective.type:
			"create":
				for key in made:
					if matches(Catalog.from_key(key),objective): count+=int(made[key])
			"evacuate":
				for record in evacuations:
					if (objective.get("species_id","")=="" or record.species_id==objective.species_id) and record.stage>=objective.get("stage",1): count+=1
			_:
				var state: Dictionary={"collect":collected,"activate":activated,"neutralize":cleared}[objective.type]
				for id in state:
					if not objective.has("ids") or id in objective.ids: count+=1
		var total=int(objective.get("count",1))
		result.append({"met":count>=total,"current":count,"total":total,"text":objective.text})
	return result
func won() -> bool: return objective_status().all(func(item): return item.met)
func evaluate() -> void:
	if won(): status="won"
	elif moves_left()==0 and (creations_left()==0 or spawn_index()<0): lose("Ходы закончились. Попробуйте изменить последовательность.")
	elif legal_actions().is_empty(): lose("Нет доступных действий. Можно отменить ход.")
func legal_actions(_include_boosters: bool=false) -> Array:
	var actions: Array=[]
	if status!="active": return actions
	if creations_left()>0 and spawn_index()>=0: actions.append({"kind":"spawn"})
	for source in range(30):
		if cells[source]==null: continue
		for destination in [source-5,source-1,source+1,source+5,source-10,source-2,source+2,source+10]:
			if can_interact(source,destination): actions.append({"kind":"interact","source":source,"index":destination})
			if can_transfer(source,destination): actions.append({"kind":"move","source":source,"index":destination})
	return actions
func apply_action(action: Dictionary,assess: bool=true) -> Dictionary:
	match action.get("kind",""):
		"spawn": return spawn(assess)
		"interact": return interact(int(action.source),int(action.index),assess)
		"move","merge","jump": return transfer(int(action.source),int(action.index),assess)
		"corridor": return corridor(int(action.source),int(action.index),assess)
	return {"ok":false,"reason":"Неизвестное действие"}
func command(source: int,destination: int) -> Dictionary:
	return {"kind":"interact" if can_interact(source,destination) else ("move" if can_transfer(source,destination) else "corridor"),"source":source,"index":destination}
func corridor(source: int,destination: int,assess: bool=true) -> Dictionary:
	if source<0 or destination<0 or source>=30 or destination>=30 or source==destination: return {"ok":false,"reason":"Выберите другую клетку"}
	var dx=destination%5-source%5
	var dy=floori(destination/5.0)-floori(source/5.0)
	if dx!=0 and dy!=0: return {"ok":false,"reason":"Нужна прямая горизонтальная или вертикальная траектория"}
	var distance=absi(dx)+absi(dy)
	if moves_left()<distance: return {"ok":false,"reason":"Не хватает ходов на весь путь"}
	var step=signi(dx) if dy==0 else signi(dy)*5
	var trial=fork()
	var previous=source
	var route: Array=[]
	for offset in range(1,distance+1):
		var index=source+step*offset
		if trial.status!="active" or trial.cells[index]!=null or trial.cells[previous]==null or not trial.transfer(previous,index,true).ok: return {"ok":false,"reason":"Путь перекрыт или действие завершается раньше цели"}
		route.append(index); previous=index
	if not assess: trial.status="active"; trial.reason=""
	restore_from(trial)
	return {"ok":true,"kind":"corridor","source":source,"index":destination,"route":route,"cost":distance}
func target_action(source: int,index: int) -> Dictionary:
	var action=command(source,index)
	var trial=fork()
	var result: Dictionary=trial.apply_action(action)
	return {"action":action,"cost":trial.moves_used-moves_used,"kind":result.kind} if result.ok else {}
func preview_actions(source: int) -> Dictionary:
	var key=signature()+str(source)
	if preview_cache_key!=key:
		preview_cache_key=key; preview_cache.clear(); preview_builds+=1
		for index in range(30):
			if index==source: continue
			var value=target_action(source,index)
			if not value.is_empty(): preview_cache[index]=value
	return preview_cache
func fork():
	var copy=super.fork()
	copy.restore_from(self)
	return copy
func restore_from(snapshot) -> void:
	config=snapshot.config
	fixed_objects=snapshot.fixed_objects
	cells=snapshot.cells.duplicate(true)
	goals.produced=snapshot.goals.produced.duplicate(true); goals.merges=snapshot.goals.merges
	boosters.charges=snapshot.boosters.charges.duplicate(true)
	creations_used=snapshot.creations_used; moves_used=snapshot.moves_used
	status=snapshot.status; reason=snapshot.reason
	for key in ["terrain","crates","activated","revealed","collected","cleared","made","evacuations"]: set(key,snapshot.get(key).duplicate(true))
func search_key() -> String:
	return JSON.stringify([cells,creations_used,terrain,crates,activated,revealed,collected,cleared,made,evacuations],"",true)
func signature() -> String: return search_key()+str(moves_used)+status