extends "res://scripts/evolution_lab.gd"
const UI=preload("res://scripts/mobile_ui.gd")
const Geometry=preload("res://scripts/mobile_layout.gd")
const MobilePreferences=preload("res://scripts/mobile_preferences.gd")
const MobileChrome=preload("res://scripts/mobile_chrome.gd")
const PuzzleChrome=preload("res://scripts/mobile_puzzle_chrome.gd")
const MobileEvolution=preload("res://scripts/mobile_evolution.gd")
const MobileLegacy=preload("res://scripts/mobile_legacy.gd")
const MobileResult=preload("res://scripts/mobile_result.gd")
const MobileStory=preload("res://scripts/mobile_story.gd")
const MobileArt=preload("res://scripts/mobile_mutant_art.gd")
const MobileTutorial=preload("res://scripts/mobile_tutorial.gd")
const TouchScroll=preload("res://scripts/mobile_scroll.gd")
var size=Vector2(540,960)
var geometry=Geometry.new()
var mounted=false
var pending_layout=false
var puzzle_chrome
var test_safe=Rect2()
var test_density=0.0
var test_font_scale=0.0
var suspended_archive: Control
var rebuilding_settings=false
var sandbox_notice: Label
var notice_seconds=0.0
func _init() -> void: preferences=MobilePreferences.new()
func native_design() -> Vector2: return geometry.extent
func make_portal(): return load("res://scripts/mobile_portal.gd").new()
func make_bestiary(): return load("res://scripts/mobile_bestiary.gd").new()
func make_complex(): return load("res://scripts/mobile_complex.gd").new()
func make_experiment(): return MobileLegacy.new()
func make_story():
	var story=MobileStory.new(); story.owner_view=self; return story
func _ready() -> void:
	super._ready()
	remove_child(app_chrome); app_chrome.queue_free(); app_chrome=MobileChrome.new(); app_chrome.setup(game,"lab"); add_child(app_chrome)
	remove_child(tutorial); tutorial.queue_free(); tutorial=MobileTutorial.new(); tutorial.setup(self,preferences); add_child(tutorial)
	RenderingServer.set_default_clear_color(UI.BG)
	for button in [create_button,species_button]:
		for key in ["normal","hover","pressed","focus","disabled"]: button.remove_theme_stylebox_override(key)
		for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: button.remove_theme_color_override(key)
		button.theme=UI.theme_for(geometry)
	sandbox_notice=UI.label(self,"",18); sandbox_notice.hide()
	mounted=true; layout(); reflow_active()
func layout() -> void:
	if not is_instance_valid(game): return
	var canvas=Rect2(Vector2.ZERO,game.size if game.size.x>0 else Vector2(540,960))
	if portrait_mode and canvas.size.x>canvas.size.y or not portrait_mode and canvas.size.x<canvas.size.y: return
	var physical=Vector2(DisplayServer.window_get_size())
	var insets=Rect2(Vector2.ZERO,physical)
	var metrics=Geometry.android_density()
	if OS.has_feature("android"): insets=Rect2(DisplayServer.get_display_safe_area())
	if test_safe.size.x>0: insets=test_safe; physical=canvas.size
	var density_value=float(metrics.density) if OS.has_feature("android") else maxf(1,physical.x/(360 if portrait_mode else 640))
	if test_density>0: density_value=test_density
	geometry.text_scale=clampf(test_font_scale if test_font_scale>0 else float(metrics.font_scale),1,1.7); geometry.density_source=metrics.source
	var changed=geometry.configure(canvas,physical,insets,density_value,portrait_mode)
	position=geometry.safe.position; scale=Vector2.ONE*geometry.factor; size=geometry.extent
	if mounted and changed and not pending_layout: pending_layout=true; call_deferred("reflow_active")
func reflow_active() -> void:
	pending_layout=false
	if not mounted: return
	game.cancel_control(); rebuild(); app_chrome.reflow()
	for button in [create_button,species_button]: button.theme=UI.theme_for(geometry)
	if is_instance_valid(complex_ui): complex_ui.reflow()
	if portal_ui.visible: portal_ui.reflow()
	if is_instance_valid(experiment_ui): experiment_ui.reflow()
	if is_instance_valid(story_screen): story_screen.refresh()
	if is_instance_valid(overlay):
		if panel_kind=="settings": show_audio_settings()
		elif panel_kind=="collection" and overlay.has_method("reflow"): overlay.reflow()
		elif panel_kind=="result": show_panel("result")
	arrange(); queue_redraw()
func apply_orientation(resize_window: bool=true) -> void:
	get_window().content_scale_size=Vector2i(540,960) if portrait_mode else Vector2i(960,540)
	if OS.has_feature("android"): DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT if portrait_mode else DisplayServer.SCREEN_LANDSCAPE)
	elif resize_window and DisplayServer.get_name()!="headless" and not game.save_path.begins_with("res://.godot/"): get_window().size=get_window().content_scale_size
	layout()
