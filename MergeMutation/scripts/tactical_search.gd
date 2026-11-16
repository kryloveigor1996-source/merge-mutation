extends RefCounted
## BFS over actual session transitions. No session preload: avoids a dependency cycle.
static func solve(initial,max_states: int=100000,include_boosters: bool=false) -> Dictionary:
	var first = initial.fork()
	var states: Array=[first]
	var parents: Array[int]=[-1]
	var incoming: Array=[{}]
	var seen := {first.signature():true}
	var head := 0
	var cutoff := false
	while head<states.size():
		var state = states[head]
		if state.goals.all_met(state.config.goals):
			var actions: Array=[]
			var cursor := head
			while parents[cursor]>=0:
				actions.append(incoming[cursor])
				cursor=parents[cursor]
			actions.reverse()
			var transfers := 0
			var merges := 0
			for action in actions:
				if action.kind=="move": transfers+=1
				if action.kind=="merge": merges+=1
			return {"won":true,"exhaustive":false,"cutoff":cutoff,"actions":actions,"moves":state.moves_used-initial.moves_used,"creations":state.creations_used-initial.creations_used,"merges":merges,"transfers":transfers,"explored":head+1,"visited":states.size(),"method":"BFS","limit":max_states}
		for action in state.legal_actions(include_boosters):
			var next = state.fork()
			var result: Dictionary=next.apply_action(action,false)
			if not result.ok: continue
			var key: String=next.signature()
			if seen.has(key): continue
			if states.size()>=max_states:
				cutoff=true
				continue
			seen[key]=true
			states.append(next)
			parents.append(head)
			incoming.append(action)
		head+=1
	return {"won":false,"exhaustive":not cutoff,"cutoff":cutoff,"actions":[],"explored":head,"visited":states.size(),"method":"BFS","limit":max_states}
