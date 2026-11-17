extends Control
const Session = preload("res://scripts/mutation_session.gd")
const Art = preload("res://scripts/mutant_art.gd")
const W = preload("res://scripts/journey_widgets.gd")
var game: Control
var session
var number := 0
var selected := -1
var pressed := -1
var pointer_start := Vector2.ZERO
var busy := false
var elapsed := 0.0
var effect_time := 0.0
var effect_index := -1
var effect_kind := ""
var message: Label
var counters: Label
var completed: Dictionary={}
var learned: Dictionary={}
var sprites: Dictionary={}
var animation: Tween
var action_layer: Node2D
static func config(index: int) -> Dictionary:
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://experiment/levels/level_%02d.json" % index)) if index>=1 and index<=5 else null
	return data if data is Dictionary and Session.valid_experiment(data) else {}
func setup(value: Control) -> void:
	game=value
	size=Vector2(360,720)
	z_index=30
	mouse_filter=Control.MOUSE_FILTER_STOP
	show_list()
func clear() -> void:
	if animation: animation.kill()
	busy=false
	selected=-1
	pressed=-1
	effect_time=0
	sprites.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
func show_list() -> void:
	clear()
	session=null
	number=0
	W.label(self,"ТАКТИЧЕСКИЕ МУТАЦИИ",Rect2(18,30,324,44),22,W.INK,true)
	W.label(self,"5 испытаний · без постоянных наград\nПрогресс только до закрытия режима",Rect2(22,88,316,55),14,W.INK,true)
	for index in range(1,6):
		var data := config(index)
		var entry := W.button(self,"Trial%d" % index,"%d. %s%s" % [index,data.get("name","Ошибка конфигурации")," ✓" if completed.has(index) else ""],Rect2(20,157+(index-1)*82,320,68),func(): start_trial(index))
		entry.add_theme_font_size_override("font_size",13)
	W.button(self,"ExperimentExit","В ЛАБОРАТОРИЮ",Rect2(24,644,312,54),exit_experiment,Color("b5e9ee"))
	queue_redraw()
func start_trial(index: int) -> bool:
	var attempt := Session.new()
	if not attempt.start(config(index)): return false
	clear()
	session=attempt
	number=index
	W.label(self,"%d · %s" % [index,session.config.name],Rect2(18,15,324,52),19,W.INK,true)
	counters=W.label(self,"",Rect2(16,72,328,24),14,W.INK,true)
	var show_tip: bool=session.config.required.any(func(id): return not learned.has(id))
	message=W.label(self,session.config.tip if show_tip else "Доставьте формы II на отмеченные клетки. Спланируйте порядок действий.",Rect2(22,102,316,62),14,W.INK,true)
	W.label(self,"Цели: Р — Рогач · С — Слизик · К — Крылатик",Rect2(16,516,328,22),12,W.INK,true)
	W.button(self,"ExperimentSpawn","СОЗДАТЬ",Rect2(24,545,312,44),create_creature)
	W.button(self,"ExperimentRestart","ЗАНОВО",Rect2(24,601,148,48),func(): start_trial(number),Color("ffd7b6"))
	W.button(self,"ExperimentList","ИСПЫТАНИЯ",Rect2(184,601,152,48),show_list,Color("b5e9ee"))
	W.button(self,"ExperimentExit","В ЛАБОРАТОРИЮ",Rect2(24,661,312,46),exit_experiment,Color("ded2fb"))
	action_layer=Node2D.new()
	action_layer.draw.connect(draw_action_marks)
	add_child(action_layer)
	refresh()
	return true
func exit_experiment() -> void:
	if is_queued_for_deletion(): return
	if animation: animation.kill()
	if get_parent()!=null: get_parent().remove_child(self)
	queue_free()
func center(index: int) -> Vector2:
	return Vector2(40+(index%5)*56,177+floori(float(index)/5)*56)+Vector2(28,28)
func cell_at(point: Vector2) -> int:
	if not Rect2(40,177,280,336).has_point(point): return -1
	return int((point.x-40)/56)+5*int((point.y-177)/56)
func refresh() -> void:
	for sprite in sprites.values(): sprite.queue_free()
	sprites.clear()
	for index in range(30):
		if session.cells[index]==null: continue
		var sprite := Art.new()
		sprite.setup_form(session.cells[index])
		sprite.scale=Vector2.ONE*0.72
		sprite.position=center(index)
		add_child(sprite)
		sprites[index]=sprite
	move_child(action_layer,get_child_count()-1)
	counters.text="Ходы: %d / %d · Доставьте формы II к меткам" % [session.moves_used,session.config.move_limit]
	var spawn: Button=get_node("ExperimentSpawn")
	spawn.disabled=busy or session.status!="active" or session.creations_left()==0
	spawn.text="СОЗДАТЬ РОГАЧА · %d" % session.creations_left() if session.creations_left()>0 else "СОЗДАНИЯ НЕ НУЖНЫ"
	if session.status=="won":
		completed[number]=true
		message.text="Успех! Все формы доставлены. Наград кампании нет."
	elif session.status=="lost": message.text=session.reason
	queue_redraw()
func create_creature() -> void:
	if busy or session==null: return
	finish_action(session.spawn())
func act(destination: int,explicit_tap: bool=true) -> void:
	if busy or session==null or selected<0 or destination<0 or session.status!="active": return
	if destination==selected: return
	if session.ground(destination)=="rock" and not explicit_tap:
		message.text="Для разрушения нажмите на камень после выбора Рогача."
		return
	finish_action(session.break_rock(selected,destination) if session.ground(destination)=="rock" else session.transfer(selected,destination))
