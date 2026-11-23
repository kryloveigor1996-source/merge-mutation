extends "res://scripts/evolution_legacy_experiment.gd"
const MobileScroll=preload("res://scripts/mobile_scroll.gd")
const UI=preload("res://scripts/mobile_ui.gd")
const Chrome=preload("res://scripts/mobile_puzzle_chrome.gd")
const Renderer=preload("res://scripts/mobile_board.gd")
var chrome
var result_panel: Control
func center(index: int) -> Vector2: return game.view.geometry.center(index)
func cell_at(point: Vector2) -> int: return game.view.geometry.cell_at(point)
func setup(value: Control) -> void:
	super.setup(value); reflow()
func show_list() -> void:
	chrome=null; result_panel=null
	super.show_list()
	size=game.view.native_design(); theme=UI.theme_for(game.view.geometry)
	for child in get_children():
		if child is Label: child.hide()
		elif child is Button: child.hide()
	var heading=UI.label(self,"Тактические испытания",26); heading.position=Vector2(116,24); heading.size=Vector2(size.x-232,84)
	var exit=UI.button(self,"MobileTrialBack","‹",exit_experiment,game.view.geometry.touch); exit.position=Vector2(16,16); exit.size=Vector2(84,84)
	L.place(trial_scroll,list_rect())
	for row in trial_scroll.get_child(0).get_children(): row.custom_minimum_size.y=game.view.geometry.touch; row.add_theme_font_size_override("font_size",22)
	MobileScroll.attach(trial_scroll,func(): return game.view.overlay==null and session==null)
func list_rect() -> Rect2: return Rect2(20,120,game.view.native_design().x-40,game.view.native_design().y-140)
func start_trial(index: int) -> bool:
	chrome=null; result_panel=null
	var ok=super.start_trial(index)
	if ok: rebuild_chrome(); refresh()
	return ok
func rebuild_chrome() -> void:
	if is_instance_valid(chrome): remove_child(chrome); chrome.queue_free()
	chrome=Chrome.new(); add_child(chrome)
	var actions={"back":show_list,"restart":func(): start_trial(number),"undo":undo_action}
	if session.config.creation_limit>0: actions.spawn=create_creature
	chrome.setup(game.view,"%02d · %s" % [number,session.config.name],goal_description,actions)
func goal_description() -> String:
	var text="Доставить к меткам:
"
	for destination in session.config.destinations: text+=session.Catalog.title(destination)+"
"
	return text+"
"+session.config.tip
func arrange() -> void:
	if session==null: return
	size=game.view.native_design(); theme=UI.theme_for(game.view.geometry)
	for child in get_children():
		if child is Control and child!=chrome and child!=result_panel: child.hide()
	for index in sprites:
		sprites[index].position=center(index); sprites[index].scale=Vector2.ONE*game.view.geometry.board().size.x/500*1.15
func refresh() -> void:
	super.refresh()
	if session!=null and session.status!="active" and not busy: show_result()
	if is_instance_valid(chrome): chrome.update("Ходы %d · Отмены %d" % [session.moves_left(),history.remaining],message.text,{"undo":{"disabled":busy or not history.can_undo()},"spawn":{"disabled":busy or session.status!="active" or session.creations_left()==0,"text":"Создать · %d" % session.creations_left()}})
func reflow() -> void:
	if is_instance_valid(result_panel): remove_child(result_panel); result_panel.queue_free(); result_panel=null
	gesture.cancel(); selected=-1; pressed=-1
	if animation: animation.kill()
	busy=false
	if session==null: show_list()
	else: arrange(); rebuild_chrome(); refresh()
	queue_redraw()
func draw_action_marks() -> void:
	if session==null: return
	Renderer.targets(action_layer,session,game.view.geometry,selected)
	for target in session.config.destinations:
		var p=center(target.cell)
		action_layer.draw_string(ThemeDB.fallback_font,p+Vector2(-20,30),{"slime":"С","horn":"Р","wing":"К"}.get(target.species_id,"?")+" II",HORIZONTAL_ALIGNMENT_LEFT,-1,16,UI.BIO)
func show_result() -> void:
	if is_instance_valid(result_panel): return
	var card=UI.modal(self,game.view.geometry,"Испытание завершено" if session.status=="won" else "Попробуем иначе")
	result_panel=card.overlay
	UI.label(card.content,"%d · %s
Ходы %d / %d
Без постоянных наград и открытий" % [number,session.config.name,session.moves_used,session.config.move_limit])
	if session.status=="won" and number<10: UI.button(card.content,"NextTrial","Следующее испытание",func(): start_trial(number+1),game.view.geometry.touch)
	if history.can_undo(): UI.button(card.content,"TrialResultUndo","Отменить ход",undo_action,game.view.geometry.touch)
	UI.button(card.footer,"TrialList","Испытания",show_list,game.view.geometry.touch)
	UI.button(card.footer,"TrialComplex","В комплекс",func(): exit_experiment(); game.view.open_complex(),game.view.geometry.touch)
func undo_action() -> void:
	if busy: return
	if is_instance_valid(result_panel): remove_child(result_panel); result_panel.queue_free(); result_panel=null
	super.undo_action()
func back() -> void:
	if is_instance_valid(chrome) and chrome.close_modal(): return
	if session!=null: show_list()
	else: exit_experiment(); game.view.open_complex()
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),UI.BG)
	if session!=null: Renderer.draw(self,session,game.view.geometry)
func _gui_input(event: InputEvent) -> void:
	if session==null: super._gui_input(event); return
	if is_instance_valid(result_panel) or is_instance_valid(chrome) and chrome.blocked() or game.view.overlay!=null: gesture.cancel(); accept_event(); return
	super._gui_input(event)
func choose(index: int) -> void:
	super.choose(index)
	if session!=null and not busy: refresh()
