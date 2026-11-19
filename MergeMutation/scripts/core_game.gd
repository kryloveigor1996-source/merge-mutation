extends "res://scripts/main.gd"
const Progress=preload("res://scripts/core_progress.gd")
const Store=preload("res://scripts/profile_store.gd")
const Registry=preload("res://scripts/complex_registry.gd")
const HabitatIndex=preload("res://scripts/ecosystem_catalog.gd")
const CoreView=preload("res://scripts/core_lab.gd")
const Music=preload("res://scripts/music_manager.gd")
signal progression_changed
var progression
var habitat_catalogs: Dictionary={}
var expected_hash:=""
var core_migration:=false
var pending_forms: Dictionary={}
var reward_settled:=false
var reward_pending:=false
var music
var audio_settings_path:="user://merge_mutation_settings.cfg"
func legacy_mode() -> bool:
	var isolated: bool=save_path.begins_with("res://.godot/") or ProjectSettings.globalize_path(save_path).contains("/.godot/")
	return Layout.core_legacy() and isolated
func developer_mode() -> bool:
	return not OS.has_feature("android") and "--developer-profile" in OS.get_cmdline_user_args() and save_path.begins_with("res://.godot/")
func make_view():
	return super.make_view() if legacy_mode() else CoreView.new()
func _ready() -> void:
	super._ready()
	if not legacy_mode():
		music=Music.new()
		music.settings_path=audio_settings_path
		add_child(music)
		for player in view.sound.players.values(): player.bus="SFX"
		view.sound.set_enabled(music.volumes.sfx>0)
		music.volumes_changed.connect(func(): view.sound.set_enabled(music.volumes.sfx>0))
		get_tree().quit_on_go_back=false
func _load_game() -> bool:
	if legacy_mode(): return super._load_game()
	var loaded:=super._load_game()
	if not loaded: return false
	expected_hash=FileAccess.get_sha256(save_path) if FileAccess.file_exists(save_path) else ""
	progression=Progress.new()
	if not prepare_catalogs(): return block_core("Не удалось прочитать каталог вольеров")
	var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string(save_path)) if FileAccess.file_exists(save_path) else {}
	if save_extra.has("core_progress"):
		if not progression.decode(save_extra.core_progress,campaign_progress.completed): return block_core(progression.error)
		# Sandbox organisms are not campaign discoveries. Preserve exactly the saved collection.
		if raw is Dictionary and raw.get("discoveries") is Array:
			discoveries.clear()
			for key in raw.discoveries: discoveries[key]=true
	else:
		core_migration=true
		progression.initial()
		for number in campaign_progress.completed: progression.claim("lab_%02d" % number)
		if not import_demo(): return false
	if not validate_installed(): return block_core("Сохранение содержит неизвестные оформления. Исходник не изменён.")
	if core_migration:
		if not commit_progress(progression.copy()): return block_core("Перенос не завершён. Исходник сохранён.")
	return true
func prepare_catalogs() -> bool:
	var registry:=Registry.new()
	if not registry.load_files(): return false
	var index:=HabitatIndex.new()
	if not index.load_file(registry,"res://data/ecosystems.json"): return false
	habitat_catalogs=index.catalogs
	return true
func block_core(reason: String) -> bool:
	write_blocked=true
	load_error=reason
	return false
func import_demo() -> bool:
	var path:=save_path+".habitat-demo-v1.json"
	if not FileAccess.file_exists(path): return true
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>1048576: return block_core("Не удалось прочитать прежнее оформление")
	var raw: Variant=JSON.parse_string(file.get_as_text())
	file.close()
	if not raw is Dictionary or raw.get("format")!="merge_mutation_demo_renovation" or not Catalog.integer(raw.get("version"),2) or int(raw.get("version",0))<1 or not raw.get("habitats") is Dictionary: return block_core("Неверный формат прежнего оформления")
	var mappings: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/ecosystems/pr18-design-map.json"))
	for id in raw.habitats:
		if not habitat_catalogs.has(id): continue
		var room: Variant=raw.habitats[id]
		if not room is Dictionary or not room.get("installed",{}) is Dictionary: return block_core("Неверное прежнее оформление")
		var choices: Dictionary=room.get("installed",{}).duplicate(true)
		if raw.version==1:
			for slot in choices:
				var mapped: Variant=mappings.get(id,{}).get(slot,{}).get(choices[slot],choices[slot])
				choices[slot]=mapped
		progression.data.habitats[id]=choices
	var backup:=path+".pre-core-loop-"+FileAccess.get_sha256(path).substr(0,12)+".bak"
	if not FileAccess.file_exists(backup) and DirAccess.copy_absolute(path,backup)!=OK: return block_core("Не удалось сохранить копию прежнего оформления")
	return true
func validate_installed() -> bool:
	for id in progression.data.habitats:
		if not habitat_catalogs.has(id): return false
		for slot in progression.data.habitats[id]:
			var choice: Variant=progression.data.habitats[id][slot]
			if not choice is String or habitat_catalogs[id].design(slot,choice).is_empty(): return false
	return true
func _start_fresh(persist: bool) -> void:
	if legacy_mode(): super._start_fresh(persist); return
	if progression==null:
		progression=Progress.new()
		progression.initial()
		prepare_catalogs()
	super._start_fresh(false)
	if persist: _save_game()
func unlock(form: Dictionary) -> bool:
	if legacy_mode(): return super.unlock(form)
	if in_campaign(): pending_forms[Catalog.key(form)]=form.duplicate(true)
	return false
func habitat_for_species(id: String) -> String:
	for habitat in habitat_catalogs:
		if habitat=="habitat_"+id: return habitat
	return ""
