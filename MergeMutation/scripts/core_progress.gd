extends RefCounted
## One authoritative resource/claim/renovation/observation record inside profile v2.
const C=preload("res://scripts/mutant_catalog.gd")
var config: Dictionary={}
var data: Dictionary={}
var error:=""
func _init() -> void:
	var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/core_economy.json"))
	if raw is Dictionary: config=raw
func initial() -> void:
	data={"version":1,"bio_capsules":int(config.resource.initial),"claimed_levels":[],"habitats":{},"observations":{}}
func decode(raw: Variant,completed: Array) -> bool:
	if not raw is Dictionary or not raw.has_all(["version","bio_capsules","claimed_levels","habitats","observations"]) or raw.version!=1: return fail("Неподдерживаемые данные развития")
	if not C.integer(raw.bio_capsules,int(config.resource.maximum)) or not raw.claimed_levels is Array or not raw.habitats is Dictionary or not raw.observations is Dictionary: return fail("Повреждены данные развития")
	var seen: Array=[]
	for id in raw.claimed_levels:
		if not id is String or not config.rewards.has(id) or id in seen or not int(id.substr(4)) in completed: return fail("Повреждена история наград")
		seen.append(id)
	for number in completed:
		if "lab_%02d" % number not in seen: return fail("История наград неполная")
	for room in raw.habitats:
		if not C.valid_id(room) or not raw.habitats[room] is Dictionary: return fail("Повреждён вольер")
		for slot in raw.habitats[room]:
			if not C.valid_id(slot) or not C.valid_id(raw.habitats[room][slot]): return fail("Повреждено оформление")
	for id in raw.observations:
		if not C.valid_id(id) or raw.observations[id]!=true: return fail("Повреждены наблюдения")
	data=raw.duplicate(true)
	return true
func fail(reason: String) -> bool:
	error=reason
	return false
func copy() -> RefCounted:
	var result=get_script().new()
	result.data=data.duplicate(true)
	return result
func balance() -> int: return int(data.get("bio_capsules",0))
func cost(habitat: String,slot: String) -> int: return int(config.prices.get(habitat,{}).get(slot,-1))
func reward(id: String) -> int:
	var entry: Dictionary=config.rewards.get(id,{})
	return int(entry.get("base",0))+int(entry.get("bonus",0))
func claim(id: String) -> int:
	if not config.rewards.has(id) or id in data.claimed_levels: return 0
	var amount:=reward(id)
	if balance()+amount>int(config.resource.maximum): return -1
	data.bio_capsules=balance()+amount
	data.claimed_levels.append(id)
	data.claimed_levels.sort()
	return amount
func installed(habitat: String) -> Dictionary: return data.get("habitats",{}).get(habitat,{}).duplicate(true)
func install(habitat: String,slot: String,choice: String) -> Dictionary:
	var choices:=installed(habitat)
	var amount: int=0 if choices.has(slot) else cost(habitat,slot)
	if amount<0: return {"ok":false,"reason":"Предмет не зарегистрирован"}
	if choices.get(slot)==choice: return {"ok":true,"changed":false,"cost":0}
	if balance()<amount: return {"ok":false,"reason":"Недостаточно биокапсул. Получайте их в экспедициях."}
	choices[slot]=choice
	data.habitats[habitat]=choices
	data.bio_capsules=balance()-amount
	return {"ok":true,"changed":true,"cost":amount}
func record(habitat: String,event: String) -> String:
	for entry in config.observations:
		if entry.habitat_id==habitat and entry.event==event and not data.observations.has(entry.id):
			data.observations[entry.id]=true
			return entry.title
	return ""
