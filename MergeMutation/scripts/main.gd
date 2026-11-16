extends Control
## Merge Mutation: gameplay state, rules and backwards-compatible saves.
## No external assets or addons required.
const LabView = preload("res://scripts/lab_view.gd")
const Catalog = preload("res://scripts/mutant_catalog.gd")
const SaveCodec = preload("res://scripts/save_codec.gd")
const CampaignSession = preload("res://scripts/campaign_session.gd")
const CampaignProgress = preload("res://scripts/campaign_progress.gd")
const CampaignLevels = preload("res://scripts/campaign_levels.gd")

const COLS := 5
const ROWS := 6
const CELL := 62.0
const BOARD_X := 25.0
const BOARD_Y := 147.0
const SPAWN_COST := 10
const SAVE_PATH := "user://merge_mutation_save_v2.json"
const LEGACY_SAVE_PATH := "user://merge_mutation_save.json"

var cells: Array = []
var coins: int = 100
var merges: int = 0
var discoveries: Dictionary = {}
var active_species := "slime"
var save_extra: Dictionary = {}
var write_blocked := false
var needs_backup := false
var load_error := ""
var selected: int = -1
var pointer_pos := Vector2.ZERO
var dragging := false
var message := "Соединяйте одинаковые виды одной стадии"
var message_time := 0.0
var rng := RandomNumberGenerator.new()
var save_path := SAVE_PATH
var reset_dialog: ConfirmationDialog
var view: LabView
var campaign: CampaignSession
var campaign_progress := CampaignProgress.new()
var sandbox_cells: Array=[]
var last_reward := {"coins":0,"stars":0}

func in_campaign() -> bool:
	return campaign!=null

func start_level(number: int) -> bool:
	if number<1 or number>campaign_progress.unlocked(): return false
	var attempt := CampaignSession.new()
	if not attempt.start(CampaignLevels.get_level(number)): return false
	_cancel_drag()
	if not in_campaign(): sandbox_cells=cells.duplicate(true)
	campaign=attempt
	cells=campaign.cells
	last_reward={"coins":0,"stars":0}
	if not save_extra.has("campaign") and FileAccess.file_exists(save_path): needs_backup=true
	save_extra["campaign"]=campaign_progress.encode()
	for form in cells:
		if form!=null: unlock(form)
	if is_instance_valid(view):
		view.close_panel()
		view.rebuild()
	settle_campaign_action()
	return true

func leave_campaign() -> void:
	if in_campaign():
		_cancel_drag()
		cells=sandbox_cells.duplicate(true)
		sandbox_cells.clear()
		campaign=null
		_save_game()
		if is_instance_valid(view): view.rebuild()
	if is_instance_valid(view): view.close_panel()

func campaign_result(result: Dictionary) -> void:
	if not result.ok: return
	var discovered := unlock(result.form)
	if is_instance_valid(view):
		match result.kind:
			"spawn": view.spawn(result.index)
			"move": view.move(result.source,result.index)
			"merge": view.merge(result.source,result.index,discovered)
	settle_campaign_action()

func settle_campaign_action() -> void:
	if campaign.status=="won":
		last_reward=campaign_progress.finish(int(campaign.config.number))
		coins+=int(last_reward.coins)
	save_extra["campaign"]=campaign_progress.encode()
	_save_game()
	if is_instance_valid(view):
		view.queue_redraw()
		if campaign.status!="active": view.show_panel("result")

func _ready() -> void:
	rng.randomize()
	if not _load_game():
		_start_fresh(not write_blocked)
	reset_dialog = ConfirmationDialog.new()
	reset_dialog.dialog_text = "Начать заново?\nПоле, монеты и коллекция будут сброшены."
	reset_dialog.confirmed.connect(_new_game)
	add_child(reset_dialog)
	view = LabView.new()
	view.game = self
	add_child(view)
	resized.connect(view.layout)
	set_process(true)
	queue_redraw()
	if write_blocked:
		_notice("Ошибка загрузки: файл сохранён. Запись заблокирована до «Новой игры».")

