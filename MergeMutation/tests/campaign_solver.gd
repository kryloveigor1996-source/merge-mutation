extends RefCounted
const Session = preload("res://scripts/campaign_session.gd")
const Search = preload("res://scripts/tactical_search.gd")
static func solve(config: Dictionary,max_states: int=60000) -> Dictionary:
	var session := Session.new()
	if not session.start(config): return {"won":false,"exhaustive":true,"actions":[]}
	return Search.solve(session,max_states,false)
