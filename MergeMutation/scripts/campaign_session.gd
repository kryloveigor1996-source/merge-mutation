extends RefCounted
const Catalog = preload("res://scripts/mutant_catalog.gd")
const Levels = preload("res://scripts/campaign_levels.gd")
const Goals = preload("res://scripts/campaign_goals.gd")
const Boosters = preload("res://scripts/booster_system.gd")
const Search = preload("res://scripts/tactical_search.gd")
var config: Dictionary={}
var cells: Array=[]
var goals := Goals.new()
var boosters := Boosters.new()
var creations_used := 0
var moves_used := 0
var status := "active"
var reason := ""
# Failure search is bounded. A cutoff never means defeat.
const FAILURE_STATES := 300
func start(data: Dictionary,teleporter_charges: int=0) -> bool:
	if not Levels.valid(data) or teleporter_charges<0: return false
	config=data.duplicate(true)
	config.blocked_cells=config.blocked_cells.map(func(value): return int(value))
	config.spawn_points=config.get("spawn_points",[]).map(func(value): return int(value))
	cells.resize(30)
	cells.fill(null)
	goals=Goals.new()
	boosters=Boosters.new()
	boosters.grant("teleporter",teleporter_charges)
	creations_used=0
	moves_used=0
	status="active"
	reason=""
	for item in config.initial:
		var form := Catalog.make(item.species_id,int(item.evolution_stage))
		cells[int(item.cell)]=form
		goals.record(form)
	evaluate()
	return true
func blocked(index: int) -> bool:
	return index<0 or index>=30 or index in config.blocked_cells
static func adjacent(first: int,second: int) -> bool:
	return first>=0 and first<30 and second>=0 and second<30 and absi(first%5-second%5)+absi(floori(float(first)/5)-floori(float(second)/5))==1
func neighbours(index: int) -> Array[int]:
	var result: Array[int]=[]
	for target in [index-5,index-1,index+1,index+5]:
		if adjacent(index,target) and not blocked(target): result.append(target)
	return result
func creations_left() -> int:
	return maxi(0,int(config.creation_limit)-creations_used)
func moves_left() -> int:
	return -1 if config.move_limit==-1 else maxi(0,int(config.move_limit)-moves_used)
func next_species() -> String:
	return config.sequence[creations_used] if creations_left()>0 else ""
func next_spawn_point() -> int:
	return config.spawn_points[creations_used%config.spawn_points.size()] if not config.spawn_points.is_empty() else -1
func spawn_index() -> int:
	if not config.spawn_points.is_empty():
		var index := next_spawn_point()
		return index if not blocked(index) and cells[index]==null else -1
	for index in range(30):
		if not blocked(index) and cells[index]==null: return index
	return -1
func spawn(assess: bool=true) -> Dictionary:
	var index := spawn_index()
	if status!="active" or creations_left()==0 or index<0: return {"ok":false,"reason":"Освободите точку появления" if creations_left()>0 else "Создания закончились"}
	cells[index]=Catalog.make(next_species())
	creations_used+=1
	goals.record(cells[index])
	if assess: evaluate()
	return {"ok":true,"kind":"spawn","index":index,"form":cells[index]}
func can_transfer(source: int,destination: int) -> bool:
	return status=="active" and not blocked(source) and not blocked(destination) and cells[source]!=null and moves_left()!=0 and adjacent(source,destination) and (cells[destination]==null or Catalog.can_merge(cells[source],cells[destination]))
func transfer(source: int,destination: int,assess: bool=true) -> Dictionary:
	if not can_transfer(source,destination):
		return {"ok":false,"reason":"Только соседняя клетка: вверх, вниз, влево или вправо" if not adjacent(source,destination) else "Клетка недоступна или мутанты не совпадают"}
	var kind := "move"
	if cells[destination]!=null:
		kind="merge"
		cells[destination]=Catalog.evolve(cells[destination])
		goals.merges+=1
		goals.record(cells[destination])
	else:
		cells[destination]=cells[source]
	cells[source]=null
	moves_used+=1
	if assess: evaluate()
	return {"ok":true,"kind":kind,"source":source,"index":destination,"form":cells[destination]}
