extends Control
const W = preload("res://scripts/journey_widgets.gd")
const Worlds = preload("res://scripts/world_registry.gd")
const Model = preload("res://scripts/world_map_model.gd")
const MapCanvas = preload("res://scripts/world_map_canvas.gd")
const Door = preload("res://scripts/portal_art.gd")
const Dialogue = preload("res://scripts/context_dialogue.gd")
var game: Control
var lab_view: Node2D
var page := "hub"
var selected := "laboratory"
var world_ids: Array[String]=[]
var main_door: Node2D
var map_model
var map_scroll: ScrollContainer
var map_canvas: Control
var scroll_target := 0.0
var applying_scroll := false
var offsets: Dictionary={}
var collection_return := false
var swiping := false
var swipe_start := Vector2.ZERO
var swipe_travel := Vector2.ZERO
var quote := ""
var hint: Label
var entering := false
var last_transition: Tween
var fade: Tween
func setup(value: Control,view: Node2D) -> void:
	game=value
	lab_view=view
	size=Vector2(360,720)
	mouse_filter=Control.MOUSE_FILTER_STOP
	clip_contents=true
	z_index=22
	hide()
func clear_page() -> void:
	if is_instance_valid(map_scroll): offsets[selected]=map_scroll.scroll_vertical
	if last_transition: last_transition.kill()
	entering=false
	map_scroll=null
	map_canvas=null
	for child in get_children():
		remove_child(child)
		child.queue_free()
func appear() -> void:
	show()
	if fade: fade.kill()
	modulate.a=0
	fade=create_tween()
	fade.tween_property(self,"modulate:a",1.0,0.18)
func quote_for(context: String) -> void:
	var line: Dictionary=game.dialogue.next_line(context)
	if not line.is_empty(): quote=Dialogue.text(line)
func open_hub(id: String="") -> void:
	clear_page()
	page="hub"
	world_ids=Worlds.ids()
	if world_ids.is_empty():
		W.label(self,"Каталог миров недоступен",Rect2(20,180,320,100),20,W.INK,true)
		W.button(self,"PortalBack","В ЛАБОРАТОРИЮ",Rect2(22,610,316,48),close_to_lab)
		appear()
		return
	if not id.is_empty() and id in world_ids: selected=id
	if not selected in world_ids: selected=world_ids[0]
	quote_for("hub")
	build_hub()
	appear()
func build_hub() -> void:
	var done: Array=game.completed_world_level_ids()
	var entry := Worlds.world(selected)
	var unlocked := Worlds.unlocked(selected,done)
	var index := world_ids.find(selected)
	W.label(self,"ЗАЛ ПОРТАЛОВ",Rect2(20,18,320,38),24,W.INK,true)
	W.label(self,"★ %d    ·    %d монет    ·    %d / %d" % [game.campaign_progress.stars,game.coins,index+1,world_ids.size()],Rect2(20,60,320,24),12,W.INK,true)
	var title: String=entry.name if unlocked or entry.unlock.type!="unavailable" else "НЕИЗВЕСТНЫЙ МИР"
	W.label(self,title,Rect2(20,99,320,48),23,W.INK,true)
	for offset in [-1,1]:
		if world_ids.size()<2: continue
		var other: String=world_ids[posmod(index+offset,world_ids.size())]
		var neighbour := Door.new()
		neighbour.setup(Worlds.world(other).portal_style,Worlds.unlocked(other,done))
		neighbour.position=Vector2(180+offset*212,291)
		neighbour.scale=Vector2.ONE*0.86
		neighbour.modulate=Color(0.72,0.8,0.82)
		add_child(neighbour)
	main_door=Door.new()
	main_door.setup(entry.portal_style,unlocked)
	main_door.position=Vector2(180,291)
	add_child(main_door)
	W.button(self,"PortalPrev","<",Rect2(10,275,46,58),func(): shift(-1),Color("d5e7df")).disabled=world_ids.size()<2
	W.button(self,"PortalNext",">",Rect2(304,275,46,58),func(): shift(1),Color("d5e7df")).disabled=world_ids.size()<2
	var description: String=entry.description if unlocked else Worlds.locked_reason(selected,done)
	W.label(self,description,Rect2(28,433,304,64),15,W.INK,true)
	var progress := Worlds.status(selected,done)
	var caption := "Пройдено %d / %d испытаний" % [progress.completed,progress.total]
	if progress.total==0: caption="Карта исследуется · испытания готовятся" if unlocked else "Портал закрыт"
	W.label(self,caption,Rect2(20,506,320,25),12,W.INK,true)
	var bar := ProgressBar.new()
	bar.position=Vector2(48,536)
	bar.size=Vector2(264,10)
	bar.max_value=maxi(1,progress.total)
	bar.value=progress.completed
	bar.show_percentage=false
	bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background",W.box(Color("bed4d0"),5))
	bar.add_theme_stylebox_override("fill",W.box(Color("8dcb91"),5))
	add_child(bar)
	bar.size=Vector2(264,10)
	hint=W.label(self,quote,Rect2(28,557,304,44),11,W.INK,true)
	W.button(self,"PortalEnter","ВОЙТИ В ПОРТАЛ" if unlocked else "ПОЧЕМУ ЗАКРЫТ?",Rect2(22,610,316,48),enter_portal,Color("ffda69") if unlocked else Color("c3d5d4"))
	W.button(self,"PortalBack","В ЛАБОРАТОРИЮ",Rect2(22,666,152,48),close_to_lab,Color("b5e9ee"))
	W.button(self,"PortalCollection","КОЛЛЕКЦИЯ",Rect2(186,666,152,48),show_collection,Color("ded2fb"))
	queue_redraw()
