extends "res://scripts/landscape_complex.gd"
const Factory=preload("res://scripts/ecosystem_factory.gd")
const Detail=preload("res://scripts/ecosystem_habitat.gd")
const Chrome=preload("res://scripts/app_chrome.gd")
const Index=preload("res://scripts/ecosystem_catalog.gd")
const Species=preload("res://scripts/mutant_catalog.gd")
const Layout=preload("res://scripts/landscape_layout.gd")
var chrome: Control
func close_living(highlight: bool=true) -> void:
	super.close_living(highlight)
	if game.view.archive_return:
		game.view.archive_return=false
		game.view.call_deferred("show_panel","collection")
func exit_complex() -> void:
	game.view.archive_return=false
	super.exit_complex()
func back() -> void:
	if not Layout.world_legacy() and detail==null and modal==null: return
	super.back()
func viewport_rect() -> Rect2: return Rect2(0,70,804,400)
func make_living_detail(): return Detail.new()
func create_living_models() -> void: living_models=Factory.create(registry,game.save_path)
func decorate_rooms(rooms: Array) -> void:
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/ecosystems.json"))
	var descriptions: Dictionary={}
	if data is Dictionary:
		for entry in data.get("rooms",[]): descriptions[entry.habitat_id]=entry
	if not Layout.world_legacy():
		var slime: Dictionary={}
		var horn: Dictionary={}
		for candidate in rooms:
			if candidate.habitat_id=="habitat_slime": slime=candidate
			elif candidate.habitat_id=="habitat_horn": horn=candidate
		if not slime.is_empty() and not horn.is_empty():
			var first: Array=horn.rect.duplicate()
			horn.rect=slime.rect.duplicate()
			slime.rect=first
	for room in rooms:
		room.preview_accessible=descriptions.has(room.habitat_id)
		if room.preview_accessible:
			var entry: Dictionary=descriptions[room.habitat_id]
			room.size_class={"S":"small","M":"medium","L":"giant","XL":"giant"}.get(entry.room_size,"small")
			room.name=Species.species(room.species_id).name+" · "+entry.room_size
			if not Layout.world_legacy(): room["archive_name"]=room.name
			room.description=entry.origin+" · "+entry.temperament+". Демонстрация не меняет открытия коллекции."
func setup(value: Control,model=null) -> void:
	super.setup(value,model)
	get_node("ComplexBack").hide()
	chrome=Chrome.new()
	chrome.setup(game,"complex")
	add_child(chrome)
func _process(delta: float) -> void:
	super._process(delta)
	chrome.visible=detail==null and modal==null and not is_instance_valid(game.view.story_screen)
