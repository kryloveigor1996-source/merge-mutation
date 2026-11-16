extends SceneTree
const Catalog = preload("res://scripts/mutant_catalog.gd")
const Codec = preload("res://scripts/save_codec.gd")
const Game = preload("res://scripts/main.gd")
const Art = preload("res://scripts/mutant_art.gd")
const Sizes = preload("res://scripts/mutant_sizes.gd")
var checks := 0
var failures := 0
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:
		failures+=1
		printerr("FAIL: ",label)
func _initialize() -> void:
	call_deferred("_run")
func write(path: String,value: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(value)
	file.close()
func _run() -> void:
	check(Catalog.ids().size()==10 and Catalog.total_forms()==50,"ten species fifty forms")
	for id in Catalog.ids():
		check(Catalog.valid_id(id) and Catalog.maximum(id)==5 and Catalog.available(id),"catalog entry "+id)
		for stage in range(1,6):
			var form := Catalog.make(id,stage)
			check(Catalog.known_form(form) and Catalog.from_key(Catalog.key(form))==form,"form identity")
			check(Catalog.can_merge(form,form)==(stage<5),"catalog maximum")
			for other in Catalog.ids():
				check(Catalog.can_merge(form,Catalog.make(other,stage))==(other==id and stage<5),"cross species rules")
			var art := Art.new()
			art.setup_form(form)
			check(art.species_id==id and art.evolution_stage==stage,"visual identity")
			check((art.texture!=null)==(Catalog.LEGACY_IDS.find(id)<6),"base PNG or procedural")
			check(maxf(art.visible_rect().size.x,art.visible_rect().size.y)<=86.01,"safe stage growth")
			check(Rect2(-43,-43,86,86).encloses(art.visible_rect()),"bounded silhouette")
			for point in [Vector2(-100,-100),Vector2(500,900)]:
				for picked in [false,true]:
					var bounds := art.guarded_bounds(picked)
					var safe := Sizes.clamp_center(point,bounds)
					check(Sizes.PLAY_AREA.grow(0.01).encloses(Rect2(safe+bounds.position,bounds.size)),"every stage fits tray while picked/resting")
			art.setup_form(form,true)
			check(is_equal_approx(maxf(art.visible_rect().size.x,art.visible_rect().size.y),48),"fixed collection scale")
			art.free()
	check(Catalog.register_species({"id":"test_species","name":"Test","max_stage":7,"images":{1:"res://missing.png"}}),"extensible catalog")
	check(Catalog.can_merge(Catalog.make("test_species",6),Catalog.make("test_species",6)),"seventh stage without rule change")
	check(not Catalog.can_merge(Catalog.make("test_species",7),Catalog.make("test_species",7)),"new catalog max respected")
	var fallback := Art.new()
	fallback.setup_form(Catalog.make("test_species",6))
	check(fallback.texture==null,"missing PNG procedural fallback")
	fallback.setup_form(Catalog.make("future_species",3))
	check(fallback.texture==null and not Catalog.can_merge(Catalog.make("future_species"),Catalog.make("future_species")),"unknown species safe")
	fallback.free()
	Catalog.entries.erase("test_species")
	var old := {"cells":range(11),"coins":12345,"merges":77,"highest":8,"settings":{"music":false},"future_field":[1,2]}
	var decoded := Codec.decode(old)
	check(decoded.ok and decoded.coins==12345 and decoded.merges==77,"migration currency")
	check(decoded.cells.size()==30 and decoded.cells[0]==null,"partial board padded")
	for level in range(1,11):
		check(decoded.cells[level]==Catalog.make(Catalog.legacy_id(level)),"legacy mapping %d" % level)
		check(decoded.discoveries.has(Catalog.key(Catalog.make(Catalog.legacy_id(level)))) and not decoded.discoveries.has(Catalog.key(Catalog.make(Catalog.legacy_id(level),2))),"conservative collection")
	var encoded := Codec.encode(decoded.cells,decoded.coins,decoded.merges,decoded.active_species,decoded.discoveries,decoded.extra)
	check(encoded.settings==old.settings and encoded.future_field==old.future_field,"extra data preserved")
	var again := Codec.decode(JSON.parse_string(JSON.stringify(encoded)))
	check(again.ok and not again.migrated and again.cells==decoded.cells and again.discoveries==decoded.discoveries,"migration idempotent")
	check(JSON.stringify(JSON.parse_string(JSON.stringify(Codec.encode(again.cells,again.coins,again.merges,again.active_species,again.discoveries,again.extra))),"",true)==JSON.stringify(JSON.parse_string(JSON.stringify(encoded)),"",true),"stable round trip")
	for raw in [{},{"cells":[]},{"schema_version":2,"cells":[null]}]:
		var result := Codec.decode(raw)
		check(result.ok and result.cells.size()==30 and result.cells.count(null)==30,"empty/incomplete data safe")
	for bad in [null,[],{"schema_version":3},{"cells":"bad"},{"coins":-1},{"cells":[true]},{"cells":[1.5]},{"discoveries":["broken"]}]:
		check(not Codec.decode(bad).ok,"invalid save rejected")
	var unknown := Codec.decode({"schema_version":2,"cells":[Catalog.make("future_species",42)],"active_species":"future_species","discoveries":["future_species:42"]})
	check(unknown.ok and unknown.cells[0].evolution_stage==42 and unknown.extra.retained_active_species=="future_species","unknown forms preserved")
	var overflow := Codec.decode({"schema_version":2,"cells":Array(range(31)).map(func(_x): return null)})
	check(overflow.ok and overflow.extra.retained_overflow_cells.size()==1,"overflow retained")
	var game := Game.new()
	game.save_path="res://.godot/species_test_save.json"
	write(game.save_path,JSON.stringify(old))
	var hash := FileAccess.get_sha256(game.save_path)
	check(game._load_game() and game.needs_backup,"in place custom migration requests backup")
	game._save_game()
	var backup := game.save_path+".pre-update-"+hash.substr(0,12)+".bak"
	check(FileAccess.file_exists(backup) and FileAccess.get_sha256(backup)==hash,"backup byte identical")
	game.discoveries.clear()
	check(game.unlock(Catalog.make("wing",3)),"first unlock")
	check(not game.unlock(Catalog.make("wing",3)) and game.known_discoveries()==1,"no duplicate unlock")
	check(not game.is_unlocked("wing",4),"unobtained form hidden")
	game.cells.fill(null)
	game.cells[4]=Catalog.make("wing",3)
	game._save_game()
	game.discoveries.clear()
	check(game._load_game() and game.is_unlocked("wing",3) and not game.is_unlocked("wing",4),"collection persists")
	for bad in ["{","[]",'{"schema_version":99}']:
		write(game.save_path,bad)
		check(not game._load_game() and game.write_blocked,"load blocks writes")
		game._start_fresh(false)
		game._spawn()
		game._save_game()
		check(FileAccess.get_file_as_string(game.save_path)==bad,"corrupt original never overwritten")
	game._new_game()
	check(game._load_game() and not game.write_blocked,"explicit reset recovers")
	root.add_child(game)
	game.view.sound.set_enabled(false)
	for id in Catalog.ids():
		game.cells.fill(null)
		game.coins=100
		check(game.select_species(id),"picker selection")
		game._spawn()
		check(game.cells.count(Catalog.make(id))==1 and game.coins==90,"selected base species created")
		game.view.collection_species=id
		var before := game.discoveries.duplicate()
		game.view.show_panel("collection")
		await process_frame
		await process_frame
		var portraits := game.view.overlay.find_children("*","Node2D",true,false).filter(func(node): return node is Art)
		check(portraits.size()==5 and portraits.all(func(node): return node.species_id==id),"five-stage species collection")
		for portrait: Art in portraits:
			check(Rect2(Vector2.ZERO,portrait.get_parent().size).encloses(portrait.transform*portrait.render_bounds()),"all fifty portraits fit actual cards")
		check(game.discoveries==before,"viewing does not unlock")
		game.view.close_panel()
	game.view.show_panel("species")
	check(is_instance_valid(game.view.species_button),"compact native species button exists")
	check(game.view.overlay.find_children("*","Button",true,false).size()==11,"ten choices plus back")
	var buttons := game.view.overlay.find_children("*","Button",true,false)
	buttons[1].pressed.emit()
	check(game.active_species=="eyeball" and not is_instance_valid(game.view.overlay),"native species choice selects and closes")
	game.view.species_button.pressed.emit()
	check(game.view.panel_kind=="species","compact button opens picker")
	game.free()
	DirAccess.remove_absolute("res://.godot/species_test_save.json")
	print("Species/evolution checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
