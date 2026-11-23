extends "res://scripts/portal_hub.gd"
const UI=preload("res://scripts/mobile_ui.gd")
const Chrome=preload("res://scripts/mobile_chrome.gd")
const Scroll=preload("res://scripts/mobile_scroll.gd")
const MobileMapCanvas=preload("res://scripts/mobile_map_canvas.gd")
const MobilePreview=preload("res://scripts/mobile_preview.gd")
var chrome
var hub_scroll: ScrollContainer
var carousel: Control
var hub_handler
var saved_hub_offset=0
func setup(value: Control,view: Node2D) -> void:
	super.setup(value,view); size=game.view.native_design(); theme=UI.theme_for(game.view.geometry)
func mount_chrome() -> void:
	chrome=Chrome.new(); chrome.setup(game,"portals"); add_child(chrome)
func hub_area() -> Rect2:
	var layout=game.view.geometry
	return Rect2(16,layout.touch+28,size.x-32,size.y-layout.touch*2-56)
func build_hub() -> void:
	size=game.view.native_design(); theme=UI.theme_for(game.view.geometry)
	var others=world_ids.filter(func(id): return id!="laboratory")
	if selected=="laboratory" and not others.is_empty(): selected=others[0]
	mount_chrome()
	hub_scroll=ScrollContainer.new(); hub_scroll.name="PortalHallScroll"; hub_scroll.position=hub_area().position; hub_scroll.size=hub_area().size; hub_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; add_child(hub_scroll)
	var column=UI.column(hub_scroll); column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	UI.label(column,"ЭКСПЕДИЦИИ",20)
	var lab=UI.button(column,"LaboratoryStand","",func(): game.open_world_map("laboratory"),game.view.geometry.touch)
	lab.custom_minimum_size.y=240
	var notice=Board.new(); notice.setup("notice_board",true); notice.position=Vector2(120,125); notice.scale=Vector2.ONE*.66; lab.add_child(notice)
	var title=UI.label(lab,"Лаборатория
Карта 10 уровней
Открыть →",23); title.position=Vector2(230,38); title.size=Vector2(maxf(180,size.x-298),170)
	if not others.is_empty():
		var entry: Dictionary=Worlds.world(selected); var unlocked=Worlds.unlocked(selected,game.completed_world_level_ids())
		UI.label(column,entry.name if unlocked or entry.unlock.type!="unavailable" else "Неизвестный мир",24)
		carousel=Control.new(); carousel.name="WorldCarousel"; carousel.custom_minimum_size=Vector2(0,310); carousel.mouse_filter=Control.MOUSE_FILTER_IGNORE; carousel.clip_contents=true; column.add_child(carousel)
		main_door=Door.new(); main_door.setup(entry.portal_style,unlocked); main_door.position=Vector2((size.x-32)*.5,155); carousel.add_child(main_door)
		var previous=UI.button(carousel,"PortalPrev","‹",func(): shift(-1),game.view.geometry.touch); previous.position=Vector2(0,110); previous.size=Vector2.ONE*game.view.geometry.touch
		var next=UI.button(carousel,"PortalNext","›",func(): shift(1),game.view.geometry.touch); next.position=Vector2(size.x-32-game.view.geometry.touch,110); next.size=Vector2.ONE*game.view.geometry.touch
		hint=UI.label(column,entry.description if unlocked else Worlds.locked_reason(selected,game.completed_world_level_ids()),20)
		UI.label(column,"Листайте двери. Короткое нажатие — вход.",18)
	UI.label(column,"ЭКСПЕРИМЕНТАЛЬНЫЕ РЕЖИМЫ",20)
	UI.button(column,"EvolutionEntry","Tactical Evolution · 10",func(): game.view.open_evolution(),game.view.geometry.touch)
	UI.button(column,"LegacyEntry","Тактические испытания · 10",func(): game.view.open_experiment(),game.view.geometry.touch)
	UI.button(column,"SandboxZone","Песочница",func(): game.view.open_sandbox(),game.view.geometry.touch)
	hub_handler=Scroll.attach(hub_scroll,func(): return visible and page=="hub" and not entering and not is_instance_valid(preview) and not is_instance_valid(game.view.overlay) and not is_instance_valid(game.view.story_screen))
	hub_handler.horizontal_control=carousel; hub_handler.horizontal_swipe=swipe
	hub_handler.tapped=func(point):
		var global=hub_scroll.get_global_transform_with_canvas()*point
		var button=hub_handler.control_at(hub_scroll,global)
		if button!=null: button.pressed.emit()
		elif is_instance_valid(carousel) and Rect2(Vector2.ZERO,carousel.size).has_point(carousel.get_global_transform_with_canvas().affine_inverse()*global): enter_portal()
	quote_for("hub")
	var hint_id="hub_portal_hint"
	if not game.journey_state.has_seen(hint_id): game.record_journey_seen(hint_id)
	call_deferred("restore_hub_offset")
func restore_hub_offset() -> void:
	if is_instance_valid(hub_scroll): hub_scroll.scroll_vertical=saved_hub_offset
func shift(direction: int) -> void:
	if entering or page!="hub": return
	var others=world_ids.filter(func(id): return id!="laboratory")
	if others.is_empty(): return
	saved_hub_offset=hub_scroll.scroll_vertical
	open_hub(others[posmod(others.find(selected)+direction,others.size())])
func clear_page() -> void:
	super.clear_page(); hub_scroll=null; carousel=null
func close_to_lab() -> void:
	hide(); game.view.open_complex()
func open_map(id: String) -> bool:
	if not super.open_map(id): return false
	size=game.view.native_design(); theme=UI.theme_for(game.view.geometry)
	for child in get_children():
		if child is Label or child is Button: child.hide()
	map_scroll.position=hub_area().position; map_scroll.size=hub_area().size
	map_model.setup(id,game.completed_world_level_ids(),map_scroll.size.x)
	var old=map_canvas; map_scroll.remove_child(old); old.queue_free()
	map_canvas=MobileMapCanvas.new(); map_canvas.name="WorldMapCanvas"; map_canvas.setup(self,map_model); map_scroll.add_child(map_canvas)
	map_canvas.custom_minimum_size=Vector2(map_model.width(),map_model.height())
	scroll_target=clampf(scroll_target,0,maxf(0,map_model.height()-map_scroll.size.y)); horizontal_target=clampf(horizontal_target,0,maxf(0,map_model.width()-map_scroll.size.x))
	mount_chrome()
	var header=chrome.get_child(0)
	var back=UI.button(header,"MobileMapBack","‹",func(): open_hub(),game.view.geometry.touch); back.size_flags_horizontal=0; header.move_child(back,0)
	chrome.caption.text=Worlds.world(selected).name
	chrome.resources.text="Карта уровней"
	return true
func open_preview(world_id: String,level_id: String) -> bool:
	var value=PreviewModel.build(world_id,level_id,game)
	if value.is_empty(): return false
	close_preview(); preview=MobilePreview.new(); preview.setup(self,value); add_child(preview); return true
func reflow() -> void:
	var data: Dictionary=preview.data.duplicate(true) if is_instance_valid(preview) else {}
	if page=="hub": open_hub(selected)
	else: open_map(selected)
	if not data.is_empty(): open_preview(data.world_id,data.level_id)
func _gui_input(event: InputEvent) -> void:
	if page=="map": return
	if event is InputEventScreenTouch and event.canceled: swiping=false
func _draw() -> void: draw_rect(Rect2(Vector2.ZERO,size),UI.BG)
