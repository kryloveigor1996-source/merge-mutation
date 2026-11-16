extends RefCounted
static var data: Dictionary={}
var last_global := -1000000
var contexts: Dictionary={}
var quotes: Dictionary={}
static func ensure() -> void:
	if data.is_empty():
		var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue.json"))
		if raw is Dictionary: data=raw
static func scene(id: String) -> Dictionary:
	ensure()
	return data.get("scenes",{}).get(id,{}).duplicate(true)
static func speaker_name(id: String) -> String:
	return "Профессор" if id=="scientist" else "Лабораторный ИИ"
static func text(line: Dictionary) -> String:
	return "%s: %s" % [speaker_name(line.get("speaker","ai")),line.get("text","")]
func next_line(context: String,now: int=-1) -> Dictionary:
	ensure()
	if now<0: now=Time.get_ticks_msec()
	if now-last_global<12000 or now-int(contexts.get(context,-1000000))<30000: return {}
	for line in data.get("contexts",{}).get(context,[]):
		if now-int(quotes.get(line.id,-1000000))>=120000:
			last_global=now
			contexts[context]=now
			quotes[line.id]=now
			return line.duplicate(true)
	return {}
