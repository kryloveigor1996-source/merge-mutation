extends RefCounted
## Deterministic witness generator, followed by independent replay in campaign_test.
const Session = preload("res://scripts/campaign_session.gd")
const Catalog = preload("res://scripts/mutant_catalog.gd")
static func solve(config: Dictionary) -> Dictionary:
	var session := Session.new()
	if not session.start(config): return {"won":false}
	var actions: Array=[]
	for iteration in range(200):
		if session.status!="active": break
		var pair: Array=[]
		if session.moves_left()!=0:
			for first in range(30):
				for second in range(first+1,30):
					if Catalog.can_merge(session.cells[first],session.cells[second]):
						pair=[first,second]
						break
				if not pair.is_empty(): break
		var result: Dictionary
		if pair.is_empty():
			actions.append({"kind":"spawn","index":session.spawn_index(),"species_id":session.next_species()})
			result=session.spawn()
		else:
			actions.append({"kind":"merge","source":pair[0],"index":pair[1]})
			result=session.transfer(pair[0],pair[1])
		if not result.ok: break
	return {"won":session.status=="won","actions":actions,"moves":session.moves_used,"creations":session.creations_used,"merges":session.goals.merges}
