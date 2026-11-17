extends "res://scripts/portal_hub.gd"
const L=preload("res://scripts/landscape_layout.gd")
const PreviewLandscape=preload("res://scripts/landscape_preview.gd")
const DOOR_RECT:=Rect2(230,140,200,270)
func setup(value: Control,view: Node2D) -> void:
	super.setup(value,view)
	size=L.DESIGN
func build_hub() -> void:
	var done: Array=game.completed_world_level_ids()
	var entry: Dictionary=Worlds.world(selected)
	var unlocked: bool=Worlds.unlocked(selected,done)
	var index:=world_ids.find(selected)
	W.label(self,"ЗАЛ ПОРТАЛОВ",Rect2(20,18,600,44),26,W.INK,true)
	W.label(self,"★ %d · %d монет · %d/%d" % [game.campaign_progress.stars,game.coins,index+1,world_ids.size()],Rect2(650,32,290,40),15)
	var clip:=Control.new()
	clip.position=Vector2(20,92)
	clip.size=Vector2(600,360)
	clip.clip_contents=true
	clip.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(clip)
	for offset in [-1,0,1]:
		var id: String=world_ids[posmod(index+offset,world_ids.size())]
		var door=Board.new() if Worlds.world(id).portal_style=="notice_board" else Door.new()
		door.setup(Worlds.world(id).portal_style,Worlds.unlocked(id,done))
		door.position=Vector2(310+offset*240,180)
		if offset!=0:
			door.scale=Vector2.ONE*0.86
			door.modulate=Color("a9c8be")
		else: main_door=door
		clip.add_child(door)
	W.button(self,"PortalPrev","<",Rect2(20,242,60,60),func(): shift(-1))
	W.button(self,"PortalNext",">",Rect2(560,242,60,60),func(): shift(1))
	W.label(self,entry.name if unlocked or entry.unlock.type!="unavailable" else "НЕИЗВЕСТНЫЙ МИР",Rect2(650,102,290,60),24)
	W.label(self,entry.description if unlocked else Worlds.locked_reason(selected,done),Rect2(650,180,290,106),17)
	var progress: Dictionary=Worlds.status(selected,done)
	W.label(self,"Пройдено %d / %d" % [progress.completed,progress.total],Rect2(650,300,290,34),16)
	var instruction: String="Нажмите на стенд — карта лаборатории" if entry.portal_style=="notice_board" else "Нажмите на дверь — вход в мир"
	W.label(self,instruction,Rect2(20,468,600,50),17,W.INK,true)
	hint=W.label(self,quote,Rect2(650,348,290,70),13)
	var hint_id: String="hub_board_hint" if entry.portal_style=="notice_board" else "hub_portal_hint"
	if not game.journey_state.has_seen(hint_id):
		object_hint_left=5
		hint.text="Короткое нажатие открывает мир. Свайп — выбор соседнего."
		game.record_journey_seen(hint_id)
	W.button(self,"PortalBack","НАЗАД",Rect2(650,448,136,60),close_to_lab,Color("b5e9ee"))
	W.button(self,"PortalCollection","КОЛЛЕКЦИЯ",Rect2(800,448,140,60),show_collection,Color("ded2fb"))
func release_object(point: Vector2) -> void:
	var delta:=point-swipe_start
	if maxf(swipe_distance,delta.length())>12: swipe(swipe_travel if swipe_travel.length()>0 else delta)
	elif DOOR_RECT.has_point(swipe_start) and DOOR_RECT.has_point(point): enter_portal()
func open_map(id: String) -> bool:
	if not super.open_map(id): return false
	for child in get_children():
		if child is Label:
			L.place(child,Rect2(20,18 if child.position.y<60 else (90 if child.position.y<100 else 160),230,100 if child==hint else 60))
	L.place(map_scroll,Rect2(280,18,660,498))
	L.place(get_node("MapBack"),Rect2(20,384,230,54))
	L.place(get_node("MapCollection"),Rect2(20,454,230,54))
	# Recompute only presentation geometry, leaving routes/IDs/unlocks untouched.
	map_model.setup(id,game.completed_world_level_ids(),660)
	map_canvas.custom_minimum_size=Vector2(map_model.width(),map_model.height())
	scroll_target=clampf(scroll_target,0,maxf(0,map_model.height()-498))
	horizontal_target=clampf(horizontal_target,0,maxf(0,map_model.width()-660))
	return true
func open_preview(world_id: String,level_id: String) -> bool:
	var value: Dictionary=PreviewModel.build(world_id,level_id,game)
	if value.is_empty(): return false
	close_preview()
	preview=PreviewLandscape.new()
	preview.name="LevelPreview"
	preview.setup(self,value)
	add_child(preview)
	return true
func _draw() -> void:
	draw_rect(Rect2(0,0,960,540),Color("c9e8df"))
	if page=="hub":
		draw_style_box(W.box(Color("edf3de")),Rect2(12,84,616,374))
		draw_style_box(W.box(Color("e2eee0")),Rect2(638,14,310,512))
		if object_hint_left>0: draw_rect(DOOR_RECT.grow(6),Color("e8b345"),false,4)
