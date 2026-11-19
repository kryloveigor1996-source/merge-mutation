extends Control
const W=preload("res://scripts/journey_widgets.gd")
const C=preload("res://scripts/mutant_catalog.gd")
const Art=preload("res://scripts/mutant_art.gd")
const Model=preload("res://scripts/bestiary_model.gd")
const Chrome=preload("res://scripts/app_chrome.gd")
var game: Control
var archive:=Model.new()
var selected:="slime"
var stage:=1
var query: LineEdit
var filter: OptionButton
var list: VBoxContainer
var content: Control
var preview_mode:=false
func setup(value: Control) -> void:
	game=value
	size=Vector2(960,540)
	mouse_filter=Control.MOUSE_FILTER_STOP
	mouse_force_pass_scroll_events=false
	archive.load_file()
	selected=game.view.collection_species
	query=LineEdit.new()
	query.name="BestiarySearch"
	query.add_theme_stylebox_override("normal",W.box(Color("e8f2df"),7))
	query.add_theme_color_override("font_color",W.INK)
	query.add_theme_color_override("font_placeholder_color",Color("5e7572"))
	query.placeholder_text="Поиск по названию"
	query.position=Vector2(20,78)
	query.size=Vector2(226,42)
	add_child(query)
	query.text_changed.connect(func(_text): refresh_list())
	filter=OptionButton.new()
	filter.name="BestiaryFilter"
	filter.add_theme_stylebox_override("normal",W.box(Color("c6e3d3"),7))
	filter.add_theme_color_override("font_color",W.INK)
	for title in ["Все виды","Открытые","Неизвестные"]: filter.add_item(title)
	filter.position=Vector2(20,126)
	filter.size=Vector2(226,40)
	filter.item_selected.connect(func(_index): refresh_list())
	add_child(filter)
	var scroll:=ScrollContainer.new()
	scroll.position=Vector2(20,176)
	scroll.size=Vector2(232,290)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	list=VBoxContainer.new()
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var chrome:=Chrome.new()
	chrome.setup(game,"bestiary")
	add_child(chrome)
	if OS.is_debug_build():
		W.button(self,"BestiaryTest","ТЕСТ ДОСЬЕ",Rect2(280,78,200,36),func(): set_preview(not preview_mode),Color("d5e1d4"))
	refresh_list()
	show_entry(selected)
func set_preview(value: bool) -> void:
	preview_mode=value
	show_entry(selected)
func refresh_list() -> void:
	for child in list.get_children(): list.remove_child(child); child.queue_free()
	var ids: Array=archive.filtered(game,query.text,filter.selected)
	for id in ids:
		var row:=Button.new()
		row.name="Species_"+id
		row.text=C.species(id).name if Model.known(game,id) else "??? · неизвестный вид"
		row.custom_minimum_size=Vector2(215,44)
		for style in ["normal","hover","focus","pressed"]:
			row.add_theme_stylebox_override(style,W.box(Color("ffdf91") if id==selected else Color("d4e8dd"),7))
		for style in ["font_color","font_hover_color","font_focus_color","font_pressed_color"]: row.add_theme_color_override(style,W.INK)
		row.pressed.connect(func(): stage=1; show_entry(id))
		list.add_child(row)
	if ids.is_empty():
		var label:=Label.new()
		label.text="Ничего не найдено"
		list.add_child(label)
func show_entry(id: String) -> void:
	selected=id
	game.view.collection_species=id
	refresh_list()
	if is_instance_valid(content): remove_child(content); content.queue_free()
	content=Control.new()
	content.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(content)
	var data: Dictionary=archive.dossier(game,id,preview_mode)
	if data.is_empty():
		W.label(content,archive.error,Rect2(290,140,600,120),20)
		return
	W.label(content,("ТЕСТ · НЕ ОТКРЫВАЕТ КОЛЛЕКЦИЮ" if preview_mode else "ИССЛЕДОВАТЕЛЬСКИЙ АРХИВ"),Rect2(280,120,230,54),13)
	W.label(content,data.name,Rect2(280,178,230,56),24,W.INK,true)
	W.label(content,"Образец "+data.specimen,Rect2(280,234,230,34),15,W.INK,true)
	var art:=Art.new()
	var visible_form: bool=preview_mode or game.is_unlocked(id,stage)
	art.setup_form(C.make(id,stage),true)
	art.position=Vector2(395,330)
	art.scale=Vector2.ONE*2
	if not visible_form: art.modulate=Color(0.05,0.08,0.09)
	content.add_child(art)
	for form_stage in range(1,C.maximum(id)+1):
		var known_form: bool=game.is_unlocked(id,form_stage)
		W.button(content,"Form_"+str(form_stage),C.stage_label(form_stage) if known_form or preview_mode else "?",Rect2(277+(form_stage-1)*48,414,44,44),func(): stage=form_stage; show_entry(id),Color("ffde89") if stage==form_stage else Color("c8ded7"))
	var scroll:=ScrollContainer.new()
	scroll.position=Vector2(534,80)
	scroll.size=Vector2(408,330)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var text:=Label.new()
	text.custom_minimum_size.x=385
	text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size",16)
	text.add_theme_color_override("font_color",W.INK)
	scroll.add_child(text)
	var visit:=W.button(content,"VisitHabitat","Посетить вольер",Rect2(534,420,400,44),visit_habitat)
	if data.hidden:
		text.text="Образец ещё не открыт.\n\nИмя, происхождение, способности и наблюдения скрыты. Демонстрационный вольер не открывает вид в коллекции."
		visit.text="Сведения о вольере скрыты"
		visit.disabled=true
		return
	var ability_names: Dictionary={"ram":"Таран (тактические правила)","acid":"Кислотоустойчивость (тактические правила)","flight":"Полёт (тактические правила)"}
	var abilities: Array=[]
	for ability in data.abilities: abilities.append(ability_names.get(ability,ability))
	text.text="Классификация: "+data.classification+"\nПроисхождение: "+data.origin+"\nБиом: "+data.biome+"\nХарактер: "+data.temperament+"\n\nОрганизм: "+data.organism+"\nПривычки: "+data.habits+"\n\nИзвестные способности: "+(", ".join(abilities) if not abilities.is_empty() else "Для открытых форм не зарегистрированы")+"\n\n"+data.concept_status+"\n\nЗаметки:\n"+data.notes
	for record in archive.records(id):
		text.text+="\n\nДЕМО-НАБЛЮДЕНИЕ · "+record.text+"\n"+record.unlock_hint
	var status: Dictionary=game.view.habitat_status(data.habitat_id)
	visit.disabled=not status.available
	visit.text=("Посетить вольер · %d%%" % status.progress) if status.available else status.reason
func visit_habitat() -> void:
	var data: Dictionary=archive.dossier(game,selected,preview_mode)
	if not data.get("hidden",true): game.view.visit_from_bestiary(data.habitat_id)
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var viewport:=get_viewport()
		game.view.close_panel()
		game.view.open_complex()
		viewport.set_input_as_handled()
func _draw() -> void:
	draw_rect(Rect2(0,0,960,540),Color("cce4db"))
	for rect in [Rect2(12,72,246,398),Rect2(268,72,250,398),Rect2(526,72,422,398)]:
		draw_style_box(W.box(Color("fff3d6")),rect)
