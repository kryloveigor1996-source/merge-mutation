extends "res://scripts/mutation_experiment.gd"
const L=preload("res://scripts/landscape_layout.gd")
const MENU:=Rect2(300,72,640,412)
func setup(value: Control) -> void:
	super.setup(value)
	size=L.DESIGN
func show_list() -> void:
	super.show_list()
	size=L.DESIGN
	L.place(trial_scroll,MENU)
	L.place(get_node("ExperimentExit"),Rect2(20,452,250,56))
	for child in get_children():
		if child is Label:
			L.place(child,Rect2(20,30 if child.position.y<70 else 160,250,110))
func list_rect() -> Rect2: return MENU
func center(index: int) -> Vector2: return L.center(index)
func cell_at(point: Vector2) -> int: return L.cell_at(point)
func refresh() -> void:
	super.refresh()
	arrange()
func arrange() -> void:
	if session==null: return
	size=L.DESIGN
	var map: Dictionary={"ExperimentSpawn":Rect2(710,106,230,54),"ExperimentUndo":Rect2(710,174,230,54),"ExperimentRestart":Rect2(710,242,230,54),"ExperimentList":Rect2(710,310,230,54),"ExperimentExit":Rect2(710,452,230,54)}
	for id in map:
		L.place(get_node(id),map[id])
		get_node(id).add_theme_font_size_override("font_size",16)
	for child in get_children():
		if not child is Label: continue
		if child==message: L.place(child,Rect2(20,302,250,190))
		elif child==counters:
			child.text="Ходы: %d / %d" % [session.moves_used,session.config.move_limit]
			L.place(child,Rect2(20,122,250,42))
		elif child.text.begins_with("Цели:"): L.place(child,Rect2(308,482,350,40))
		else: L.place(child,Rect2(20,26,250,80))
	if not has_node("LandscapeGoals"):
		var goals:=W.label(self,"",Rect2(20,176,250,112),17)
		goals.name="LandscapeGoals"
	var goal_text: PackedStringArray=[]
	for target in session.config.destinations: goal_text.append(Session.Catalog.title(target))
	get_node("LandscapeGoals").text="Доставить к меткам:\n"+"\n".join(goal_text)
	L.place(get_node("LandscapeGoals"),Rect2(20,176,250,112))
	for sprite in sprites.values(): sprite.scale=Vector2.ONE*0.86
func _draw() -> void:
	draw_rect(Rect2(0,0,960,540),Color("dfeee5"))
	draw_style_box(W.box(Color("fff8de")),Rect2(10,12,272,514))
	draw_style_box(W.box(Color("c4dfd7")),Rect2(698,12,252,514))
	if session==null: return
	for index in range(30):
		if index in session.config.blocked_cells: continue
		var p:=center(index)
		var terrain: String=session.ground(index)
		var color: Color={"normal":Color("b9d9d1"),"rock":Color("a4a4a0"),"acid":Color("83df50"),"gap":Color("294c61")}[terrain]
		draw_style_box(W.box(color,9),Rect2(p-Vector2(30,30),Vector2(60,60)))
		if terrain=="rock": draw_polyline(PackedVector2Array([p+Vector2(-12,-24),p+Vector2(6,-3),p+Vector2(-5,8),p+Vector2(12,24)]),W.INK,3)
		elif terrain=="acid":
			for i in range(3): draw_circle(p+Vector2(-14+i*14,10+sin(elapsed*2+i)*4),3,Color("d5ff8e"))
		elif terrain=="gap": draw_line(p+Vector2(-15,-10),p+Vector2(10,8),Color("112d3e"),6)
		if index==selected: draw_arc(p,29,0,TAU,32,Color.WHITE,3)
	if effect_time>0 and effect_index>=0:
		for i in range(8): draw_circle(center(effect_index)+Vector2.from_angle(i*TAU/8)*(1-effect_time/0.65)*42,3,Color("ffbe62"))
	if effect_kind=="undo" and effect_time>0: draw_rect(L.BOARD,Color(0.2,0.8,0.9,effect_time*0.5))
