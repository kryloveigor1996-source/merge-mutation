extends RefCounted
const Worlds = preload("res://scripts/world_registry.gd")
var world_id := ""
var entry: Dictionary={}
var completed: Array=[]
var nodes: Array=[]
var current := 0
func setup(id: String,done: Array) -> bool:
	entry=Worlds.world(id)
	if entry.is_empty(): return false
	world_id=id
	completed=done.duplicate()
	nodes.clear()
	current=0
	for index in range(entry.levels.size()):
		var level: String=entry.levels[index]
		nodes.append({"id":level,"number":index+1,"preview":false})
	var first_missing := 0
	while first_missing<entry.levels.size() and entry.levels[first_missing] in completed: first_missing+=1
	current=first_missing
	if nodes.is_empty():
		for index in range(int(entry.map.get("preview_nodes",0))):
			nodes.append({"id":"%s_preview_%03d" % [id,index+1],"number":index+1,"preview":true})
	current=mini(current,maxi(0,nodes.size()-1))
	return true
func state(index: int) -> String:
	if index<0 or index>=nodes.size(): return "locked"
	var node: Dictionary=nodes[index]
	if node.preview: return "preview"
	if node.id in completed: return "completed"
	return "current" if Worlds.can_launch(world_id,node.id,completed) else "locked"
func fogged(index: int) -> bool:
	if index>=0 and index<nodes.size() and nodes[index].id in completed: return false
	return index>current+2
func point(index: int) -> Vector2:
	return Vector2(168+82*sin(float(index)*1.15),100+index*float(entry.map.get("spacing",112)))
func height() -> float:
	return 200+maxi(0,nodes.size()-1)*float(entry.map.get("spacing",112))
func visible_range(scroll: float,viewport_height: float) -> Vector2i:
	var step: float=entry.map.get("spacing",112)
	return Vector2i(maxi(0,floori((scroll-100)/step)-1),mini(nodes.size(),ceili((scroll+viewport_height-100)/step)+2))
func hit(position: Vector2) -> int:
	var index := roundi((position.y-100)/float(entry.map.get("spacing",112)))
	if index<0 or index>=nodes.size(): return -1
	return index if position.distance_to(point(index))<=32 else -1
