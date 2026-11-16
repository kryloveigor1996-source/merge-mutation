extends Node2D
## Presentation only: does not own coins, cells, merge rules or the save format.
const Catalog = preload("res://scripts/mutant_catalog.gd")
const Art = preload("res://scripts/mutant_art.gd")
const Burst = preload("res://scripts/merge_burst.gd")
const Audio = preload("res://scripts/lab_audio.gd")
const Sizes = preload("res://scripts/mutant_sizes.gd")
const DESIGN := Vector2(360,720)
const INK := Color("25465a")
const CREAM := Color("fff8de")
var game: Control
var creatures: Dictionary = {}
var motion: Dictionary = {}
var drag_index := -1
var sound: Node
var overlay: Control
var create_button: Button
var nav_left: Button
var nav_right: Button
var teleport_button: Button
var rejected_index := -1
var rejection_time := 0.0
var species_button: Button
var collection_species := "slime"
var banner := ""
var banner_alpha := 0.0:
	set(value):
		banner_alpha = value
		queue_redraw()
		if is_instance_valid(discovery_layer):
			discovery_layer.queue_redraw()
var banner_scale := 1.0:
	set(value):
		banner_scale=value
		if is_instance_valid(discovery_layer):
			discovery_layer.queue_redraw()
var discovery_layer: Node2D
var discovery_player: AnimationPlayer
var panel_kind := ""
var effects: Node2D
var style_cache: Dictionary = {}

static func fitted_rect(available: Rect2) -> Rect2:
	var factor := minf(available.size.x/DESIGN.x,available.size.y/DESIGN.y)
	return Rect2(available.position+(available.size-DESIGN*factor)*0.5,DESIGN*factor)

func layout() -> void:
	var available := Rect2(Vector2.ZERO,game.size if game.size.x>0 and game.size.y>0 else DESIGN)
	if OS.has_feature("android"):
		var physical_size := Vector2(DisplayServer.window_get_size())
		if physical_size.x>0 and physical_size.y>0:
			var safe := DisplayServer.get_display_safe_area()
			var ratio := available.size/physical_size
			var usable := Rect2(Vector2(safe.position)*ratio,Vector2(safe.size)*ratio).intersection(available)
			if usable.size.x>0 and usable.size.y>0:
				available = usable
	var fitted := fitted_rect(available)
	position = fitted.position
	scale = Vector2.ONE*(fitted.size.x/DESIGN.x)

func _ready() -> void:
	discovery_layer=Node2D.new()
	discovery_layer.z_index=19
	discovery_layer.draw.connect(_draw_discovery_banner)
	add_child(discovery_layer)
	effects = Node2D.new()
	effects.z_index = 8
	add_child(effects)
	discovery_player = AnimationPlayer.new()
	add_child(discovery_player)
	var library := AnimationLibrary.new()
	var animation := Animation.new()
	animation.length = 1.9
	var opacity_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(opacity_track,NodePath(".:banner_alpha"))
	animation.track_insert_key(opacity_track,0.0,1.0)
	animation.track_insert_key(opacity_track,1.5,1.0)
	animation.track_insert_key(opacity_track,1.9,0.0)
	var scale_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(scale_track,NodePath(".:banner_scale"))
	animation.track_insert_key(scale_track,0.0,0.8)
	animation.track_insert_key(scale_track,0.15,1.06)
	animation.track_insert_key(scale_track,0.3,1.0)
	library.add_animation("discovery",animation)
	discovery_player.add_animation_library("",library)
	sound = Audio.new()
	add_child(sound)
	var settings := ConfigFile.new()
	if settings.load("user://merge_mutation_settings.cfg") == OK:
		sound.set_enabled(bool(settings.get_value("audio","enabled",true)))
	species_button=button("ВЫБОР ВИДА",Rect2(207,72,133,51),Color("e5dcff"),func(): show_panel("species"))
	species_button.add_theme_color_override("font_disabled_color",INK)
	species_button.add_theme_stylebox_override("disabled",style(Color("e5dcff")))
	create_button = button("СОЗДАТЬ  ·  10",Rect2(37,558,286,58),Color("ffda69"),game._create_requested)
	create_button.add_theme_font_size_override("font_size",20)
	teleport_button=button("ТЕЛЕПОРТ",Rect2(266,558,72,58),Color("ded2fb"),game.toggle_teleporter)
	teleport_button.size=Vector2(72,58)
	teleport_button.add_theme_stylebox_override("disabled",style(Color("d5dedb")))
	teleport_button.add_theme_color_override("font_disabled_color",Color("627f8c"))
	create_button.add_theme_stylebox_override("disabled",style(Color("d5dedb")))
	create_button.add_theme_color_override("font_disabled_color",Color("627f8c"))
	teleport_button.hide()
	nav_left=button("КОЛЛЕКЦИЯ",Rect2(18,638,104,54),Color("b5e9ee"),left_nav)
	button("КАМПАНИЯ",Rect2(128,638,104,54),Color("ded2fb"),func(): show_panel("levels"))
	nav_right=button("НАСТРОЙКИ",Rect2(238,638,104,54),Color("ffd7b6"),right_nav)
	layout()
	rebuild()

