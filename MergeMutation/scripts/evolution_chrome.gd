extends "res://scripts/app_chrome.gd"
func setup(value: Control,current: String) -> void:
	super.setup(value,current)
	reflow()
func reflow() -> void:
	if not game.view.portrait_mode:
		size=Vector2(960,540)
		Layout.place(resources,Rect2(24,18,310,34)); resources.add_theme_font_size_override("font_size",18)
		for child in get_children():
			if child is Label and child!=resources: Layout.place(child,Rect2(350,18,470,34))
		Layout.place(get_node("AppSettings"),Rect2(838,14,106,44))
		for i in range(3):
			var id: String=["complex","portals","bestiary"][i]
			get_node("Nav_"+id).add_theme_font_size_override("font_size",16)
			Layout.place(get_node("Nav_"+id),Rect2(20+i*310,484,300,44))
		queue_redraw()
		return
	size=Vector2(540,960)
	Layout.place(resources,Rect2(18,14,350,42))
	resources.add_theme_font_size_override("font_size",17)
	for child in get_children():
		if child is Label and child!=resources: Layout.place(child,Rect2(18,65,504,42))
	Layout.place(get_node("AppSettings"),Rect2(388,14,134,48))
	for i in range(3):
		var id: String=["complex","portals","bestiary"][i]
		var button: Button=get_node("Nav_"+id)
		button.add_theme_font_size_override("font_size",15)
		Layout.place(button,Rect2(12+i*174,892,168,54))
static func replace(parent: Node,value: Control,current: String):
	for child in parent.get_children():
		if child.get_script()!=null and child.get_script().resource_path=="res://scripts/app_chrome.gd": parent.remove_child(child); child.queue_free()
	var result=load("res://scripts/evolution_chrome.gd").new()
	result.setup(value,current)
	parent.add_child(result)
	return result
func _draw() -> void:
	if not game.view.portrait_mode: super._draw(); return
	draw_style_box(W.box(Color("417f93"),12),Rect2(8,8,524,110))
	draw_style_box(W.box(Color("417f93"),12),Rect2(8,884,524,68))