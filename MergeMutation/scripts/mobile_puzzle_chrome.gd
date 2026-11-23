extends Control
const UI=preload("res://scripts/mobile_ui.gd")
const TouchScroll=preload("res://scripts/mobile_scroll.gd")
var view
var layout
var title=""
var goals: Callable
var commands: Dictionary
var buttons: Dictionary={}
var counters: Label
var goal_button: Button
var description: Label
var modal: Control
var notice=""
var notice_time=0.0
func setup(owner_view,text: String,goal_source: Callable,actions: Dictionary) -> void:
	view=owner_view; layout=view.geometry; title=text; goals=goal_source; commands=actions
	mouse_filter=Control.MOUSE_FILTER_IGNORE; z_index=10
	reflow()
func reflow() -> void:
	UI.clear(self); buttons.clear(); modal=null
	size=layout.extent
	theme=UI.theme_for(layout)
	var header=HBoxContainer.new(); header.position=Vector2(16,12); header.size=Vector2(size.x-32,layout.touch); header.mouse_filter=Control.MOUSE_FILTER_IGNORE; header.add_theme_constant_override("separation",8); add_child(header)
	var back=UI.button(header,"PuzzleBack","‹",commands.back,layout.touch); back.size_flags_horizontal=0
	var heading=UI.label(header,title,24); heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL; heading.max_lines_visible=2; heading.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; heading.clip_text=true; heading.custom_minimum_size.y=layout.touch; heading.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	var restart=UI.button(header,"PuzzleRestart","↻",confirm_restart,layout.touch); restart.size_flags_horizontal=0
	var settings=UI.button(header,"PuzzleSettings","⚙",func(): view.show_panel("settings"),layout.touch); settings.size_flags_horizontal=0
	goal_button=UI.button(self,"PuzzleGoals","",show_goals,layout.touch)
	goal_button.position=Vector2(20,layout.touch+24); goal_button.size=Vector2(size.x-40,layout.touch)
	if not layout.portrait: goal_button.position=Vector2(16,layout.touch+28); goal_button.size=Vector2(layout.board().position.x-32,layout.touch*1.5)
	var dock=VBoxContainer.new(); dock.name="PuzzleActions"; dock.mouse_filter=Control.MOUSE_FILTER_IGNORE; dock.add_theme_constant_override("separation",8); add_child(dock)
	if layout.portrait: dock.position=Vector2(20,size.y-layout.touch-56); dock.size=Vector2(size.x-40,layout.touch+40)
	else: dock.position=Vector2(size.x-216,layout.touch+28); dock.size=Vector2(200,size.y-layout.touch-44)
	counters=UI.label(dock,"",20)
	var row: Container=UI.row(dock) if layout.portrait else UI.column(dock)
	for key in ["undo","spawn","teleport"]:
		if commands.has(key): buttons[key]=UI.button(row,"Mobile"+key.capitalize(),{"undo":"↶ Отменить","spawn":"Создать","teleport":"Телепорт"}[key],commands[key],layout.touch)
	description=UI.label(self,"",20); description.max_lines_visible=3; description.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	var spare=dock.position.y-layout.board().end.y-20
	description.visible=layout.portrait and spare>=64
	description.position=Vector2(20,layout.board().end.y+16); description.size=Vector2(size.x-40,maxf(0,spare))
func update(text: String,detail: String="",states: Dictionary={}) -> void:
	if not is_instance_valid(counters): return
	counters.text=text; description.text=detail
	refresh_caption()
	for key in states:
		if buttons.has(key):
			buttons[key].disabled=states[key].get("disabled",false)
			if states[key].has("text"): buttons[key].text=states[key].text
func compact(text: String) -> String:
	var width=goal_button.size.x-36
	var font_size=get_theme_default_font_size()
	var value=text
	while value.length()>0 and ThemeDB.fallback_font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>width-18: value=value.left(value.length()-1)
	return value+("…" if value!=text else "")
func refresh_caption() -> void:
	if not is_instance_valid(goal_button): return
	var full: String=goals.call()
	goal_button.autowrap_mode=TextServer.AUTOWRAP_OFF
	goal_button.text=compact(full.get_slice("\n",0))+"\n"+compact(notice if notice_time>0 else "Подробнее ↓")
	goal_button.tooltip_text=full+("\n\n"+notice if notice_time>0 else "")
func show_notice(text: String) -> void:
	notice=text; notice_time=4; refresh_caption()
func _process(delta: float) -> void:
	if notice_time>0:
		notice_time=maxf(0,notice_time-delta)
		if notice_time==0: refresh_caption()
func show_goals() -> void:
	close_modal()
	var card=UI.modal(self,layout,title)
	modal=card.overlay
	UI.label(card.content,goals.call(),22)
	if notice_time>0: UI.label(card.content,notice,22)
	TouchScroll.attach(card.scroll,func(): return is_instance_valid(modal))
	UI.button(card.footer,"GoalsClose","Понятно",close_modal,layout.touch)
func confirm_restart() -> void:
	close_modal()
	var card=UI.modal(self,layout,"Начать уровень заново?")
	modal=card.overlay
	UI.label(card.content,"Текущая попытка будет начата заново. Прогресс кампании сохраняется.",22)
	UI.button(card.footer,"RestartCancel","Отмена",close_modal,layout.touch)
	UI.button(card.footer,"RestartConfirm","Заново",func(): close_modal(); commands.restart.call(),layout.touch)
func close_modal() -> bool:
	if not is_instance_valid(modal): return false
	remove_child(modal); modal.queue_free(); modal=null; return true
func blocked() -> bool: return is_instance_valid(modal)
