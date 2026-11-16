extends Control
const W = preload("res://scripts/journey_widgets.gd")
var owner_ui: Control
var model
var pressed := false
var travel := Vector2.ZERO
var last_visible_count := 0
var background_texture: Texture2D
func setup(parent_ui: Control,value) -> void:
	owner_ui=parent_ui
	model=value
	custom_minimum_size=Vector2(model.width(),model.height())
	var path: String=model.entry.map.get("layout",{}).get("background_texture","")
	if path.begins_with("res://") and ResourceLoader.exists(path): background_texture=load(path) as Texture2D
	mouse_filter=Control.MOUSE_FILTER_STOP
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.index==0:
			if event.pressed:
				pressed=true
				travel=Vector2.ZERO
			else:
				if pressed and travel.length()<12: activate(event.position)
				pressed=false
		accept_event()
	elif event is InputEventScreenDrag:
		if event.index==0 and pressed:
			travel+=event.relative
			owner_ui.pan_by(-event.relative)
		accept_event()
	elif event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:
				pressed=true
				travel=Vector2.ZERO
			else:
				if pressed and travel.length()<12: activate(event.position)
				pressed=false
			accept_event()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			owner_ui.scroll_by(-80 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 80)
			accept_event()
	elif event is InputEventMouseMotion and pressed:
		travel+=event.relative
		owner_ui.pan_by(-event.relative)
		accept_event()
func activate(position: Vector2) -> void:
	var index: int=model.hit(position)
	if index>=0: owner_ui.activate_node(index)
func _draw() -> void:
	var top: float=owner_ui.map_scroll.scroll_vertical
	var viewport_height: float=owner_ui.map_scroll.size.y
	var visible_rect := Rect2(owner_ui.map_scroll.scroll_horizontal,top,owner_ui.map_scroll.size.x,viewport_height)
	var swamp: bool=model.entry.map.theme=="swamp"
	var background := Color("446f63") if swamp else Color("deece5")
	draw_rect(visible_rect,background)
	if background_texture: draw_texture_rect(background_texture,Rect2(0,0,model.width(),model.height()),false)
	for route_index in model.visible_routes(visible_rect):
		var route: Dictionary=model.routes[route_index]
		for segment in route.segments:
			var clipped: Vector2=model.clip_segment(segment.a,segment.b,visible_rect.grow(4))
			if clipped.x<0: continue
			var distance: float=ceilf((segment.offset+segment.length*clipped.x)/12.0)*12.0-segment.offset
			while distance<=segment.length*clipped.y:
				var position: Vector2=segment.a.lerp(segment.b,distance/segment.length)
				draw_circle(position,2.5,Color("a7c1b4") if model.fogged(route.to) else Color("698c83"))
				distance+=12
	var indices: Array=model.visible_indices(top,viewport_height)
	last_visible_count=indices.size()
	for index in indices:
		var point: Vector2=model.point(index)
		for side in [-1,1]:
			var decor := Vector2(168+side*140,point.y+31*sin(index*2.7+side))
			if swamp:
				draw_circle(decor,19,Color("5d8e63"))
				draw_line(decor,decor+Vector2(side*14,-36),Color("a8cf75"),4,true)
			else:
				draw_style_box(W.box(Color("b8d8d0"),8),Rect2(decor-Vector2(15,21),Vector2(30,42)))
				draw_circle(decor,4,Color("f5dda0"))
		var state: String=model.state(index)
		var fog: bool=model.fogged(index)
		var color := Color("ffdc79") if state=="current" else (Color("9de1b0") if state=="completed" else Color("afc5c2"))
		if state=="preview": color=Color("87ac91")
		if fog: color=Color("a3b9b6") if not swamp else Color("678d7b")
		draw_circle(point+Vector2(0,5),33,Color(0.07,0.23,0.24,0.23))
		draw_circle(point,32,W.INK)
		draw_circle(point,29,color)
		if state=="current": draw_arc(point,37,0,TAU,48,Color("d49a36"),2,true)
		if fog:
			for cloud in range(4): draw_circle(point+Vector2(-32+cloud*23,sin(index+cloud)*10),24,Color(0.76,0.84,0.8,0.28))
			W.draw_lock(self,point,Color("c2d2cc"))
		else:
			var text := str(index+1)
			var font := ThemeDB.fallback_font
			draw_string(font,point+Vector2(-font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,22).x*0.5,8),text,HORIZONTAL_ALIGNMENT_LEFT,-1,22,W.INK)
			if state=="completed":
				var star := PackedVector2Array()
				for corner in range(10): star.append(point+Vector2(0,-41)+Vector2.from_angle(-PI/2+corner*PI/5)*(10 if corner%2==0 else 4.5))
				draw_colored_polygon(star,Color("e8ae39"))
			elif state in ["locked","preview"]:
				draw_circle(point+Vector2(23,22),10,W.INK)
				draw_line(point+Vector2(19,22),point+Vector2(27,22),Color("dce9dc"),2,true)
