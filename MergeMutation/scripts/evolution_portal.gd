extends "res://scripts/ecosystem_portal.gd"
const ChromeAdaptive=preload("res://scripts/evolution_chrome.gd")
const PreviewAdaptive=preload("res://scripts/evolution_preview.gd")
func build_hub() -> void:
	super.build_hub()
	W.button(self,"EvolutionEntry","ТАКТИЧЕСКАЯ ЭВОЛЮЦИЯ",Rect2(650,426,290,44),func(): game.view.open_evolution(),Color("ffe39a"))
	chrome=ChromeAdaptive.replace(self,game,"portals")
	reflow_hub()
func reflow_hub() -> void:
	size=Vector2(540,960) if game.view.portrait_mode else Vector2(960,540)
	if not game.view.portrait_mode: return
	var labels: Array=[]
	for child in get_children():
		if child is Label: labels.append(child)
		elif child is Control and child.clip_contents and child!=map_scroll:
			child.position=Vector2(0,198); child.size=Vector2(540,365)
			for door in child.get_children(): door.position.x-=40
	for index in range(labels.size()):
		var child: Label=labels[index]
		var rect: Rect2={0:Rect2(20,130,500,50),1:Rect2(20,178,500,24),2:Rect2(20,564,500,54),3:Rect2(28,622,484,88),4:Rect2(28,710,484,30),5:Rect2(20,740,500,44),6:Rect2(20,744,500,40)}.get(index,Rect2(20,744,500,40))
		L.place(child,rect)
		child.add_theme_font_size_override("font_size",18)
		if child==hint or index in [0,1,5]: child.hide()
	W.label(self,"Нажмите на стенд или листайте двери",Rect2(20,130,500,44),16,W.INK,true)
	L.place(get_node("PortalPrev"),Rect2(12,352,56,64))
	L.place(get_node("PortalNext"),Rect2(472,352,56,64))
	L.place(get_node("SandboxZone"),Rect2(20,758,500,48))
	get_node("SandboxZone").text="ПЕСОЧНИЦА · СВОБОДНЫЕ ЭКСПЕРИМЕНТЫ"
	L.place(get_node("EvolutionEntry"),Rect2(20,822,500,48))
func open_map(id: String) -> bool:
	if not super.open_map(id): return false
	chrome=ChromeAdaptive.replace(self,game,"portals")
	size=Vector2(540,960) if game.view.portrait_mode else Vector2(960,540)
	if not game.view.portrait_mode: return true
	var index=0
	for child in get_children():
		if child is Label:
			L.place(child,Rect2(20,126+index*44,500,44))
			child.visible=index==0
			index+=1
	L.place(map_scroll,Rect2(20,188,500,612))
	L.place(get_node("MapBack"),Rect2(20,820,500,48))
	map_model.setup(id,game.completed_world_level_ids(),500)
	map_canvas.custom_minimum_size=Vector2(map_model.width(),map_model.height())
	scroll_target=clampf(scroll_target,0,maxf(0,map_model.height()-612))
	horizontal_target=clampf(horizontal_target,0,maxf(0,map_model.width()-500))
	return true
func open_preview(world_id: String,level_id: String) -> bool:
	var data=PreviewModel.build(world_id,level_id,game)
	if data.is_empty(): return false
	close_preview()
	preview=PreviewAdaptive.new(); preview.name="LevelPreview"
	preview.setup(self,data)
	add_child(preview)
	if is_instance_valid(chrome): chrome.hide()
	return true
func release_object(point: Vector2) -> void:
	if not game.view.portrait_mode: super.release_object(point); return
	var delta=point-swipe_start
	if maxf(swipe_distance,delta.length())>12: swipe(swipe_travel if swipe_travel.length()>0 else delta)
	elif Rect2(170,245,200,270).has_point(swipe_start) and Rect2(170,245,200,270).has_point(point): enter_portal()
func reflow() -> void:
	var had_preview: Dictionary=preview.data.duplicate(true) if is_instance_valid(preview) else {}
	if page=="hub": open_hub(selected)
	else: open_map(selected)
	if not had_preview.is_empty(): open_preview(had_preview.world_id,had_preview.level_id)
func _draw() -> void:
	if not game.view.portrait_mode: super._draw(); return
	draw_rect(Rect2(0,0,540,960),Color("c9e8df"))
	if page=="hub":
		draw_style_box(W.box(Color("edf3de")),Rect2(12,190,516,370))
		draw_style_box(W.box(Color("e2eee0")),Rect2(12,564,516,174))
		if object_hint_left>0: draw_rect(Rect2(164,239,212,282),Color("e8b345"),false,4)
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.canceled and event.index==0:
		swiping=false; swipe_distance=0; accept_event(); return
	super._gui_input(event)