func shift(direction: int) -> void:
	if entering or page!="hub" or world_ids.is_empty(): return
	var index := world_ids.find(selected)
	open_hub(world_ids[posmod(index+direction,world_ids.size())])
func swipe(delta: Vector2) -> bool:
	if absf(delta.x)<48 or absf(delta.x)<=absf(delta.y)*1.3: return false
	shift(1 if delta.x<0 else -1)
	return true
func _gui_input(event: InputEvent) -> void:
	if page!="hub": return
	if event is InputEventScreenTouch:
		if event.index!=0:
			accept_event()
			return
		if event.pressed:
			swiping=true
			swipe_start=event.position
			swipe_travel=Vector2.ZERO
		else:
			if swiping: swipe(swipe_travel if swipe_travel.length()>0 else event.position-swipe_start)
			swiping=false
		accept_event()
	elif event is InputEventScreenDrag:
		if event.index==0 and swiping: swipe_travel+=event.relative
		accept_event()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			swiping=true
			swipe_start=event.position
		else:
			if swiping: swipe(event.position-swipe_start)
			swiping=false
		accept_event()
func enter_portal() -> void:
	if entering: return
	var done: Array=game.completed_world_level_ids()
	if not Worlds.unlocked(selected,done):
		quote_for("locked")
		hint.text=Worlds.locked_reason(selected,done)
		main_door.create_tween().tween_property(main_door,"rotation",0.0,0.25).from(-0.025)
		return
	entering=true
	quote_for("portal_enter")
	hint.text=quote
	var id := selected
	last_transition=main_door.opening()
	last_transition.tween_callback(func():
		if visible and page=="hub" and selected==id: game.open_world_map(id)
	)