func style(color: Color,radius: int=13) -> StyleBoxFlat:
	var key := color.to_html()+str(radius)
	if color.a==1.0 and style_cache.has(key):
		return style_cache[key]
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = INK
	box.set_border_width_all(2)
	box.set_corner_radius_all(radius)
	box.shadow_color = Color(0.08,0.22,0.27,0.2)
	box.shadow_size = 2
	box.shadow_offset = Vector2(0,3)
	if color.a==1.0:
		style_cache[key] = box
	return box

func button(title: String,rect: Rect2,color: Color,callback: Callable,parent: Node = self) -> Button:
	var control := Button.new()
	control.text = title
	control.position = rect.position
	control.size = rect.size
	control.custom_minimum_size = rect.size
	control.add_theme_stylebox_override("normal",style(color))
	control.add_theme_stylebox_override("hover",style(color.lightened(0.12)))
	control.add_theme_stylebox_override("pressed",style(color.darkened(0.12)))
	control.add_theme_stylebox_override("focus",style(color.lightened(0.15)))
	control.add_theme_color_override("font_color",INK)
	control.add_theme_color_override("font_hover_color",INK)
	control.add_theme_color_override("font_pressed_color",INK)
	control.add_theme_color_override("font_focus_color",INK)
	control.add_theme_font_size_override("font_size",10)
	control.pressed.connect(callback)
	parent.add_child(control)
	return control