func use_booster(id: String,source: int,destination: int,assess: bool=true) -> Dictionary:
	var result := boosters.activate(self,id,source,destination)
	if result.ok and assess: evaluate()
	return result
func legal_actions(include_boosters: bool=false) -> Array:
	var actions: Array=[]
	if status!="active": return actions
	if creations_left()>0 and spawn_index()>=0:
		actions.append({"kind":"spawn","index":spawn_index(),"species_id":next_species()})
	for source in range(30):
		if cells[source]==null or blocked(source): continue
		for destination in neighbours(source):
			if can_transfer(source,destination):
				actions.append({"kind":"move" if cells[destination]==null else "merge","source":source,"index":destination})
		if include_boosters and boosters.remaining("teleporter")>0:
			for destination in range(30):
				if not blocked(destination) and cells[destination]==null:
					actions.append({"kind":"teleporter","source":source,"index":destination})
	return actions
func apply_action(action: Dictionary,assess: bool=true) -> Dictionary:
	match action.kind:
		"spawn": return spawn(assess)
		"move","merge": return transfer(int(action.source),int(action.index),assess)
		"teleporter": return use_booster("teleporter",int(action.source),int(action.index),assess)
	return {"ok":false}
func fork():
	var copy = get_script().new()
	copy.config=config
	copy.cells=cells.duplicate(true)
	copy.goals.produced=goals.produced.duplicate(true)
	copy.goals.merges=goals.merges
	copy.boosters.charges=boosters.charges.duplicate()
	copy.creations_used=creations_used
	copy.moves_used=moves_used
	copy.status="active"
	return copy
func signature() -> String:
	var board: Array=[]
	for form in cells: board.append("" if form==null else Catalog.key(form))
	return JSON.stringify([board,creations_used,moves_left(),goals.produced,goals.merges,boosters.charges],"",true)
func pair_distance(first: int,second: int) -> int:
	# Relaxation ignores other creatures: an admissible lower bound, never too high.
	var queue: Array[int]=[first]
	var distance := {first:0}
	var head := 0
	while head<queue.size():
		var index: int=queue[head]
		if index==second: return distance[index]
		for next in neighbours(index):
			if not distance.has(next):
				distance[next]=int(distance[index])+1
				queue.append(next)
		head+=1
	return 1000000
func merge_lower_bound() -> int:
	var best := 1000000
	for first in range(30):
		if cells[first]==null: continue
		for second in range(first+1,30):
			if Catalog.can_merge(cells[first],cells[second]): best=mini(best,pair_distance(first,second))
	return best
func has_matching_pair() -> bool:
	for first in range(30):
		for second in range(first+1,30):
			if Catalog.can_merge(cells[first],cells[second]): return true
	return false
func evaluate() -> void:
	if goals.all_met(config.goals):
		status="won"
		return
	if moves_left()==0:
		# Even a teleport cannot merge. Overestimate all remaining base creations;
		# if this cannot meet the goals, no placement or charge can save the attempt.
		var possible := Goals.new()
		possible.produced=goals.produced.duplicate(true)
		possible.merges=goals.merges
		for offset in range(creations_left()):
			possible.record(Catalog.make(config.sequence[creations_used+offset]))
		if not possible.all_met(config.goals):
			lose("Ходы закончились: оставшимся целям нужны слияния")
			return
	if legal_actions(true).is_empty():
		lose("Нет доступных действий для оставшихся целей")
		return
	if creations_left()==0 and not has_matching_pair():
		lose("Созданий и подходящих пар больше нет")
		return
	if creations_left()==0 and boosters.remaining("teleporter")==0:
		var minimum := merge_lower_bound()
		if minimum==1000000 or (moves_left()>=0 and minimum>moves_left()):
			lose("Не хватает ходов или маршрута до подходящей пары")
			return
	# Exact when exhausted; intentionally conservative when the budget is exceeded.
	if moves_left()>=0 and moves_left()<=3:
		var proof := Search.solve(self,FAILURE_STATES,true)
		if not proof.won and proof.exhaustive: lose("Оставшимися действиями цели уже не выполнить")
func lose(message: String) -> void:
	status="lost"
	reason=message
