extends SceneTree
const Session=preload("res://scripts/evolution_session.gd")
const Solver=preload("res://scripts/mutation_search.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var proofs: Dictionary={}
	for number in range(1,11):
		var path="res://evolution/levels/level_%02d.json" % number
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
		var session=Session.new()
		if not session.start(data): printerr("FAIL: invalid ",number); quit(1); return
		var start=Time.get_ticks_msec()
		var result=Solver.solve(session,200000)
		print("Evolution ",number,": ",result.get("moves",-1)," moves; ",result.visited," states; ",Time.get_ticks_msec()-start,"ms; won=",result.won," cutoff=",result.cutoff)
		if not result.won: quit(1); return
		proofs[str(number)]=result
	var file=FileAccess.open("res://.godot/evolution-proofs.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(proofs,"\t"))
	file.close()
	print("Evolution solver checks: 10; failures: 0")
	quit()