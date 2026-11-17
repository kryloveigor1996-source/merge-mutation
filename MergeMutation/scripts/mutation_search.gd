extends RefCounted
## Dijkstra with integer-cost buckets: spawning is free, all other actions cost one move.
## Uses the exact playable session, including destructible terrain and positional goals.
static func solve(initial,limit: int=150000) -> Dictionary:
	var first = initial.fork()
	var states: Array=[first]
	var parents: Array[int]=[-1]
	var incoming: Array=[{}]
	var buckets: Dictionary={0:[0]}
	var best := {first.signature():0}
	var visited := 0
	for cost in range(initial.moves_left()+1):
		var queue: Array=buckets.get(cost,[])
		var head := 0
		while head<queue.size():
			var cursor: int=queue[head]
			head+=1
			var state = states[cursor]
			visited+=1
			if state.won():
				var actions: Array=[]
				while parents[cursor]>=0:
					actions.push_front(incoming[cursor])
					cursor=parents[cursor]
				return {"won":true,"optimal":true,"moves":cost,"actions":actions,"visited":visited,"cutoff":false}
			for action in state.legal_actions():
				var next = state.fork()
				if not next.apply_action(action,false).ok: continue
				var distance: int=next.moves_used-initial.moves_used
				var key: String=next.signature()
				if best.has(key) and best[key]<=distance: continue
				if states.size()>=limit: return {"won":false,"optimal":false,"cutoff":true,"visited":visited,"actions":[]}
				best[key]=distance
				states.append(next)
				parents.append(queue[head-1])
				incoming.append(action)
				if distance==cost: queue.append(states.size()-1)
				else:
					if not buckets.has(distance): buckets[distance]=[]
					buckets[distance].append(states.size()-1)
	return {"won":false,"optimal":false,"cutoff":false,"visited":visited,"actions":[]}
