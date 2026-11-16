extends RefCounted
## Pure, non-destructive decoding. File backup/write protection belongs to main.gd.
const Catalog = preload("res://scripts/mutant_catalog.gd")
const VERSION := 2
const RESERVED := ["schema_version","coins","merges","cells","discoveries","active_species","highest"]

static func decode(raw: Variant,count: int=30) -> Dictionary:
	if not raw is Dictionary:
		return {"ok":false,"error":"Save root is not an object"}
	var version: Variant=raw.get("schema_version",1)
	if not Catalog.integer(version,VERSION) or int(version)<1:
		return {"ok":false,"error":"Unsupported save version"}
	var coins: Variant=raw.get("coins",100)
	var merges: Variant=raw.get("merges",0)
	if not Catalog.integer(coins) or not Catalog.integer(merges):
		return {"ok":false,"error":"Invalid currency/statistics"}
	var values: Variant=raw.get("cells",[])
	if not values is Array:
		return {"ok":false,"error":"Invalid board"}
	var extra: Dictionary = raw.duplicate(true)
	for field in RESERVED:
		extra.erase(field)
	var needs_backup: bool = int(version)<VERSION or values.size()!=count
	if values.size()>count:
		extra["retained_overflow_cells"]=values.slice(count)
	var cells: Array=[]
	cells.resize(count)
	cells.fill(null)
	var legacy_highest := 0
	for index in range(mini(values.size(),count)):
		var value: Variant=values[index]
		if value==null:
			continue
		if int(version)==1 and Catalog.integer(value,10):
			var level := int(value)
			if level>0:
				cells[index]=Catalog.make(Catalog.legacy_id(level))
				legacy_highest=maxi(legacy_highest,level)
		elif Catalog.valid_form(value):
			cells[index]=Catalog.canonical(value)
		else:
			return {"ok":false,"error":"Invalid creature at cell %d" % index}
	var discoveries: Dictionary={}
	var saved_forms: Variant=raw.get("discoveries",[])
	if not saved_forms is Array:
		return {"ok":false,"error":"Invalid collection"}
	for saved in saved_forms:
		var form := Catalog.from_key(saved)
		if form.is_empty():
			return {"ok":false,"error":"Invalid collection entry"}
		discoveries[Catalog.key(form)]=true
	if int(version)==1:
		if raw.has("highest"):
			if not Catalog.integer(raw.highest,10):
				return {"ok":false,"error":"Invalid legacy collection"}
			legacy_highest=maxi(legacy_highest,int(raw.highest))
		for level in range(1,legacy_highest+1):
			discoveries[Catalog.key(Catalog.make(Catalog.legacy_id(level)))]=true
		extra["legacy_highest"]=legacy_highest
	for form in cells:
		if form!=null:
			discoveries[Catalog.key(form)]=true
	var active: Variant=raw.get("active_species","slime")
	if not active is String or not Catalog.available(active):
		extra["retained_active_species"]=active
		active="slime"
	return {"ok":true,"cells":cells,"coins":int(coins),"merges":int(merges),"discoveries":discoveries,"active_species":active,"extra":extra,"migrated":int(version)<VERSION,"needs_backup":needs_backup}

static func encode(cells: Array,coins: int,merges: int,active: String,discoveries: Dictionary,extra: Dictionary) -> Dictionary:
	var result := extra.duplicate(true)
	result["schema_version"]=VERSION
	result["cells"]=cells.duplicate(true)
	result["coins"]=coins
	result["merges"]=merges
	result["active_species"]=active
	var keys := discoveries.keys()
	keys.sort()
	result["discoveries"]=keys
	return result
