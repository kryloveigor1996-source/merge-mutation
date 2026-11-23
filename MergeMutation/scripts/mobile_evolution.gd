extends "res://scripts/evolution_screen.gd"
const UI=preload("res://scripts/mobile_ui.gd")
const Chrome=preload("res://scripts/mobile_puzzle_chrome.gd")
const Renderer=preload("res://scripts/mobile_board.gd")
var chrome
var list_shell: Dictionary={}
func center(index: int) -> Vector2: return game.view.geometry.center(index)
func clear_ui() -> void:
	chrome=null
	super.clear_ui()
func reflow() -> void:
	clear_ui(); size=game.view.native_design(); theme=UI.theme_for(game.view.geometry)
	if session==null: build_list()
	else: build_trial(); refresh()
	queue_redraw()
func build_list() -> void:
	list_shell=UI.shell(self,game.view.geometry,"Tactical Evolution",leave,func(): game.view.show_panel("settings"),true)
	UI.button(list_shell.dock,"EvolutionExit","В комплекс",leave,game.view.geometry.touch)
	list_scroll=ScrollContainer.new(); UI.fill(list_scroll); list_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; list_shell.body.add_child(list_scroll)
	var rows=UI.column(list_scroll); rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL; rows.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for index in range(1,11):
		var data=Levels.get_level(index)
		var item=UI.button(rows,"EvolutionLevel%d" % index,"%d · %s%s
Сложность %d/5 · %d ходов" % [index,data.name," ✓" if completed.has(index) else "",data.difficulty,data.move_limit],func(): start_trial(index),game.view.geometry.touch)
		item.mouse_filter=Control.MOUSE_FILTER_IGNORE
	TouchScroll.attach(list_scroll,func(): return game.view.overlay==null and session==null,func(point):
		var local=point+Vector2(0,list_scroll.scroll_vertical)
		for item in rows.get_children():
			if item.get_rect().has_point(local): item.pressed.emit(); return
	)
func build_trial() -> void:
	super.build_trial()
	for child in get_children():
		if child is Control: child.hide()
	for connection in marks.draw.get_connections(): marks.draw.disconnect(connection.callable)
	marks.z_index=3; marks.draw.connect(func(): Renderer.targets(marks,session,game.view.geometry,selected))
	chrome=Chrome.new(); add_child(chrome)
	var actions={"back":back,"restart":func(): start_trial(number),"undo":undo}
	if session.config.creation_limit>0: actions.spawn=spawn_creature
	chrome.setup(game.view,"%02d · %s" % [number,session.config.name],goal_description,actions)
func goal_description() -> String:
	var lines: PackedStringArray=[]
	for goal in session.objective_status(): lines.append(("✓ " if goal.met else "○ ")+goal.text+" (%d/%d)" % [mini(goal.current,goal.total),goal.total])
	return "
".join(lines)
func refresh() -> void:
	super.refresh()
	for index in actors:
		actors[index].position=center(index); actors[index].scale=Vector2.ONE*game.view.geometry.board().size.x/500*1.15
	if is_instance_valid(chrome):
		chrome.update("Ходы %d · Отмены %d" % [session.moves_left(),history.remaining],"Выбран: "+session.Catalog.title(session.cells[selected]) if selected>=0 and session.cells[selected]!=null else "Нажмите на мутанта, затем на цель",{"undo":{"disabled":busy or not history.can_undo()},"spawn":{"disabled":busy or session.status!="active" or session.creations_left()==0,"text":"Создать · %d" % session.creations_left()}})
func choose(index: int) -> void:
	super.choose(index)
	if session!=null and not busy: refresh()
func notify(text: String) -> void:
	if is_instance_valid(chrome): chrome.show_notice(text)
func finish(result: Dictionary) -> void:
	game.view.preferences.master("tap_controls")
	if result.kind in ["move","merge","jump","push","corridor"]: game.view.preferences.master("movement")
	var mastery: Dictionary={"push":"mechanism_crate","reveal":"mechanism_hidden","neutralize":"mechanism_anomaly"}
	if mastery.has(result.kind): game.view.preferences.master(mastery[result.kind])
	if result.kind in ["push","reveal","activate","neutralize","jump","break"]: game.view.preferences.master("action_"+result.kind)
	selected=-1; idle=0; busy=true; gesture.cancel(); refresh()
	game.view.sound.play_event("merge" if result.kind=="merge" else ("spawn" if result.kind=="spawn" else "select"))
	if session.status=="won": completed[number]=true; game.music.event("victory")
	animation=create_tween()
	if result.has("source") and actors.has(result.index) and result.kind in ["move","merge","push","jump","corridor"]:
		actors[result.index].position=center(result.source)
		animation.tween_property(actors[result.index],"position",center(result.index),.22).set_trans(Tween.TRANS_QUAD)
	else: animation.tween_interval(.22)
	animation.tween_callback(func(): busy=false; refresh())
func show_result() -> void:
	if is_instance_valid(result_panel): return
	var card=UI.modal(self,game.view.geometry,"Эксперимент завершён" if session.status=="won" else "Попробуем иначе")
	result_panel=card.overlay; result_panel.name="EvolutionResult"
	UI.label(card.content,"%d · %s
Ходы: %d / %d
Без постоянных наград и открытий" % [number,session.config.name,session.moves_used,session.config.move_limit])
	if session.status=="won" and number<10: UI.button(card.content,"EvolutionNext","Следующий эксперимент",func(): start_trial(number+1),game.view.geometry.touch)
	if history.can_undo(): UI.button(card.content,"EvolutionResultUndo","Отменить ход",undo,game.view.geometry.touch)
	UI.button(card.footer,"EvolutionReturn","В комплекс",leave,game.view.geometry.touch)
	UI.button(card.footer,"EvolutionRetry","Повторить",func(): start_trial(number),game.view.geometry.touch)
func back() -> void:
	if is_instance_valid(chrome) and chrome.close_modal(): return
	super.back()
func _gui_input(event: InputEvent) -> void:
	if session==null: return
	if busy or is_instance_valid(result_panel) or (is_instance_valid(chrome) and chrome.blocked()) or game.view.overlay!=null: gesture.cancel(); accept_event(); return
	var click=gesture.feed(event)
	if not click.is_empty() and game.view.geometry.cell_at(click.origin)==game.view.geometry.cell_at(click.point): choose(game.view.geometry.cell_at(click.point))
	accept_event()
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),UI.BG)
	if session!=null: Renderer.draw(self,session,game.view.geometry)
func start_trial(index: int) -> bool:
	var ok=super.start_trial(index)
	if not ok: return false
	for hint in game.view.tutorial.requests:
		if hint.scope!="evolution_"+str(index): continue
		hint.target=game.view.geometry.board()
	return true
