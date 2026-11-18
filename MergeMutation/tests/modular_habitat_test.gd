extends SceneTree
const Catalog=preload("res://scripts/renovation_catalog.gd")
const State=preload("res://scripts/renovation_state.gd")
const Resident=preload("res://scripts/modular_habitat_state.gd")
const Complex=preload("res://scripts/complex_registry.gd")
const Living=preload("res://scripts/living_registry.gd")
const Layout=preload("res://scripts/landscape_living_config.gd")
var checks:=0
var failures:=0
const PATH="res://.godot/modular-unit-demo.json"
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",label)
func raw() -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string("res://data/renovation/horn.json"))
func write(data: Variant,path: String=PATH) -> void:
	var f:=FileAccess.open(path,FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var cat:=Catalog.new()
	check(cat.load_file() and cat.slots.size()==10 and cat.zones.size()==3,"ten slots, three zones")
	if cat.slots.is_empty():
		printerr(cat.error)
		quit(1)
		return
	var designs: Dictionary={}
	for id in cat.slots:
		check(cat.slots[id].designs.size()==3,"three designs "+id)
		for d in cat.slots[id].designs:
			check(not designs.has(d.design_id) and cat.design(id,d.design_id)==d,"stable unique design "+d.design_id)
			designs[d.design_id]=true
	for kind in ["duplicate_slot","duplicate_design","missing_design","missing_reference","cycle","geometry","collision","wrong_habitat","wrong_zone","visual","anchor","nonfinite","overlap_zones","zone_anchor","missing_texture","small_touch","duplicate_dependency","wrong_cost"]:
		var data:=raw()
		match kind:
			"duplicate_slot": data.slots.append(data.slots[0].duplicate(true))
			"duplicate_design": data.slots[1].designs[0].design_id=data.slots[0].designs[0].design_id
			"missing_design": data.slots[0].designs=[]
			"missing_reference": data.slots[0].requires=["missing_slot"]
			"cycle": data.slots[0].requires=["floor"]; data.slots[1].requires=["walls"]
			"geometry": data.slots[0].rect=[0,0,2400,315]
			"collision": data.slots[4].collision=[1100,280,110,40]
			"wrong_habitat": data.slots[0].habitat_id="elsewhere"
			"wrong_zone": data.slots[0].zone_id="missing"
			"visual": data.slots[0].designs[0].visual="unknown_visual"
			"anchor": data.slots[0].anchor=[-1,100]
			"nonfinite": data.slots[0].rect[0]=NAN
			"overlap_zones": data.zones[1].rect[0]=700
			"zone_anchor": data.slots[0].anchor=[100,80]
			"missing_texture": data.slots[0].designs[0]["texture"]="res://missing-renovation-texture.png"
			"small_touch": data.slots[0].touch[2]=2
			"duplicate_dependency": data.slots[2].requires=["walls","walls"]
			"wrong_cost": data.slots[0].cost=2
		var bad:=Catalog.new()
		check(not bad.configure(data) and bad.slots.is_empty(),"validator rejects "+kind)
	DirAccess.remove_absolute(PATH)
	var room:=State.new()
	check(room.setup(cat,PATH) and room.points==3 and room.progress()==0,"fresh poor room")
	check(not FileAccess.file_exists(PATH),"opening does not create sidecar")
	for id in cat.slots:
		for d in cat.slots[id].designs:
			check(room.preview(id,d.design_id),"preview each design")
			check(room.points==3 and room.installed.is_empty() and not FileAccess.file_exists(PATH),"preview no state or file")
			room.cancel_preview()
			check(room.visual_choice(id)=="" and room.points==3,"cancel exact visual rollback")
	check(not room.preview("unknown","unknown"),"invalid preview")
	for id in ["walls","floor","bed"]:
		var d: String=cat.slots[id].designs[0].design_id
		check(room.confirm(id,d).ok,"first install")
		var balance: int=room.points
		var bytes:=FileAccess.get_file_as_string(PATH)
		check(room.confirm(id,d).ok and room.points==balance and FileAccess.get_file_as_string(PATH)==bytes,"duplicate confirmation is no-op")
	check(room.points==0 and room.progress()==30,"three points, thirty percent")
	var bytes:=FileAccess.get_file_as_string(PATH)
	check(not room.confirm("training","training_boulder").ok and room.points==0 and FileAccess.get_file_as_string(PATH)==bytes,"insufficient points leaves everything unchanged")
	for d in cat.slots.bed.designs:
		check(room.confirm("bed",d.design_id).ok and room.points==0 and room.progress()==30,"free changes do not increase progress")
	var loaded:=State.new()
	check(loaded.setup(cat,PATH) and loaded.installed==room.installed and loaded.points==0,"sidecar reload")
	for id in cat.slots:
		if not room.installed.has(id):
			check(room.grant_test_point() and room.confirm(id,cat.slots[id].designs[0].design_id).ok,"test grant/install "+id)
	check(room.progress()==100 and room.installed.size()==10 and room.points==0,"ten independent slots")
	var saved:=FileAccess.get_file_as_string(PATH)
	check(not room.reset_demo(false) and FileAccess.get_file_as_string(PATH)==saved,"reset requires explicit confirmation")
	check(room.reset_demo(true) and room.points==3 and room.progress()==0,"isolated reset")
	var dependency:=raw()
	dependency.slots[2].requires=["walls"]
	var depcat:=Catalog.new()
	check(depcat.configure(dependency),"acyclic dependency accepted")
	var dep:=State.new()
	dep.setup(depcat,"res://.godot/modular-dependency.json")
	dep.reset_demo(true)
	check(not dep.available("bed") and not dep.confirm("bed","stone_cave").ok,"dependency enforced")
	dep.confirm("walls","rock_wall")
	check(dep.available("bed"),"dependency opens")
	var variable:=raw()
	var extra: Dictionary=variable.slots[2].duplicate(true)
	extra.slot_id="bed_annex"
	extra.rect=[430,248,160,92]
	extra.touch=extra.rect.duplicate()
	extra.anchor=[510,290]
	for d in extra.designs: d.design_id="annex_"+d.design_id
	variable.slots.append(extra)
	var flexible:=Catalog.new()
	check(flexible.configure(variable) and flexible.slots.size()==11,"catalog not fixed at ten slots")
	DirAccess.remove_absolute("res://.godot/modular-variable.json")
	var flexible_room:=State.new()
	flexible_room.setup(flexible,"res://.godot/modular-variable.json")
	for id in ["walls","floor","bed_annex"]: flexible_room.confirm(id,flexible.slots[id].designs[0].design_id)
	check(flexible_room.progress()==27,"progress uses configured slot count")
	# Another habitat can write the shared sidecar without being lost by this room.
	var external: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	external.habitats["habitat_future"]={"preserve":true}
	write(external)
	check(room.grant_test_point(),"merge unrelated habitat update")
	external=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	check(external.habitats.habitat_future.preserve,"unrelated habitat retained")
	external.habitats.habitat_horn.points+=1
	write(external)
	saved=FileAccess.get_file_as_string(PATH)
	var balance: int=room.points
	check(not room.grant_test_point() and room.points==balance and FileAccess.get_file_as_string(PATH)==saved,"conflicting external room edit is protected")
	write({"format":State.FORMAT,"version":1,"future_root":{"keep":true},"habitats":{"habitat_other":{"keep":true},"habitat_horn":{"habitat_id":"habitat_horn","points":2,"future_room":7,"installed":{"unknown_slot":"old_design","bed":"obsolete_design","walls":"rock_wall"}}}})
	check(room.reload() and room.points==2 and room.progress()==10,"unknown IDs inert")
	room.confirm("floor","sand_floor")
	var retained: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	check(retained.future_root.keep and retained.habitats.habitat_other.keep and retained.habitats.habitat_horn.future_room==7 and retained.habitats.habitat_horn.installed.unknown_slot=="old_design" and retained.habitats.habitat_horn.installed.bed=="obsolete_design","unknown data retained on write")
	for data in [{"format":State.FORMAT,"version":2,"habitats":{}},{"format":State.FORMAT,"version":1,"habitats":{"habitat_horn":{"points":-1,"installed":{}}}},{"broken":true}]:
		write(data)
		saved=FileAccess.get_file_as_string(PATH)
		check(not room.reload() and room.read_only and not room.confirm("walls","rock_wall").ok and not room.grant_test_point() and FileAccess.get_file_as_string(PATH)==saved,"invalid or future save protected")
	check(room.reset_demo(true) and room.points==3,"confirmed reset recovers protected demo with backup")
	var failed:=State.new()
	failed.setup(cat,"res://.godot/nonexistent-directory/no-demo.json")
	check(not failed.confirm("walls","rock_wall").ok and failed.points==3 and failed.installed.is_empty(),"failed write rolls back purchase")
	for id in cat.slots:
		room.grant_test_point()
		room.confirm(id,cat.slots[id].designs[0].design_id)
	var complex:=Complex.new()
	check(complex.load_files(),"complex registry")
	var base:=Living.new()
	check(base.load_files(complex),"living profile")
	var resident:=Resident.new()
	resident.setup("habitat_horn",Layout.build(base,complex,"normal"),42)
	resident.attach(room)
	check(resident.inhabited() and resident.objects().size()==10,"one resident uses installed objects")
	for mode in [false,true,false]:
		resident.switch_panorama(mode)
		resident.position=Vector2(48,354)
		check(resident.move_to_point(Vector2(resident.registry.world_width-48,354)) and resident.target.x==resident.registry.world_width-48,"all furniture preserves passage")
		for object in resident.objects():
			var a: Array=object.rect
			check(Rect2(0,0,resident.registry.world_width,420).encloses(Rect2(a[0],a[1],a[2],a[3])),"projected object fits")
			if object.solid:
				var b: Array=object.collision_rect
				check(not Rect2(b[0],b[1],b[2],b[3]).intersects(Rect2(48,274,resident.registry.world_width-96,80)),"collision outside walking lane")
	for id in ["bed","feeder","toy","cabinets","training"]:
		resident.cancel_action()
		resident.stone_broken=false
		var rect: Rect2=cat.project_rect(cat.slots[id],resident.registry.world_width)
		resident.position=Vector2(maxf(48,rect.position.x-70),354)
		resident.profile.movement_speed=400
		check(resident.request_slot(id) and not resident.request_slot(id) and not resident.react(),"one guarded target "+id)
		var seen: Dictionary={}
		for i in range(300):
			seen[resident.behavior]=true
			resident.advance(0.05)
			if resident.action_slot.is_empty(): break
		var expected: String={"bed":"sleep","feeder":"inspect","toy":"react","cabinets":"inspect","training":"ram"}[id]
		check(seen.has("walk") and seen.has(expected) and resident.action_slot.is_empty(),"existing FSM completes "+id)
		if id=="training":
			check(resident.stone_broken and resident.hit_count>0,"training breaks temporarily")
			resident.remaining=100
			for i in range(100): resident.advance(0.05)
			check(not resident.stone_broken,"training restores")
	resident.cancel_action()
	var light: bool=resident.lighting_on
	check(resident.request_slot("lighting") and resident.lighting_on!=light and not resident.request_slot("lighting"),"lighting interaction guarded")
	var autonomous:=0
	for i in range(100):
		resident.cancel_action()
		resident.choose_next()
		if not resident.action_slot.is_empty(): autonomous+=1
	check(autonomous>0,"autonomous installed-object use")
	resident.cancel_action()
	resident.stone_broken=false
	resident.position=Vector2(800,354)
	check(resident.request_slot("training"),"training reachable from right")
	for i in range(300):
		resident.advance(0.05)
		if resident.behavior=="ram": break
	check(resident.behavior=="ram" and resident.facing==1,"ram faces its target after walking from right")
	var installed: Dictionary=room.installed.duplicate()
	resident.switch_panorama(true)
	resident.switch_panorama(false)
	check(room.installed==installed,"one installation set in both projections")
	room.preview("bed","soft_bed")
	var collisions: Array=resident.objects().duplicate(true)
	room.preview("training","training_target")
	check(resident.objects()==collisions,"preview leaves real collisions unchanged")
	room.cancel_preview()
	print("Modular habitat checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
