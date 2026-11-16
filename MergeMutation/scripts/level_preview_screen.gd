extends Control
const W = preload("res://scripts/journey_widgets.gd")
const Silhouette = preload("res://scripts/discovery_silhouette.gd")
var owner_ui: Control
var data: Dictionary={}
func setup(parent_ui: Control,value: Dictionary) -> void:
	owner_ui=parent_ui
	data=value
	size=Vector2(360,720)
	mouse_filter=Control.MOUSE_FILTER_STOP
	W.label(self,"ИСПЫТАНИЕ %02d" % data.number,Rect2(30,87,300,25),12)
	W.label(self,data.name,Rect2(30,116,300,52),22)
	var scroll := ScrollContainer.new()
	scroll.name="PreviewDetails"
	scroll.position=Vector2(30,177)
	scroll.size=Vector2(300,372)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",12)
	scroll.add_child(body)
	add_text(body,"ЦЕЛИ\n"+data.goals,17)
	add_text(body,"Создания: %d · Ходы: %s" % [data.creation_limit,"без лимита" if data.move_limit<0 else str(data.move_limit)],13)
	add_text(body,"Сложность: "+data.difficulty,14)
	add_text(body,"БУСТЕРЫ\n"+data.boosters,14)
	if not data.discoveries.is_empty():
		add_text(body,"Ещё не открытые формы среди целей",13)
		var row := HFlowContainer.new()
		row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation",10)
		body.add_child(row)
		for form in data.discoveries:
			row.add_child(Silhouette.new())
	else:
		add_text(body,"Новые формы по целям не заявлены или уже знакомы. Другие открытия не указаны.",13)
	add_text(body,("Уровень уже пройден.\n" if data.completed else "")+data.best_text,13)
	W.button(self,"PreviewPlay","ИГРАТЬ",Rect2(28,570,304,52),func(): owner_ui.play_preview())
	W.button(self,"PreviewClose","ЗАКРЫТЬ",Rect2(28,636,304,48),func(): owner_ui.close_preview(),Color("b5e9ee"))
func add_text(parent: Node,text: String,font_size: int) -> void:
	var label := Label.new()
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.text=text
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",W.INK)
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
func _draw() -> void:
	draw_rect(Rect2(0,0,360,720),Color(0.08,0.2,0.24,0.48))
	draw_style_box(W.box(Color("fff8de"),18),Rect2(16,74,328,626))

# Touch scrolling remains available with mouse emulation disabled in project settings.
var detail_touch := -1
func _input(event: InputEvent) -> void:
	var scroll: ScrollContainer=get_node("PreviewDetails")
	if event is InputEventScreenTouch:
		if event.pressed and scroll.get_global_rect().has_point(event.position):
			detail_touch=event.index
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index==detail_touch:
			detail_touch=-1
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index==detail_touch:
		scroll.scroll_vertical-=int(event.relative.y)
		get_viewport().set_input_as_handled()