func open_map(id: String) -> bool:
	if not Worlds.unlocked(id,game.completed_world_level_ids()): return false
	clear_page()
	page="map"
	selected=id
	map_model=Model.new()
	if not map_model.setup(id,game.completed_world_level_ids()): return false
	var entry: Dictionary=map_model.entry
	W.label(self,entry.name,Rect2(20,18,320,40),24,W.INK,true)
	var progress := Worlds.status(id,game.completed_world_level_ids())
	var caption := "★ %d   ·   Пройдено %d / %d" % [game.campaign_progress.stars,progress.completed,progress.total]
	if entry.levels.is_empty(): caption="ДЕМОНСТРАЦИЯ · игровые уровни готовятся"
	W.label(self,caption,Rect2(18,65,324,30),12,W.INK,true)
	hint=W.label(self,"Выберите испытание. Дальние участки скрыты туманом." if not entry.levels.is_empty() else "Это предварительный маршрут. Узлы не запускаются и не выдают наград.",Rect2(26,102,308,47),13,W.INK,true)
	map_scroll=ScrollContainer.new()
	map_scroll.name="WorldMapScroll"
	map_scroll.position=Vector2(12,158)
	map_scroll.size=Vector2(336,490)
	map_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	map_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(map_scroll)
	map_canvas=MapCanvas.new()
	map_canvas.name="WorldMapCanvas"
	map_canvas.setup(self,map_model)
	map_scroll.add_child(map_canvas)
	var active_scroll := map_scroll
	var active_canvas := map_canvas
	map_scroll.get_v_scroll_bar().value_changed.connect(func(value: float):
		if active_scroll!=map_scroll or not is_instance_valid(active_canvas): return
		if not applying_scroll: scroll_target=value
		active_canvas.queue_redraw()
	)
	scroll_target=clampf(float(offsets.get(id,maxf(0,map_model.point(map_model.current).y-180))),0,maxf(0,map_model.height()-map_scroll.size.y))
	call_deferred("place_initial_scroll",id)
	W.button(self,"MapBack","К ПОРТАЛАМ",Rect2(22,666,152,48),func(): open_hub(id),Color("b5e9ee"))
	W.button(self,"MapCollection","КОЛЛЕКЦИЯ",Rect2(186,666,152,48),show_collection,Color("ded2fb"))
	appear()
	return true
func activate_node(index: int) -> void:
	if page!="map" or index<0 or index>=map_model.nodes.size(): return
	var state: String=map_model.state(index)
	if state in ["completed","current"]:
		if game.start_world_level(selected,map_model.nodes[index].id): return
	hint.text="Это демонстрационный маршрут. Игровые испытания появятся позже." if state=="preview" else "Сначала завершите предыдущее испытание."
func place_initial_scroll(id: String) -> void:
	if page!="map" or selected!=id or not is_instance_valid(map_scroll): return
	applying_scroll=true
	map_scroll.scroll_vertical=roundi(scroll_target)
	applying_scroll=false
func scroll_by(amount: float) -> void:
	if not is_instance_valid(map_scroll): return
	scroll_target=clampf(scroll_target+amount,0,maxf(0,map_model.height()-map_scroll.size.y))
func _process(delta: float) -> void:
	if not visible or page!="map" or not is_instance_valid(map_scroll): return
	if absf(map_scroll.scroll_vertical-scroll_target)>0.5:
		applying_scroll=true
		var next := roundi(lerpf(map_scroll.scroll_vertical,scroll_target,1-exp(-18*delta)))
		if next==map_scroll.scroll_vertical: next+=1 if scroll_target>next else -1
		map_scroll.scroll_vertical=next
		applying_scroll=false
		map_canvas.queue_redraw()
func close_to_lab() -> void:
	cancel_opening()
	collection_return=false
	hide()
	game.leave_campaign()
func show_collection() -> void:
	cancel_opening()
	hide()
	lab_view.show_panel("collection")
	collection_return=true
func cancel_opening() -> void:
	if last_transition: last_transition.kill()
	entering=false
	if is_instance_valid(main_door): main_door.flash=0
func restore_collection() -> void:
	if collection_return:
		collection_return=false
		show()
func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		if page=="map": open_hub(selected)
		else: close_to_lab()
		get_viewport().set_input_as_handled()
func _draw() -> void:
	draw_rect(Rect2(0,0,360,720),Color("c9e8df"))
	for y in range(0,721,48): draw_line(Vector2(0,y),Vector2(360,y),Color("b1d4ce"),1)
	for x in range(0,361,60): draw_line(Vector2(x,0),Vector2(x,720),Color("b9dcd4"),1)
	if page=="hub":
		draw_style_box(W.box(Color("ecf3dc"),14),Rect2(12,92,336,456))
		draw_rect(Rect2(0,414,360,135),Color("bfd5c6"))
		for x in range(-180,540,45): draw_line(Vector2(180,414),Vector2(x,549),Color("9ab9ad"),1)
		for y in range(438,550,27): draw_line(Vector2(0,y),Vector2(360,y),Color("9ab9ad"),1)
		for side in [0,1]:
			var x: int=17+int(side)*326
			draw_line(Vector2(x,116),Vector2(x,235),W.INK,7,true)
			draw_line(Vector2(x,116),Vector2(x,235),Color("7cafab"),3,true)
			draw_circle(Vector2(x,120),5,Color("ffdc79"))
