extends Control
const W=preload("res://scripts/journey_widgets.gd")
const G=preload("res://scripts/evolution_geometry.gd")
const Levels=preload("res://scripts/evolution_levels.gd")
const Session=preload("res://scripts/evolution_session.gd")
const History=preload("res://scripts/mutation_history.gd")
const Board=preload("res://scripts/evolution_board.gd")
const TouchScroll=preload("res://scripts/evolution_touch_scroll.gd")
const Art=preload("res://scripts/mutant_art.gd")
const Tap=preload("res://scripts/puzzle_tap.gd")
var gesture=Tap.new()
var game
var session
var history=History.new()
var number=0
var selected=-1
var pressed=-1
var pointer_start=Vector2.ZERO
var travel=0.0
var elapsed=0.0
var idle=0.0
var busy=false
var animation: Tween
var actors: Dictionary={}
var marks: Node2D
var result_panel: Control
var status_label: Label
var goal_text: Label
var feedback: Label
var list_scroll: ScrollContainer
var list_area=Rect2()
var last_pointer=Vector2.ZERO
var completed: Dictionary={}
var completed_before_attempt=false
func tall() -> bool: return game.view.portrait_mode
func setup(value) -> void:
	game=value
	z_index=30
	mouse_filter=Control.MOUSE_FILTER_STOP
	show_list()
func clear_ui() -> void:
	if animation!=null: animation.kill()
	busy=false; selected=-1; pressed=-1; gesture.cancel()
	actors.clear()
	result_panel=null
	for child in get_children(): remove_child(child); child.queue_free()
func reflow() -> void:
	clear_ui()
	size=G.design(tall())
	if session==null: build_list()
	else: build_trial(); refresh()
	queue_redraw()
func show_list() -> void:
	session=null
	number=0
	history.reset()
	reflow()
func build_list() -> void:
	W.label(self,"ТАКТИЧЕСКАЯ ЭВОЛЮЦИЯ",Rect2(20,20,330 if tall() else 250,70),23)
	W.label(self,"10 новых экспериментов\nБез постоянных наград и открытий",Rect2(20,100 if tall() else 145,500 if tall() else 250,70),17)
	W.button(self,"EvolutionSettings","НАСТРОЙКИ",Rect2(384 if tall() else 800,22,136,48),func(): game.view.show_panel("settings"))
	list_area=Rect2(20,186,500,638) if tall() else Rect2(300,84,640,368)
	list_scroll=ScrollContainer.new()
	list_scroll.name="EvolutionList"
	list_scroll.position=list_area.position
	list_scroll.size=list_area.size
	list_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	list_scroll.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(list_scroll)
	var rows=VBoxContainer.new()
	rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	rows.mouse_filter=Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation",12)
	list_scroll.add_child(rows)
	for index in range(1,11):
		var data=Levels.get_level(index)
		var button=W.button(rows,"EvolutionLevel%d" % index,"%d. %s%s\nСложность %d/5 · %d ходов" % [index,data.name," ✓" if completed.has(index) else "",data.difficulty,data.move_limit],Rect2(0,0,list_area.size.x,74),func(): start_trial(index))
		button.custom_minimum_size=Vector2(list_area.size.x,74)
		button.add_theme_font_size_override("font_size",17)
		button.mouse_filter=Control.MOUSE_FILTER_IGNORE
	W.button(self,"EvolutionExit","В КОМПЛЕКС",Rect2(20,874,500,60) if tall() else Rect2(20,452,250,60),leave)