func set_portrait(value: bool) -> void:
	if portrait_mode==value: return
	portrait_mode=value; preferences.portrait=value
	if not preferences.save(): game._notice(preferences.error)
	game.cancel_control(); tutorial.dismiss(); tutorial.requests.clear(); apply_orientation(); reflow_active()
func cell_index(point: Vector2) -> int: return geometry.cell_at(point,not game.in_campaign())
func cell_center(index: int) -> Vector2: return geometry.center(index,not game.in_campaign())
func clamp_art(point: Vector2,bounds: Rect2) -> Vector2:
	var board=geometry.board(not game.in_campaign())
	return Vector2(clampf(point.x,board.position.x-bounds.position.x,board.end.x-bounds.end.x),clampf(point.y,board.position.y-bounds.position.y,board.end.y-bounds.end.y))
func arrange() -> void:
	if not is_instance_valid(create_button): return
	for control in landscape_buttons.values(): control.hide()
	for control in [nav_left,nav_right,species_button,experiment_button,create_button,teleport_button]: control.hide()
	if not mounted: return
	if game.in_campaign():
		if not is_instance_valid(puzzle_chrome):
			puzzle_chrome=PuzzleChrome.new(); add_child(puzzle_chrome)
			var actions={"back":func(): game.leave_campaign(); open_complex(),"restart":func(): game.start_level(int(game.campaign.config.number),false)}
			if game.campaign.config.creation_limit>0: actions.spawn=game._create_requested
			if game.campaign.boosters.remaining("teleporter")>0: actions.teleport=game.toggle_teleporter
			puzzle_chrome.setup(self,"%02d · %s" % [game.campaign.config.number,game.campaign.config.name],func(): return game.campaign.goals.text(game.campaign.config.goals),actions)
		puzzle_chrome.update("Ходы %s · Создания %d" % [str(game.campaign.moves_left()),game.campaign.creations_left()],game.message if game.message_time>0 else "Нажмите на мутанта, затем на цель",{"spawn":{"disabled":game.control_busy or game.campaign.status!="active" or game.campaign.creations_left()==0},"teleport":{"disabled":game.control_busy or game.campaign.boosters.remaining("teleporter")==0}})
	else:
		if is_instance_valid(puzzle_chrome): remove_child(puzzle_chrome); puzzle_chrome.queue_free(); puzzle_chrome=null
		if not input_blocked():
			create_button.show(); create_button.position=Vector2(20,size.y-geometry.touch*2-42); create_button.size=Vector2(size.x-40,geometry.touch); create_button.custom_minimum_size=Vector2.ZERO
			create_button.text="Создать · 10 монет"
			if not geometry.portrait: create_button.position=Vector2(size.x-216,geometry.touch+28); create_button.size=Vector2(200,geometry.touch)
			species_button.show(); species_button.position=Vector2(20,geometry.touch+28) if geometry.portrait else Vector2(16,geometry.touch+28)
			species_button.size=Vector2(size.x-40,geometry.touch) if geometry.portrait else Vector2(geometry.board(true).position.x-32,geometry.touch); species_button.custom_minimum_size=Vector2.ZERO
	app_chrome.visible=not game.in_campaign() and not input_blocked()
func add_creature(index: int) -> Art:
	var actor=MobileArt.new(); actor.presentation_factor=geometry.board(not game.in_campaign()).size.x/500*1.15
	actor.setup_form(game.cells[index]); actor.scale=Vector2.ONE*actor.presentation_factor; actor.position=rest_position(index,actor); add_child(actor); creatures[index]=actor; return actor
func rebuild() -> void:
	if is_instance_valid(puzzle_chrome): remove_child(puzzle_chrome); puzzle_chrome.queue_free(); puzzle_chrome=null
	super.rebuild()
func open_evolution() -> void:
	game.leave_campaign(); close_panel(); close_navigation()
	experiment_ui=MobileEvolution.new(); experiment_ui.setup(game); add_child(experiment_ui)
func show_panel(kind: String) -> void:
	if kind=="species":
		close_panel(); panel_kind="species"
		var host=Control.new(); host.size=native_design(); host.z_index=70; host.theme=UI.theme_for(geometry); add_child(host); overlay=host
		var card=UI.modal(host,geometry,"Вид для песочницы")
		UI.label(card.content,"Свободные эксперименты · создание 10 монет")
		for id in Catalog.ids():
			var key=id
			var button=UI.button(card.content,"SandboxSpecies_"+id,Catalog.species(id).name,func():
				if game.select_species(key): close_panel()
			,geometry.touch)
			button.disabled=not Catalog.available(id)
		UI.button(card.footer,"SpeciesClose","Закрыть",close_panel,geometry.touch)
		TouchScroll.attach(card.scroll,func(): return overlay==host); return
	if kind=="result":
		close_panel()
		if is_instance_valid(overlay): remove_child(overlay); overlay.queue_free()
		panel_kind="result"; overlay=MobileResult.new(); overlay.z_index=50; overlay.setup(game); add_child(overlay); return
	super.show_panel(kind)
