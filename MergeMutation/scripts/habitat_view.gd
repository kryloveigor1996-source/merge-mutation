extends Control
const W=preload("res://scripts/journey_widgets.gd")
const Art=preload("res://scripts/mutant_art.gd")
const EnvView=preload("res://scripts/habitat_environment.gd")
const PALETTES:={"stone":["ac937b","625d61"],"acid":["8adca2","267b7c"],"air":["b4dcf4","7563ac"],"crystal":["d5b8e9","6a597e"],"forest":["b9d79a","426a65"],"secret":["556a83","243448"]}
var data: Dictionary={}
var highlight_left:=0.0
var environment
var active:=false
func setup(value: Dictionary,living_model=null) -> void:
	data=value
	position=Vector2(data.rect[0],data.rect[1])
	size=Vector2(data.rect[2],data.rect[3])
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	z_index=2 # Tall rooms remain above the backgrounds of every floor they span.
	set_process(false)
	if living_model!=null and data.preview_accessible:
		environment=EnvView.new()
		environment.setup(living_model,Vector2(size.x-14,size.y-61))
		environment.position=Vector2(7,35)
		add_child(environment)
		if living_model.has_method("renovation_objects"): living_model.renovation.changed.connect(queue_redraw)
	elif data.preview_accessible and data.has("species_id"):
		var art:=Art.new()
		art.setup_form({"species_id":data.species_id,"evolution_stage":1})
		art.position=Vector2(size.x*0.5,size.y*0.63)
		art.scale=Vector2.ONE*minf(1.4,(size.x-16)/70.0)
		add_child(art)
func highlight() -> void:
	highlight_left=1.4
	set_process(active)
	queue_redraw()
func set_active(value: bool) -> void:
	active=value
	if is_instance_valid(environment): environment.set_active(value)
	set_process(value and highlight_left>0)
func object_area() -> Rect2:
	var area: Array=data.get("interaction_rect",[8,35,size.x-16,size.y-61])
	return Rect2(area[0],area[1],area[2],area[3])
func _process(delta: float) -> void:
	highlight_left=maxf(0,highlight_left-delta)
	queue_redraw()
	if highlight_left==0 or not active: set_process(false)
func _draw() -> void:
	if data.is_empty(): return
	var palette: Array=PALETTES.get(data.theme_id,PALETTES.stone)
	var wall:=Color(palette[0])
	var glass:=Color(palette[1])
	draw_style_box(W.box(wall,9),Rect2(Vector2.ZERO,size))
	var window:=Rect2(7,35,size.x-14,size.y-61)
	draw_style_box(W.box(glass,5),window)
	# Biome decorations use only original Godot geometry, no hidden species art.
	if data.theme_id=="stone":
		for index in range(3): draw_circle(Vector2(17+index*(size.x-34)/2,window.end.y-10),10,Color("8d7c74"))
	elif data.theme_id=="acid":
		draw_rect(Rect2(9,window.end.y-25,size.x-18,22),Color("9fec61"))
		for index in range(3): draw_circle(Vector2(18+index*25,window.end.y-25),4,Color("d8ff9c"))
	elif data.theme_id=="air":
		for index in range(2):
			draw_circle(Vector2(26+index*30,75+index*28),13,Color("d8eff9"))
			draw_line(Vector2(10,120),Vector2(size.x-10,110),Color("a6c7ec"),3)
	elif data.theme_id=="forest":
		for index in range(3):
			draw_line(Vector2(30+index*40,window.end.y),Vector2(30+index*40,100),Color("41604d"),7)
			draw_circle(Vector2(30+index*40,95),24,Color("7dac65"))
	elif data.theme_id=="crystal":
		for index in range(3):
			var p:=Vector2(25+index*34,window.end.y-8)
			draw_colored_polygon(PackedVector2Array([p+Vector2(-11,0),p+Vector2(0,-50-index*8),p+Vector2(12,0)]),Color("a794db"))
	elif data.theme_id=="secret":
		# Abstract instrument shadow, deliberately no recognizable creature/form.
		draw_rect(Rect2(size.x*0.28,80,size.x*0.44,window.size.y-70),Color("1d2d40"))
		for index in range(5): draw_line(Vector2(10+index*(size.x-20)/4,36),Vector2(10+index*(size.x-20)/4,window.end.y),Color("8294a0"),6)
		for index in range(7): draw_line(Vector2(15+index*43,size.y-43),Vector2(30+index*43,size.y-27),Color("ecc756"),6)
		var warning:=Vector2(size.x-22,20)
		draw_colored_polygon(PackedVector2Array([warning+Vector2(0,-10),warning+Vector2(-10,8),warning+Vector2(10,8)]),Color("ffd16a"))
		draw_string(ThemeDB.fallback_font,warning+Vector2(-2,5),"!",HORIZONTAL_ALIGNMENT_LEFT,-1,13,W.INK)
	# Glazing reflection and frame screws.
	draw_line(Vector2(12,45),Vector2(size.x*0.44,75),Color(0.8,0.96,1,0.3),4)
	for p in [Vector2(5,5),Vector2(size.x-5,5),Vector2(5,size.y-5),size-Vector2(5,5)]: draw_circle(p,2,Color("dfedf1"))
	var title: String={"acid":"КИСЛОТА","air":"ВОЗДУХ","crystal":"МИНЕРАЛЫ","forest":"БИОМ"}.get(data.theme_id,data.name) if not data.has("archive_name") else data.archive_name
	var ink:=Color("f8efc8") if data.theme_id=="secret" else W.INK
	draw_string(ThemeDB.fallback_font,Vector2(8,22),title,HORIZONTAL_ALIGNMENT_LEFT,size.x-16,10 if size.x<110 else 13,ink)
	var footer: String=("ОБИТАЕМЫЙ ВОЛЬЕР" if data.preview_accessible else "ЗАКРЫТО") if data.get("permanent_room",false) else ("ДЕМО · ОБЗОР" if data.preview_accessible else "ЗАКРЫТО")
	if is_instance_valid(environment) and environment.model.has_method("renovation_objects"):
		footer="РЕМОНТ · %d%%" % environment.model.renovation.progress()
	draw_string(ThemeDB.fallback_font,Vector2(8,size.y-9),footer,HORIZONTAL_ALIGNMENT_LEFT,size.x-16,9,ink)
	if not data.preview_accessible: W.draw_lock(self,Vector2(size.x*0.5,size.y*0.56),Color("f5d77a"))
	if highlight_left>0: draw_rect(Rect2(2,2,size.x-4,size.y-4),Color(1,0.9,0.35,minf(1,highlight_left)),false,4)
