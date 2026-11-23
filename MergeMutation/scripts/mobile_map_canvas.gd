extends "res://scripts/world_map_canvas.gd"
const UI=preload("res://scripts/mobile_ui.gd")
var distance=0.0
func activate(point: Vector2) -> void:
	var best=-1; var nearest=owner_ui.game.view.geometry.touch*.5
	for index in model.visible_indices(owner_ui.map_scroll.scroll_vertical,owner_ui.map_scroll.size.y):
		var d=point.distance_to(model.point(index))
		if d<=nearest: best=index; nearest=d
	if best>=0: owner_ui.activate_node(best)
func _gui_input(event: InputEvent) -> void:
	if is_instance_valid(owner_ui.preview): pressed=false; accept_event(); return
	if event is InputEventScreenTouch:
		if event.index!=0 or event.canceled: pressed=false; distance=0; accept_event(); return
		if event.pressed: distance=0
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed: distance=0
	if event is InputEventScreenDrag or event is InputEventMouseMotion:
		if pressed: distance+=event.relative.length()
		if event is InputEventScreenDrag and event.index!=0: pressed=false; accept_event(); return
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and not event.pressed and distance>12: pressed=false
	super._gui_input(event)
func _draw() -> void:
	var area=Rect2(owner_ui.map_scroll.scroll_horizontal,owner_ui.map_scroll.scroll_vertical,owner_ui.map_scroll.size.x,owner_ui.map_scroll.size.y)
	draw_rect(area,UI.BG)
	if background_texture: draw_texture_rect(background_texture,Rect2(0,0,model.width(),model.height()),false)
	for route_index in model.visible_routes(area):
		var route: Dictionary=model.routes[route_index]
		for segment in route.segments:
			var clipped: Vector2=model.clip_segment(segment.a,segment.b,area.grow(4))
			if clipped.x<0: continue
			draw_line(segment.a.lerp(segment.b,clipped.x),segment.a.lerp(segment.b,clipped.y),UI.LINE if model.fogged(route.to) else Color("6a8d78"),4,true)
	var indices: Array=model.visible_indices(area.position.y,area.size.y); last_visible_count=indices.size()
	var radius=maxf(34,owner_ui.game.view.geometry.touch*.5)
	for index in indices:
		var point: Vector2=model.point(index); var state: String=model.state(index); var fog: bool=model.fogged(index)
		var color=Color("25353a") if state in ["locked","preview"] else Color("324d3a")
		draw_circle(point,radius,color); draw_arc(point,radius,0,TAU,40,UI.BIO if state=="current" else UI.LINE,2)
		var text="?" if fog else str(index+1)
		draw_string(ThemeDB.fallback_font,point+Vector2(-ThemeDB.fallback_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,25).x*.5,9),text,HORIZONTAL_ALIGNMENT_LEFT,-1,25,UI.MUTED if fog else UI.INK)
		if state=="completed": draw_string(ThemeDB.fallback_font,point+Vector2(radius*.5,-radius*.5),"★",HORIZONTAL_ALIGNMENT_LEFT,-1,18,UI.BIO)