func _process(delta: float) -> void:
	if message_time > 0.0:
		message_time -= delta
		if message_time <= 0.0:
			message = "Соединяйте одинаковые виды одной стадии"
			queue_redraw()
			if is_instance_valid(view):
				view.queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_cancel_drag()
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if cells.size() == COLS * ROWS:
			_save_game()

func _cancel_drag() -> void:
	if is_instance_valid(view):
		view.cancel_selection()
	selected = -1
	dragging = false
	queue_redraw()

func _new_game() -> void:
	if in_campaign():
		start_level(int(campaign.config.number))
		return
	# Explicit confirmed reset permits replacing a damaged v2 save, with a backup.
	needs_backup=FileAccess.file_exists(save_path)
	write_blocked=false
	load_error=""
	_start_fresh(true)

func _start_fresh(persist: bool) -> void:
	_cancel_drag()
	cells.resize(COLS * ROWS)
	cells.fill(null)
	discoveries.clear()
	active_species="slime"
	for index in [6, 8, 16, 18]:
		cells[index] = Catalog.make("slime")
		unlock(cells[index])
	coins = 100
	merges = 0
	message = "Соединяйте одинаковые виды одной стадии"
	message_time = 0.0
	if persist:
		_save_game()
	if is_instance_valid(view):
		view.rebuild()
		view.close_panel()
	queue_redraw()

func unlock(form: Dictionary) -> bool:
	var key := Catalog.key(form)
	if discoveries.has(key):
		return false
	discoveries[key]=true
	return true

func is_unlocked(id: String,stage: int) -> bool:
	return discoveries.has(Catalog.key(Catalog.make(id,stage)))

func known_discoveries() -> int:
	var count := 0
	for key in discoveries:
		if Catalog.known_form(Catalog.from_key(key)):
			count+=1
	return count

func select_species(id: String) -> bool:
	if in_campaign() or not Catalog.available(id) or dragging:
		return false
	active_species=id
	_save_game()
	return true

func _design_position(pos: Vector2) -> Vector2:
	return view.to_local(pos) if is_instance_valid(view) else pos

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press(_design_position(event.position))
		else:
			_release(_design_position(event.position))
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		pointer_pos = _design_position(event.position)
		queue_redraw()
		accept_event()
	elif event is InputEventScreenTouch:
		if event.index != 0:
			return
		if event.pressed:
			_press(_design_position(event.position))
		else:
			_release(_design_position(event.position))
		accept_event()
	elif event is InputEventScreenDrag and dragging:
		if event.index != 0:
			return
		pointer_pos = _design_position(event.position)
		queue_redraw()
		accept_event()

func _press(pos: Vector2) -> void:
	if dragging or (in_campaign() and campaign.status!="active"):
		return
	if Rect2(37, 558, 286, 58).has_point(pos):
		_spawn()
		return
	var index := _cell_at(pos)
	if index >= 0 and cells[index] != null:
		selected = index
		dragging = true
		pointer_pos = pos
		if is_instance_valid(view):
			view.pick(index)
		queue_redraw()

func _release(pos: Vector2) -> void:
	if not dragging:
		return
	var destination := _cell_at(pos)
	if in_campaign():
		var source := selected
		var result := campaign.transfer(source,destination)
		if result.ok: campaign_result(result)
		_cancel_drag()
		return
	if destination >= 0 and destination != selected:
		if cells[destination] == null:
			cells[destination] = cells[selected]
			cells[selected] = null
			if is_instance_valid(view):
				view.move(selected,destination)
			_save_game()
		elif Catalog.can_merge(cells[selected],cells[destination]):
			cells[destination] = Catalog.evolve(cells[destination])
			var new_stage: int = cells[destination].evolution_stage
			cells[selected] = null
			coins += 15 * new_stage
			merges += 1
			var discovered := unlock(cells[destination])
			if is_instance_valid(view):
				view.merge(selected,destination,discovered)
			_notice("%s! +%d монет" % [Catalog.title(cells[destination]),15*new_stage])
			_save_game()
		else:
			_notice("Нужны одинаковые вид и стадия ниже максимальной")
	_cancel_drag()

