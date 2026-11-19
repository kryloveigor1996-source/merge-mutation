extends RefCounted
## Presentation preferences live with the existing audio ConfigFile, never in the wallet.
var path=""
var portrait=false
var hints=true
var shown: Dictionary={}
var learned: Dictionary={}
var error=""
func setup(value: String) -> void:
	path=value
	var file=ConfigFile.new()
	if file.load(path)!=OK: return
	portrait=file.get_value("presentation","portrait",false)==true
	hints=file.get_value("tutorial","enabled",true)!=false
	for key in ["shown","learned"]:
		var value_at: Variant=file.get_value("tutorial",key,{})
		if value_at is Dictionary:
			for id in value_at:
				if id is String and id.length()<64 and value_at[id]==true: get(key)[id]=true
func save() -> bool:
	var file=ConfigFile.new()
	file.load(path)
	file.set_value("presentation","portrait",portrait)
	file.set_value("tutorial","version",1)
	file.set_value("tutorial","enabled",hints)
	file.set_value("tutorial","shown",shown)
	file.set_value("tutorial","learned",learned)
	var result=file.save(path)
	error="" if result==OK else "Не удалось сохранить настройки"
	return result==OK
func master(id: String) -> void:
	if learned.has(id): return
	learned[id]=true
	save()