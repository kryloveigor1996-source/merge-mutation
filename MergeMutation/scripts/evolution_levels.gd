extends RefCounted
const Session=preload("res://scripts/evolution_session.gd")
const COUNT=10
static func get_level(number: int) -> Dictionary:
	if number<1 or number>COUNT: return {}
	var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://evolution/levels/level_%02d.json" % number))
	return raw if raw is Dictionary and Session.valid(raw) else {}