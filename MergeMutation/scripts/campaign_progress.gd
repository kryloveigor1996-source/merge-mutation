extends RefCounted
const Catalog = preload("res://scripts/mutant_catalog.gd")
const Levels = preload("res://scripts/campaign_levels.gd")
var completed: Array[int]=[]
var claimed: Array[int]=[]
var stars := 0
var extra: Dictionary={}
func unlocked() -> int:
	var next := 1
	while next in completed and next<Levels.COUNT: next+=1
	return next
func decode(raw: Variant) -> bool:
	if not raw is Dictionary or raw.get("version",1)!=1: return false
	for field in ["completed","claimed"]:
		if not raw.get(field,raw.get("completed",[]) if field=="claimed" else []) is Array: return false
	var done: Array[int]=[]
	var awards: Array[int]=[]
	for number in raw.get("completed",[]):
		if not Catalog.integer(number,Levels.COUNT) or number<1 or int(number) in done: return false
		done.append(int(number))
	# Missing claim data is conservatively treated as already rewarded.
	for number in raw.get("claimed",raw.get("completed",[])):
		if not Catalog.integer(number,Levels.COUNT) or not int(number) in done or int(number) in awards: return false
		awards.append(int(number))
	if awards.size()!=done.size(): return false
	if not Catalog.integer(raw.get("stars",awards.size())) or int(raw.get("stars",awards.size()))<awards.size(): return false
	completed=done
	claimed=awards
	stars=int(raw.get("stars",awards.size()))
	extra=raw.duplicate(true)
	return true
func encode() -> Dictionary:
	var data := extra.duplicate(true)
	data.merge({"version":1,"completed":completed.duplicate(),"claimed":claimed.duplicate(),"stars":stars,"last_unlocked":unlocked()},true)
	return data
func finish(number: int) -> Dictionary:
	if number<1 or number>unlocked(): return {"coins":0,"stars":0}
	if not number in completed: completed.append(number)
	if number in claimed: return {"coins":0,"stars":0}
	claimed.append(number)
	var data := Levels.get_level(number)
	stars+=int(data.reward_stars)
	return {"coins":int(data.reward_coins),"stars":int(data.reward_stars)}
