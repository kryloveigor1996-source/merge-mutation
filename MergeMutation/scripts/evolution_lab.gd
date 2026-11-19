extends "res://scripts/core_lab.gd"
const G=preload("res://scripts/evolution_geometry.gd")
const Preferences=preload("res://scripts/evolution_preferences.gd")
const Tutorial=preload("res://scripts/contextual_tutorial.gd")
const ChromeAdaptive=preload("res://scripts/evolution_chrome.gd")
const ComplexAdaptive=preload("res://scripts/evolution_complex.gd")
const BestiaryAdaptive=preload("res://scripts/evolution_bestiary.gd")
const PortalAdaptive=preload("res://scripts/evolution_portal.gd")
const ResultAdaptive=preload("res://scripts/evolution_result.gd")
const StoryAdaptive=preload("res://scripts/evolution_story.gd")
const OldExperiment=preload("res://scripts/evolution_legacy_experiment.gd")
const Evolution=preload("res://scripts/evolution_screen.gd")
const Movement=preload("res://scripts/evolution_movement.gd")
var portrait_mode=false
var app_suspended=false
const Marks=preload("res://scripts/puzzle_marks.gd")
var target_key=""
var tap_targets: Dictionary={}
var preferences=Preferences.new()
var tutorial
func native_design() -> Vector2: return G.design(portrait_mode)
func make_complex(): return ComplexAdaptive.new()
func make_bestiary(): return BestiaryAdaptive.new()
func make_portal(): return PortalAdaptive.new()
func make_experiment(): return OldExperiment.new()
func make_story():
	var story=StoryAdaptive.new()
	story.owner_view=self
	return story
func _ready() -> void:
	preferences.setup(game.audio_settings_path)
	portrait_mode=preferences.portrait
	super._ready()
	if is_instance_valid(app_chrome): remove_child(app_chrome); app_chrome.queue_free()
	app_chrome=ChromeAdaptive.replace(self,game,"lab")
	tutorial=Tutorial.new()
	tutorial.setup(self,preferences)
	add_child(tutorial)
	apply_orientation(false)
func layout() -> void:
	if not is_instance_valid(game): return
	var available=Rect2(Vector2.ZERO,game.size if game.size.x>0 else native_design())
	if OS.has_feature("android"):
		var physical=Vector2(DisplayServer.window_get_size())
		if physical.x>0 and physical.y>0:
			var safe=DisplayServer.get_display_safe_area()
			var usable=Rect2(Vector2(safe.position)*available.size/physical,Vector2(safe.size)*available.size/physical).intersection(available)
			if usable.size.x>0 and usable.size.y>0: available=usable
	var fit=G.fit(available,portrait_mode)
	position=fit.position; scale=Vector2.ONE*fit.size.x/native_design().x
func apply_orientation(resize_window: bool=true) -> void:
	get_window().content_scale_size=Vector2i(native_design())
	if OS.has_feature("android"): DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT if portrait_mode else DisplayServer.SCREEN_LANDSCAPE)
	elif resize_window and DisplayServer.get_name()!="headless" and not game.save_path.begins_with("res://.godot/"): get_window().size=Vector2i(native_design())
	layout()
func set_portrait(value: bool) -> void:
	if portrait_mode==value: return
	portrait_mode=value
	preferences.portrait=value
	if not preferences.save(): game._notice(preferences.error)
	game.cancel_control()
	tutorial.dismiss(); tutorial.requests.clear()
	apply_orientation()
	rebuild()
	app_chrome.reflow()
	if is_instance_valid(complex_ui): complex_ui.chrome.reflow(); complex_ui.reflow()
	if portal_ui.visible: portal_ui.reflow()
	if is_instance_valid(experiment_ui): experiment_ui.reflow()
	if is_instance_valid(story_screen): story_screen.refresh()
	if is_instance_valid(overlay):
		if panel_kind=="settings": show_audio_settings()
		elif panel_kind=="collection": show_panel("collection")
		elif panel_kind=="result": show_panel("result")
		else: adapt_panel()
	arrange()
func open_evolution() -> void:
	game.leave_campaign()
	close_panel(); close_navigation()
	experiment_ui=Evolution.new()
	experiment_ui.setup(game)
	add_child(experiment_ui)
func input_blocked() -> bool:
	return is_instance_valid(overlay) or is_instance_valid(complex_ui) or portal_ui.visible or is_instance_valid(experiment_ui) or is_instance_valid(story_screen)
