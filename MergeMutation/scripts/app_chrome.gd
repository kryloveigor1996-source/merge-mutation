extends Control
## Shared compatible-screen navigation. Specialized puzzles and habitats do not use it.
const Layout=preload("res://scripts/landscape_layout.gd")
const W=preload("res://scripts/journey_widgets.gd")
var game: Control
var section:=""
var resources: Label
func setup(value: Control,current: String) -> void:
	game=value
	section=current
	size=Vector2(960,540)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	z_index=1
	resources=W.label(self,"",Rect2(24,18,310,34),18,Color("fff4d5"))
	W.label(self,{"lab":"ЛАБОРАТОРИЯ","complex":"КОМПЛЕКС","portals":"ПОРТАЛЫ","bestiary":"БЕСТИАРИЙ"}.get(section,section),Rect2(350,18,470,34),22,Color("fff4d5"),true)
	W.button(self,"AppSettings","НАСТРОЙКИ",Rect2(838,14,106,44),func(): navigate("settings"),Color("d4ece6"))
	var ids=["lab","complex","portals","bestiary"]
	var names=["ЛАБОРАТОРИЯ","КОМПЛЕКС","ПОРТАЛЫ","БЕСТИАРИЙ"]
	if not Layout.world_legacy():
		ids=["complex","portals","bestiary"]
		names=["КОМПЛЕКС","ПОРТАЛЫ","БЕСТИАРИЙ"]
	for i in range(ids.size()):
		var id: String=ids[i]
		W.button(self,"Nav_"+id,names[i],Rect2(20+i*(310 if not Layout.world_legacy() else 233),484,300 if not Layout.world_legacy() else 220,44),func(): navigate(id),Color("ffd983") if id==section else Color("c2e7e3"))
func navigate(id: String) -> void:
	game.view.close_panel()
	match id:
		"lab": game.view.close_navigation(); game.leave_campaign()
		"complex": game.leave_campaign(); game.view.open_complex()
		"portals": game.view.close_navigation(); game.open_portals()
		"bestiary": game.view.close_navigation(); game.view.show_panel("collection")
		"settings":
			if not Layout.world_legacy(): game.view.settings_return=section
			game.view.close_navigation()
			game.view.show_panel("settings")
	game.view.arrange()
func _process(_delta: float) -> void:
	resources.text="Монеты: %d   ★ %d" % [game.coins,game.campaign_progress.stars]
func _draw() -> void:
	draw_style_box(W.box(Color("417f93"),12),Rect2(12,8,936,56))
	draw_style_box(W.box(Color("417f93"),12),Rect2(12,478,936,56))
