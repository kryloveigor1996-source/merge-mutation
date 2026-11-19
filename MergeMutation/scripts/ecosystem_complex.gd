extends "res://scripts/landscape_complex.gd"
const Factory=preload("res://scripts/ecosystem_factory.gd")
const Detail=preload("res://scripts/ecosystem_habitat.gd")
const Chrome=preload("res://scripts/app_chrome.gd")
const Index=preload("res://scripts/ecosystem_catalog.gd")
const Species=preload("res://scripts/mutant_catalog.gd")
var chrome: Control
func viewport_rect() -> Rect2: return Rect2(0,70,804,400)
func make_living_detail(): return Detail.new()
func create_living_models() -> void: living_models=Factory.create(registry,game.save_path)
func decorate_rooms(rooms: Array) -> void:
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/ecosystems.json"))
	var descriptions: Dictionary={}
	if data is Dictionary:
		for entry in data.get("rooms",[]): descriptions[entry.habitat_id]=entry
	for room in rooms:
		room.preview_accessible=descriptions.has(room.habitat_id)
		if room.preview_accessible:
			var entry: Dictionary=descriptions[room.habitat_id]
			room.size_class={"S":"small","M":"medium","L":"giant","XL":"giant"}.get(entry.room_size,"small")
			room.name=Species.species(room.species_id).name+" · "+entry.room_size
			room.description=entry.origin+" · "+entry.temperament+". Демонстрация не меняет открытия коллекции."
func setup(value: Control,model=null) -> void:
	super.setup(value,model)
	get_node("ComplexBack").hide()
	chrome=Chrome.new()
	chrome.setup(game,"complex")
	add_child(chrome)
func _process(delta: float) -> void:
	super._process(delta)
	chrome.visible=detail==null and modal==null
