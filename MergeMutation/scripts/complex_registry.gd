extends RefCounted
## Demo geometry and preview permissions only; never reads or writes player progress.
const Catalog=preload("res://scripts/mutant_catalog.gd")
var floors: Array=[]
var habitats: Dictionary={}
var floor_by_id: Dictionary={}
var room_rects: Dictionary={}
var extent:=0.0
var width:=360.0
var error:=""
func load_files(floor_path: String="res://data/complex/floors.json",habitat_path: String="res://data/complex/habitats.json") -> bool:
	if not FileAccess.file_exists(floor_path) or not FileAccess.file_exists(habitat_path): return fail("Конфигурация комплекса отсутствует")
	var first: Variant=JSON.parse_string(FileAccess.get_file_as_string(floor_path))
	var second: Variant=JSON.parse_string(FileAccess.get_file_as_string(habitat_path))
	return configure(first,second)
func fail(message: String) -> bool:
	error=message
	floors.clear()
	habitats.clear()
	floor_by_id.clear()
	room_rects.clear()
	extent=0
	return false
static func number(value: Variant,low: float,high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=low and value<=high
static func rectangle(value: Variant) -> bool:
	if not value is Array or value.size()!=4: return false
	for part in value:
		if not number(part,0,1000000): return false
	return value[2]>=44 and value[3]>=44
func configure(floor_data: Variant,room_data: Variant,display_width: float=360) -> bool:
	fail("")
	if not number(display_width,360,4000): return fail("Неверная ширина обзора")
	width=display_width
	if not floor_data is Dictionary or not room_data is Dictionary or not floor_data.get("floors") is Array or not room_data.get("habitats") is Array: return fail("Некорректные данные комплекса")
	if floor_data.floors.is_empty() or floor_data.floors.size()>200: return fail("Неверное количество этажей")
	var depths: Dictionary={}
	for item in floor_data.floors:
		if not item is Dictionary or not Catalog.valid_id(item.get("floor_id")) or floor_by_id.has(item.floor_id) or not Catalog.integer(item.get("depth"),10000) or depths.has(int(item.depth)): return fail("Повтор или неверный ID/глубина этажа")
		if not item.get("name") is String or not Catalog.valid_id(item.get("theme_id")) or not number(item.get("height"),120,4000) or not item.get("habitats") is Array or not item.get("preview_accessible") is bool: return fail("Неверные параметры этажа")
		var copy: Dictionary=item.duplicate(true)
		depths[int(item.depth)]=true
		floors.append(copy)
		floor_by_id[item.floor_id]=copy
	floors.sort_custom(func(a,b): return a.depth<b.depth)
	for floor in floors:
		floor.top=extent
		extent+=float(floor.height)
	for item in room_data.habitats:
		if not item is Dictionary or not Catalog.valid_id(item.get("habitat_id")) or habitats.has(item.habitat_id) or not floor_by_id.has(item.get("floor_id")): return fail("Повтор или неверная ссылка комнаты")
		if not Catalog.valid_id(item.get("theme_id")) or not Catalog.valid_id(item.get("size_class")) or not item.get("name") is String or not item.get("description") is String or not item.get("preview_accessible") is bool or not rectangle(item.get("rect")): return fail("Неверные параметры комнаты")
		if item.has("species_id") and (not item.species_id is String or not Catalog.available(item.species_id)): return fail("Неизвестный вид")
		var floor: Dictionary=floor_by_id[item.floor_id]
		var local:=Rect2(item.rect[0],item.rect[1],item.rect[2],item.rect[3])
		if local.position.x<28 or local.end.x>width-12 or local.position.y<36 or local.position.y>=floor.height or local.end.y+floor.top>extent: return fail("Комната выходит за границы комплекса")
		if item.has("interaction_rect"):
			if not rectangle(item.interaction_rect): return fail("Неверная интерактивная область")
			var area: Array=item.interaction_rect
			if not Rect2(Vector2.ZERO,local.size).encloses(Rect2(area[0],area[1],area[2],area[3])): return fail("Интерактивная область вне комнаты")
		var world:=Rect2(local.position+Vector2(0,floor.top),local.size)
		for existing in room_rects.values():
			if existing.intersects(world): return fail("Пересечение комнат, включая межэтажные")
		habitats[item.habitat_id]=item.duplicate(true)
		room_rects[item.habitat_id]=world
	var listed: Dictionary={}
	for floor in floors:
		for id in floor.habitats:
			if not id is String or listed.has(id) or not habitats.has(id) or habitats[id].floor_id!=floor.floor_id: return fail("Неверный список комнат этажа")
			listed[id]=true
	if listed.size()!=habitats.size(): return fail("Комната отсутствует в списке этажа")
	return true
func get_floor(id: String) -> Dictionary: return floor_by_id.get(id,{}).duplicate(true)
func get_habitat(id: String) -> Dictionary: return habitats.get(id,{}).duplicate(true)
func get_floor_for_habitat(id: String) -> Dictionary:
	return get_floor(habitats[id].floor_id) if habitats.has(id) else {}
func get_habitat_for_species(id: String) -> Dictionary:
	if not Catalog.available(id): return {}
	for floor in floors:
		for room_id in floor.habitats:
			if habitats[room_id].get("species_id","")==id: return get_habitat(room_id)
	return {}
func floor_at(y: float) -> Dictionary:
	for floor in floors:
		if y<floor.top+floor.height: return floor
	return floors.back() if not floors.is_empty() else {}
func visible_floors(top: float,height: float) -> Array:
	var result: Array=[]
	for floor in floors:
		var bounds:=Rect2(0,floor.top,width,floor.height)
		if bounds.intersects(Rect2(0,top,width,height)): result.append(floor.floor_id)
	# Tall rooms can overlap a visible floor while anchored on an earlier floor.
	for id in room_rects:
		if room_rects[id].intersects(Rect2(0,top,width,height)) and habitats[id].floor_id not in result: result.append(habitats[id].floor_id)
	return result
