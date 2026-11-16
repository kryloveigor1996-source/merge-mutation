extends RefCounted
const Catalog = preload("res://scripts/mutant_catalog.gd")
const Levels = preload("res://scripts/campaign_levels.gd")
const Goals = preload("res://scripts/campaign_goals.gd")
var config: Dictionary={}
var cells: Array=[]
var goals := Goals.new()
var creations_used := 0
var moves_used := 0
var status := "active"
var reason := ""
func start(data: Dictionary) -> bool:
	if not Levels.valid(data): return false
	config=data.duplicate(true)
	# JSON numbers are floats; Array membership distinguishes float from int.
	config.blocked_cells=config.blocked_cells.map(func(value): return int(value))
	cells.resize(30)
	cells.fill(null)
	goals=Goals.new()
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
func creations_left() -> int:
	return maxi(0,int(config.creation_limit)-creations_used)
func moves_left() -> int:
	return -1 if config.move_limit==-1 else maxi(0,int(config.move_limit)-moves_used)
func next_species() -> String:
	return config.sequence[creations_used] if creations_left()>0 else ""
func spawn_index() -> int:
	for index in range(30):
		if not blocked(index) and cells[index]==null: return index
	return -1
func spawn() -> Dictionary:
	var index := spawn_index()
	if status!="active" or creations_left()==0 or index<0: return {"ok":false}
	cells[index]=Catalog.make(next_species())
	creations_used+=1
	goals.record(cells[index])
	evaluate()
	return {"ok":true,"kind":"spawn","index":index,"form":cells[index]}
func transfer(source: int,destination: int) -> Dictionary:
	if status!="active" or blocked(source) or blocked(destination) or source==destination or cells[source]==null or moves_left()==0:
		return {"ok":false}
	var kind := "move"
	if cells[destination]!=null:
		if not Catalog.can_merge(cells[source],cells[destination]): return {"ok":false}
		kind="merge"
		cells[destination]=Catalog.evolve(cells[destination])
		goals.merges+=1
		goals.record(cells[destination])
	else:
		cells[destination]=cells[source]
	cells[source]=null
	moves_used+=1
	evaluate()
	return {"ok":true,"kind":kind,"source":source,"index":destination,"form":cells[destination]}
func has_merge() -> bool:
	for first in range(30):
		if cells[first]==null: continue
		for second in range(first+1,30):
			if Catalog.can_merge(cells[first],cells[second]): return true
	return false
func evaluate() -> void:
	# Victory always takes precedence over exhaustion on the final action.
	if goals.all_met(config.goals):
		status="won"
		return
	if moves_left()==0:
		# With no moves, only the remaining queue prefix fitting the board can help.
		var possible := Goals.new()
		possible.produced=goals.produced.duplicate(true)
		possible.merges=goals.merges
		var free := 0
		for index in range(30):
			if not blocked(index) and cells[index]==null: free+=1
		for offset in range(mini(free,creations_left())):
			possible.record(Catalog.make(config.sequence[creations_used+offset]))
		if possible.all_met(config.goals): return
		status="lost"
		reason="Ходы закончились, для оставшихся целей нужны слияния или свободные клетки"
		return
	if creations_left()>0 and spawn_index()>=0: return
	if moves_left()!=0 and has_merge(): return
	status="lost"
	reason="Ходы закончились" if moves_left()==0 else ("Поле заполнено, подходящих пар нет" if spawn_index()<0 else "Создания закончились, подходящих пар нет")