func label(value: String,pos: Vector2,font_size: int,color: Color=INK,centered: bool=false) -> void:
	var font := ThemeDB.fallback_font
	var x := pos.x-font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*0.5 if centered else pos.x
	draw_string(font,Vector2(x,pos.y),value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func plate(rect: Rect2,color: Color,radius: int=12) -> void:
	draw_style_box(style(color,radius),rect)

func cell_center(index: int) -> Vector2:
	return Vector2(game.BOARD_X+(index%5)*game.CELL+31,game.BOARD_Y+floori(float(index)/5)*game.CELL+30)

func add_creature(index: int) -> Art:
	var creature := Art.new()
	creature.setup_form(game.cells[index])
	creature.position = rest_position(index,creature)
	add_child(creature)
	creatures[index] = creature
	return creature

func rest_position(index: int,creature: Art) -> Vector2:
	return Sizes.clamp_center(cell_center(index),creature.guarded_bounds())

func drag_position(pointer: Vector2,creature: Art) -> Vector2:
	return Sizes.clamp_center(pointer+Vector2(0,-8),creature.guarded_bounds(true))

func rebuild() -> void:
	rejection_time=0
	rejected_index=-1
	for tween: Tween in motion.values():
		tween.kill()
	motion.clear()
	for creature: Node2D in creatures.values():
		creature.free()
	creatures.clear()
	drag_index = -1
	discovery_player.stop()
	banner_alpha = 0
	for child in effects.get_children():
		child.free()
	for index in range(game.cells.size()):
		if game.cells[index]!=null:
			add_creature(index)
	queue_redraw()

func spawn(index: int) -> void:
	add_creature(index).pop()
	sound.play_event("spawn")
	queue_redraw()

func pick(index: int) -> void:
	if not creatures.has(index):
		return
	drag_index = index
	if motion.has(index):
		(motion[index] as Tween).kill()
	var creature: Art = creatures[index]
	creature.z_index = Sizes.ACTIVE_Z
	creature.position=Sizes.clamp_center(creature.position,creature.guarded_bounds(true))
	creature.lift()
	sound.play_event("select")
	queue_redraw()

func cancel_selection() -> void:
	if creatures.has(drag_index):
		var creature: Art = creatures[drag_index]
		var resting_index := drag_index
		creature.settle()
		var tween := create_tween()
		tween.tween_property(creature,"position",rest_position(drag_index,creature),0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.finished.connect(func():
			if is_instance_valid(creature) and drag_index!=resting_index:
				creature.z_index=0
		)
		motion[drag_index] = tween
	drag_index = -1
	queue_redraw()

func move(source: int,destination: int) -> void:
	if not creatures.has(source):
		rebuild()
		return
	var creature: Art = creatures[source]
	creatures.erase(source)
	creatures[destination] = creature
	drag_index = destination
	cancel_selection()

func merge(source: int,destination: int,discovered: bool) -> void:
	# Logical merge has already completed; these nodes are visual only.
	for index in [source,destination]:
		if motion.has(index):
			(motion[index] as Tween).kill()
		if creatures.has(index):
			var old: Art = creatures[index]
			creatures.erase(index)
			if old.animation:
				old.animation.kill()
			old.reparent(effects)
			old.z_index = 3
			var tween := old.create_tween().set_parallel(true)
			tween.tween_property(old,"position",cell_center(destination),0.12)
			tween.tween_property(old,"scale",Vector2.ZERO,0.12)
			tween.chain().tween_callback(old.queue_free)
	drag_index = -1
	var creature := add_creature(destination)
	creature.pop()
	var burst := Burst.new()
	burst.position = cell_center(destination)
	burst.discovery = discovered
	burst.z_index = 8
	effects.add_child(burst)
	sound.play_event("discover" if discovered else "merge")
	if discovered:
		banner = "ОТКРЫТО: %s" % Catalog.title(game.cells[destination])
		banner_alpha = 1
		discovery_player.stop()
		discovery_player.play("discovery")
	queue_redraw()

func _process(delta: float) -> void:
	if rejection_time>0:
		rejection_time=maxf(0,rejection_time-delta)
		queue_redraw()
	if creatures.has(drag_index):
		var creature: Art = creatures[drag_index]
		creature.position = creature.position.lerp(drag_position(game.pointer_pos,creature),1-exp(-30*delta))
		queue_redraw()

func wrapped_message(value: String) -> void:
	var font := ThemeDB.fallback_font
	var line := ""
	var lines: Array[String] = []
	for word in value.split(" "):
		if font.get_string_size(line+" "+word,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x>318:
			lines.append(line)
			line = word
		else:
			line += (" " if not line.is_empty() else "")+word
	lines.append(line)
	for i in range(mini(lines.size(),2)):
		label(lines[i],Vector2(180,540+i*12),10,INK,true)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,DESIGN),Color("d1f0ee"))
	# Tiled laboratory wall, pipes, shelf and glassware.
	for y in range(0,720,48):
		draw_line(Vector2(0,y),Vector2(360,y),Color("b8e0df"),1)
	for x in range(0,361,60):
		draw_line(Vector2(x,0),Vector2(x,720),Color("c2e7e5"),1)
	draw_line(Vector2(8,45),Vector2(8,575),INK,7)
	draw_line(Vector2(8,45),Vector2(8,575),Color("81bac6"),4)
	draw_line(Vector2(351,83),Vector2(351,599),INK,7)
	draw_line(Vector2(351,83),Vector2(351,599),Color("81bac6"),4)
	plate(Rect2(18,15,324,44),Color("4c9fba"))
	label("УРОВЕНЬ %d" % game.campaign.config.number if game.in_campaign() else "MERGE MUTATION",Vector2(180,43),23,CREAM,true)
	# Original miniature flasks make the laboratory theme visible at a glance.
	for x in [35,325]:
		draw_circle(Vector2(x,38),8,INK)
		draw_circle(Vector2(x,38),6,Color("9ff0bc"))
		draw_rect(Rect2(x-3,24,6,10),CREAM)
		draw_line(Vector2(x-5,24),Vector2(x+5,24),INK,2,true)
		draw_circle(Vector2(x-2,36),2,Color.WHITE)
	plate(Rect2(20,72,178,51),CREAM)
	var playing: bool=game.in_campaign()
	nav_left.text="ПОВТОРИТЬ" if playing else "КОЛЛЕКЦИЯ"
	nav_right.text="ПЕСОЧНИЦА" if playing else "НАСТРОЙКИ"
	species_button.disabled=playing
	create_button.text="СОЗДАТЬ" if playing else "СОЗДАТЬ  ·  10"
	create_button.position=Vector2(25,558) if playing else Vector2(37,558)
	create_button.custom_minimum_size=Vector2(233,58) if playing else Vector2(286,58)
	create_button.size=create_button.custom_minimum_size
	teleport_button.visible=playing
	if playing:
		teleport_button.text="ТЕЛЕПОРТ\nТЕСТ · %d%s" % [game.campaign.boosters.remaining("teleporter")," ✓" if game.teleport_mode else ""]
		teleport_button.disabled=game.campaign.status!="active" or game.campaign.boosters.remaining("teleporter")==0
	create_button.disabled=playing and (game.campaign.status!="active" or game.campaign.creations_left()==0 or game.campaign.spawn_index()<0)
	if playing:
		label("СОЗДАНИЯ",Vector2(32,88),9)
		label(str(game.campaign.creations_left()),Vector2(32,112),23)
		label("ХОДЫ",Vector2(116,88),9)
		label("∞" if game.campaign.moves_left()<0 else str(game.campaign.moves_left()),Vector2(116,112),23)
		var next: String=game.campaign.next_species()
		species_button.text="ДАЛЕЕ\n"+(Catalog.title(Catalog.make(next)) if not next.is_empty() else "Нет созданий")
		if not next.is_empty() and game.campaign.spawn_index()<0: species_button.text+="\nТочка занята"
		label(game.campaign.config.name,Vector2(23,136),10)
	else:
		draw_circle(Vector2(42,97),12,Color("d49832"))
		draw_circle(Vector2(42,95),11,Color("ffdb69"))
		label("+",Vector2(42,100),17,Color("b77730"),true)
		label("МОНЕТЫ · ★ %d" % game.campaign_progress.stars,Vector2(62,87),9)
		label(str(game.coins),Vector2(62,112),23)
		species_button.text="ВИД  ▾\n"+String(Catalog.species(game.active_species).get("name","Выбрать"))
		label("ОПЫТ %03d" % game.merges,Vector2(23,136),9)
		label("ФОРМЫ %02d / %d" % [game.known_discoveries(),Catalog.total_forms()],Vector2(238,136),9)
	# Containment tray with raised, checkerboard specimen pads.
	plate(Rect2(18,139,324,389),Color("4d91a4"),16)
	for index in range(30):
		var p := cell_center(index)-Vector2(29,28)
		var tile := Color("e8f4ed") if (index%5+floori(float(index)/5))%2==0 else Color("d2e9e5")
		plate(Rect2(p,Vector2(58,58)),tile,10)
		if game.in_campaign() and game.campaign.blocked(index):
			plate(Rect2(p,Vector2(58,58)),Color("668893"),10)
			draw_line(p+Vector2(15,15),p+Vector2(43,43),INK,4,true)
			draw_line(p+Vector2(43,15),p+Vector2(15,43),INK,4,true)
		if playing and index in game.campaign.config.spawn_points:
			var frame := StyleBoxFlat.new()
			frame.bg_color=Color.TRANSPARENT
			frame.border_color=Color("218eaa")
			frame.set_border_width_all(3)
			frame.set_corner_radius_all(10)
			draw_style_box(frame,Rect2(p+Vector2(3,3),Vector2(52,52)))
			draw_line(p+Vector2(46,6),p+Vector2(46,16),Color("14758f"),2,true)
			draw_polyline(PackedVector2Array([p+Vector2(42,12),p+Vector2(46,16),p+Vector2(50,12)]),Color("14758f"),2,true)
		if playing and game.dragging and valid_target(index):
			var highlight := StyleBoxFlat.new()
			highlight.bg_color=Color(0.75,0.95,0.6,0.3)
			highlight.border_color=Color("a66fea") if game.teleport_mode else Color("4baf68")
			highlight.set_border_width_all(3)
			highlight.set_corner_radius_all(10)
			draw_style_box(highlight,Rect2(p+Vector2(1,1),Vector2(56,56)))
		if rejection_time>0 and index==rejected_index:
			draw_rect(Rect2(p+Vector2(2,2),Vector2(54,54)),Color("df5365"),false,3)
		if index == drag_index:
			draw_style_box(style(Color("ffe8a0")),Rect2(p,Vector2(58,58)))
	for screw in [Vector2(23,144),Vector2(337,144),Vector2(23,523),Vector2(337,523)]:
		draw_circle(screw,3,Color("d5edf0"))
		draw_line(screw-Vector2(1.5,0),screw+Vector2(1.5,0),INK,1)
	wrapped_message(game.campaign.goals.text(game.campaign.config.goals) if playing and game.message_time<=0 else game.message)
	label("Один шаг по стороне · Голубая рамка: появление" if playing else "Один вид + одна стадия = эволюция",Vector2(180,630),9,INK,true)
	label("v2.0  /  ЛАБОРАТОРИЯ ЭВОЛЮЦИИ",Vector2(180,711),8,Color("4e7987"),true)

func _draw_discovery_banner() -> void:
	if banner_alpha<=0:
		return
	discovery_layer.draw_set_transform(Vector2(180,141),0,Vector2.ONE*banner_scale)
	discovery_layer.draw_style_box(style(Color("ffdf79",banner_alpha)),Rect2(-154,-16,308,32))
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(banner,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
	discovery_layer.draw_string(font,Vector2(-width*0.5,5),banner,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(INK,banner_alpha))

func close_panel() -> void:
	if is_instance_valid(overlay):
		overlay.hide()
		overlay.queue_free()
	overlay = null
	panel_kind = ""

func text_node(value: String,font_size: int=15) -> Label:
	var control := Label.new()
	control.text = value
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.add_theme_color_override("font_color",INK)
	control.add_theme_font_size_override("font_size",font_size)
	return control

func show_panel(kind: String) -> void:
	game._cancel_drag()
	close_panel()
	panel_kind = kind
	overlay = Control.new()
	overlay.size = DESIGN
	overlay.z_index = Sizes.OVERLAY_Z
	add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.07,0.2,0.28,0.64)
	shade.size = DESIGN
	overlay.add_child(shade)
	var panel := PanelContainer.new()
	panel.position = Vector2(16,64)
	panel.size = Vector2(328,580)
	panel.add_theme_stylebox_override("panel",style(CREAM))
	overlay.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","top","right","bottom"]:
		margin.add_theme_constant_override("margin_"+side,14)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",12)
	margin.add_child(content)
	content.add_child(text_node({"collection":"КОЛЛЕКЦИЯ","species":"ВЫБОР ВИДА","settings":"НАСТРОЙКИ","upgrades":"УЛУЧШЕНИЯ","levels":"КАМПАНИЯ","result":"РЕЗУЛЬТАТ"}.get(kind,kind),22))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",10)
	scroll.add_child(body)
	if kind == "levels":
		campaign_levels_panel(body)
	elif kind == "result":
		campaign_result_panel(body)
	elif kind == "species":
		body.add_child(text_node("Тестовый режим: доступны все виды. Создание первой стадии — 10 монет.",13))
		for id in Catalog.ids():
			var entry := Catalog.species(id)
			var choice := Button.new()
			choice.text=("✓ " if id==game.active_species else "")+entry.name
			choice.custom_minimum_size.y=48
			choice.disabled=not Catalog.available(id)
			choice.add_theme_stylebox_override("normal",style((entry.color as Color).lightened(0.45)))
			choice.add_theme_color_override("font_color",INK)
			choice.pressed.connect(func():
				if game.select_species(id):
					close_panel()
					queue_redraw()
			)
			body.add_child(choice)
	elif kind == "collection":
		body.add_child(text_node("Открыто %d / %d форм" % [game.known_discoveries(),Catalog.total_forms()],13))
		var picker := OptionButton.new()
		picker.custom_minimum_size.y=48
		picker.add_theme_stylebox_override("normal",style(Color("e5dcff")))
		picker.add_theme_color_override("font_color",INK)
		var ids := Catalog.ids()
		for id in ids:
			picker.add_item(Catalog.species(id).name)
		picker.select(maxi(0,ids.find(collection_species)))
		picker.item_selected.connect(func(index: int):
			collection_species=ids[index]
			show_panel("collection")
		)
		body.add_child(picker)
		for stage in range(1,Catalog.maximum(collection_species)+1):
			var known: bool=game.is_unlocked(collection_species,stage)
			var card := PanelContainer.new()
			card.custom_minimum_size=Vector2(0,64)
			card.add_theme_stylebox_override("panel",style(Color("dcf0e8") if known else Color("dce3e4")))
			body.add_child(card)
			var row := HBoxContainer.new()
			card.add_child(row)
			var portrait := Control.new()
			portrait.custom_minimum_size=Vector2(66,60)
			row.add_child(portrait)
			var art := Art.new()
			art.setup_form(Catalog.make(collection_species,stage),true)
			art.position=Vector2(33,30)
			if not known:
				art.modulate=Color(0.08,0.12,0.15)
			portrait.add_child(art)
			row.add_child(text_node((Catalog.title(Catalog.make(collection_species,stage)) if known else "Неизвестная форма")+"\nСТАДИЯ "+Catalog.stage_label(stage),13))
	elif kind == "upgrades":
		body.add_child(text_node("THE NEXT EXPERIMENT",18))
		body.add_child(text_node("Улучшения появятся позже. Сейчас доступны десять видов и пять стадий каждого.",16))
		for title in ["Incubator","Lab equipment","Specimen habitats"]:
			var planned := Button.new()
			planned.text = title+"  /  SOON"
			planned.custom_minimum_size.y = 58
			planned.disabled = true
			body.add_child(planned)
	else:
		var toggle := CheckButton.new()
		toggle.text = "Sound effects"
		toggle.custom_minimum_size.y = 52
		toggle.add_theme_color_override("font_color",INK)
		toggle.button_pressed = sound.enabled
		toggle.toggled.connect(func(value: bool):
			sound.set_enabled(value)
			var settings := ConfigFile.new()
			settings.set_value("audio","enabled",value)
			if settings.save("user://merge_mutation_settings.cfg") != OK:
				game._notice("Could not save sound setting")
		)
		body.add_child(toggle)
		body.add_child(text_node("Merge Mutation 2.0\nОбъединяйте один вид одной стадии. Награда: 15 × новая стадия. Создание выбранного вида стадии I: 10 монет.",15))
		var reset := Button.new()
		reset.text = "НОВАЯ ИГРА…"
		reset.custom_minimum_size.y = 54
		reset.pressed.connect(func():
			game.reset_dialog.dialog_text="Начать заново? Поле, монеты и коллекция песочницы будут сброшены. Прогресс кампании сохранится."
			game.reset_dialog.popup_centered()
		)
		body.add_child(reset)
	var close := Button.new()
	close.text = "В ПЕСОЧНИЦУ" if kind in ["levels","result"] else "В ЛАБОРАТОРИЮ"
	close.custom_minimum_size.y = 48
	close.add_theme_stylebox_override("normal",style(Color("ffda69")))
	close.add_theme_color_override("font_color",INK)
	close.add_theme_color_override("font_focus_color",INK)
	close.add_theme_color_override("font_hover_color",INK)
	close.pressed.connect(game.leave_campaign if kind in ["levels","result"] else close_panel)
	content.add_child(close)
	close.grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and is_instance_valid(overlay):
		close_panel()
		get_viewport().set_input_as_handled()

func left_nav() -> void:
	if game.in_campaign():
		game.reset_dialog.dialog_text="Начать этот уровень заново? Награды за пройденные уровни сохранятся."
		game.reset_dialog.popup_centered()
	else:
		show_panel("collection")

func right_nav() -> void:
	if game.in_campaign(): game.leave_campaign()
	else: show_panel("settings")

func action_row(body: VBoxContainer,title: String,callback: Callable,disabled: bool=false,color: Color=Color("ded2fb")) -> void:
	var control := Button.new()
	control.text=title
	control.custom_minimum_size.y=48
	control.disabled=disabled
	control.add_theme_stylebox_override("normal",style(color))
	control.add_theme_stylebox_override("disabled",style(Color("ccd6d7")))
	control.add_theme_color_override("font_disabled_color",Color("627f8c"))
	control.add_theme_color_override("font_color",INK)
	control.pressed.connect(callback)
	body.add_child(control)

func campaign_levels_panel(body: VBoxContainer) -> void:
	body.add_child(text_node("★ %d · Пройдено %d/10\nНаграда за первое прохождение: 100 монет, за №5 и №10 — 150." % [game.campaign_progress.stars,game.campaign_progress.completed.size()],13))
	for number in range(1,11):
		var config: Dictionary=game.CampaignLevels.get_level(number)
		var done: bool=number in game.campaign_progress.completed
		var locked: bool=number>game.campaign_progress.unlocked()
		var prefix := "✓ " if done else ("🔒 " if locked else "▶ ")
		action_row(body,prefix+"%d. %s" % [number,config.name],func(): game.start_level(number),locked,Color("ffda69") if not locked and not done else Color("ded2fb"))
	body.add_child(text_node("Выход и повтор начинают испытание заново. Поле песочницы сохраняется отдельно.",12))

func campaign_result_panel(body: VBoxContainer) -> void:
	if not game.in_campaign(): return
	var won: bool=game.campaign.status=="won"
	body.add_child(text_node("ЭКСПЕРИМЕНТ УДАЛСЯ!" if won else "ПОПРОБУЕМ ЕЩЁ РАЗ",21))
	body.add_child(text_node(game.campaign.goals.text(game.campaign.config.goals),16))
	if won:
		body.add_child(text_node("+%d монет · +%d ★" % [game.last_reward.coins,game.last_reward.stars],23))
		if game.last_reward.coins==0: body.add_child(text_node("Награда за первое прохождение уже получена.",14))
		if game.campaign.config.number<10:
			action_row(body,"СЛЕДУЮЩИЙ УРОВЕНЬ",func(): game.start_level(int(game.campaign.config.number)+1))
		else:
			body.add_child(text_node("Все десять уровней пройдены!",18))
	else:
		body.add_child(text_node(game.campaign.reason+". Монеты не списаны.",16))
	action_row(body,"ПОВТОРИТЬ",func(): game.start_level(int(game.campaign.config.number)))
	action_row(body,"ВЫБОР УРОВНЕЙ",func(): show_panel("levels"))

func valid_target(index: int) -> bool:
	if not game.in_campaign() or game.selected<0 or index==game.selected or game.campaign.blocked(index): return false
	if game.teleport_mode:
		return game.campaign.boosters.remaining("teleporter")>0 and game.cells[index]==null
	return game.campaign.can_transfer(game.selected,index)

func reject_drop(index: int) -> void:
	rejected_index=index
	rejection_time=0.4
	if creatures.has(game.selected):
		var creature: Art=creatures[game.selected]
		creature.modulate=Color("ffb7c0")
		creature.create_tween().tween_property(creature,"modulate",Color.WHITE,0.3)
	queue_redraw()
