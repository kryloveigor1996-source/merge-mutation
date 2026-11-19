extends RefCounted
const Index=preload("res://scripts/ecosystem_catalog.gd")
const Living=preload("res://scripts/living_registry.gd")
const Resident=preload("res://scripts/ecosystem_state.gd")
const Renovation=preload("res://scripts/ecosystem_renovation.gd")
static func create(complex_registry,save_path: String,config_path: String="") -> Dictionary:
	var models: Dictionary={}
	if not complex_registry.habitats.has("habitat_horn") and not complex_registry.habitats.has("habitat_slime"): return models
	var index:=Index.new()
	if not index.load_file(complex_registry,config_path): return models
	for id in index.rooms:
		var room: Dictionary=index.rooms[id]
		var living:=Living.new()
		if not living.load_files(complex_registry): continue
		var profile: Dictionary=room.motion_profile.duplicate(true)
		profile.profile_id="ecosystem_resident"
		profile.species_id=room.species_id
		profile.movement_type=room.movement_driver
		profile.allowed_behaviors=["idle","walk","sleep","inspect","react","ram"]
		profile.start_x=room.start_x
		profile.movement_speed=room.movement_speed
		profile.walk_range=[48,index.sizes[room.room_size]-48]
		profile.preferred_objects=room.preferred_objects.duplicate()
		living.profiles={"ecosystem_resident":profile}
		living.assignments={id:{"habitat_id":id,"species_id":room.species_id,"behavior_profile":"ecosystem_resident","default_stage":2}}
		living.world_width=index.sizes[room.room_size]
		var model:=Resident.new()
		model.setup(id,living)
		model.configure_ecology(room)
		var state:=Renovation.new()
		state.setup(index.catalogs[id],save_path+".habitat-demo-v1.json")
		model.attach(state)
		models[id]=model
	return models
