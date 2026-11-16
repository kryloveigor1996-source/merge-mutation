extends RefCounted
## Stable species IDs and pure evolution rules. No board/economy dependencies.
const LEGACY_IDS := ["slime","eyeball","horn","bubble","shell","wing","tentacle","chimera","rex","ultra"]
const NAMES := ["Слизик","Глазастик","Рогач","Пузырник","Панцирник","Крылатик","Щупальник","Химера","Мутант-рекс","Ультрамутант"]
const COLORS := ["A3DE37","E66DB8","F18A35","F47785","48B9E4","7654C8","28B6A7","E3B449","C64C43","47516C"]
static var entries: Dictionary = {}

static func _ensure() -> void:
	if not entries.is_empty():
		return
	for index in range(LEGACY_IDS.size()):
		var images := {}
		if index<6:
			images[1]="res://assets/mutants/slime_lv1.png" if index==0 else "res://assets/mutants/mutant_lv%d.png" % (index+1)
		entries[LEGACY_IDS[index]]={"id":LEGACY_IDS[index],"name":NAMES[index],"color":Color(COLORS[index]),"max_stage":5,"images":images,"display":{"art_index":index+1,"size_index":index+1,"stage_growth":0.04},"available":true}

static func ids() -> Array[String]:
	_ensure()
	var result: Array[String]=[]
	result.assign(entries.keys())
	return result

static func species(id: String) -> Dictionary:
	_ensure()
	return entries.get(id,{}).duplicate(true)

static func valid_id(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length()>64:
		return false
	for index in range(value.length()):
		var code: int=value.unicode_at(index)
		if not (code>=97 and code<=122 or index>0 and (code>=48 and code<=57 or code==95)):
			return false
	return true

static func integer(value: Variant,maximum: int=2147483647) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=maximum and floor(float(value))==value

static func register_species(data: Dictionary) -> bool:
	_ensure()
	if not valid_id(data.get("id")) or entries.has(data.id) or not data.get("name") is String or not integer(data.get("max_stage"),1000000) or int(data.max_stage)<1:
		return false
	var entry := data.duplicate(true)
	entry["color"]=entry.get("color",Color("8aa3af"))
	entry["images"]=entry.get("images",{})
	entry["display"]=entry.get("display",{"art_index":1,"size_index":1,"stage_growth":0.04})
	entry["available"]=entry.get("available",true)
	if not entry.color is Color or not entry.images is Dictionary or not entry.display is Dictionary or not entry.available is bool:
		return false
	entries[entry.id]=entry
	return true

static func available(id: String) -> bool:
	return bool(species(id).get("available",false))

static func maximum(id: String) -> int:
	return int(species(id).get("max_stage",0))

static func make(id: String,stage: int=1) -> Dictionary:
	return {"species_id":id,"evolution_stage":stage}

static func valid_form(value: Variant) -> bool:
	return value is Dictionary and valid_id(value.get("species_id")) and integer(value.get("evolution_stage"),1000000) and int(value.evolution_stage)>0

static func canonical(value: Dictionary) -> Dictionary:
	var result := value.duplicate(true)
	result.evolution_stage=int(result.evolution_stage)
	return result

static func known_form(value: Variant) -> bool:
	return valid_form(value) and maximum(value.species_id)>=int(value.evolution_stage)

static func can_merge(first: Variant,second: Variant) -> bool:
	return known_form(first) and known_form(second) and first.species_id==second.species_id and int(first.evolution_stage)==int(second.evolution_stage) and int(first.evolution_stage)<maximum(first.species_id)

static func evolve(value: Dictionary) -> Dictionary:
	var result := canonical(value)
	if not known_form(result) or result.evolution_stage>=maximum(result.species_id):
		return result
	result.evolution_stage+=1
	return result

static func legacy_id(level: int) -> String:
	return LEGACY_IDS[level-1] if level>=1 and level<=LEGACY_IDS.size() else ""

static func key(value: Dictionary) -> String:
	return "%s:%d" % [value.species_id,int(value.evolution_stage)]

static func from_key(value: Variant) -> Dictionary:
	if not value is String:
		return {}
	var parts: PackedStringArray=value.split(":")
	if parts.size()!=2 or not valid_id(parts[0]) or not parts[1].is_valid_int():
		return {}
	var form := make(parts[0],int(parts[1]))
	return form if valid_form(form) else {}

static func stage_label(stage: int) -> String:
	return ["I","II","III","IV","V"][stage-1] if stage>=1 and stage<=5 else str(stage)

static func title(form: Dictionary) -> String:
	return "%s %s" % [species(form.species_id).get("name","Неизвестный вид"),stage_label(int(form.evolution_stage))]

static func total_forms() -> int:
	var total := 0
	for id in ids():
		total+=maximum(id)
	return total
