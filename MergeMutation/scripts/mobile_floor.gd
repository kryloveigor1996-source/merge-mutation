extends "res://scripts/complex_floor.gd"
const UI=preload("res://scripts/mobile_ui.gd")
const Room=preload("res://scripts/mobile_room.gd")
var display_width=540.0
func setup(value: Dictionary,registry,living_models: Dictionary={}) -> void:
	data=value; position=Vector2(0,data.top); display_width=registry.width; size=Vector2(display_width,data.height); mouse_filter=Control.MOUSE_FILTER_IGNORE
	for id in data.habitats:
		var room=Room.new(); var room_data: Dictionary=registry.get_habitat(id)
		if not data.preview_accessible: room_data.preview_accessible=false
		room.setup(room_data,living_models.get(id)); add_child(room); rooms[id]=room
	set_process(false)
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("182327"))
	draw_rect(Rect2(8,0,28,size.y),Color("0c161c"))
	for x in [14,30]: draw_line(Vector2(x,0),Vector2(x,size.y),Color("75868b"),2)
	for y in range(20,int(size.y),70): draw_line(Vector2(14,y),Vector2(30,y),UI.LINE,2)
	draw_rect(Rect2(42,0,display_width-54,38),UI.PANEL)
	draw_string(ThemeDB.fallback_font,Vector2(52,27),("0" if data.depth==0 else "−%d" % data.depth)+" / "+data.name,HORIZONTAL_ALIGNMENT_LEFT,display_width-70,20,UI.MUTED)
	draw_line(Vector2(38,size.y-7),Vector2(display_width-12,size.y-7),UI.LINE,9)
	if data.depth==0:
		draw_rect(Rect2(56,66,display_width-90,size.y-90),Color("243830"))
		draw_string(ThemeDB.fallback_font,Vector2(74,106),"ЛАБОРАТОРИЯ",HORIZONTAL_ALIGNMENT_LEFT,-1,24,UI.INK)
		draw_rect(Rect2(display_width*.5-26,122,52,maxf(40,size.y-150)),UI.LINE)
