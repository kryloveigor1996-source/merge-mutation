extends Control
const UI=preload("res://scripts/mobile_ui.gd")
const Art=preload("res://scripts/mutant_art.gd")
var data: Dictionary={}
var model
var active=false
var highlight_left=0.0
var art
func setup(value: Dictionary,living_model=null) -> void:
	data=value; model=living_model; position=Vector2(data.rect[0],data.rect[1]); size=Vector2(data.rect[2],data.rect[3]); mouse_filter=Control.MOUSE_FILTER_IGNORE; z_index=2
	if model!=null and data.preview_accessible:
		art=Art.new(); art.setup_form({"species_id":model.profile.species_id,"evolution_stage":1}); add_child(art)
		art.scale=Vector2.ONE*minf(1.9,(size.x-32)/85)
	set_process(false)
func set_active(value: bool) -> void: active=value; set_process(value)
func highlight() -> void: highlight_left=1.4; queue_redraw()
func object_area() -> Rect2: return Rect2(Vector2.ZERO,size)
func _process(delta: float) -> void:
	highlight_left=maxf(0,highlight_left-delta)
	if model!=null:
		model.tick(delta)
		if is_instance_valid(art):
			art.position=Vector2(size.x*.5+sin(model.simulation_time*.4)*minf(18,size.x*.08),size.y*.56)
			art.rotation=sin(model.elapsed*2)*.02
	queue_redraw()
func _draw() -> void:
	var known: bool=data.preview_accessible and model!=null
	var color=Color("22352f") if data.theme_id=="acid" else Color("34302d")
	if not known: color=Color("1a242a")
	draw_rect(Rect2(Vector2.ZERO,size),color)
	draw_rect(Rect2(0,0,size.x,32),Color("34453f") if known else UI.LINE)
	for y in range(78,int(size.y-48),48): draw_line(Vector2(8,y),Vector2(size.x-8,y),Color(1,1,1,.035),1)
	for x in [12,size.x-16]: draw_line(Vector2(x,44),Vector2(x,size.y-48),UI.LINE,4)
	if known:
		draw_rect(Rect2(size.x-56,84,38,maxf(40,size.y*.3)),Color("435649"))
		for i in range(3): draw_circle(Vector2(size.x-37,102+i*24),3,UI.BIO)
	else:
		draw_string(ThemeDB.fallback_font,Vector2(size.x*.5-12,size.y*.57),"?",HORIZONTAL_ALIGNMENT_LEFT,-1,40,UI.MUTED)
	draw_string(ThemeDB.fallback_font,Vector2(14,62),data.get("archive_name",data.name),HORIZONTAL_ALIGNMENT_LEFT,size.x-28,20,UI.INK)
	draw_rect(Rect2(0,size.y-42,size.x,42),Color("14201c"))
	var footer="Неизученный обитатель" if not known else "%d / %d объектов" % [model.renovation.installed.size(),model.renovation.catalog.slots.size()]
	draw_string(ThemeDB.fallback_font,Vector2(12,size.y-16),footer,HORIZONTAL_ALIGNMENT_LEFT,size.x-24,17,UI.MUTED)
	draw_line(Vector2(0,size.y+3),Vector2(size.x,size.y+3),Color("65776c"),6)
	if highlight_left>0: draw_rect(Rect2(2,2,size.x-4,size.y-4),UI.BIO,false,3)