func start_trial(index: int) -> bool:
	var attempt=Session.new()
	if not attempt.start(Levels.get_level(index)): return false
	completed_before_attempt=completed.has(index)
	session=attempt; number=index; history.reset(); idle=0
	reflow()
	game.view.tutorial.request("tap_controls","Нажмите на обитателя, затем на отмеченную клетку. Цифра — цена. Повторное нажатие снимает выбор.",G.board(tall()),"evolution_"+str(number))
	for object in session.config.objects:
		var hints: Dictionary={"plate":"Плита работает, пока на ней стоит обитатель или ящик.","crate":"Рогач толкает ящик в свободную соседнюю клетку.","hidden":"Глазастик обнаруживает скрытые механизмы рядом с собой.","portal":"Подходящий обитатель эвакуируется при входе в портал.","equipment":"Подойдите к прибору и взаимодействуйте с ним подходящим обитателем.","sample":"Образец подбирает обитатель, вошедший в клетку.","anomaly":"У аномалии есть требования к виду, стадии и питанию."}
		if hints.has(object.type):
			var target=int(object.cell)
			if object.type=="hidden":
				for candidate in range(30):
					if session.cells[candidate]!=null and session.cells[candidate].species_id=="eyeball": target=candidate; break
			var radius=G.board(tall()).size.x/5*.4
			game.view.tutorial.request("mechanism_"+object.type,hints[object.type],Rect2(G.center(target,tall())-Vector2.ONE*radius,Vector2.ONE*radius*2),"evolution_"+str(number))
	return true
func build_trial() -> void:
	W.label(self,"%d · %s" % [number,session.config.name],Rect2(20,12,370,60) if tall() else Rect2(20,20,260,65),22)
	W.button(self,"EvolutionSettings","НАСТРОЙКИ",Rect2(408,18,112,48) if tall() else Rect2(814,18,126,48),func(): game.view.show_panel("settings"))
	status_label=W.label(self,"",Rect2(20,78,500,30) if tall() else Rect2(20,98,260,40),17)
	var scroll=ScrollContainer.new()
	scroll.name="EvolutionGoals"
	scroll.position=Vector2(20,114) if tall() else Vector2(20,148)
	scroll.size=Vector2(500,82) if tall() else Vector2(260,206)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	goal_text=Label.new()
	goal_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	goal_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	goal_text.add_theme_font_size_override("font_size",16)
	goal_text.add_theme_color_override("font_color",W.INK)
	goal_text.mouse_filter=Control.MOUSE_FILTER_IGNORE
	scroll.add_child(goal_text)
	TouchScroll.attach(scroll,func(): return game.view.overlay==null and session!=null and session.status=="active")
	feedback=W.label(self,"",Rect2(20,358,260,120) if not tall() else Rect2(20,78,500,32),15)
	feedback.hide()
	var positions: Dictionary={"EvolutionSpawn":Rect2(20,828,242,54) if tall() else Rect2(710,106,230,54),"EvolutionUndo":Rect2(278,828,242,54) if tall() else Rect2(710,174,230,54),"EvolutionRestart":Rect2(192,896,155,48) if tall() else Rect2(710,242,230,54),"EvolutionList":Rect2(20,896,155,48) if tall() else Rect2(710,310,230,54),"EvolutionExit":Rect2(364,896,156,48) if tall() else Rect2(710,452,230,54)}
	W.button(self,"EvolutionSpawn","СОЗДАТЬ",positions.EvolutionSpawn,spawn_creature)
	W.button(self,"EvolutionUndo","ОТМЕНИТЬ",positions.EvolutionUndo,undo)
	W.button(self,"EvolutionRestart","ЗАНОВО",positions.EvolutionRestart,func(): start_trial(number),Color("d9e8e0"))
	W.button(self,"EvolutionList","УРОВНИ",positions.EvolutionList,show_list,Color("c6e4df"))
	W.button(self,"EvolutionExit","КОМПЛЕКС",positions.EvolutionExit,leave,Color("c6e4df"))
	marks=Node2D.new()
	marks.z_index=2
	marks.draw.connect(func(): Board.draw_targets(marks,session,tall(),selected))
	add_child(marks)