func cell_index(point: Vector2) -> int: return G.cell_at(point,portrait_mode)
func cell_center(index: int) -> Vector2: return G.center(index,portrait_mode)
func clamp_art(point: Vector2,bounds: Rect2) -> Vector2:
	var board=G.board(portrait_mode)
	return Vector2(clampf(point.x,board.position.x-bounds.position.x,board.end.x-bounds.end.x),clampf(point.y,board.position.y-bounds.position.y,board.end.y-bounds.end.y))
func arrange() -> void:
	super.arrange()
	if game.in_campaign(): nav_right.text="НАСТРОЙКИ"
	species_button.visible=not portrait_mode or not game.in_campaign()
	experiment_button.visible=not game.in_campaign()
	if not is_instance_valid(create_button) or not portrait_mode: return
	Layout.place(create_button,Rect2(20,828,330,54))
	Layout.place(teleport_button,Rect2(364,828,156,54))
	Layout.place(species_button,Rect2(20,158,500,40))
	species_button.add_theme_font_size_override("font_size",16)
	Layout.place(experiment_button,Rect2(20,828,242,54))
	if not game.in_campaign():
		Layout.place(create_button,Rect2(278,828,242,54))
		if is_instance_valid(app_chrome) and app_chrome.has_method("reflow"): app_chrome.reflow()
	else:
		for id in ["КОЛЛЕКЦИЯ","ПОРТАЛЫ","НАСТРОЙКИ"]:
			if landscape_buttons.has(id): landscape_buttons[id].hide()
		Layout.place(nav_left,Rect2(20,896,155,48)); nav_left.show()
		Layout.place(nav_right,Rect2(364,896,156,48)); nav_right.text="НАСТРОЙКИ"; nav_right.show()
		Layout.place(landscape_buttons["ПОРТАЛЫ"],Rect2(192,896,155,48)); landscape_buttons["ПОРТАЛЫ"].show()
func right_nav() -> void:
	show_panel("settings")
func show_panel(kind: String) -> void:
	if kind=="result":
		close_panel()
		if is_instance_valid(overlay): remove_child(overlay); overlay.queue_free()
		panel_kind="result"
		overlay=ResultAdaptive.new(); overlay.z_index=50; overlay.setup(game); add_child(overlay)
		return
	super.show_panel(kind)
	if kind not in ["settings","collection"]: adapt_panel()
func adapt_panel() -> void:
	if not is_instance_valid(overlay): return
	overlay.size=native_design()
	overlay.mouse_filter=Control.MOUSE_FILTER_STOP
	if overlay.get_child_count()==0: return
	var shade=overlay.get_child(0)
	if shade is ColorRect: shade.size=native_design(); shade.color=Color("19333c"); shade.mouse_filter=Control.MOUSE_FILTER_STOP
	if portrait_mode and overlay.get_child_count()>1 and overlay.get_child(1) is PanelContainer:
		overlay.get_child(1).position=Vector2(12,140); overlay.get_child(1).size=Vector2(516,700)
func show_audio_settings() -> void:
	game.cancel_control()
	var rebuilding=panel_kind=="settings"
	var destination=settings_return
	if rebuilding: settings_return=""
	close_panel()
	if rebuilding: settings_return=destination
	panel_kind="settings"
	overlay=Control.new(); overlay.name="AudioSettings"; overlay.size=native_design(); overlay.z_index=70
	overlay.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var shade=ColorRect.new()
	shade.name="OpaqueSettingsBackground"; shade.size=native_design(); shade.color=Color("17313b"); shade.mouse_filter=Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)
	var panel=Panel.new()
	panel.position=Vector2(12,96) if portrait_mode else Vector2(140,20)
	panel.size=Vector2(516,804) if portrait_mode else Vector2(680,500)
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel",W.box(Color("e3efe3"),18))
	overlay.add_child(panel)
	W.label(overlay,"НАСТРОЙКИ",Rect2(24,116,492,54) if portrait_mode else Rect2(180,32,600,44),28,W.INK,true)
	var titles={"master":"Общая громкость","music":"Музыка","sfx":"Звуковые эффекты"}
	var row=0
	if is_instance_valid(game.music):
		for key in titles:
			W.label(overlay,titles[key],Rect2(30,196+row*116,480,38) if portrait_mode else Rect2(180,92+row*64,310,44),20)
			var slider=HSlider.new()
			slider.name="Volume_"+key
			slider.position=Vector2(30,238+row*116) if portrait_mode else Vector2(494,92+row*64)
			slider.size=Vector2(480,48) if portrait_mode else Vector2(280,44)
			slider.min_value=0; slider.max_value=1; slider.step=0.01; slider.value=game.music.volumes[key]
			slider.value_changed.connect(func(value): game.music.set_volume(key,value))
			overlay.add_child(slider); row+=1
	W.button(overlay,"OrientationToggle","ВЕРТИКАЛЬНО  ⇄  ГОРИЗОНТАЛЬНО",Rect2(24,582,492,56) if portrait_mode else Rect2(180,306,600,48),func(): set_portrait(not portrait_mode),Color("bfe3dc"))
	W.button(overlay,"TutorialToggle","ПОДСКАЗКИ: "+("ВКЛ" if preferences.hints else "ВЫКЛ"),Rect2(24,658,492,56) if portrait_mode else Rect2(180,368,600,48),func(): preferences.hints=not preferences.hints; preferences.save(); show_audio_settings(),Color("bfe3dc"))
	W.button(overlay,"SettingsClose","ГОТОВО",Rect2(24,816,492,60) if portrait_mode else Rect2(290,450,380,54),close_panel)
