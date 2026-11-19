extends "res://scripts/core_bestiary.gd"
const TouchScroll=preload("res://scripts/evolution_touch_scroll.gd")
const ChromeAdaptive=preload("res://scripts/evolution_chrome.gd")
func setup(value: Control) -> void:
	super.setup(value)
	ChromeAdaptive.replace(self,game,"bestiary")
	for child in get_children():
		if child is ScrollContainer: TouchScroll.attach(child,func(): return game.view.overlay==self and not is_instance_valid(game.view.story_screen),func(point): select_scrolled_row(child,point))
	reflow()
func show_entry(id: String) -> void:
	super.show_entry(id)
	if is_instance_valid(content):
		for child in content.get_children():
			if child is ScrollContainer and child.get_child_count()>0:
				child.get_child(0).mouse_filter=Control.MOUSE_FILTER_IGNORE
				TouchScroll.attach(child,func(): return game.view.overlay==self and not is_instance_valid(game.view.story_screen))
	if game.view.portrait_mode: reflow_content()
func reflow() -> void:
	if not game.view.portrait_mode:
		size=Vector2(960,540)
		query.position=Vector2(20,78); query.size=Vector2(226,44)
		filter.position=Vector2(20,126); filter.size=Vector2(226,44)
		for child in get_children():
			if child is ScrollContainer: child.position=Vector2(20,176); child.size=Vector2(232,290)
		show_entry(selected)
		queue_redraw()
		return
	size=Vector2(540,960)
	query.position=Vector2(20,132); query.size=Vector2(310,48)
	filter.position=Vector2(340,132); filter.size=Vector2(180,48)
	for child in get_children():
		if child is ScrollContainer: child.position=Vector2(20,192); child.size=Vector2(500,130)
	reflow_content()
	queue_redraw()
func reflow_content() -> void:
	if not is_instance_valid(content): return
	var label_index=0
	for child in content.get_children():
		if child is Label:
			if label_index==0: child.hide()
			elif label_index==1: child.position=Vector2(230,352); child.size=Vector2(288,52)
			else: child.position=Vector2(230,408); child.size=Vector2(288,36)
			label_index+=1
		elif child is Node2D: child.position=Vector2(120,410); child.scale=Vector2.ONE*1.6
		elif child is Button:
			if child.name=="VisitHabitat": child.position=Vector2(20,824); child.size=Vector2(500,48)
			else:
				var index=int(str(child.name).trim_prefix("Form_"))-1
				child.position=Vector2(230+index*57,462); child.size=Vector2(50,48)
		elif child is ScrollContainer:
			child.position=Vector2(20,530); child.size=Vector2(500,280)
			var text=child.get_child(0)
			text.custom_minimum_size.x=470
			if text is RichTextLabel: text.add_theme_font_size_override("normal_font_size",18)
func _draw() -> void:
	if not game.view.portrait_mode: super._draw(); return
	draw_rect(Rect2(0,0,540,960),Color("cce4db"))
	for rect in [Rect2(12,126,516,204),Rect2(12,340,516,180),Rect2(12,522,516,354)]: draw_style_box(W.box(Color("fff3d6")),rect)
func refresh_list() -> void:
	super.refresh_list()
	list.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for row in list.get_children():
		if row is Control: row.mouse_filter=Control.MOUSE_FILTER_IGNORE
func select_scrolled_row(scroll: ScrollContainer,point: Vector2) -> void:
	var local=point+Vector2(scroll.scroll_horizontal,scroll.scroll_vertical)
	for row in list.get_children():
		if row is Button and row.get_rect().has_point(local): row.pressed.emit(); return