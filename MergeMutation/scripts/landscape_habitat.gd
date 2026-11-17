extends "res://scripts/living_habitat.gd"
const Layout=preload("res://scripts/landscape_layout.gd")
const Config=preload("res://scripts/landscape_living_config.gd")
const Registry=preload("res://scripts/living_registry.gd")
var camera_velocity:=0.0
var find_target:=false
var stage_menu: Control
func setup(parent_screen: Control,value,room: Dictionary,floor: Dictionary) -> void:
	complex_screen=parent_screen
	model=value
	size=Layout.DESIGN
	mouse_filter=Control.MOUSE_FILTER_STOP
	z_index=20
	W.button(self,"HabitatBack","НАЗАД",Rect2(10,12,84,48),func(): closed.emit())
	W.label(self,Catalog.species(room.species_id).name,Rect2(104,10,230,30),22,Color.WHITE)
	W.label(self,"Этаж −%d · %s" % [floor.depth,room.habitat_id],Rect2(104,40,230,25),12,Color.WHITE)
	W.button(self,"HabitatDemo","СТАДИИ · ТЕСТ",Rect2(344,12,146,48),toggle_stages)
	W.button(self,"HabitatPanorama","ПАНОРАМА",Rect2(500,12,164,48),toggle_panorama)
	W.button(self,"HabitatFind","НАЙТИ МУТАНТА",Rect2(674,12,160,48),find_resident)
	W.button(self,"HabitatInfo","ИНФО",Rect2(844,12,104,48),func(): complex_screen.show_room_info(model.habitat_id))
	environment=Env.new()
	environment.setup(model,Vector2(940,440),940)
	environment.position=Vector2(10,74)
	environment.mouse_filter=Control.MOUSE_FILTER_STOP
	environment.gui_input.connect(environment_input)
	add_child(environment)
	status=W.label(self,"",Rect2(20,516,920,22),12,Color.WHITE,true)
	model.stage_changed.connect(update_controls)
	update_controls()
	set_active(true)
func find_resident() -> void:
	camera_velocity=0
	find_target=true
func update_controls() -> void:
	get_node("HabitatFind").disabled=not model.inhabited()
	get_node("HabitatPanorama").text="ОБЫЧНЫЙ ВИД" if model.registry.world_width>940 else "ПАНОРАМА"
	status.text="ТЕСТ · стадия %d · %s · касайтесь мутанта или камня" % [model.stage,model.registry.stages[model.stage].name]
func toggle_stages() -> void:
	if is_instance_valid(stage_menu):
		stage_menu.queue_free()
		stage_menu=null
		return
	stage_menu=Panel.new()
	stage_menu.add_theme_stylebox_override("panel",W.box(Color("fff8de"),12))
	stage_menu.name="DemoStageMenu"
	stage_menu.position=Vector2(344,66)
	stage_menu.size=Vector2(260,260)
	stage_menu.z_index=5
	add_child(stage_menu)
	W.label(stage_menu,"Демонстрация, не улучшение",Rect2(8,4,244,30),13)
	for stage in range(1,5):
		W.button(stage_menu,"Stage%d" % stage,"СТАДИЯ %d" % stage,Rect2(8,38+(stage-1)*54,244,48),func(): model.set_stage(stage); toggle_stages())
func toggle_panorama() -> void:
	var base:=Registry.new()
	if not base.load_files(complex_screen.registry): return
	var next=Config.build(base,complex_screen.registry,"normal" if model.registry.world_width>940 else "panorama")
	if next==null: return
	var stage: int=model.stage
	model.registry=next
	model.profile=next.profiles[next.assignments[model.habitat_id].behavior_profile]
	model.set_stage(stage)
	camera_velocity=0
	find_target=true
	environment.refresh()
	update_controls()
func _process(delta: float) -> void:
	update_controls()
	if find_target:
		var target: float=clampf(model.position.x-470,0,maxf(0,model.registry.world_width-940))
		environment.set_camera(move_toward(environment.camera_x,target,delta*1800))
		if absf(environment.camera_x-target)<1: find_target=false
	elif not pressing:
		environment.set_camera(environment.camera_x+camera_velocity*delta)
		camera_velocity=move_toward(camera_velocity,0,delta*2200)
func set_active(value: bool) -> void:
	super.set_active(value)
	if not value:
		pressing=false
		camera_velocity=0
		find_target=false
func environment_input(event: InputEvent) -> void:
	var info: Dictionary=complex_screen.pointer_event(event)
	if info.is_empty(): return
	var point: Vector2=info.point
	if info.get("cancel",false):
		pressing=false
		camera_velocity=0
	elif info.down:
		pressing=true
		touch_start=point
		touch_last=point
		touch_travel=0
		camera_velocity=0
		find_target=false
	elif info.motion and pressing:
		var shift: Vector2=point-touch_last
		touch_travel+=shift.length()
		if touch_travel>=12:
			environment.set_camera(environment.camera_x-shift.x)
			camera_velocity=clampf(-shift.x*30,-1800,1800)
		touch_last=point
	elif info.up and pressing:
		pressing=false
		if maxf(touch_travel,point.distance_to(touch_start))<12:
			camera_velocity=0
			interact((point-environment.world.position)/environment.world.scale)
	environment.accept_event()
func interact(point: Vector2) -> void:
	var rock: Dictionary=model.training_object()
	if not rock.is_empty():
		var r: Array=rock.rect
		if Rect2(r[0]-8,r[1]-8,r[2]+16,r[3]+24).has_point(point):
			model.request_ram()
			return
	if point.distance_to(model.position-Vector2(0,35))<46: model.react()
func _draw() -> void:
	draw_rect(Rect2(0,0,960,540),Color("293e48"))
	draw_style_box(W.box(Color("c9b99b"),10),Rect2(7,71,946,446))