func finish_action(result: Dictionary) -> void:
	if not result.ok:
		message.text=result.get("reason","Действие недоступно")
		return
	selected=-1
	busy=true
	effect_time=0.65
	effect_index=int(result.index)
	effect_kind=result.kind
	var ability_id: String={"break":"ram","jump":"flight"}.get(result.kind,"")
	if ability_id.is_empty() and session.used.has("acid"): ability_id="acid"
	if not ability_id.is_empty() and not learned.has(ability_id):
		learned[ability_id]=true
		message.text={"ram":"Камень разрушен за один ход!","flight":"Один разрыв, свободное приземление — один ход!","acid":"Слизик безопасно проходит кислоту."}[ability_id]
	refresh()
	animation=create_tween()
	if result.kind in ["move","merge","jump"]:
		var sprite: Node2D=sprites[int(result.index)]
		var from := center(int(result.source))
		var to := center(int(result.index))
		animation.tween_method(func(t: float): sprite.position=from.lerp(to,t)+Vector2(0,-sin(t*PI)*(26 if result.kind=="jump" else 6)),0.0,1.0,0.26)
	else: animation.tween_interval(0.26)
	animation.tween_callback(func():
		busy=false
		refresh()
	)
func _gui_input(event: InputEvent) -> void:
	if session==null or busy: return
	var point := Vector2.ZERO
	var down := false
	var up := false
	if event is InputEventScreenTouch:
		if event.index!=0: return
		point=event.position
		down=event.pressed
		up=not down
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		point=event.position
		down=event.pressed
		up=not down
	else: return
	if down:
		pressed=cell_at(point)
		pointer_start=point
		if pressed>=0:
			if selected>=0 and pressed!=selected and (session.cells[pressed]==null or session.can_transfer(selected,pressed)): act(pressed,true)
			elif session.cells[pressed]!=null:
				selected=pressed
				var id := Session.ability(session.cells[pressed])
				message.text={"ram":"Таран: нажмите на соседний камень.","acid":"Слизик: кислота безопасна.","flight":"Летун: один разрыв, свободная клетка за ним."}.get(id,"") if not learned.has(id) else "Выберите подсвеченное действие."
				queue_redraw()
	if up:
		if pressed>=0 and point.distance_to(pointer_start)>12: act(cell_at(point),false)
		pressed=-1
	accept_event()
func _process(delta: float) -> void:
	elapsed+=delta
	effect_time=maxf(0,effect_time-delta)
	if session!=null: queue_redraw()
	if session!=null and is_instance_valid(action_layer): action_layer.queue_redraw()
func draw_action_marks() -> void:
	if session==null: return
	if selected>=0:
		var colors := {"move":Color("4ba8e8"),"merge":Color("ecc12c"),"break":Color("f37835"),"jump":Color("ae6ce1")}
		for action in session.legal_actions():
			if action.get("source",-1)!=selected: continue
			var p := center(int(action.index))
			action_layer.draw_rect(Rect2(p-Vector2(25,25),Vector2(50,50)),colors[action.kind],false,3)
			action_layer.draw_circle(p+Vector2(17,-17),9,colors[action.kind])
			action_layer.draw_string(ThemeDB.fallback_font,p+Vector2(12,-12),{"move":"→","merge":"+","break":"!","jump":"↑"}[action.kind],HORIZONTAL_ALIGNMENT_LEFT,-1,15,W.INK)
	for target in session.config.destinations:
		var p := center(int(target.cell))
		var tag: String={"horn":"Р","slime":"С","wing":"К"}.get(target.species_id,"?")+" II"
		action_layer.draw_style_box(W.box(Color("fff8de"),3),Rect2(p+Vector2(-24,12),Vector2(32,14)))
		action_layer.draw_string(ThemeDB.fallback_font,p+Vector2(-21,23),tag,HORIZONTAL_ALIGNMENT_LEFT,-1,11,W.INK)
func _draw() -> void:
	draw_rect(Rect2(0,0,360,720),Color("e3f3eb"))
	if session==null: return
	for index in range(30):
		if index in session.config.blocked_cells: continue
		var p := center(index)
		var type: String=session.ground(index)
		var color: Color={"normal":Color("b9d9d1"),"rock":Color("a4a4a0"),"acid":Color("83df50"),"gap":Color("294c61")}[type]
		draw_style_box(W.box(color,9),Rect2(p-Vector2(26,26),Vector2(52,52)))
		if type=="rock":
			draw_polyline(PackedVector2Array([p+Vector2(-11,-22),p+Vector2(2,-5),p+Vector2(-7,4),p+Vector2(9,22)]),Color("5b6267"),3)
		elif type=="acid":
			for dot in range(3): draw_circle(p+Vector2(-14+dot*14,10+sin(elapsed*2+dot)*5),3,Color("d5ff8e"))
		elif type=="gap":
			draw_line(p+Vector2(-15,-10),p+Vector2(7,6),Color("122a3d"),5)
		if index==selected: draw_arc(p,25,0,TAU,32,Color.WHITE,3)
	if effect_time>0 and effect_index>=0:
		var p := center(effect_index)
		for dot in range(8):
			var offset := Vector2.from_angle(dot*TAU/8.0)*(1-effect_time/0.65)*38
			draw_circle(p+offset,2+effect_time*3,Color("ffae59") if effect_kind=="break" else Color("d3a8ef"))
	if session.status=="won" and effect_time>0:
		draw_arc(Vector2(180,85),120+(1-effect_time/0.65)*35,0,TAU,48,Color(0.9,0.73,0.28,effect_time/0.65),3)
