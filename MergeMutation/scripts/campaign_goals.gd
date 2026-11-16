extends RefCounted
const Catalog = preload("res://scripts/mutant_catalog.gd")
var produced: Dictionary={}
var merges := 0
func record(form: Dictionary) -> void:
	var key := Catalog.key(form)
	produced[key]=int(produced.get(key,0))+1
func count(form: Dictionary) -> int:
	return int(produced.get(Catalog.key(form),0))
func target_met(form: Dictionary) -> bool:
	return count(form)>=int(form.get("count",1))
func met(goal: Dictionary) -> bool:
	match goal.type:
		"reach_stage": return target_met(goal)
		"merge_count": return merges>=int(goal.count)
		"collect_forms":
			var required := {}
			for form in goal.forms:
				var key := Catalog.key(form)
				required[key]=int(required.get(key,0))+int(form.get("count",1))
			for key in required:
				if int(produced.get(key,0))<required[key]: return false
			return true
	return false
func all_met(goals: Array) -> bool:
	return goals.all(func(goal): return met(goal))
func target_text(form: Dictionary) -> String:
	return "%s: %d/%d" % [Catalog.title(form),mini(count(form),int(form.get("count",1))),int(form.get("count",1))]
func text(goals: Array) -> String:
	var parts: PackedStringArray=[]
	for goal in goals:
		match goal.type:
			"reach_stage": parts.append(target_text(goal))
			"merge_count": parts.append("Слияния: %d/%d" % [mini(merges,int(goal.count)),int(goal.count)])
			"collect_forms":
				for form in goal.forms: parts.append(target_text(form))
	return " · ".join(parts)
