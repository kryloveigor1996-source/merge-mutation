extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const Registry=preload("res://scripts/complex_registry.gd")
var checks:=0
var failures:=0
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:
		failures+=1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var model:=Registry.new()
	check(model.load_files(),"load complex configs")
	check(model.floors.size()==5 and model.habitats.size()==7 and model.extent==1860,"five resized floors and seven rooms")
	var first: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/complex/floors.json"))
	var second: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/complex/habitats.json"))
	check(model.get_floor("floor_01").habitats.size()==2,"two larger small rooms")
	check(model.get_floor("floor_02").habitats.size()==1 and model.get_floor("floor_04").habitats.size()==3,"one medium room and flexible three-room reserve")
	check(model.get_floor("floor_03").height>400 and model.get_habitat("habitat_secret").rect[2]>300,"tall full-width secret chamber")
	check(not model.get_habitat("habitat_secret").has("species_id"),"secret has no permanent species")
	for id in model.habitats:
		var room: Dictionary=model.get_habitat(id)
		check(room.preview_accessible==(id=="habitat_horn"),"preview permissions separate from player discoveries")
		for other in model.habitats:
			if id!=other: check(not model.room_rects[id].intersects(model.room_rects[other]),"no room overlap")
	for floor in model.floors:
		check(model.floor_at(floor.top+1).floor_id==floor.floor_id,"floor from position")
		check(floor.floor_id in model.visible_floors(floor.top,100),"visibility lookup")
	check(model.get_habitat_for_species("horn").habitat_id=="habitat_horn" and model.get_floor_for_habitat("habitat_horn").depth==1,"catalog-independent stable navigation IDs")
	check(model.get_habitat_for_species("unknown").is_empty() and model.get_habitat("missing").is_empty() and model.get_floor("missing").is_empty(),"unknown IDs are safe")
	var returned:=model.get_habitat("habitat_horn")
	returned.rect[0]=999
	check(model.get_habitat("habitat_horn").rect[0]==32,"getters do not leak mutable configuration")
	for scenario in ["duplicate_floor","duplicate_depth","bad_height","bad_room_ref","duplicate_room","overlap","bad_bounds","bad_species","bad_size","bad_interaction","missing_listing","bad_access","bad_theme","nan"]:
		var a:=first.duplicate(true)
		var b:=second.duplicate(true)
		match scenario:
			"duplicate_floor": a.floors.append(a.floors[0].duplicate(true))
			"duplicate_depth": a.floors[1].depth=0
			"bad_height": a.floors[1].height=-1
			"bad_room_ref": b.habitats[0].floor_id="missing"
			"duplicate_room": b.habitats.append(b.habitats[0].duplicate(true))
			"overlap": b.habitats[1].rect=b.habitats[0].rect.duplicate()
			"bad_bounds": b.habitats[0].rect[0]=350
			"bad_species": b.habitats[0].species_id="unknown"
			"bad_size": b.habitats[0].rect[2]=0
			"bad_interaction": b.habitats[0].interaction_rect=[90,38,82,110]
			"missing_listing": a.floors[1].habitats=[]
			"bad_access": a.floors[1].preview_accessible="yes"
			"bad_theme": b.habitats[0].theme_id="Invalid Theme"
			"nan": b.habitats[0].rect[0]=NAN
		var invalid:=Registry.new()
		check(not invalid.configure(a,b) and not invalid.error.is_empty() and invalid.floors.is_empty(),"atomic rejection "+scenario)
	var extended:=first.duplicate(true)
	extended.floors[1].height=360
	var reordered:=Registry.new()
	check(reordered.configure(extended,second) and reordered.get_habitat_for_species("horn").habitat_id=="habitat_horn" and reordered.get_floor("floor_02").top==560,"floor geometry changes without changing species IDs")
	# A tall room anchored above can occupy several sections; global intersections matter.
	var spanning:=first.duplicate(true)
	var spanning_rooms:=second.duplicate(true)
	spanning_rooms.habitats[0].rect=[32,48,98,600]
	spanning_rooms.habitats[0].interaction_rect=[8,38,82,110]
	spanning_rooms.habitats[2].rect=[138,48,202,350]
	spanning_rooms.habitats[2].interaction_rect=[8,38,186,286]

	var large:=Registry.new()
	check(large.configure(spanning,spanning_rooms),"room spans multiple floor heights without overlap")
	check("floor_01" in large.visible_floors(550,80),"spanning room keeps its anchor floor loaded")
	spanning_rooms.habitats[2].rect[0]=32
	check(not large.configure(spanning,spanning_rooms),"reject intersection across different anchor floors")
	var stress: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/complex_50.json"))
	var fifty:=Registry.new()
	check(fifty.configure(stress,stress) and fifty.floors.size()==50 and fifty.habitats.size()==50,"separate 50 floor fixture")
	for floor in fifty.floors:
		check(fifty.visible_floors(floor.top,538).size()<=4,"bounded visible floor set in large complex")
	check(not fifty.load_files("res://data/complex/missing.json") and fifty.floors.is_empty(),"missing file safely clears model")
	var game=Scene.instantiate()
	game.save_path="res://.godot/complex-test-save.json"
	root.add_child(game)
	game.view.open_complex()
	await process_frame
	check(is_instance_valid(game.view.complex_ui),"entry")
	game.view.complex_ui.exit_complex()
	await process_frame
	game.free()
	print("Complex checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
