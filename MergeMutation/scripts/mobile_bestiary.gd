extends "res://scripts/bestiary_screen.gd"
const UI=preload("res://scripts/mobile_ui.gd")
const Scroll=preload("res://scripts/mobile_scroll.gd")
const ArtCard=preload("res://scripts/mobile_art_card.gd")
var showing_dossier=false
var search_text=""
var filter_index=0
var grid: GridContainer
var card_scroll: ScrollContainer
var shell: Dictionary
var cards: Dictionary={}
func setup(value: Control) -> void:
	game=value; archive.load_file(); selected=game.view.collection_species
	mouse_filter=Control.MOUSE_FILTER_STOP; reflow()
func footer(row: HBoxContainer) -> void:
	for key in ["complex","portals","bestiary"]:
		UI.button(row,"Nav_"+key,{"complex":"Комплекс","portals":"Порталы","bestiary":"Бестиарий"}[key],func():
			if key=="complex": game.view.close_panel(); game.view.open_complex()
			elif key=="portals": game.view.close_panel(); game.open_portals()
			else: showing_dossier=false; reflow()
		,game.view.geometry.touch)
func reflow() -> void:
	UI.clear(self); cards.clear(); size=game.view.native_design(); theme=UI.theme_for(game.view.geometry)
	if showing_dossier: build_dossier()
	else: build_collection()
func build_collection() -> void:
	shell=UI.shell(self,game.view.geometry,"Бестиарий",back,func(): game.view.show_panel("settings"),true); footer(shell.dock)
	var stack=UI.column(shell.body); UI.fill(stack)
	var controls=UI.row(stack)
	query=LineEdit.new(); query.name="BestiarySearch"; query.placeholder_text="Поиск"; query.text=search_text; query.custom_minimum_size.y=game.view.geometry.touch; query.size_flags_horizontal=Control.SIZE_EXPAND_FILL; controls.add_child(query)
	query.text_changed.connect(func(text): search_text=text; refresh_list())
	filter=OptionButton.new(); filter.name="BestiaryFilter"; filter.custom_minimum_size=Vector2(160,game.view.geometry.touch)
	for text in ["Все","Открытые","Неизвестные"]: filter.add_item(text)
	filter.select(filter_index); filter.item_selected.connect(func(index): filter_index=index; refresh_list()); controls.add_child(filter)
	card_scroll=ScrollContainer.new(); card_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; card_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; stack.add_child(card_scroll)
	grid=GridContainer.new(); grid.columns=2 if game.view.geometry.portrait else 3; grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL; grid.add_theme_constant_override("h_separation",12); grid.add_theme_constant_override("v_separation",12); card_scroll.add_child(grid)
	Scroll.attach(card_scroll,func(): return game.view.overlay==self)
	refresh_list()
func refresh_list() -> void:
	if not is_instance_valid(grid): return
	UI.clear(grid); cards.clear()
	for id in archive.filtered(game,search_text,filter_index):
		var known=Model.known(game,id)
		var card=UI.button(grid,"Species_"+id,"",func(): stage=1; show_entry(id),game.view.geometry.touch)
		card.custom_minimum_size=Vector2(0,300); card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var margin=MarginContainer.new(); UI.fill(margin); margin.mouse_filter=Control.MOUSE_FILTER_IGNORE
		for key in ["margin_left","margin_right","margin_top","margin_bottom"]: margin.add_theme_constant_override(key,16)
		card.add_child(margin); var column=UI.column(margin); column.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var art=ArtCard.new(); art.setup(C.make(id),known,156); column.add_child(art)
		UI.label(column,C.species(id).name if known else "Неизвестный вид",23)
		var count=0
		for s in range(1,6):
			if game.is_unlocked(id,s): count+=1
		UI.label(column,"%d / 5 стадий" % count if known else "Сведения скрыты",18)
		cards[id]=card
	if cards.is_empty(): UI.label(grid,"Ничего не найдено")
func show_entry(id: String) -> void:
	selected=id; game.view.collection_species=id; showing_dossier=true; reflow()
func build_dossier() -> void:
	var data: Dictionary=archive.dossier(game,selected,false)
	shell=UI.shell(self,game.view.geometry,data.get("name","Архив"),back,func(): game.view.show_panel("settings"),true); footer(shell.dock)
	card_scroll=ScrollContainer.new(); UI.fill(card_scroll); card_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; shell.body.add_child(card_scroll)
	var column=UI.column(card_scroll); column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var art=ArtCard.new(); art.setup(C.make(selected,stage),game.is_unlocked(selected,stage),210); column.add_child(art)
	var row=GridContainer.new(); row.columns=mini(5,maxi(1,int((size.x-40)/(game.view.geometry.touch+12)))); column.add_child(row)
	for s in range(1,6):
		var n=s
		UI.button(row,"Form_"+str(s),C.stage_label(s) if game.is_unlocked(selected,s) else "?",func(): stage=n; reflow(),game.view.geometry.touch)
	if data.get("hidden",true): UI.label(column,"Обитатель ещё не открыт. Имя, способности и наблюдения скрыты.")
	else:
		UI.label(column,data.classification,24)
		for pair in [["Описание",data.organism],["Характер",data.temperament],["Среда обитания",data.biome+"
"+data.origin],["Привычки",data.habits]]:
			UI.label(column,pair[0],25); UI.label(column,pair[1])
		UI.label(column,"Способности",25)
		var abilities: PackedStringArray=[]
		for ability in data.abilities: abilities.append({"ram":"Таран","acid":"Кислотоустойчивость","flight":"Полёт"}.get(ability,"Исследование продолжается"))
		if selected=="eyeball": abilities.append("Обнаружение скрытых механизмов (Tactical Evolution)")
		UI.label(column,", ".join(abilities) if not abilities.is_empty() else "Для известных форм пока не зарегистрированы")
		UI.label(column,"Научные наблюдения",25)
		var count=0
		for entry in game.progression.config.observations:
			if entry.species_id==selected and game.progression.data.get("observations",{}).has(entry.id): UI.label(column,entry.title+"
"+entry.text); count+=1
		if count==0: UI.label(column,"Понаблюдайте за обитателем в его вольере.")
		UI.label(column,"Записки учёного",25); UI.label(column,data.notes)
		var status: Dictionary=game.view.habitat_status(data.habitat_id)
		var visit=UI.button(column,"VisitHabitat","В вольер · %d%%" % status.progress if status.available else status.reason,visit_habitat,game.view.geometry.touch); visit.disabled=not status.available
	Scroll.attach(card_scroll,func(): return game.view.overlay==self)
func back() -> void:
	if showing_dossier: showing_dossier=false; reflow()
	else: game.view.close_panel(); game.view.open_complex()
func _draw() -> void: draw_rect(Rect2(Vector2.ZERO,size),UI.BG)
