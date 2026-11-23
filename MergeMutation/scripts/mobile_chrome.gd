extends "res://scripts/app_chrome.gd"
const UI=preload("res://scripts/mobile_ui.gd")
var caption: Label
func setup(value: Control,current: String) -> void:
	game=value; section=current; mouse_filter=Control.MOUSE_FILTER_IGNORE; z_index=5
	reflow()
func reflow() -> void:
	UI.clear(self); size=game.view.native_design(); theme=UI.theme_for(game.view.geometry)
	var header=UI.row(self); header.mouse_filter=Control.MOUSE_FILTER_IGNORE; header.position=Vector2(16,12); header.size=Vector2(size.x-32,game.view.geometry.touch)
	var titles=UI.column(header); titles.size_flags_horizontal=Control.SIZE_EXPAND_FILL; titles.mouse_filter=Control.MOUSE_FILTER_IGNORE
	caption=UI.label(titles,{"lab":"Лаборатория","complex":"Комплекс","portals":"Портальный зал","bestiary":"Бестиарий"}.get(section,section),24)
	resources=UI.label(titles,"",18)
	if section=="complex":
		var lift=UI.button(header,"ComplexLift","↕",func():
			if is_instance_valid(game.view.complex_ui): game.view.complex_ui.show_lift()
		,game.view.geometry.touch); lift.size_flags_horizontal=0
	var gear=UI.button(header,"AppSettings","⚙",func(): navigate("settings"),game.view.geometry.touch); gear.size_flags_horizontal=0
	var footer=UI.row(self); footer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	footer.position=Vector2(16,size.y-game.view.geometry.touch-16); footer.size=Vector2(size.x-32,game.view.geometry.touch)
	for id in ["complex","portals","bestiary"]:
		var button=UI.button(footer,"Nav_"+id,{"complex":"Комплекс","portals":"Порталы","bestiary":"Бестиарий"}[id],func(): navigate(id),game.view.geometry.touch)
		if id==section: button.add_theme_stylebox_override("normal",UI.box(Color("273e32"),UI.BIO))
func navigate(id: String) -> void:
	if id=="settings":
		game.view.show_panel("settings"); return
	super.navigate(id)
func _draw() -> void: pass
