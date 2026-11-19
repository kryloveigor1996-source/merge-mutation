extends "res://scripts/ecosystem_renovation.gd"
var owner_game
func bind(game,config) -> void:
	owner_game=game
	catalog=config
	for slot in catalog.slots: catalog.slots[slot].cost=game.progression.cost(catalog.habitat_id,slot)
	owner_game.progression_changed.connect(sync)
	sync()
func sync() -> void:
	installed=owner_game.progression.installed(catalog.habitat_id)
	points=owner_game.progression.balance()
	read_only=owner_game.write_blocked
	changed.emit()
func confirm(id: String,choice: String) -> Dictionary:
	if read_only or not available(id) or catalog.design(id,choice).is_empty(): return {"ok":false,"reason":"Предмет недоступен"}
	var result: Dictionary=owner_game.install_item(catalog.habitat_id,id,choice)
	if result.ok: cancel_preview()
	return result
func grant_test_point() -> bool: return false
func reset_demo(_confirmed: bool) -> bool: return false
func commit(_next: Dictionary,_balance: int,_reset: bool=false) -> bool: return false
