extends "res://scripts/lab_view.gd"
const Layout=preload("res://scripts/landscape_layout.gd")
const PortalLandscape=preload("res://scripts/landscape_portal.gd")
const ExperimentLandscape=preload("res://scripts/landscape_experiment.gd")
const ComplexLandscape=preload("res://scripts/landscape_complex.gd")
const StoryLandscape=preload("res://scripts/landscape_story.gd")
var landscape_buttons: Dictionary={}
func make_portal(): return PortalLandscape.new()
func make_experiment(): return ExperimentLandscape.new()
func make_complex(): return ComplexLandscape.new()
func make_story(): return StoryLandscape.new()
func rebuild() -> void:
	super.rebuild()
	arrange()
func _ready() -> void:
	super._ready()
	for control in landscape_buttons.values(): control.add_theme_font_size_override("font_size",16)
	create_button.add_theme_font_size_override("font_size",20)
	game.reset_dialog.size=Vector2i(460,200)
	arrange()
func button(title: String,rect: Rect2,color: Color,callback: Callable,parent: Node=self) -> Button:
	var result:=super.button(title,rect,color,callback,parent)
	landscape_buttons[title]=result
	return result
func layout() -> void:
	var available:=Rect2(Vector2.ZERO,game.size if game.size.x>0 else Layout.DESIGN)
	if OS.has_feature("android"):
		var physical:=Vector2(DisplayServer.window_get_size())
		if physical.x>0 and physical.y>0:
			var safe:=DisplayServer.get_display_safe_area()
			available=Rect2(Vector2(safe.position)*available.size/physical,Vector2(safe.size)*available.size/physical).intersection(available)
	var fitted:=Layout.fit(available)
	position=fitted.position
	scale=Vector2.ONE*fitted.size.x/960.0
func cell_index(point: Vector2) -> int: return Layout.cell_at(point)
func cell_center(index: int) -> Vector2: return Layout.center(index)
func clamp_art(point: Vector2,bounds: Rect2) -> Vector2:
	return Vector2(clampf(point.x,Layout.BOARD.position.x-bounds.position.x,Layout.BOARD.end.x-bounds.end.x),clampf(point.y,Layout.BOARD.position.y-bounds.position.y,Layout.BOARD.end.y-bounds.end.y))
func rest_position(index: int,creature: Art) -> Vector2: return clamp_art(cell_center(index),creature.guarded_bounds())
func drag_position(pointer: Vector2,creature: Art) -> Vector2: return clamp_art(pointer+Vector2(0,-8),creature.guarded_bounds(true))
func pick(index: int) -> void:
	if not creatures.has(index): return
	drag_index=index
	if motion.has(index): motion[index].kill()
	var creature: Art=creatures[index]
	creature.z_index=Sizes.ACTIVE_Z
	creature.position=clamp_art(creature.position,creature.guarded_bounds(true))
	creature.lift()
	sound.play_event("select")
	queue_redraw()
func arrange() -> void:
	if not is_instance_valid(create_button): return
	var playing: bool=game.in_campaign()
	var placement: Dictionary={"СОЗДАТЬ  ·  10":Rect2(710,110,230,54),"ВЫБОР ВИДА":Rect2(20,210,250,54),"КОЛЛЕКЦИЯ":Rect2(710,238,230,50),"ПОРТАЛЫ":Rect2(710,298,230,50),"ЭКСПЕРИМЕНТ":Rect2(710,358,230,50),"НАСТРОЙКИ":Rect2(710,478,230,48),"КОМПЛЕКС":Rect2(710,418,230,50),"ТЕЛЕПОРТ":Rect2(710,174,230,50)}
	for key in placement:
		if landscape_buttons.has(key): Layout.place(landscape_buttons[key],placement[key])
	complex_button.visible=not playing
	experiment_button.disabled=playing
	species_button.disabled=playing
	teleport_button.visible=playing
	teleport_button.text="ТЕЛЕПОРТ · %d" % game.campaign.boosters.remaining("teleporter") if playing else "ТЕЛЕПОРТ"
	teleport_button.disabled=playing and (game.campaign.status!="active" or game.campaign.boosters.remaining("teleporter")==0)
	create_button.text="СОЗДАТЬ" if playing else "СОЗДАТЬ · 10"
	create_button.disabled=playing and (game.campaign.status!="active" or game.campaign.creations_left()==0 or game.campaign.spawn_index()<0)
	nav_left.text="ПОВТОРИТЬ" if playing else "КОЛЛЕКЦИЯ"
	nav_right.text="В ПЕСОЧНИЦУ" if playing else "НАСТРОЙКИ"
	var next: String=game.campaign.next_species() if playing else ""
	species_button.text=("ДАЛЕЕ: "+Catalog.species(next).name if not next.is_empty() else "НЕТ СОЗДАНИЙ") if playing else "ВИД: "+Catalog.species(game.active_species).name
