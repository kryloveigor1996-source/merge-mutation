extends Control
const Env=preload("res://scripts/habitat_environment.gd")
const W=preload("res://scripts/journey_widgets.gd")
const Catalog=preload("res://scripts/mutant_catalog.gd")
signal closed
var complex_screen: Control
var model
var environment
var stage_label: Label
var status: Label
var reaction: Button
var training: Button
var touch_start:=Vector2.ZERO
var touch_travel:=0.0
var touch_last:=Vector2.ZERO
var pressing:=false
func setup(parent_screen: Control,value,room: Dictionary,floor: Dictionary) -> void:
	complex_screen=parent_screen
	model=value
	size=Vector2(360,720)
	mouse_filter=Control.MOUSE_FILTER_STOP
	z_index=20
	W.button(self,"HabitatBack","НАЗАД",Rect2(10,14,84,44),func(): closed.emit(),Color("b7dfd5"))
	W.label(self,Catalog.species(room.species_id).name,Rect2(108,12,240,36),24,Color("f3efd8"),true)
	W.label(self,"Этаж −%d · %s" % [floor.depth,room.habitat_id],Rect2(98,54,250,29),12,Color("bce7d6"),true)
	environment=Env.new()
	environment.setup(model,Vector2(340,420))
	environment.position=Vector2(10,102)
	environment.mouse_filter=Control.MOUSE_FILTER_STOP
	environment.gui_input.connect(environment_input)
	add_child(environment)
	reaction=W.button(self,"HabitatReact","ПОЗВАТЬ",Rect2(10,536,106,46),func(): model.react())
	training=W.button(self,"HabitatTrain","ТРЕНИРОВКА",Rect2(124,536,126,46),func(): model.request_ram())
	W.button(self,"HabitatInfo","ИНФО",Rect2(258,536,92,46),func(): complex_screen.show_room_info(model.habitat_id),Color("b7dfd5"))
	stage_label=W.label(self,"",Rect2(10,588,340,26),12,Color("f4dfa5"),true)
	for stage in range(1,5):
		W.button(self,"HabitatStage%d" % stage,"СТАДИЯ %d" % stage,Rect2(10+(stage-1)*86,620,82,46),func(): model.set_stage(stage),Color("c4dfc4"))
	status=W.label(self,"",Rect2(10,678,340,29),12,Color("d0e7db"),true)
	model.stage_changed.connect(update_controls)
	update_controls()
	set_active(true)
func set_active(value: bool) -> void:
	set_process(value)
	if is_instance_valid(environment): environment.set_active(value)
func update_controls() -> void:
	stage_label.text="ТЕСТОВЫЙ ПРОСМОТР · %d — %s" % [model.stage,model.registry.stages[model.stage].name]
	reaction.disabled=not model.inhabited() or model.cooldown>0 or model.behavior=="ram" or model.intent=="ram"
	training.disabled=model.stage<3 or model.cooldown>0 or model.stone_broken or model.behavior=="ram" or model.intent=="ram"
	status.text="Камера пока пуста" if not model.inhabited() else {"idle":"Осматривается и отдыхает","walk":"Гуляет по вольеру","sleep":"Спит. Тс-с...","inspect":"Изучает обстановку","react":"О! Кто здесь?","ram":"Проверка камня на прочность!"}.get(model.behavior,"")
func _process(_delta: float) -> void: update_controls()
func environment_input(event: InputEvent) -> void:
	var info: Dictionary=complex_screen.pointer_event(event)
	if info.is_empty(): return
	var point: Vector2=info.point
	if info.get("cancel",false): pressing=false
	elif info.down:
		pressing=true
		touch_start=point
		touch_last=point
		touch_travel=0
	elif info.motion and pressing:
		touch_travel+=point.distance_to(touch_last)
		touch_last=point
	elif info.up and pressing:
		pressing=false
		if maxf(touch_travel,point.distance_to(touch_start))<12:
			if point.distance_to(model.position-Vector2(0,35))<46: model.react()
			else:
				var rock: Dictionary=model.training_object()
				if not rock.is_empty():
					var r: Array=rock.rect
					if Rect2(r[0]-8,r[1]-8,r[2]+16,r[3]+24).has_point(point): model.request_ram()
	environment.accept_event()
func _draw() -> void:
	draw_rect(Rect2(0,0,360,720),Color("293e48"))
	draw_style_box(W.box(Color("c9b99b"),10),Rect2(7,99,346,426))
