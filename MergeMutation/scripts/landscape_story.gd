extends "res://scripts/story_screen.gd"
const L=preload("res://scripts/landscape_layout.gd")
func refresh() -> void:
	super.refresh()
	size=L.DESIGN
	for child in get_children():
		if child is Label:
			if child.position.y<80: L.place(child,Rect2(20,20,390,60))
			elif child.position.y<100: L.place(child,Rect2(20,84,390,28))
			elif child.position.y<400: L.place(child,Rect2(466,100,440,42))
			else: L.place(child,Rect2(466,164,440,240))
	L.place(get_node("StoryNext"),Rect2(466,438,270,58))
	L.place(get_node("StorySkip"),Rect2(754,438,160,58))
func _draw() -> void:
	draw_rect(Rect2(0,0,960,540),Color("c9eae6"))
	draw_style_box(W.box(Color("fff8de"),18),Rect2(440,76,500,434))
	# Existing procedural character art stays proportionate in a separate portrait region.
	draw_set_transform(Vector2(28,60),0,Vector2.ONE*0.95)
	draw_cast()
