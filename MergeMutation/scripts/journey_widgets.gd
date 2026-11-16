extends RefCounted
const INK := Color("25465a")
static func box(color: Color,radius: int=14) -> StyleBoxFlat:
	var value := StyleBoxFlat.new()
	value.bg_color=color
	value.border_color=INK
	value.set_border_width_all(2)
	value.set_corner_radius_all(radius)
	value.shadow_color=Color(0.07,0.2,0.25,0.2)
	value.shadow_size=3
	value.shadow_offset=Vector2(0,3)
	return value
static func label(parent: Node,value: String,rect: Rect2,font_size: int=16,color: Color=INK,center: bool=false) -> Label:
	var node := Label.new()
	node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	node.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	node.text=value
	node.position=rect.position
	node.custom_minimum_size=Vector2(rect.size.x,0)
	node.size=rect.size
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	node.size=rect.size
	return node
static func button(parent: Node,id: String,title: String,rect: Rect2,callback: Callable,color: Color=Color("ffda69")) -> Button:
	var node := Button.new()
	node.name=id
	node.text=title
	for state in ["normal","focus","hover","pressed"]:
		node.add_theme_stylebox_override(state,box(color.darkened(0.08) if state=="pressed" else color))
	node.add_theme_stylebox_override("disabled",box(Color("b9ced0")))
	for state in ["font_color","font_hover_color","font_focus_color","font_pressed_color"]:
		node.add_theme_color_override(state,INK)
	node.add_theme_color_override("font_disabled_color",Color("637f8a"))
	node.add_theme_font_size_override("font_size",13)
	node.position=rect.position
	node.custom_minimum_size=rect.size
	node.size=rect.size
	node.pressed.connect(callback)
	parent.add_child(node)
	return node
static func draw_lock(canvas: CanvasItem,center: Vector2,color: Color=Color("ffdf85")) -> void:
	canvas.draw_arc(center+Vector2(0,-9),10,PI,TAU,16,color,4,true)
	canvas.draw_style_box(box(color,5),Rect2(center+Vector2(-14,-9),Vector2(28,25)))
	canvas.draw_circle(center+Vector2(0,0),3,INK)
	canvas.draw_line(center+Vector2(0,1),center+Vector2(0,8),INK,3,true)
