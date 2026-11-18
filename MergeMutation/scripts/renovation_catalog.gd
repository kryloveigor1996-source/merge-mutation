extends RefCounted
## Immutable authored geometry and identifiers; no player data or UI dependencies.
const C=preload("res://scripts/mutant_catalog.gd")
var habitat_id:=""
var slots: Dictionary={}
var zones: Dictionary={}
var error:=""
var world_size:=Vector2(2350,420)
const VISUALS={
	"walls":["rock","nature","future"],"floor":["stone","sand","metal"],
	"bed":["cave","cushion","pod"],"feeder":["bowl","auto","wood"],
	"training":["boulder","crystal","target"],"cabinets":["wood","metal","future"],
	"plants":["cactus","fern","mushrooms"],"lighting":["torch","lamp","neon"],
	"toy":["ball","tire","robot"],"water":["pool","pond","tank"]
}
static func path_for_habitat(id: String) -> String:
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/renovation/catalog.json"))
	if not data is Dictionary or not data.get(id) is String or not data[id].begins_with("res://"): return ""
	return data[id]
func load_file(path: String="res://data/renovation/horn.json") -> bool:
	return configure(JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null)
static func rectangle(a: Variant,bounds: Rect2) -> bool:
	if not a is Array or a.size()!=4: return false
	for n in a:
		if not (n is int or n is float) or not is_finite(n): return false
	return a[2]>0 and a[3]>0 and bounds.encloses(Rect2(a[0],a[1],a[2],a[3]))
func fail(message: String) -> bool:
	slots.clear()
	zones.clear()
	error=message
	return false
func configure(data: Variant) -> bool:
	fail("")
	if not data is Dictionary or data.get("version")!=1 or not C.valid_id(data.get("habitat_id")) or not data.get("slots") is Array or not data.get("zones") is Array: return fail("Неверный каталог")
	if not data.get("world_size") is Array or data.world_size.size()!=2 or data.world_size[0]!=2350 or data.world_size[1]!=420 or data.slots.is_empty() or data.slots.size()>256: return fail("Неверный размер мира или число слотов")
	habitat_id=data.habitat_id
	var bounds:=Rect2(Vector2.ZERO,world_size)
	for zone in data.zones:
		if not zone is Dictionary or not C.valid_id(zone.get("zone_id")) or zones.has(zone.zone_id) or not rectangle(zone.get("rect"),bounds): return fail("Неверная зона")
		var a: Array=zone.rect
		for existing in zones.values():
			var b: Array=existing.rect
			if Rect2(a[0],a[1],a[2],a[3]).intersects(Rect2(b[0],b[1],b[2],b[3])): return fail("Зоны пересекаются")
		zones[zone.zone_id]=zone.duplicate(true)
	var design_ids: Dictionary={}
	for slot in data.slots:
		if not slot is Dictionary or not C.valid_id(slot.get("slot_id")) or slots.has(slot.slot_id) or slot.get("habitat_id")!=habitat_id or not zones.has(slot.get("zone_id")): return fail("Неверный ID или ссылка слота")
		if not slot.get("name") is String or slot.name.is_empty() or not slot.get("description") is String or slot.get("layer") not in ["back","ground","far","objects","front","light"]: return fail("Неверное описание слота")
		if not VISUALS.has(slot.get("kind")): return fail("Неизвестный тип предмета")
		if not rectangle(slot.get("rect"),bounds) or not rectangle(slot.get("touch"),bounds): return fail("Геометрия вне мира")
		if slot.touch[2]<44 or slot.touch[3]<44: return fail("Слишком маленькая область касания")
		if not slot.get("anchor") is Array or slot.anchor.size()!=2: return fail("Неверный маркер")
		for n in slot.anchor:
			if not (n is int or n is float) or not is_finite(n): return fail("Неверный маркер")
		if not bounds.has_point(Vector2(slot.anchor[0],slot.anchor[1])): return fail("Маркер вне мира")
		var area: Array=zones[slot.zone_id].rect
		if not Rect2(area[0],area[1],area[2],area[3]).has_point(Vector2(slot.anchor[0],slot.anchor[1])): return fail("Маркер вне своей зоны")
		if not C.integer(slot.get("cost"),100) or slot.cost!=1 or not slot.get("requires") is Array: return fail("Неверная стоимость или зависимости")
		if slot.get("interaction") not in ["none","sleep","feed","training","storage","light","play"]: return fail("Неверное взаимодействие")
		if not slot.get("collision") is Array: return fail("Неверная коллизия")
		if not slot.collision.is_empty():
			var r: Array=slot.rect
			if not rectangle(slot.collision,Rect2(r[0],r[1],r[2],r[3])): return fail("Коллизия вне предмета")
			var a: Array=slot.collision
			if Rect2(a[0],a[1],a[2],a[3]).intersects(Rect2(48,274,2254,80)): return fail("Предмет перекрывает дорожку")
		if not slot.get("designs") is Array or slot.designs.size()!=3: return fail("Нужны три варианта")
		for design in slot.designs:
			if not design is Dictionary or not C.valid_id(design.get("design_id")) or design_ids.has(design.design_id) or not C.valid_id(design.get("visual")) or not design.get("name") is String: return fail("Неверный или повторный вариант")
			if design.visual not in VISUALS[slot.kind]: return fail("Неизвестное оформление")
			if design.has("texture") and (not design.texture is String or not design.texture.begins_with("res://")): return fail("Неверный ресурс")
			if design.has("texture") and not ResourceLoader.exists(design.texture,"Texture2D"): return fail("Отсутствует текстура варианта")
			design_ids[design.design_id]=true
		slots[slot.slot_id]=slot.duplicate(true)
	var pending: Dictionary={}
	for id in slots:
		var seen: Dictionary={}
		for dep in slots[id].requires:
			if not dep is String or not slots.has(dep) or seen.has(dep): return fail("Неверная зависимость")
			seen[dep]=true
		pending[id]=seen
	while not pending.is_empty():
		var ready: Array=[]
		for id in pending:
			if pending[id].is_empty(): ready.append(id)
		if ready.is_empty(): return fail("Циклическая зависимость")
		for id in ready:
			pending.erase(id)
			for key in pending: pending[key].erase(id)
	return true
func design(slot_id: String,design_id: String) -> Dictionary:
	for d in slots.get(slot_id,{}).get("designs",[]):
		if d.design_id==design_id: return d
	return {}
func project_rect(slot: Dictionary,width: float,key: String="rect") -> Rect2:
	var a: Array=slot[key]
	var origin: Array=slot.rect
	var x:=clampf(origin[0]*width/world_size.x,8,maxf(8,width-origin[2]-12))
	if origin[2]==world_size.x:
		if key=="rect": return Rect2(0,a[1],width,a[3])
		return Rect2(clampf(a[0]*width/world_size.x,8,width-a[2]-12),a[1],a[2],a[3])
	return Rect2(x+a[0]-origin[0],a[1],a[2],a[3])
func marker(slot: Dictionary,width: float) -> Vector2:
	if slot.rect[2]==world_size.x: return Vector2(slot.anchor[0]*width/world_size.x,slot.anchor[1])
	var rect:=project_rect(slot,width)
	return rect.position+Vector2(slot.anchor[0]-slot.rect[0],slot.anchor[1]-slot.rect[1])