func refresh() -> void:
	for actor in actors.values(): actor.queue_free()
	actors.clear()
	for index in range(30):
		if session.cells[index]==null: continue
		var art=Art.new()
		art.setup_form(session.cells[index])
		art.position=G.center(index,tall())
		art.scale=Vector2.ONE*(1.15 if tall() else 0.80)
		add_child(art)
		actors[index]=art
	status_label.text="Ходы %d/%d · Создания %d" % [session.moves_used,session.config.move_limit,session.creations_left()]
	var lines: PackedStringArray=[]
	for goal in session.objective_status(): lines.append(("✓ " if goal.met else "○ ")+goal.text+" (%d/%d)" % [mini(goal.current,goal.total),goal.total])
	goal_text.text="\n".join(lines)
	get_node("EvolutionSpawn").disabled=busy or session.status!="active" or session.creations_left()==0
	get_node("EvolutionUndo").disabled=busy or not history.can_undo()
	get_node("EvolutionUndo").text="↶ ОТМЕНИТЬ (%d)" % history.remaining
	queue_redraw(); marks.queue_redraw()
	if session.status!="active": show_result()
func notify(text: String) -> void:
	feedback.text=text
	feedback.show()
	status_label.visible=not tall()
	var timer=get_tree().create_timer(3)
	timer.timeout.connect(func():
		if is_instance_valid(feedback): feedback.hide(); status_label.show()
	)
func spawn_creature() -> void:
	if busy or gesture.active: return
	var result=history.execute(session,{"kind":"spawn"})
	if not result.ok:
		notify(result.get("reason","Создание недоступно"))
		if session.creations_left()>0: game.view.tutorial.request("blocked_incubator","Освободите инкубатор перед созданием нового обитателя.",Rect2(G.center(session.next_spawn_point(),tall())-Vector2.ONE*30,Vector2.ONE*60))
		return
	finish(result)
func act(index: int) -> void:
	if busy or selected<0 or index<0 or index==selected or session.status!="active": return
	var result=history.execute(session,session.command(selected,index))
	if not result.ok: notify(result.get("reason","Действие недоступно")); return
	finish(result)
func finish(result: Dictionary) -> void:
	game.view.preferences.master("tap_controls")
	if result.kind in ["move","merge","jump","push","corridor"]: game.view.preferences.master("movement")
	var mastery: Dictionary={"push":"mechanism_crate","reveal":"mechanism_hidden","neutralize":"mechanism_anomaly"}
	if mastery.has(result.kind): game.view.preferences.master(mastery[result.kind])
	if result.kind=="activate" and session.object_at(result.index).type=="equipment": game.view.preferences.master("mechanism_equipment")
	if not session.evacuations.is_empty(): game.view.preferences.master("mechanism_portal")
	if not session.collected.is_empty(): game.view.preferences.master("mechanism_sample")
	if result.kind in ["push","reveal","activate","neutralize","jump","break"]: game.view.preferences.master("action_"+result.kind)
	selected=-1; idle=0; busy=true
	refresh()
	game.view.sound.play_event("merge" if result.kind=="merge" else ("spawn" if result.kind=="spawn" else "select"))
	if session.status=="won": completed[number]=true; game.music.event("victory")
	animation=create_tween()
	if result.has("source") and actors.has(result.index) and result.kind in ["move","merge","push","jump","corridor"]:
		var actor=actors[result.index]
		actor.position=G.center(result.source,tall())
		animation.tween_property(actor,"position",G.center(result.index,tall()),0.22).set_trans(Tween.TRANS_QUAD)
	else: animation.tween_interval(0.22)
	animation.tween_callback(func(): busy=false; refresh())
func undo() -> void:
	if busy or not history.undo(session): return
	if not completed_before_attempt and session.status!="won": completed.erase(number)
	reflow()
	notify("Действие отменено вместе с механизмами и целями")
