extends SceneTree
const Levels = preload("res://scripts/campaign_levels.gd")
const Solver = preload("res://tests/campaign_solver.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var proofs := {}
	var failed := false
	for number in range(1,11):
		var started := Time.get_ticks_msec()
		var proof := Solver.solve(Levels.get_level(number),60000)
		proofs[str(number)]=proof
		print("Level ",number,": ",JSON.stringify(proof)," elapsed_ms=",Time.get_ticks_msec()-started)
		failed=failed or not proof.won
	var file := FileAccess.open("res://.godot/tactical-solutions.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(proofs,"\t"))
	file.close()
	quit(1 if failed else 0)
