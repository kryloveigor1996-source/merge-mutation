extends RefCounted
## Attempt-local tools. Future tools are declared, but have no enabled effects.
const TYPES := {
	"teleporter":{"name":"Телепортатор","enabled":true},
	"evacuator":{"name":"Эвакуатор","enabled":false},
	"evolution_serum":{"name":"Сыворотка эволюции","enabled":false}
}
var charges: Dictionary={"teleporter":0}
func grant(id: String,amount: int) -> bool:
	if not TYPES.has(id) or not TYPES[id].enabled or amount<0: return false
	charges[id]=int(charges.get(id,0))+amount
	return true
func remaining(id: String) -> int:
	return int(charges.get(id,0))
func activate(session,id: String,source: int,destination: int) -> Dictionary:
	if id!="teleporter" or remaining(id)<1 or session.status!="active": return {"ok":false,"reason":"Нет заряда Телепортатора"}
	if session.blocked(source) or session.blocked(destination) or source==destination or session.cells[source]==null or session.cells[destination]!=null:
		return {"ok":false,"reason":"Телепорт: нужна свободная доступная клетка"}
	session.cells[destination]=session.cells[source]
	session.cells[source]=null
	charges[id]=remaining(id)-1
	return {"ok":true,"kind":"move","source":source,"index":destination,"form":session.cells[destination],"booster":id}