func show_audio_settings() -> void:
	game.cancel_control()
	if panel_kind=="collection" and is_instance_valid(overlay):
		suspended_archive=overlay; remove_child(overlay); overlay=null; panel_kind=""
	var rebuilding=panel_kind=="settings"; var destination=settings_return
	if rebuilding: settings_return=""
	rebuilding_settings=rebuilding
	close_panel()
	rebuilding_settings=false
	if rebuilding: settings_return=destination
	panel_kind="settings"
	var host=Control.new(); host.size=native_design(); host.z_index=70; add_child(host)
	var card=UI.modal(host,geometry,"Настройки"); overlay=host
	host.theme=UI.theme_for(geometry)
	for key in ["master","music","sfx"]:
		UI.label(card.content,{"master":"Общая громкость","music":"Музыка","sfx":"Звуковые эффекты"}[key])
		var slider=load("res://scripts/mobile_slider.gd").new(); slider.name="Volume_"+key; slider.custom_minimum_size=Vector2(0,geometry.touch); slider.min_value=0; slider.max_value=1; slider.step=.01
		if is_instance_valid(game.music): slider.value=game.music.volumes[key]
		slider.value_changed.connect(func(value): game.music.set_volume(key,value)); card.content.add_child(slider)
	UI.button(card.content,"OrientationToggle","Ориентация: "+("вертикальная" if portrait_mode else "горизонтальная"),func(): set_portrait(not portrait_mode),geometry.touch)
	UI.button(card.content,"TutorialToggle","Подсказки: "+("вкл" if preferences.hints else "выкл"),func(): preferences.hints=not preferences.hints; preferences.save(); show_audio_settings(),geometry.touch)
	UI.button(card.footer,"SettingsClose","Готово",close_panel,geometry.touch)
	TouchScroll.attach(card.scroll,func(): return overlay==host)
func close_panel() -> void:
	var returning=panel_kind=="settings" and is_instance_valid(suspended_archive) and not rebuilding_settings
	super.close_panel()
	if returning:
		overlay=suspended_archive; suspended_archive=null; panel_kind="collection"; add_child(overlay); overlay.reflow()
func show_context_hint(text: String) -> void:
	var chrome=puzzle_chrome
	if is_instance_valid(experiment_ui) and experiment_ui.get("chrome")!=null: chrome=experiment_ui.chrome
	if is_instance_valid(chrome):
		chrome.show_notice(text)
		if chrome.description.visible: chrome.description.text=text
	elif is_instance_valid(complex_ui):
		if is_instance_valid(complex_ui.detail): complex_ui.detail.show_hint(text)
		else: complex_ui.show_hint(text)
	elif portal_ui.visible and is_instance_valid(portal_ui.hint): portal_ui.hint.text=text
	else: show_notice(text)
func show_notice(text: String) -> void:
	if is_instance_valid(puzzle_chrome): puzzle_chrome.show_notice(text)
	elif is_instance_valid(sandbox_notice): sandbox_notice.text=text; notice_seconds=4
func handle_back() -> void:
	if is_instance_valid(overlay) and panel_kind=="settings": close_panel(); return
	if is_instance_valid(overlay) and panel_kind=="collection" and overlay.has_method("back"): overlay.back(); return
	if is_instance_valid(story_screen): story_screen.find_child("StorySkip",true,false).pressed.emit(); return
	if is_instance_valid(puzzle_chrome) and puzzle_chrome.close_modal(): return
	if is_instance_valid(experiment_ui) and experiment_ui.has_method("back"): experiment_ui.back(); return
	super.handle_back()
func input_blocked() -> bool:
	return super.input_blocked() or is_instance_valid(puzzle_chrome) and puzzle_chrome.blocked()
func _process(delta: float) -> void:
	super._process(delta)
	if mounted and game.in_campaign(): arrange()
	notice_seconds=maxf(0,notice_seconds-delta)
	if is_instance_valid(sandbox_notice):
		sandbox_notice.visible=notice_seconds>0 and not game.in_campaign() and not input_blocked()
		sandbox_notice.position=Vector2(20,size.y-geometry.touch*2-72) if geometry.portrait else Vector2(size.x-216,geometry.touch*2+44)
		sandbox_notice.size=Vector2(size.x-40,28) if geometry.portrait else Vector2(200,100)
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,geometry.extent),UI.BG)
	for index in range(30):
		var color=Color("26393b")
		if game.in_campaign() and game.campaign.blocked(index): color=Color("141e22")
		var cell=geometry.board(not game.in_campaign()).size.x/5
		draw_style_box(UI.box(color),Rect2(cell_center(index)-Vector2.ONE*cell*.46,Vector2.ONE*cell*.92))
	draw_tap_targets()

func _exit_tree() -> void:
	if is_instance_valid(suspended_archive): suspended_archive.free(); suspended_archive=null
