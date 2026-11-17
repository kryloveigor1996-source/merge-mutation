extends RefCounted
## Attempt-local UI command history. Search never uses this object or undo actions.
const FREE_UNDOS := 2
var remaining := FREE_UNDOS
var snapshots: Array=[]
func reset() -> void:
	snapshots.clear()
	remaining=FREE_UNDOS
func execute(session,action: Dictionary) -> Dictionary:
	var before = session.fork()
	before.config=session.config.duplicate(true)
	var result: Dictionary=session.apply_action(action)
	if result.ok: snapshots.append(before)
	return result
func can_undo() -> bool:
	return remaining>0 and not snapshots.is_empty()
func undo(session) -> bool:
	if not can_undo(): return false
	session.restore_from(snapshots.pop_back())
	remaining-=1
	return true
