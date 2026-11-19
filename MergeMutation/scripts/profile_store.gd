extends RefCounted
## Compare-and-swap profile write. Claims, currency and installed choices share one file.
static func write(path: String,value: Dictionary,expected_hash: String,backup: bool=false) -> Dictionary:
	var exists:=FileAccess.file_exists(path)
	if exists and FileAccess.get_sha256(path)!=expected_hash or not exists and not expected_hash.is_empty():
		return {"ok":false,"reason":"Профиль изменился. Перезапустите игру, чтобы перечитать сохранение."}
	if backup and exists:
		var copy_path:=path+".pre-core-loop-"+expected_hash.substr(0,12)+".bak"
		if not FileAccess.file_exists(copy_path) and DirAccess.copy_absolute(path,copy_path)!=OK: return {"ok":false,"reason":"Не удалось создать резервную копию"}
	var stream:=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if stream==null: return {"ok":false,"reason":"Не удалось записать прогресс"}
	stream.store_string(JSON.stringify(value))
	stream.flush()
	var status:=stream.get_error()
	stream.close()
	if status!=OK or DirAccess.rename_absolute(path+".tmp",path)!=OK: return {"ok":false,"reason":"Не удалось завершить сохранение"}
	return {"ok":true,"hash":FileAccess.get_sha256(path)}
