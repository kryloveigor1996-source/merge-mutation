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
	busy=false
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
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.canceled and event.index==0:
		pressed=-1; selected=-1; list_pressed=false; accept_event(); queue_redraw(); return
	super._gui_input(event)