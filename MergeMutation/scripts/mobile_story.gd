extends "res://scripts/story_screen.gd"
const UI=preload("res://scripts/mobile_ui.gd")
var owner_view
func refresh() -> void:
	clear_children()
	if owner_view==null: return
	size=owner_view.native_design(); theme=UI.theme_for(owner_view.geometry)
	var line: Dictionary=data.lines[index]
	var scroll=ScrollContainer.new(); scroll.position=Vector2(20,size.y*.48); scroll.size=Vector2(size.x-40,size.y*.52-owner_view.geometry.touch-44); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; add_child(scroll)
	var stack=UI.column(scroll); stack.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	UI.label(stack,data.title,26); UI.label(stack,"%d / %d" % [index+1,data.lines.size()],18)
	UI.label(stack,Dialogue.speaker_name(line.speaker),24); UI.label(stack,line.text,22)
	var buttons=UI.row(self); buttons.position=Vector2(20,size.y-owner_view.geometry.touch-16); buttons.size=Vector2(size.x-40,owner_view.geometry.touch)
	UI.button(buttons,"StoryNext","К порталам" if index==data.lines.size()-1 else "Далее",advance,owner_view.geometry.touch)
	UI.button(buttons,"StorySkip","Пропустить",complete,owner_view.geometry.touch)
	load("res://scripts/mobile_scroll.gd").attach(scroll,func(): return visible)
	queue_redraw()
func _draw() -> void:
	if owner_view==null: return
	draw_rect(Rect2(Vector2.ZERO,size),UI.BG)
	var scale_factor=minf((size.x-60)/340,(size.y*.44)/370)
	draw_set_transform(Vector2((size.x-340*scale_factor)*.5,10),0,Vector2.ONE*scale_factor)
	draw_cast()
