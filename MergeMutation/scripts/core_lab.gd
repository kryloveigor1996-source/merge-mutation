extends "res://scripts/landscape_lab.gd"
const ComplexCore=preload("res://scripts/core_complex.gd")
const BestiaryCore=preload("res://scripts/core_bestiary.gd")
const ResultCore=preload("res://scripts/core_result.gd")
const W=preload("res://scripts/journey_widgets.gd")
func make_complex(): return ComplexCore.new()
func make_bestiary(): return BestiaryCore.new()
func open_home() -> void:
	super.open_home()
func show_story(id: String) -> void:
	super.show_story(id)
	if is_instance_valid(story_screen): story_screen.z_index=60
func habitat_status(id: String) -> Dictionary:
	var source:=Registry.new()
	source.load_files()
	var room: Dictionary=source.get_habitat(id)
	if room.is_empty(): return {"available":false,"progress":0,"reason":"Вольер на подготовке"}
	if not game.species_known(room.get("species_id","")): return {"available":false,"progress":0,"reason":"Обитатель ещё не открыт"}
	if not game.habitat_catalogs.has(id): return {"available":false,"progress":0,"reason":"Вольер на подготовке"}
	var total: int=game.habitat_catalogs[id].slots.size()
	return {"available":true,"progress":roundi(100.0*game.progression.installed(id).size()/total),"reason":""}
func close_panel() -> void:
	if game.reward_pending and panel_kind=="result": return
	super.close_panel()
func show_panel(kind: String) -> void:
	if kind=="result":
		close_panel()
		if is_instance_valid(overlay):
			overlay.hide()
			overlay.queue_free()
		panel_kind="result"
		overlay=ResultCore.new()
		overlay.z_index=50
		overlay.setup(game)
		add_child(overlay)
		return
	if kind=="settings":
		show_audio_settings()
		return
	super.show_panel(kind)
	if kind=="species" and is_instance_valid(overlay):
		relabel(overlay)
func relabel(node: Node) -> void:
	if node is Label and node.text.begins_with("Тестовый режим:"):
		node.text="Песочница: свободные эксперименты. Открытия комплекса доступны в экспедициях."
	for child in node.get_children(): relabel(child)
func show_audio_settings() -> void:
	close_panel()
	panel_kind="settings"
	overlay=Control.new()
	overlay.size=Vector2(960,540)
	overlay.z_index=50
	add_child(overlay)
	var shade:=ColorRect.new()
	shade.size=overlay.size
	shade.color=Color(0.08,0.18,0.22,0.95)
	overlay.add_child(shade)
	W.label(overlay,"ЗВУК",Rect2(180,68,600,50),30,Color.WHITE,true)
	if is_instance_valid(game.music):
		var labels={"master":"Общая громкость","music":"Музыка","sfx":"Звуковые эффекты"}
		var row:=0
		for key in labels:
			W.label(overlay,labels[key],Rect2(190,146+row*74,300,36),20,Color.WHITE)
			var slider:=HSlider.new()
			slider.name="Volume_"+key
			slider.position=Vector2(490,146+row*74)
			slider.size=Vector2(280,44)
			slider.min_value=0
			slider.max_value=1
			slider.step=0.01
			slider.value=game.music.volumes[key]
			slider.value_changed.connect(func(value): game.music.set_volume(key,value))
			overlay.add_child(slider)
			row+=1
	W.button(overlay,"SettingsClose","ГОТОВО",Rect2(290,402,380,60),close_panel)
func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(game.music) or panel_kind=="settings": return
	var context:="sandbox"
	if game.in_campaign() or is_instance_valid(experiment_ui): context="puzzles"
	elif is_instance_valid(overlay) and panel_kind=="collection": context="bestiary"
	elif is_instance_valid(complex_ui):
		context=complex_ui.detail.model.habitat_id if is_instance_valid(complex_ui.detail) else "complex"
	elif portal_ui.visible: context="portals"
	game.music.context(context)
func handle_back() -> void:
	if is_instance_valid(story_screen):
		story_screen.get_node("StorySkip").pressed.emit()
	elif is_instance_valid(overlay):
		if panel_kind=="result":
			if not game.reward_pending: game.leave_campaign(); open_complex()
		elif panel_kind=="collection": close_panel(); open_complex()
		else: close_panel()
	elif is_instance_valid(complex_ui): complex_ui.back()
	elif portal_ui.visible:
		if is_instance_valid(portal_ui.preview): portal_ui.close_preview()
		elif portal_ui.page=="map": portal_ui.open_hub()
		else: portal_ui.close_to_lab()
	elif is_instance_valid(experiment_ui): close_navigation()
	elif game.in_campaign(): game.leave_campaign(); open_complex()
	else: game.open_portals()
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		handle_back()
		get_viewport().set_input_as_handled()
