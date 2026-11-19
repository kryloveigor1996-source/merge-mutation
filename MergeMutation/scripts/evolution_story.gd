extends "res://scripts/landscape_story.gd"
var owner_view
func refresh() -> void:
	super.refresh()
	if owner_view==null or not owner_view.portrait_mode: return
	size=Vector2(540,960)
	var row=0
	for child in get_children():
		if child is Label:
			var rect: Rect2=[Rect2(24,24,492,60),Rect2(24,90,492,30),Rect2(34,510,472,44),Rect2(34,566,472,230)][mini(row,3)]
			L.place(child,rect); row+=1
	L.place(get_node("StoryNext"),Rect2(24,850,310,60))
	L.place(get_node("StorySkip"),Rect2(350,850,166,60))
func _draw() -> void:
	if owner_view==null or not owner_view.portrait_mode: super._draw(); return
	draw_rect(Rect2(0,0,540,960),Color("c9eae6"))
	draw_style_box(W.box(Color("fff8de"),18),Rect2(16,486,508,332))
	draw_set_transform(Vector2(90,114),0,Vector2.ONE)
	draw_cast()