func show_result() -> void:
	if is_instance_valid(result_panel): return
	result_panel=Control.new()
	result_panel.name="EvolutionResult"
	result_panel.size=size
	result_panel.z_index=20
	result_panel.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(result_panel)
	var shade=ColorRect.new()
	shade.size=size; shade.color=Color("cce5dc")
	result_panel.add_child(shade)
	var width=size.x-60
	W.label(result_panel,"ЭКСПЕРИМЕНТ ЗАВЕРШЁН" if session.status=="won" else "ПОПРОБУЕМ ИНАЧЕ",Rect2(30,110 if tall() else 50,width,60),28,W.INK,true)
	W.label(result_panel,"%d · %s\nХоды: %d / %d\nБез постоянных наград и открытий" % [number,session.config.name,session.moves_used,session.config.move_limit],Rect2(30,210 if tall() else 130,width,150),21,W.INK,true)
	if session.status=="won" and number<10: W.button(result_panel,"EvolutionNext","СЛЕДУЮЩИЙ ЭКСПЕРИМЕНТ",Rect2(30,470 if tall() else 300,width,60),func(): start_trial(number+1))
	W.button(result_panel,"EvolutionReturn","В КОМПЛЕКС",Rect2(30,550 if tall() else 376,width,60),leave)
	W.button(result_panel,"EvolutionRetry","Повторить",Rect2(30,650 if tall() else 456,150,44),func(): start_trial(number),Color("dce9e0"))
	if history.can_undo(): W.button(result_panel,"EvolutionResultUndo","Отменить ход",Rect2(size.x-210,650 if tall() else 456,180,44),undo,Color("dce9e0"))
func leave() -> void:
	game.view.close_navigation()
	game.view.open_complex()
func back() -> void:
	if session!=null: show_list()
	else: leave()
func exit_experiment() -> void:
	if animation!=null: animation.kill()
	if get_parent()!=null: get_parent().remove_child(self)
	queue_free()
func cancel_control() -> void:
	gesture.cancel(); pressed=-1
	if session==null: return
	if animation!=null: animation.kill()
	busy=false
	# Session is authoritative; never leave a killed tween at an intermediate position.
	refresh()
func choose(index: int) -> void:
	if busy or session==null or session.status!="active" or index<0: return
	if index==selected: selected=-1
	elif selected>=0 and not session.target_action(selected,index).is_empty(): act(index); return
	elif session.cells[index]!=null: selected=index
	queue_redraw(); marks.queue_redraw()
func _gui_input(event: InputEvent) -> void:
	if session!=null:
		if busy: gesture.cancel(); accept_event(); return
		var click=gesture.feed(event)
		if not click.is_empty() and G.cell_at(click.origin,tall())==G.cell_at(click.point,tall()): choose(G.cell_at(click.point,tall()))
		accept_event(); return
	# List swipes remain available independently of board controls.
	var point=Vector2.ZERO
	var down=false
	var up=false
	var motion=false
	if event is InputEventScreenTouch:
		if event.index!=0: return
		if event.canceled: pressed=-1; accept_event(); return
		point=event.position; down=event.pressed; up=not down
	elif event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			if event.pressed: list_scroll.scroll_vertical+=86 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -86
			accept_event(); return
		if event.button_index!=MOUSE_BUTTON_LEFT: return
		point=event.position; down=event.pressed; up=not down
	elif event is InputEventScreenDrag:
		if event.index!=0: return
		point=event.position; motion=true
	elif event is InputEventMouseMotion: point=event.position; motion=true
	else: return
	if down:
		pointer_start=point; last_pointer=point; travel=0
		pressed=0 if list_area.has_point(point) else -1
	elif motion and pressed>=0:
		travel+=point.distance_to(last_pointer)
		list_scroll.scroll_vertical-=int(point.y-last_pointer.y); last_pointer=point
	elif up and pressed>=0:
		pressed=-1
		if maxf(travel,point.distance_to(pointer_start))<12 and list_area.has_point(point):
			var row=int((point.y-list_area.position.y+list_scroll.scroll_vertical)/86)
			if row>=0 and row<10: start_trial(row+1)
	accept_event()
func _process(delta: float) -> void:
	elapsed+=delta; idle+=delta
	if session!=null and session.status=="active":
		queue_redraw()
		if idle>15: game.view.tutorial.request("idle","Выберите обитателя: подсветка покажет допустимые действия и их стоимость.",G.board(tall()),"evolution_"+str(number))
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("e3f0e8"))
	if session!=null: Board.draw_board(self,session,tall(),selected,elapsed)