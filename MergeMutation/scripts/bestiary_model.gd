extends RefCounted
const C=preload("res://scripts/mutant_catalog.gd")
const Abilities=preload("res://scripts/mutation_session.gd")
var entries: Dictionary={}
var observations: Array=[]
var error:=""
func load_file(path: String="res://data/bestiary.json") -> bool:
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	entries.clear()
	observations.clear()
	if not data is Dictionary or data.get("version")!=1 or not data.get("dossiers") is Array or not data.get("observations") is Array:
		error="Архив недоступен"
		return false
	for entry in data.dossiers:
		if not entry is Dictionary or not C.available(entry.get("species_id","")) or entries.has(entry.species_id): return false
		for key in ["specimen","classification","origin","biome","temperament","organism","habits","notes","habitat_id","concept_status"]:
			if not entry.get(key) is String: return false
		entries[entry.species_id]=entry.duplicate(true)
	for item in data.observations:
		if not item is Dictionary or not entries.has(item.get("species_id","")) or not item.get("id") is String or not item.get("text") is String: return false
		observations.append(item.duplicate(true))
	return entries.size()==C.ids().size()
static func known(game,id: String) -> bool:
	for stage in range(1,C.maximum(id)+1):
		if game.is_unlocked(id,stage): return true
	return false
func filtered(game,query: String="",filter: int=0) -> Array:
	var result: Array=[]
	for id in C.ids():
		var opened:=known(game,id)
		if filter==1 and not opened or filter==2 and opened: continue
		var title: String=C.species(id).name if opened else "Неизвестный вид"
		if not query.strip_edges().is_empty() and not title.to_lower().contains(query.strip_edges().to_lower()): continue
		result.append(id)
	return result
func dossier(game,id: String,preview: bool=false) -> Dictionary:
	if not entries.has(id): return {}
	if not preview and not known(game,id): return {"name":"Неизвестный вид","specimen":"???","hidden":true}
	var result: Dictionary=entries[id].duplicate(true)
	result.name=C.species(id).name
	result.hidden=false
	result.abilities=[]
	for stage in range(1,C.maximum(id)+1):
		if not preview and not game.is_unlocked(id,stage): continue
		var ability: String=Abilities.ability(C.make(id,stage))
		if not ability.is_empty() and ability not in result.abilities: result.abilities.append(ability)
	return result
func records(id: String) -> Array:
	var result: Array=[]
	for item in observations:
		if item.species_id==id: result.append(item)
	return result