func handle_back() -> void:
	if not is_instance_valid(overlay) and is_instance_valid(experiment_ui) and experiment_ui is Evolution: experiment_ui.back(); return
	super.handle_back()
func _draw() -> void:
	if not portrait_mode: super._draw(); draw_tap_targets(); return
	draw_rect(Rect2(0,0,540,960),Color("d1f0ee"))
	plate(Rect2(12,10,516,108),Color("4c9fba"))
	label("УРОВЕНЬ %d · %s" % [game.campaign.config.number,game.campaign.config.name] if game.in_campaign() else "ЛАБОРАТОРИЯ",Vector2(270,50),22,CREAM,true)
	label("Ходы: %s · Создания: %d" % [str(game.campaign.moves_left()),game.campaign.creations_left()] if game.in_campaign() else "Монеты: %d · Биокапсулы: %d" % [game.coins,game.progression.balance()],Vector2(270,92),17,CREAM,true)
	if game.message_time>0: draw_text_block(game.message,Rect2(20,122,500,70),16)
	elif game.in_campaign(): draw_text_block(game.campaign.goals.text(game.campaign.config.goals),Rect2(20,122,500,70),16)
	plate(G.board(true).grow(8),Color("4d91a4"))
	for index in range(30):
		if game.in_campaign() and game.campaign.blocked(index): continue
		plate(Rect2(cell_center(index)-Vector2.ONE*46,Vector2.ONE*92),Color("c5e3db"),10)
	draw_tap_targets()
func _process(delta: float) -> void:
	_process_puzzle_guard()
	super._process(delta)
	if is_instance_valid(complex_ui) and is_instance_valid(complex_ui.detail): complex_ui.detail.set_active(not app_suspended and not is_instance_valid(overlay) and complex_ui.modal==null)
func sync_puzzle_art() -> void:
	for tween: Tween in motion.values(): tween.kill()
	motion.clear(); drag_index=-1
	for index in creatures:
		var actor=creatures[index]
		actor.position=rest_position(index,actor)
		actor.z_index=0
	queue_redraw()
func _process_puzzle_guard() -> void:
	# The inherited view follows drag_index, so a tap selection must never set it.
	if game.in_campaign(): drag_index=-1
func draw_tap_targets() -> void:
	if game.tap_source<0 or input_blocked() or not game.in_campaign(): return
	var key=game.campaign.signature()+str(game.tap_source)+str(game.teleport_mode)
	if key!=target_key:
		target_key=key; tap_targets.clear()
		for index in range(30):
			if index==game.tap_source: continue
			var result=Movement.apply(game.campaign,game.tap_source,index,false)
			if game.teleport_mode:
				var trial=game.campaign.fork()
				result=trial.use_booster("teleporter",game.tap_source,index)
			if not result.ok: continue
			tap_targets[index]={"cost":int(result.get("cost",1)),"kind":Marks.category("move",game.teleport_mode) if game.teleport_mode else Marks.category("merge" if game.cells[index]!=null else "move")}
	var radius=44 if portrait_mode else 28
	Marks.selected(self,cell_center(game.tap_source),radius)
	for index in tap_targets:
		Marks.target(self,cell_center(index),radius,tap_targets[index].kind,tap_targets[index].cost)
func hint_scope() -> String:
	if is_instance_valid(experiment_ui): return ("evolution_" if experiment_ui is Evolution else "legacy_")+str(experiment_ui.number)
	if is_instance_valid(complex_ui): return "habitat_"+complex_ui.detail.model.habitat_id if is_instance_valid(complex_ui.detail) else "complex"
	if game.in_campaign(): return "campaign"
	if portal_ui.visible: return "portals"
	return "sandbox"