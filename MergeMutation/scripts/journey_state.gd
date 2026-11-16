extends RefCounted
var seen: Dictionary={}
var extra: Dictionary={}
func decode(raw: Variant) -> bool:
	if not raw is Dictionary or raw.get("version",1)!=1 or not raw.get("seen",{}) is Dictionary: return false
	for id in raw.get("seen",{}):
		if not id is String or not raw.seen[id] is bool: return false
	seen=raw.get("seen",{}).duplicate(true)
	extra=raw.duplicate(true)
	return true
func encode() -> Dictionary:
	var result := extra.duplicate(true)
	result.merge({"version":1,"seen":seen.duplicate()},true)
	return result
func has_seen(id: String) -> bool:
	return bool(seen.get(id,false))
