extends SceneTree
const Registry=preload("res://scripts/complex_registry.gd")
const Factory=preload("res://scripts/ecosystem_factory.gd")
const Progression=preload("res://scripts/environment_progression.gd")
const Archive=preload("res://scripts/bestiary_model.gd")
const Scene=preload("res://scenes/main.tscn")
const Detail=preload("res://scripts/ecosystem_habitat.gd")
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("FAIL: ",label)
func write(path: String,data: Dictionary) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
func run() -> void:
	var registry:=Registry.new()
	check(registry.load_files(),"registry loads")
	var path:="res://.godot/pr20-model-profile.json"
	DirAccess.remove_absolute(path+".habitat-demo-v1.json")
	var old:=Factory.create(registry,path,"res://tests/fixtures/ecosystems_pr19.json")
	var old_room=old.habitat_slime.renovation
	for id in old_room.catalog.offers:
		if old_room.points==0: old_room.grant_test_point()
		old_room.confirm(id,old_room.catalog.slots[id].designs[2].design_id)
	var raw:=FileAccess.get_file_as_string(old_room.path)
	var current:=Factory.create(registry,path)
	check(current.size()==2,"new room config loads")
	check(current.habitat_slime.registry.world_width==940,"small acid room actual geometry")
	check(current.habitat_slime.renovation.installed==old_room.installed and current.habitat_slime.renovation.points==old_room.points,"PR19 choices and points retained")
	check(raw==FileAccess.get_file_as_string(old_room.path),"resize needs no save migration or duplicate progress")
	for slot in current.habitat_slime.renovation.catalog.slots.values():
		var rect: Rect2=current.habitat_slime.renovation.catalog.project_rect(slot,940,"touch")
		check(rect.size.x>=44 and rect.size.y>=44 and Rect2(0,0,940,420).encloses(rect),"authored S hitbox "+slot.slot_id)
	var game=Scene.instantiate()
	game.save_path="res://.godot/pr20-camera-profile.json"
	root.add_child(game)
	await process_frame
	await process_frame
	if is_instance_valid(game.view.story_screen): game.view.close_story()
	var ui=game.view.complex_ui
	var original=ui.living_models.habitat_slime
	for size_name in ["M","L"]:
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/ecosystems_pr19.json"))
		var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/ecosystem_slime_medium.json"))
		var width: int=1880 if size_name=="M" else 2820
		catalog.world_size[0]=width
		catalog.zones.back().rect[2]=width-catalog.zones.back().rect[0]
		var catalog_path: String="res://.godot/pr20-"+size_name+"-catalog.json"
		write(catalog_path,catalog)
		data.rooms[1].catalog=catalog_path
		data.rooms[1].room_size=size_name
		var index_path: String="res://.godot/pr20-"+size_name+"-index.json"
		write(index_path,data)
		var models:=Factory.create(registry,"res://.godot/pr20-"+size_name+"-profile.json",index_path)
		check(models.size()==2,"configurable "+size_name+" factory")
		if models.size()!=2: continue
		ui.living_models.habitat_slime=models.habitat_slime
		ui.open_living("habitat_slime")
		var detail=ui.detail
		check(detail.environment.visible_width==940 and detail.get_node("HabitatFind").visible,"automatic "+size_name+" camera")
		detail.environment.set_camera(100000)
		check(detail.environment.camera_x==width-940,"large camera upper bound "+size_name)
		detail.environment.set_camera(-100)
		check(detail.environment.camera_x==0,"large camera lower bound "+size_name)
		detail.environment.set_camera(420)
		ui.close_living()
		ui.open_living("habitat_slime")
		check(ui.detail.environment.camera_x==420,"large camera returns "+size_name)
		ui.close_living()
	ui.living_models.habitat_slime=original
	var decorations: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/environment_progression.json"))
	check(Progression.validate(decorations),"decor schema valid")
	for fault in ["threshold","layer","kind","point","asset"]:
		var invalid:=decorations.duplicate(true)
		var item: Dictionary=invalid.habitats.habitat_horn[1]
		match fault:
			"threshold": item.threshold=-5
			"layer": item.layer="input_button"
			"kind": item.kind="unknown"
			"point": item.positions=[[NAN,0]]
			"asset": item.texture="res://missing.png"
		check(not Progression.validate(invalid),"reject invalid decoration "+fault)
	var archive:=Archive.new()
	check(archive.load_file() and archive.entries.size()==10,"full existing catalog")
	for id in archive.entries:
		var data: Dictionary=archive.dossier(game,id,true)
		check(not data.hidden and data.species_id==id and not data.has("unlock_reward"),"test dossiers are metadata "+id)
	check(archive.records("horn").size()==2 and archive.records("slime").size()==1,"observations use explicit demo event records")
	game.free()
	print("World progression model checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
