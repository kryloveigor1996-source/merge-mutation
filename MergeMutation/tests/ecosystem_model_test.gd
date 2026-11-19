extends SceneTree
const Complex=preload("res://scripts/complex_registry.gd")
const Index=preload("res://scripts/ecosystem_catalog.gd")
const Factory=preload("res://scripts/ecosystem_factory.gd")
const Room=preload("res://scripts/ecosystem_renovation.gd")
const Catalog=preload("res://scripts/renovation_catalog.gd")
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
func write(path: String,data: Variant) -> void:
	var f:=FileAccess.open(path,FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
func install_all(state) -> void:
	while state.installed.size()<state.catalog.slots.size():
		var options: Array=state.offered()
		check(not options.is_empty(),"offers eventually cover configured slots")
		if options.is_empty(): return
		var id: String=options[0]
		if state.points==0: state.grant_test_point()
		check(state.confirm(id,state.catalog.slots[id].designs[0].design_id).ok,"install offered "+id)
func advance(model,seconds: float) -> void:
	for i in range(ceili(seconds/0.05)): model.advance(0.05)
func run() -> void:
	var registry:=Complex.new()
	registry.load_files()
	var index:=Index.new()
	check(index.load_file(registry) and index.rooms.size()==2,"two ecosystem habitats reference existing species")
	check(index.sizes.S==940 and index.sizes.M==1880 and index.sizes.L==2820 and index.sizes.XL>=4700,"room sizes independent of window pixels")
	for id in index.rooms:
		var cat=index.catalogs[id]
		check(cat.slots.size()==(10 if id=="habitat_horn" else 6),"individual slot counts")
		for slot in cat.slots.values():
			check(slot.designs.size()==3,"three designs per ecosystem item")
			check(slot.has("action") and slot.has("construction"),"world actions and construction are data driven")
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Index.default_path()))
	for problem in ["species","driver","size","negative_weight","habit","event","reference","motion"]:
		var invalid:=fixture.duplicate(true)
		match problem:
			"species": invalid.rooms[0].species_id="invented_species"
			"driver": invalid.rooms[0].behavior_driver="unknown"
			"size": invalid.room_sizes.M=500
			"negative_weight": invalid.rooms[0].autonomy[0].weight=-1
			"habit": invalid.rooms[0].habits=["unknown"]
			"event": invalid.rooms[0].rare_events[0].event_id="unknown"
			"reference": invalid.rooms[0].preferred_objects=["missing"]
			"motion": invalid.rooms[0].motion_profile.body_radius=80
		var bad:=Index.new()
		check(not bad.configure(invalid,registry),"reject ecosystem schema "+problem)
	var path:="res://.godot/ecosystem-model-profile.json"
	DirAccess.remove_absolute(path+".habitat-demo-v1.json")
	var models:=Factory.create(registry,path)
	check(models.size()==2,"one model for each live habitat")
	if models.size()!=2:
		quit(1)
		return
	var horn=models.habitat_horn
	var slime=models.habitat_slime
	check(horn.registry!=slime.registry and horn.renovation!=slime.renovation,"separate dimensions and balances")
	check(horn.registry.world_width==940 and slime.registry.world_width==1880,"automatic S and M")
	# A real data-driven XL configuration, not a phone-dependent zoom factor.
	var huge_catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/renovation/ecosystem_horn.json"))
	huge_catalog.world_size=[4700,420]
	for zone in huge_catalog.zones:
		zone.rect[0]*=5
		zone.rect[2]*=5
	for slot in huge_catalog.slots:
		var origin: float=slot.rect[0]
		if slot.rect[2]==940:
			slot.rect[2]=4700
			slot.anchor[0]*=5
			slot.touch[0]*=5
		else:
			slot.rect[0]*=5
			slot.touch[0]+=origin*4
			slot.anchor[0]+=origin*4
			if not slot.collision.is_empty(): slot.collision[0]+=origin*4
	write("res://.godot/ecosystem-xl-catalog.json",huge_catalog)
	var huge_index:=fixture.duplicate(true)
	huge_index.rooms[0].room_size="XL"
	huge_index.rooms[0].catalog="res://.godot/ecosystem-xl-catalog.json"
	write("res://.godot/ecosystem-xl-index.json",huge_index)
	var huge:=Factory.create(registry,"res://.godot/ecosystem-xl-profile.json","res://.godot/ecosystem-xl-index.json")
	check(huge.has("habitat_horn") and huge.habitat_horn.registry.world_width==4700,"XL factory supports five logical viewports")
	if huge.has("habitat_horn"):
		check(huge.habitat_horn.walk_to(4600) and huge.habitat_horn.target.x==4600 and huge.habitat_horn.action_deadline>60,"XL movement is reachable without premature timeout")
	check(horn.profile.species_id=="horn" and slime.profile.species_id=="slime" and not slime.enter("ram"),"no new collectible species or copied horn actions")
	check(horn.renovation.points==3 and slime.renovation.points==3,"independent initial points")
	check(horn.renovation.offered().size()==3 and slime.renovation.offered().size()==3,"initial construction limited")
	check(not horn.renovation.available("lighting"),"unrevealed items cannot be installed through API")
	var initial: Array=horn.renovation.offered().duplicate()
	var id: String=initial[0]
	var choice: String=horn.renovation.catalog.slots[id].designs[0].design_id
	check(horn.renovation.preview(id,choice) and horn.renovation.points==3 and horn.objects().is_empty(),"world preview is transient")
	horn.renovation.cancel_preview()
	check(horn.renovation.confirm(id,choice).ok and horn.renovation.offered()!=initial and horn.renovation.offered().size()==3,"installation reveals next crate")
	check(slime.renovation.points==3 and slime.renovation.installed.is_empty(),"horn installation leaves slime untouched")
	install_all(horn.renovation)
	install_all(slime.renovation)
	check(horn.renovation.progress()==100 and slime.renovation.progress()==100,"independent complete ecosystems")
	var again:=Factory.create(registry,path)
	check(again.habitat_horn.renovation.installed==horn.renovation.installed and again.habitat_slime.renovation.installed==slime.renovation.installed,"both rooms reload without clobbering")
	for resident in [horn,slime]:
		resident.reset_simulation(712)
		var peer=again[resident.habitat_id]
		peer.reset_simulation(712)
		for i in range(5000):
			resident.advance(0.05)
			peer.advance(0.05)
			if i%250==0:
				check(resident.position.distance_to(peer.position)<0.001 and resident.behavior==peer.behavior,"deterministic autonomous replay")
				check(resident.position.x>=48 and resident.position.x<=resident.registry.world_width-48,"world-space movement bounds")
		check(resident.autonomous_log==peer.autonomous_log and resident.rare_log==peer.rare_log,"same seed, same weighted behavior")
		var actions: Dictionary={}
		for action in resident.autonomous_log: actions[action]=true
		check(actions.size()>=4,"varied autonomous habits")
		check(not resident.rare_log.is_empty(),"rare autonomous events occur")
		for i in range(1,resident.rare_log.size()):
			check(resident.rare_log[i].time-resident.rare_log[i-1].time>=14.99,"rare events never loop continuously")
	horn.reset_simulation(1)
	horn.simulation_time=30
	check(horn.request_rare("dust_sneeze") and not horn.request_rare("dust_sneeze"),"dust sneeze guarded")
	advance(horn,2)
	check(horn.rare_event.is_empty() and not horn.request_rare("dust_sneeze"),"rare cooldown survives completion")
	horn.cancel_action()
	horn.simulation_time=100
	horn.position=Vector2(865,354)
	check(horn.request_rare("monument_push"),"failed monument push")
	horn.cancel_action()
	horn.simulation_time=180
	horn.last_successful_ram=180
	horn.hit_count=1
	check(horn.request_rare("proud_ram"),"pride only after a successful ram")
	horn.cancel_action()
	horn.simulation_time=250
	check(not horn.request_rare("proud_ram"),"pride not detached from successful training")
	horn.reset_simulation(44)
	check(horn.auto_slot("training") and horn.current_autonomous,"autonomous training target")
	check(horn.request_slot("feeder") and horn.action_slot=="feeder" and not horn.current_autonomous,"manual command overrides autonomous target")
	horn.profile.movement_speed=0
	var timed_out:=false
	for i in range(1250):
		horn.advance(0.05)
		if horn.feedback=="Попробую другой подход":
			timed_out=true
			break
	check(timed_out and horn.action_slot.is_empty(),"stuck target timeout prevents infinite walks")
	slime.reset_simulation(12)
	slime.position=Vector2(200,354)
	check(slime.request_slot("bed"),"slime approaches acidic bed")
	for i in range(40):
		slime.advance(0.05)
		if slime.behavior=="sleep": break
	check(slime.behavior=="sleep" and slime.action_semantic=="acid_sleep" and slime.remaining>5.8,"slime unique six-second dissolution cycle")
	advance(slime,6.1)
	check(slime.behavior!="sleep" and slime.action_slot.is_empty(),"slime wakes and releases target")
	slime.cancel_action()
	slime.simulation_time=80
	check(slime.request_rare("bubble_splat"),"liquid-body rare event")
	# Real PR18 data -> explicit design mapping, same points, untouched archive.
	var old: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/renovation/horn.json"))
	var installed: Dictionary={}
	for slot in old.slots: installed[slot.slot_id]=slot.designs[1].design_id
	var migration_path:="res://.godot/ecosystem-migration.json"
	var legacy: Dictionary={"format":Room.FORMAT,"version":1,"keep_root":true,"habitats":{"habitat_horn":{"habitat_id":"habitat_horn","points":7,"installed":installed,"keep_room":42},"future_room":{"opaque":true}}}
	write(migration_path,legacy)
	var original:=FileAccess.get_file_as_string(migration_path)
	var hash:=FileAccess.get_sha256(migration_path)
	var migrated:=Room.new()
	check(migrated.setup(index.catalogs.habitat_horn,migration_path) and migrated.progress()==100 and migrated.points==7,"all PR18 designs migrate without progress/points loss")
	check(FileAccess.get_file_as_string(migration_path+".pre-ecosystems-"+hash.substr(0,12)+".bak")==original,"exact pre-migration backup")
	var migrated_data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(migration_path))
	check(migrated_data.version==2 and migrated_data.keep_root and migrated_data.habitats.future_room.opaque and migrated_data.habitats.habitat_horn.keep_room==42,"migration retains unknown fields and rooms")
	var other:=Room.new()
	check(other.setup(index.catalogs.habitat_slime,migration_path) and other.points==3,"slime starts independent after migration")
	other.confirm("bed","slime_bed_basin")
	var reloaded:=Room.new()
	check(reloaded.setup(index.catalogs.habitat_horn,migration_path) and reloaded.points==7 and reloaded.progress()==100,"slime write preserves migrated horn")
	legacy.habitats.habitat_horn.installed.bed="unmapped_future_bed"
	write(migration_path,legacy)
	original=FileAccess.get_file_as_string(migration_path)
	check(not migrated.reload() and migrated.read_only and migrated.points==7 and not migrated.error.is_empty() and FileAccess.get_file_as_string(migration_path)==original,"ambiguous migration is explicit, read-only and lossless")
	check(not migrated.grant_test_point() and not migrated.confirm("bed","stone_nest").ok,"no write over unresolved migration")
	check(migrated.reset_demo(true) and migrated.points==3 and migrated.progress()==0,"explicit reset recovers demo only")
	var v2: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(migration_path))
	v2.habitats.habitat_horn.installed={"bed":"unmapped_v2"}
	write(migration_path,v2)
	check(not migrated.reload() and migrated.read_only and migrated.points==3,"unknown v2 IDs not silently discarded")
	print("Ecosystem model checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
