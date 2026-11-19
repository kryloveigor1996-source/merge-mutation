extends "res://scripts/renovation_state.gd"
## Version 2 retains the PR18 sidecar filename and all original data in a backup.
var migration_notice:=""
func storage_version() -> int: return 2
func offered() -> Array:
	var result: Array=[]
	if read_only: return result
	for id in catalog.offers:
		if not installed.has(id) and super.available(id):
			result.append(id)
			if result.size()>=catalog.offer_limit: break
	return result
func available(id: String) -> bool:
	return super.available(id) and (installed.has(id) or id in offered())
func reload() -> bool:
	migration_notice=""
	if FileAccess.file_exists(path):
		var source:=FileAccess.open(path,FileAccess.READ)
		if source!=null and source.get_length()<=1048576:
			var raw: Variant=JSON.parse_string(source.get_as_text())
			source.close()
			if raw is Dictionary and raw.get("format")==FORMAT and raw.get("version")==1 and raw.get("habitats") is Dictionary:
				if not migrate(raw): return false
	var loaded:=super.reload()
	if loaded:
		var unresolved: int=room_data.get("installed",{}).size()-installed.size()
		if unresolved>0:
			read_only=true
			error="Сохранены неизвестные оформления (%d). Проверьте перенос или подтвердите сброс демо; очки сохранены." % unresolved
			return false
	return loaded
func migrate(raw: Dictionary) -> bool:
	var data: Dictionary=raw.duplicate(true)
	var mappings: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/ecosystems/pr18-design-map.json"))
	var unresolved: Array=[]
	if not mappings is Dictionary: return block("Нет таблицы переноса")
	for id in data.habitats:
		if not mappings.has(id): continue
		var room: Variant=data.habitats[id]
		if not room is Dictionary or not room.get("installed",{}) is Dictionary or not C.integer(room.get("points",3),100000): return block("Неверные данные переноса")
		for slot in room.get("installed",{}):
			var design: Variant=room.installed[slot]
			if mappings[id].has(slot) and design is String and mappings[id][slot].has(design):
				room.installed[slot]=mappings[id][slot][design]
			elif not (mappings[id].has(slot) and design in mappings[id][slot].values()):
				unresolved.append(id+"."+slot)
	var backup:=path+".pre-ecosystems-"+FileAccess.get_sha256(path).substr(0,12)+".bak"
	if not FileAccess.file_exists(backup) and DirAccess.copy_absolute(path,backup)!=OK: return block("Не удалось создать копию PR18")
	if not unresolved.is_empty():
		root_data=raw.duplicate(true)
		room_data=raw.habitats.get(catalog.habitat_id,{}).duplicate(true)
		installed.clear()
		for id in data.habitats.get(catalog.habitat_id,{}).get("installed",{}):
			var choice: Variant=data.habitats[catalog.habitat_id].installed[id]
			if choice is String and not catalog.design(id,choice).is_empty(): installed[id]=choice
		preview_slot=""
		preview_design=""
		read_only=true
		points=int(room_data.get("points",3))
		error="Перенос требует проверки: "+", ".join(unresolved)+". Очки и исходник сохранены; доступен подтверждаемый сброс демо."
		return false
	data.version=2
	data["migration"]={"from":1,"backup_hash":FileAccess.get_sha256(path)}
	var file:=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null: return block("Не удалось записать перенос")
	file.store_string(JSON.stringify(data))
	file.flush()
	var code:=file.get_error()
	file.close()
	if code!=OK or DirAccess.rename_absolute(path+".tmp",path)!=OK: return block("Не удалось завершить перенос")
	migration_notice="Оформления PR18 перенесены, резервная копия сохранена"
	return true