func _process(delta: float) -> void:
	super._process(delta)
	arrange()
	queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(0,0,960,540),Color("d1f0ee"))
	for y in range(0,541,48): draw_line(Vector2(0,y),Vector2(960,y),Color("b8e0df"),1)
	for x in [8,694,952]: draw_line(Vector2(x,54),Vector2(x,530),Color("6ba8ac"),6)
	plate(Rect2(16,12,928,52),Color("4c9fba"))
	label("УРОВЕНЬ %d · %s" % [game.campaign.config.number,game.campaign.config.name] if game.in_campaign() else "MERGE MUTATION · ЛАБОРАТОРИЯ",Vector2(480,47),24,CREAM,true)
	plate(Rect2(12,76,272,450),CREAM)
	plate(Rect2(700,76,248,450),Color("c5e7df"))
	plate(Layout.BOARD.grow(10),Color("4d91a4"))
	for index in range(30):
		var p:=cell_center(index)-Vector2(30,30)
		plate(Rect2(p,Vector2(60,60)),Color("e5f3eb") if index%2==0 else Color("cce6df"),9)
		if game.in_campaign() and game.campaign.blocked(index):
			plate(Rect2(p,Vector2(60,60)),Color("6f9198"),9)
			draw_line(p+Vector2(14,14),p+Vector2(46,46),INK,4)
		if game.in_campaign() and index in game.campaign.config.spawn_points: draw_rect(Rect2(p+Vector2(3,3),Vector2(54,54)),Color("218eaa"),false,3)
		if game.in_campaign() and game.dragging and valid_target(index): draw_rect(Rect2(p+Vector2(2,2),Vector2(56,56)),Color("93bd5c"),false,3)
	label("ЦЕЛИ И РЕСУРСЫ",Vector2(28,105),17)
	label(("ХОДЫ: ∞" if game.campaign.moves_left()<0 else "ХОДЫ: %d" % game.campaign.moves_left()) if game.in_campaign() else "МОНЕТЫ: %d" % game.coins,Vector2(28,143),22)
	label("Создания: %d" % game.campaign.creations_left() if game.in_campaign() else "Открыто форм: %d / 50" % game.known_discoveries(),Vector2(28,177),16)
	label("ДЕЙСТВИЯ",Vector2(720,102),16)
	var text: String=game.campaign.goals.text(game.campaign.config.goals) if game.in_campaign() else "Одинаковые вид и стадия объединяются.\nПеретащите существо на поле."
	draw_text_block(text,Rect2(28,290,238,145),17)
	draw_text_block(game.message,Rect2(28,447,238,72),14)
	label("ЛАБОРАТОРНЫЙ СИНТЕЗ",Vector2(480,510),14,INK,true)
func draw_text_block(value: String,rect: Rect2,font_size: int) -> void:
	var line:=""
	var y:=rect.position.y
	for word in value.replace("\n"," \n ").split(" "):
		if word=="\n" or ThemeDB.fallback_font.get_string_size(line+word,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>rect.size.x:
			label(line,Vector2(rect.position.x,y),font_size)
			y+=font_size+5
			line=""
		if word!="\n": line+=word+" "
		if y>rect.end.y-font_size: break
	label(line,Vector2(rect.position.x,y),font_size)
func show_panel(kind: String) -> void:
	super.show_panel(kind)
	overlay.size=Layout.DESIGN
	var shade: ColorRect=overlay.get_child(0)
	shade.size=Layout.DESIGN
	var panel: PanelContainer=overlay.get_child(1)
	panel.position=Vector2(140,20)
	panel.size=Vector2(680,500)
func _draw_discovery_banner() -> void:
	if banner_alpha<=0: return
	discovery_layer.draw_set_transform(Vector2(480,68),0,Vector2.ONE*banner_scale)
	discovery_layer.draw_style_box(style(Color("ffdf79",banner_alpha)),Rect2(-230,-16,460,32))
	discovery_layer.draw_string(ThemeDB.fallback_font,Vector2(-210,5),banner,HORIZONTAL_ALIGNMENT_LEFT,420,14,Color(INK,banner_alpha))
