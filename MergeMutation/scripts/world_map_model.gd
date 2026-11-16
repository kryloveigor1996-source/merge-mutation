extends RefCounted
const Worlds = preload("res://scripts/world_registry.gd")
const BUCKET := 256.0
var world_id := ""
var entry: Dictionary={}
var completed: Array=[]
var nodes: Array=[]
var current := 0
var positions: Array[Vector2]=[]
var routes: Array=[]
var node_buckets: Dictionary={}
var route_buckets: Dictionary={}
var long_routes: Array[int]=[]
var extent := Vector2(336,200)
func setup(id: String,done: Array) -> bool:
	entry=Worlds.world(id)
	if entry.is_empty(): return false
	world_id=id
	completed=done.duplicate()
	nodes.clear()
	positions.clear()
	routes.clear()
	node_buckets.clear()
	route_buckets.clear()
	long_routes.clear()
	for index in range(entry.levels.size()): nodes.append({"id":entry.levels[index],"number":index+1,"preview":false})
	var first_missing := 0
	while first_missing<entry.levels.size() and entry.levels[first_missing] in completed: first_missing+=1
	current=first_missing
	if nodes.is_empty():
		for index in range(int(entry.map.get("preview_nodes",0))): nodes.append({"id":"%s_preview_%03d" % [id,index+1],"number":index+1,"preview":true})
	current=mini(current,maxi(0,nodes.size()-1))
	var layout: Dictionary=entry.map.get("layout",{})
	var canvas: Array=layout.get("canvas_size",[336,200])
	extent=Vector2(maxf(336,canvas[0]),maxf(200,canvas[1]))
	var index_by_id := {}
	for index in range(nodes.size()):
		var fallback := Vector2(168+82*sin(float(index)*1.15),100+index*float(entry.map.get("spacing",112)))
		var authored: Array=layout.get("nodes",{}).get(nodes[index].id,[fallback.x,fallback.y])
		var position := Vector2(authored[0],authored[1])
		positions.append(position)
		index_by_id[nodes[index].id]=index
		extent=extent.max(position+Vector2(64,100))
		var bucket := floori(position.y/BUCKET)
		if not node_buckets.has(bucket): node_buckets[bucket]=[]
		node_buckets[bucket].append(index)
	if layout.has("routes"):
		for route in layout.routes:
			if not index_by_id.has(route.from) or not index_by_id.has(route.to): continue
			var points := PackedVector2Array([point(index_by_id[route.from])])
			for value in route.get("points",[]): points.append(Vector2(value[0],value[1]))
			points.append(point(index_by_id[route.to]))
			add_route(index_by_id[route.from],index_by_id[route.to],points)
	else:
		for index in range(nodes.size()-1):
			var points := PackedVector2Array()
			for sample in range(17):
				var t := sample/16.0
				var position := point(index).lerp(point(index+1),t)
				position.x=lerpf(point(index).x,point(index+1).x,smoothstep(0,1,t))
				points.append(position)
			add_route(index,index+1,points)
	return true
func add_route(first: int,last: int,points: PackedVector2Array) -> void:
	var bounds := Rect2(points[0],Vector2.ZERO)
	var segments: Array=[]
	var offset := 0.0
	for index in range(points.size()):
		bounds=bounds.expand(points[index])
		extent=extent.max(points[index]+Vector2(64,100))
		if index==0: continue
		var length := points[index-1].distance_to(points[index])
		if length>0: segments.append({"a":points[index-1],"b":points[index],"length":length,"offset":offset})
		offset+=length
	var route_index := routes.size()
	routes.append({"from":first,"to":last,"segments":segments,"bounds":bounds.grow(4)})
	var low := floori(bounds.position.y/BUCKET)
	var high := floori(bounds.end.y/BUCKET)
	if high-low>16:
		long_routes.append(route_index)
	else:
		for bucket in range(low,high+1):
			if not route_buckets.has(bucket): route_buckets[bucket]=[]
			route_buckets[bucket].append(route_index)
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
	return positions[index]
func height() -> float: return extent.y
func width() -> float: return extent.x
func candidates(buckets: Dictionary,top: float,bottom: float) -> Array[int]:
	var unique := {}
	for bucket in range(floori(top/BUCKET),floori(bottom/BUCKET)+1):
		for index in buckets.get(bucket,[]): unique[index]=true
	var result: Array[int]=[]
	result.assign(unique.keys())
	result.sort()
	return result
func visible_indices(scroll: float,viewport_height: float) -> Array[int]:
	var result: Array[int]=[]
	for index in candidates(node_buckets,scroll-64,scroll+viewport_height+64):
		if point(index).y>=scroll-64 and point(index).y<=scroll+viewport_height+64: result.append(index)
	return result
func visible_range(scroll: float,viewport_height: float) -> Vector2i:
	# Compatibility for old regular-layout callers. Rendering uses spatial indices.
	var indices := visible_indices(scroll,viewport_height)
	return Vector2i(0,0) if indices.is_empty() else Vector2i(indices[0],indices[-1]+1)
func visible_routes(rect: Rect2) -> Array[int]:
	var result := candidates(route_buckets,rect.position.y-8,rect.end.y+8)
	for index in long_routes:
		if not index in result: result.append(index)
	return result.filter(func(index): return routes[index].bounds.intersects(rect.grow(8)))
func hit(position: Vector2) -> int:
	var best := -1
	var distance := 32.01
	for index in candidates(node_buckets,position.y-32,position.y+32):
		var candidate := position.distance_to(point(index))
		if candidate<=32 and candidate<distance:
			best=index
			distance=candidate
	return best
static func clip_segment(a: Vector2,b: Vector2,rect: Rect2) -> Vector2:
	var low := 0.0
	var high := 1.0
	var delta := b-a
	for axis in range(2):
		if absf(delta[axis])<0.00001:
			if a[axis]<rect.position[axis] or a[axis]>rect.end[axis]: return Vector2(-1,-1)
		else:
			var first: float=(rect.position[axis]-a[axis])/delta[axis]
			var last: float=(rect.end[axis]-a[axis])/delta[axis]
			low=maxf(low,minf(first,last))
			high=minf(high,maxf(first,last))
			if high<low: return Vector2(-1,-1)
	return Vector2(low,high)
