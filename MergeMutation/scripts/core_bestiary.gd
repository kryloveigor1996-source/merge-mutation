extends "res://scripts/bestiary_screen.gd"
func setup(value: Control) -> void:
	super.setup(value)
	query.size.y=44
	filter.size.y=44
	if has_node("BestiaryTest") and not game.developer_mode(): get_node("BestiaryTest").hide()
func set_preview(value: bool) -> void:
	if game.developer_mode(): super.set_preview(value)
func show_entry(id: String) -> void:
	super.show_entry(id)
	if not is_instance_valid(content): return
	var data: Dictionary=archive.dossier(game,id,preview_mode)
	for child in content.get_children():
		if not child is ScrollContainer: continue
		var old: Node=child.get_child(0)
		child.remove_child(old)
		old.queue_free()
		var text:=RichTextLabel.new()
		text.custom_minimum_size=Vector2(385,0)
		text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		text.fit_content=true
		text.scroll_active=false
		text.bbcode_enabled=true
		text.add_theme_font_size_override("normal_font_size",16)
		text.add_theme_color_override("default_color",W.INK)
		text.add_theme_constant_override("paragraph_separation",10)
		child.add_child(text)
		if data.get("hidden",true):
			text.text="[b]Неизвестный обитатель[/b]\n\nОтправляйтесь в экспедицию, чтобы познакомиться с ним."
			continue
		var abilities: Array=[]
		var titles: Dictionary={"ram":"Таран","acid":"Кислотоустойчивость","flight":"Полёт"}
		for ability in data.abilities: abilities.append(titles.get(ability,"Свойство ещё изучается"))
		text.text="[b]Описание[/b]\n"+data.organism+"\n\n[b]Характер[/b]\n"+data.temperament+"\n\n[b]Среда обитания[/b]\n"+data.biome+"\n"+data.origin+"\n\n[b]Особенности[/b]\n"+(", ".join(abilities) if not abilities.is_empty() else "Исследование продолжается")+"\n\n"+data.habits+"\n\n[b]Заметки исследователя[/b]\n"+data.notes+"\n\n[b]Наблюдения[/b]"
		var found:=0
		for entry in game.progression.config.observations:
			if entry.species_id==id and game.progression.data.get("observations",{}).has(entry.id):
				text.text+="\n\n[b]"+entry.title+"[/b]\n"+entry.text
				found+=1
		if found==0: text.text+="\nПонаблюдайте за обитателем в его вольере."
