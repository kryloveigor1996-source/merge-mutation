extends Node2D
## Presentation only: does not own coins, cells, merge rules or the save format.
const Art = preload("res://scripts/mutant_art.gd")
const Burst = preload("res://scripts/merge_burst.gd")
const Audio = preload("res://scripts/lab_audio.gd")
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
var banner := ""
var banner_alpha := 0.0:
	set(value):
		banner_alpha = value
		queue_redraw()
var banner_scale := 1.0
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
	create_button = button("CREATE SLIME  ·  10",Rect2(37,558,286,58),Color("ffda69"),game._create_requested)
	create_button.add_theme_font_size_override("font_size",20)
	button("COLLECTION",Rect2(18,638,104,54),Color("b5e9ee"),func(): show_panel("collection"))
	button("UPGRADES",Rect2(128,638,104,54),Color("ded2fb"),func(): show_panel("upgrades"))
	button("SETTINGS",Rect2(238,638,104,54),Color("ffd7b6"),func(): show_panel("settings"))
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

func add_creature(index: int) -> Node2D:
	var creature := Art.new()
	creature.setup(game.cells[index])
	creature.position = cell_center(index)
	add_child(creature)
	creatures[index] = creature
	return creature

func rebuild() -> void:
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
		if game.cells[index]>0:
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
	var creature: Node2D = creatures[index]
	creature.z_index = 5
	creature.lift()
	sound.play_event("select")
	queue_redraw()

func cancel_selection() -> void:
	if creatures.has(drag_index):
		var creature: Node2D = creatures[drag_index]
		creature.z_index = 0
		creature.settle()
		var tween := create_tween()
		tween.tween_property(creature,"position",cell_center(drag_index),0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		motion[drag_index] = tween
	drag_index = -1
	queue_redraw()

func move(source: int,destination: int) -> void:
	if not creatures.has(source):
		rebuild()
		return
	var creature: Node2D = creatures[source]
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
		banner = "DISCOVERED!  %s" % game.NAMES[game.cells[destination]]
		banner_alpha = 1
		discovery_player.stop()
		discovery_player.play("discovery")
	queue_redraw()

func _process(delta: float) -> void:
	if creatures.has(drag_index):
		var creature: Node2D = creatures[drag_index]
		creature.position = creature.position.lerp(game.pointer_pos+Vector2(0,-8),1-exp(-30*delta))
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
	label("MERGE MUTATION",Vector2(180,43),23,CREAM,true)
	# Original miniature flasks make the laboratory theme visible at a glance.
	for x in [35,325]:
		draw_circle(Vector2(x,38),8,INK)
		draw_circle(Vector2(x,38),6,Color("9ff0bc"))
		draw_rect(Rect2(x-3,24,6,10),CREAM)
		draw_line(Vector2(x-5,24),Vector2(x+5,24),INK,2,true)
		draw_circle(Vector2(x-2,36),2,Color.WHITE)
	plate(Rect2(20,72,178,51),CREAM)
	draw_circle(Vector2(42,97),12,Color("d49832"))
	draw_circle(Vector2(42,95),11,Color("ffdb69"))
	label("+",Vector2(42,100),17,Color("b77730"),true)
	label("LAB COINS",Vector2(62,87),9)
	label(str(game.coins),Vector2(62,112),23)
	plate(Rect2(207,72,133,51),Color("e5dcff"))
	label("DISCOVERED",Vector2(220,87),9)
	label("%02d / 10" % game.highest,Vector2(220,112),23)
	label("EXPERIMENT %03d" % game.merges,Vector2(23,136),9)
	label("LAB 01",Vector2(300,136),9,INK,false)
	# Containment tray with raised, checkerboard specimen pads.
	plate(Rect2(18,139,324,389),Color("4d91a4"),16)
	for index in range(30):
		var p := cell_center(index)-Vector2(29,28)
		var tile := Color("e8f4ed") if (index%5+floori(float(index)/5))%2==0 else Color("d2e9e5")
		plate(Rect2(p,Vector2(58,58)),tile,10)
		if index == drag_index:
			draw_style_box(style(Color("ffe8a0")),Rect2(p,Vector2(58,58)))
	for screw in [Vector2(23,144),Vector2(337,144),Vector2(23,523),Vector2(337,523)]:
		draw_circle(screw,3,Color("d5edf0"))
		draw_line(screw-Vector2(1.5,0),screw+Vector2(1.5,0),INK,1)
	wrapped_message(game.message)
	label("Two of a kind. One wild discovery.",Vector2(180,630),10,INK,true)
	label("v0.2  /  THE MUTATION LAB",Vector2(180,711),8,Color("4e7987"),true)
	if banner_alpha>0:
		draw_set_transform(Vector2(180,141),0,Vector2.ONE*banner_scale)
		plate(Rect2(-154,-16,308,32),Color("ffdf79",banner_alpha))
		label(banner,Vector2(0,5),12,Color(INK,banner_alpha),true)

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
	overlay.z_index = 20
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
	content.add_child(text_node(kind.to_upper(),22))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",10)
	scroll.add_child(body)
	if kind == "collection":
		body.add_child(text_node("%d of 10 species discovered" % game.highest,13))
		for level in range(1,11):
			var card := PanelContainer.new()
			card.custom_minimum_size = Vector2(0,72)
			card.add_theme_stylebox_override("panel",style(Color("dcf0e8") if level<=game.highest else Color("dce3e4")))
			body.add_child(card)
			var row := HBoxContainer.new()
			card.add_child(row)
			var portrait := Control.new()
			portrait.custom_minimum_size = Vector2(66,68)
			row.add_child(portrait)
			var art := Art.new()
			art.setup(level)
			art.position = Vector2(33,34)
			art.scale = Vector2.ONE*0.9
			if level>game.highest:
				art.modulate = Color(0.18,0.28,0.33)
			portrait.add_child(art)
			row.add_child(text_node((game.NAMES[level] if level<=game.highest else "Unknown specimen")+"\nLEVEL %02d" % level,13))
	elif kind == "upgrades":
		body.add_child(text_node("THE NEXT EXPERIMENT",18))
		body.add_child(text_node("Lab upgrades are coming in a future update. For now, discover all ten mutants!",16))
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
		body.add_child(text_node("Merge Mutation v0.2\nCombine matching creatures. Each merge earns 15 × the new level in coins. Creating a slime costs 10 coins.",15))
		var reset := Button.new()
		reset.text = "NEW GAME…"
		reset.custom_minimum_size.y = 54
		reset.pressed.connect(func(): game.reset_dialog.popup_centered())
		body.add_child(reset)
	var close := Button.new()
	close.text = "BACK TO LAB"
	close.custom_minimum_size.y = 48
	close.add_theme_stylebox_override("normal",style(Color("ffda69")))
	close.add_theme_color_override("font_color",INK)
	close.add_theme_color_override("font_focus_color",INK)
	close.add_theme_color_override("font_hover_color",INK)
	close.pressed.connect(close_panel)
	content.add_child(close)
	close.grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and is_instance_valid(overlay):
		close_panel()
		get_viewport().set_input_as_handled()
