extends RefCounted
## A deliberately separate, atomic demo sidecar. Never writes the main save.
signal changed
signal preview_changed
const C=preload("res://scripts/mutant_catalog.gd")
const FORMAT="merge_mutation_demo_renovation"
var catalog
var path:=""
var points:=3
var installed: Dictionary={}
var root_data: Dictionary={}
var room_data: Dictionary={}
var read_only:=false
var error:=""
var preview_slot:=""
var preview_design:=""
func setup(config,save_path: String) -> bool:
	catalog=config
	path=save_path
	return reload()
func reload() -> bool:
	points=3
	installed.clear()
	root_data={}
	room_data={}
	read_only=false
	error=""
	cancel_preview()
	if not FileAccess.file_exists(path): return true
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>1048576: return block("Не удалось прочитать демо-ремонт")
	var raw: Variant=JSON.parse_string(file.get_as_text())
	if not raw is Dictionary or raw.get("format")!=FORMAT or raw.get("version")!=1 or not raw.get("habitats") is Dictionary: return block("Неизвестный или повреждённый формат демо-ремонта")
	root_data=raw.duplicate(true)
	var room: Variant=raw.habitats.get(catalog.habitat_id,{})
	if not room is Dictionary or room.get("habitat_id",catalog.habitat_id)!=catalog.habitat_id or not C.integer(room.get("points",3),100000) or not room.get("installed",{}) is Dictionary: return block("Повреждённые данные комнаты")
	room_data=room.duplicate(true)
	points=int(room.get("points",3))
	for id in room.get("installed",{}):
		var choice: Variant=room.installed[id]
		if choice is String and not catalog.design(id,choice).is_empty(): installed[id]=choice
	return true
func block(message: String) -> bool:
	read_only=true
	points=0
	error=message+" · исходный файл сохранён"
	return false
func progress() -> int: return roundi(100.0*installed.size()/catalog.slots.size())
func available(id: String) -> bool:
	if not catalog.slots.has(id): return false
	for dep in catalog.slots[id].requires:
		if not installed.has(dep): return false
	return true
func preview(id: String,choice: String) -> bool:
	if read_only or not available(id) or catalog.design(id,choice).is_empty(): return false
	preview_slot=id
	preview_design=choice
	preview_changed.emit()
	return true
func cancel_preview() -> void:
	preview_slot=""
	preview_design=""
	preview_changed.emit()
func visual_choice(id: String) -> String:
	return preview_design if id==preview_slot else installed.get(id,"")
func confirm(id: String,choice: String) -> Dictionary:
	if read_only or not available(id) or catalog.design(id,choice).is_empty(): return {"ok":false,"reason":"Предмет недоступен"}
	if installed.get(id)==choice:
		cancel_preview()
		return {"ok":true,"changed":false}
	var cost: int=0 if installed.has(id) else int(catalog.slots[id].cost)
	if points<cost: return {"ok":false,"reason":"Недостаточно тестовых очков"}
	var next: Dictionary=installed.duplicate()
	next[id]=choice
	if not commit(next,points-cost): return {"ok":false,"reason":error}
	cancel_preview()
	return {"ok":true,"changed":true}
func commit(next: Dictionary,balance: int,reset: bool=false) -> bool:
	var data: Dictionary=root_data.duplicate(true)
	if reset and FileAccess.file_exists(path):
		var latest: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		if latest is Dictionary and latest.get("format")==FORMAT and latest.get("version")==1 and latest.get("habitats") is Dictionary: data=latest.duplicate(true)
	if not reset and FileAccess.file_exists(path):
		var current: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		if not current is Dictionary or current.get("format")!=FORMAT or current.get("version")!=1 or not current.get("habitats") is Dictionary:
			error="Демо-файл изменился. Закройте и снова откройте вольер."
			return false
		var expected: Variant=JSON.parse_string(JSON.stringify(room_data))
		if JSON.stringify(current.habitats.get(catalog.habitat_id,{}),"",true)!=JSON.stringify(expected,"",true):
			error="Данные комнаты изменились. Закройте и снова откройте вольер."
			return false
		data=current.duplicate(true)
	data.merge({"format":FORMAT,"version":1},true)
	if not data.get("habitats") is Dictionary: data["habitats"]={}
	var room: Dictionary={} if reset else room_data.duplicate(true)
	# Unknown slots/designs remain inert in the sidecar until explicitly reset.
	var choices: Dictionary={} if reset else room.get("installed",{}).duplicate(true)
	choices.merge(next,true)
	room.merge({"habitat_id":catalog.habitat_id,"points":balance,"installed":choices},true)
	data.habitats[catalog.habitat_id]=room
	var file:=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:
		error="Не удалось записать демо-ремонт"
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var code:=file.get_error()
	file.close()
	if code!=OK or DirAccess.rename_absolute(path+".tmp",path)!=OK:
		error="Не удалось заменить демо-файл"
		return false
	root_data=data
	room_data=room
	installed=next.duplicate()
	points=balance
	read_only=false
	error=""
	changed.emit()
	return true
func grant_test_point() -> bool:
	return false if read_only or points>=100000 else commit(installed,points+1)
func reset_demo(confirmed: bool) -> bool:
	if not confirmed: return false
	if FileAccess.file_exists(path):
		var backup:=path+".pre-reset-"+FileAccess.get_sha256(path).substr(0,12)+".bak"
		if not FileAccess.file_exists(backup) and DirAccess.copy_absolute(path,backup)!=OK:
			error="Не удалось сохранить копию демо-ремонта"
			return false
	var ok:=commit({},3,true)
	if ok: cancel_preview()
	return ok