func _cell_at(pos: Vector2) -> int:
	var x := int(floor((pos.x - BOARD_X) / CELL))
	var y := int(floor((pos.y - BOARD_Y) / CELL))
	if x < 0 or x >= COLS or y < 0 or y >= ROWS:
		return -1
	var index := y * COLS + x
	return -1 if in_campaign() and campaign.blocked(index) else index

func _spawn() -> void:
	if in_campaign():
		campaign_result(campaign.spawn())
		return
	if not Catalog.available(active_species):
		_notice("Выберите доступный вид")
		return
	if coins < SPAWN_COST:
		_notice("Недостаточно монет")
		return
	var empty: Array[int] = []
	for i in range(cells.size()):
		if cells[i] == null:
			empty.append(i)
	if empty.is_empty():
		_notice("Поле заполнено: объедините существ")
		return
	coins -= SPAWN_COST
	var index: int = empty[rng.randi_range(0, empty.size() - 1)]
	cells[index] = Catalog.make(active_species)
	unlock(cells[index])
	if is_instance_valid(view):
		view.spawn(index)
	_save_game()
	queue_redraw()

func _create_requested() -> void:
	# Native buttons also receive touch; a second finger must not buy mid-drag.
	if not dragging:
		_spawn()

func _notice(value: String) -> void:
	message = value
	message_time = 3.0
	queue_redraw()
	if is_instance_valid(view):
		view.queue_redraw()

func _save_game() -> void:
	if write_blocked:
		_notice("Запись заблокирована: исходный файл сохранён")
		return
	if needs_backup and FileAccess.file_exists(save_path):
		var backup := save_path+".pre-update-"+FileAccess.get_sha256(save_path).substr(0,12)+".bak"
		if not FileAccess.file_exists(backup) and DirAccess.copy_absolute(save_path,backup)!=OK:
			_notice("Не удалось создать резервную копию")
			return
	var saved_cells := sandbox_cells if in_campaign() else cells
	var data := SaveCodec.encode(saved_cells,coins,merges,active_species,discoveries,save_extra)
	var temporary_path := save_path+".tmp"
	var file := FileAccess.open(temporary_path,FileAccess.WRITE)
	if file==null:
		_notice("Не удалось сохранить прогресс")
		return
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error!=OK or DirAccess.rename_absolute(temporary_path,save_path)!=OK:
		_notice("Не удалось сохранить прогресс")
	else:
		needs_backup=false

func _load_game() -> bool:
	var source := save_path
	if not FileAccess.file_exists(source):
		# Test/custom paths never fall back to the real player's legacy save.
		if save_path==SAVE_PATH and FileAccess.file_exists(LEGACY_SAVE_PATH):
			source=LEGACY_SAVE_PATH
		else:
			return false
	var file := FileAccess.open(source,FileAccess.READ)
	if file==null or file.get_length()>4194304:
		write_blocked=true
		load_error="Cannot read save"
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text())!=OK:
		write_blocked=true
		load_error="Invalid JSON"
		return false
	file.close()
	var decoded := SaveCodec.decode(json.data,COLS*ROWS)
	if not decoded.ok:
		write_blocked=true
		load_error=decoded.error
		return false
	var progress := CampaignProgress.new()
	if not progress.decode(decoded.extra.get("campaign",{})):
		write_blocked=true
		load_error="Invalid campaign progress"
		return false
	campaign_progress=progress
	campaign=null
	sandbox_cells.clear()
	cells.assign(decoded.cells)
	coins=decoded.coins
	merges=decoded.merges
	active_species=decoded.active_species
	discoveries=decoded.discoveries
	save_extra=decoded.extra
	write_blocked=false
	load_error=""
	needs_backup=decoded.needs_backup and source==save_path
	if source!=save_path:
		# Migration goes into a separate v2 file. The legacy file is never changed.
		_save_game()
	return true

func _valid_integer(value: Variant,maximum: int) -> bool:
	return Catalog.integer(value,maximum)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("b9dfdf"))
