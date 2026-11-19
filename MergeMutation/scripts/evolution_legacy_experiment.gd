extends "res://scripts/landscape_experiment.gd"
const G=preload("res://scripts/evolution_geometry.gd")
func tall() -> bool: return game.view.portrait_mode
func center(index: int) -> Vector2: return G.center(index,tall())
func cell_at(point: Vector2) -> int: return G.cell_at(point,tall())
func list_rect() -> Rect2: return Rect2(20,180,500,640) if tall() else MENU
func show_list() -> void:
	super.show_list()
	mount_settings()
	if not tall(): return
	size=G.TALL
	L.place(trial_scroll,list_rect())
	L.place(get_node("ExperimentExit"),Rect2(20,872,500,60))
	var row=0
	for child in get_children():
		if child is Label: L.place(child,Rect2(20,24+row*70,500,64)); row+=1
func arrange() -> void:
	super.arrange()
	mount_settings()
	if not tall() or session==null: return
	size=G.TALL
	L.place(get_node("ExperimentSpawn"),Rect2(20,828,242,54))
	L.place(get_node("ExperimentUndo"),Rect2(278,828,242,54))
	L.place(get_node("ExperimentRestart"),Rect2(20,896,155,48))
	L.place(get_node("ExperimentList"),Rect2(192,896,155,48))
	L.place(get_node("ExperimentExit"),Rect2(364,896,156,48))
	for child in get_children():
		if child is Label:
			if child==counters: L.place(child,Rect2(20,76,500,30))
			elif child==message: L.place(child,Rect2(20,112,500,88))
			elif child.name=="LandscapeGoals" or child.text.begins_with("Цели:"): child.hide()
			else: L.place(child,Rect2(20,14,500,54))
	for sprite in sprites.values(): sprite.scale=Vector2.ONE*1.15
func reflow() -> void:
	if animation: animation.kill()
	busy=false; selected=-1
	gesture.cancel()
	if session==null: show_list()
	else:
		# Retain session/history; only control geometry and actor positions change.
		arrange()
		for index in sprites: sprites[index].position=center(index)
	queue_redraw()
func _draw() -> void:
	if not tall(): super._draw(); return
	draw_rect(Rect2(0,0,540,960),Color("e3f0e8"))
	if session==null: return
	for index in range(30):
		if index in session.config.blocked_cells: continue
		var p=center(index)
		var color: Color={"normal":Color("b9d9d1"),"rock":Color("a4a4a0"),"acid":Color("83df50"),"gap":Color("294c61")}[session.ground(index)]
		draw_style_box(W.box(color,10),Rect2(p-Vector2.ONE*46,Vector2.ONE*92))
		if index==selected: draw_arc(p,43,0,TAU,32,Color.WHITE,3)
func mount_settings() -> void:
	if not has_node("ExperimentSettings"): W.button(self,"ExperimentSettings","⚙",Rect2(830,14,110,44),func(): game.view.show_panel("settings"))
	L.place(get_node("ExperimentSettings"),Rect2(464,76,56,44) if tall() else Rect2(830,14,110,44))
const Tap=preload("res://scripts/puzzle_tap.gd")
const Marks=preload("res://scripts/puzzle_marks.gd")
var gesture=Tap.new()
func cancel_control() -> void:
	gesture.cancel(); pressed=-1; selected=-1; list_pressed=false
	if animation: animation.kill()
	busy=false
	if session!=null: refresh()
func _gui_input(event: InputEvent) -> void:
	if session==null:
		if event is InputEventScreenTouch and event.index==0 and event.canceled:
			list_pressed=false; gesture.cancel(); accept_event(); return
		super._gui_input(event); return
	if busy: gesture.cancel(); accept_event(); return
	var click=gesture.feed(event)
	if not click.is_empty() and cell_at(click.origin)==cell_at(click.point): choose(cell_at(click.point))
	accept_event()
func choose(index: int) -> void:
	if index<0 or busy or session.status!="active": return
	if index==selected: selected=-1
	elif selected>=0 and not action_for(index).is_empty(): act(index,true); return
	elif session.cells[index]!=null:
		selected=index
		message.text="Нажмите на отмеченную клетку. Цифра — цена. Повторное нажатие снимает выбор."
	queue_redraw(); action_layer.queue_redraw()
func action_for(index: int) -> Dictionary:
	for action in session.legal_actions()+session.corridor_actions(selected):
		if action.get("source",-1)==selected and action.index==index: return action
	return {}
func draw_action_marks() -> void:
	if session==null: return
	if selected>=0:
		var radius=43 if tall() else 28
		Marks.selected(action_layer,center(selected),radius)
		for action in session.legal_actions()+session.corridor_actions(selected):
			if action.get("source",-1)!=selected: continue
			Marks.target(action_layer,center(action.index),radius,Marks.category(action.kind),int(action.get("cost",1)))
	for target in session.config.destinations:
		var p=center(target.cell)
		var tag: String={"horn":"Р","slime":"С","wing":"К"}.get(target.species_id,"?")+" II"
		action_layer.draw_string(ThemeDB.fallback_font,p+Vector2(-20,23),tag,HORIZONTAL_ALIGNMENT_LEFT,-1,12,W.INK)
func clear() -> void:
	gesture.cancel()
	super.clear()
func create_creature() -> void:
	if gesture.active: return
	super.create_creature()
func start_trial(index: int) -> bool:
	var ok=super.start_trial(index)
	if ok: game.view.tutorial.request("tap_controls","Выберите мутанта коротким нажатием, затем нажмите на отмеченную цель. Удержание и свайп не перемещают существ.",G.board(tall()),"legacy_"+str(index))
	return ok
func finish_action(result: Dictionary) -> void:
	if result.ok: game.view.preferences.master("tap_controls")
	super.finish_action(result)
