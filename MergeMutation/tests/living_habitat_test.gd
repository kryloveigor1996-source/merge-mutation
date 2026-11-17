extends SceneTree
const ComplexRegistry=preload("res://scripts/complex_registry.gd")
const Registry=preload("res://scripts/living_registry.gd")
const State=preload("res://scripts/habitat_state.gd")
var checks:=0
var failures:=0
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:
		failures+=1
		printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var complex:=ComplexRegistry.new()
	check(complex.load_files(),"new geometry valid")
	var registry:=Registry.new()
	check(registry.load_files(complex) and registry.assignments.size()==1,"only horn living assignment")
	var state:=State.new()
	state.setup("habitat_horn",registry,1234)
	check(state.stage==2 and state.inhabited(),"first entry defaults to populated stage 2")
	var counts: Array=[]
	for stage in range(1,5):
		check(state.set_stage(stage) and state.inhabited()==(stage>1),"stage resident presence")
		counts.append(state.objects().size())
		check(state.react()==(stage>1),"stage permits or denies reaction")
	check(counts==[1,3,6,9],"four stages contain genuinely different configured scenery")
	check(not state.set_stage(0) and not state.set_stage(5),"invalid development stage safe")
	state.set_stage(1)
	var before:=state.position
	state.tick(0.1)
	check(state.position==before and not state.request_ram() and not state.walk_to(280),"empty stage does not act")
	state.set_stage(2)
	check(state.enter("sleep") and state.react() and state.behavior=="react","tap wakes sleeping resident")
	check(not state.react() and not state.request_ram(),"reaction cooldown and no stage 2 training")
	for step in range(30): state.tick(0.05)
	check(state.behavior=="idle" and state.cooldown==0,"reaction finishes cleanly")
	state.set_stage(3)
	check(state.request_ram() and not state.request_ram() and not state.react(),"training rejects duplicate and conflicting input")
	for step in range(80): state.tick(0.05)
	check(state.hit_count==1 and state.stone_broken,"approach, windup and exactly one training impact")
	check(not state.request_ram(),"broken stone cannot be hit repeatedly")
	for step in range(80): state.tick(0.05)
	check(not state.stone_broken,"stone restores after a few visible seconds")
	var durations: Dictionary={}
	for repeat in range(8):
		state.enter("idle")
		durations[state.remaining]=true
	check(durations.size()>3,"random idle intervals are not a fixed loop")
	state.set_stage(4)
	var seen: Dictionary={}
	for step in range(2600):
		state.tick(0.05)
		seen[state.behavior]=true
		if step%10==0:
			check(state.position.x>=state.profile.walk_range[0] and state.position.x<=state.profile.walk_range[1] and state.position.y==state.profile.ground_y,"resident stays within allowed movement area")
			var body:=Rect2(state.position-Vector2(state.profile.body_radius,state.profile.body_height),Vector2(state.profile.body_radius*2,state.profile.body_height))
			for object in state.objects():
				if object.solid:
					var r: Array=object.rect
					check(not body.intersects(Rect2(r[0],r[1],r[2],r[3])),"ground locomotion never crosses solid scenery")
	for behavior in ["idle","walk","sleep","inspect"]: check(seen.has(behavior),"autonomous behavior "+behavior)
	# A configured solid obstruction splits the connected ground segment.
	registry.objects.barrier={"object_id":"barrier","type":"boulder","layer":"objects","rect":[220,300,30,65],"solid":true}
	registry.stages[2].objects.append("barrier")
	state.set_stage(2)
	state.walk_to(290)
	for step in range(50): state.tick(0.05)
	check(state.position.x<=220-state.profile.body_radius,"custom obstruction cannot be crossed")
	var data: Dictionary={}
	for file in ["habitats","profiles","stages","objects"]:
		data[file]=JSON.parse_string(FileAccess.get_file_as_string("res://data/living/"+file+".json"))[file]
	for scenario in ["species","object_ref","bounds","movement","range","empty_resident","duplicate"]:
		var bad:=data.duplicate(true)
		match scenario:
			"species": bad.habitats[0].species_id="slime"
			"object_ref": bad.stages[2].objects.append("missing")
			"bounds": bad.objects[0].rect[0]=999
			"movement": bad.profiles[0].movement_type="swimming"
			"range": bad.profiles[0].idle_duration_range=[4,1]
			"empty_resident": bad.stages[0].resident=true
			"duplicate": bad.objects.append(bad.objects[0].duplicate(true))
		var invalid:=Registry.new()
		check(not invalid.configure(bad,complex) and not invalid.error.is_empty(),"safe config rejection "+scenario)
	print("Living state checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