func species_known(id: String) -> bool:
	for stage in range(1,Catalog.maximum(id)+1):
		if is_unlocked(id,stage): return true
	return false
func commit_progress(candidate,coin_balance: int=-1,progress=null,known=null) -> bool:
	if write_blocked or candidate==null: return false
	var extra: Dictionary=save_extra.duplicate(true)
	extra.core_progress=candidate.data.duplicate(true)
	var campaign_data=campaign_progress if progress==null else progress
	extra.campaign=campaign_data.encode()
	var discoveries_data: Dictionary=discoveries if known==null else known
	var saved_cells: Array=sandbox_cells if in_campaign() else cells
	var encoded:=SaveCodec.encode(saved_cells,coins if coin_balance<0 else coin_balance,merges,active_species,discoveries_data,extra)
	var result:=Store.write(save_path,encoded,expected_hash,core_migration or needs_backup)
	if not result.ok:
		_notice(result.reason)
		return false
	expected_hash=result.hash
	progression=candidate
	save_extra=extra
	campaign_progress=campaign_data
	if coin_balance>=0: coins=coin_balance
	discoveries=discoveries_data.duplicate(true)
	core_migration=false
	needs_backup=false
	progression_changed.emit()
	return true
func _save_game() -> void:
	if legacy_mode(): super._save_game(); return
	if progression!=null: commit_progress(progression.copy())
func preview_boosters() -> Dictionary:
	return super.preview_boosters() if legacy_mode() else {"teleporter":0}
func start_level(number: int,test_boosters: bool=true) -> bool:
	if legacy_mode(): return super.start_level(number,test_boosters)
	if reward_pending or write_blocked: return false
	pending_forms.clear()
	reward_settled=false
	return super.start_level(number,test_boosters and developer_mode())
func leave_campaign() -> void:
	if not legacy_mode() and reward_pending:
		_notice("Сначала сохраните результат")
		return
	super.leave_campaign()
func settle_campaign_action() -> void:
	if legacy_mode(): super.settle_campaign_action(); return
	if campaign.status=="won":
		if not reward_settled: settle_victory()
	elif campaign.status!="active":
		reward_pending=false
		last_reward={"coins":0,"stars":0,"bio_capsules":0}
		_save_game()
	else: _save_game()
	if is_instance_valid(view):
		view.queue_redraw()
		if campaign.status!="active": view.show_panel("result")
func settle_victory() -> void:
	var candidate=progression.copy()
	var campaign_copy:=CampaignProgress.new()
	campaign_copy.decode(campaign_progress.encode())
	var reward: Dictionary=campaign_copy.finish(int(campaign.config.number))
	var amount: int=candidate.claim(campaign.config.id)
	if amount<0:
		reward_pending=true
		last_reward={"coins":0,"bio_capsules":0,"error":"Достигнут предел биокапсул. Результат не изменил профиль."}
		return
	var known: Dictionary=discoveries.duplicate(true)
	var opened: Array=[]
	for form in pending_forms.values():
		var id: String=form.species_id
		if not species_known(id) and id not in opened: opened.append(id)
		known[Catalog.key(form)]=true
	if not commit_progress(candidate,coins+int(reward.coins),campaign_copy,known):
		reward_pending=true
		last_reward={"coins":0,"stars":0,"bio_capsules":0,"error":"Не удалось сохранить награду. Повторите сохранение."}
		return
	reward_pending=false
	reward_settled=true
	last_reward={"coins":reward.coins,"stars":reward.stars,"bio_capsules":amount,"species":opened,"first":amount>0}
	if is_instance_valid(music):
		music.event("victory")
		if not opened.is_empty(): music.event("discovery")
	if campaign.config.id=="lab_10" and amount>0 and not journey_state.has_seen("swamp_activation") and is_instance_valid(view): view.show_story("swamp_activation")
func install_item(habitat: String,slot: String,choice: String) -> Dictionary:
	if write_blocked or not habitat_catalogs.has(habitat): return {"ok":false,"reason":"Вольер недоступен"}
	var cat=habitat_catalogs[habitat]
	var species: String="slime" if habitat=="habitat_slime" else "horn"
	if not species_known(species) or cat.design(slot,choice).is_empty(): return {"ok":false,"reason":"Предмет недоступен"}
	var installed: Dictionary=progression.installed(habitat)
	var offers: Array=[]
	for id in cat.offers:
		if installed.has(id): continue
		var ready:=true
		for dependency in cat.slots[id].requires:
			if not installed.has(dependency): ready=false
		if ready: offers.append(id)
		if offers.size()>=cat.offer_limit: break
	if not installed.has(slot) and slot not in offers: return {"ok":false,"reason":"Стройплощадка пока недоступна"}
	var candidate=progression.copy()
	var result: Dictionary=candidate.install(habitat,slot,choice)
	if not result.ok or not result.changed: return result
	if not commit_progress(candidate): return {"ok":false,"reason":"Не удалось сохранить установку. Биокапсулы не списаны."}
	return result
func observe(habitat: String,event: String) -> void:
	if legacy_mode() or write_blocked: return
	var candidate=progression.copy()
	var title: String=candidate.record(habitat,event)
	if title.is_empty(): return
	if commit_progress(candidate):
		_notice("Новое наблюдение: "+title)
		if is_instance_valid(view.complex_ui) and is_instance_valid(view.complex_ui.detail):
			view.complex_ui.detail.model.feedback="Новое наблюдение: "+title
			view.complex_ui.detail.model.feedback_left=4
func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_GO_BACK_REQUEST and not legacy_mode() and is_instance_valid(view):
		view.handle_back()
		return
	super._notification(what)
