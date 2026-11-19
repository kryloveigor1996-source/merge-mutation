extends RefCounted
## Habitat metadata references the existing species catalog; it never defines species.
const Species=preload("res://scripts/mutant_catalog.gd")
const Renovation=preload("res://scripts/renovation_catalog.gd")
const Behaviors=preload("res://scripts/ecosystem_behaviors.gd")
var rooms: Dictionary={}
var sizes: Dictionary={}
var catalogs: Dictionary={}
var error:=""
static func default_path() -> String:
	return "res://tests/fixtures/ecosystems_pr19.json" if "--living-world-legacy" in OS.get_cmdline_user_args() else "res://data/ecosystems.json"
func load_file(complex_registry,path: String="") -> bool:
	if path.is_empty(): path=default_path()
	return configure(JSON.parse_string(FileAccess.get_file_as_string(path)),complex_registry)
func fail(message: String) -> bool:
	rooms.clear()
	catalogs.clear()
	error=message
	return false
func configure(data: Variant,complex_registry) -> bool:
	fail("")
	if not data is Dictionary or data.get("version")!=1 or not data.get("rooms") is Array or not data.get("room_sizes") is Dictionary: return fail("Неверные экосистемы")
	sizes=data.room_sizes.duplicate()
	for id in ["S","M","L","XL"]:
		if not Species.integer(sizes.get(id),9400) or sizes[id]<940: return fail("Неверный размер вольера")
	if sizes.S!=940 or sizes.M<1880 or sizes.L<2820 or sizes.XL<4700: return fail("Неверная шкала помещений")
	for room in data.rooms:
		if not room is Dictionary or not Species.valid_id(room.get("habitat_id")) or rooms.has(room.habitat_id) or not Species.available(room.get("species_id","")): return fail("Неверная ссылка на вид")
		var existing: Dictionary=complex_registry.get_habitat(room.habitat_id)
		if existing.is_empty() or existing.get("species_id")!=room.species_id: return fail("Несовпадение вида и вольера")
		if not sizes.has(room.get("room_size")) or room.get("movement_driver") not in ["ground_horizontal","slime_crawl"] or not Behaviors.DRIVERS.has(room.get("behavior_driver")): return fail("Неверный профиль")
		var driver=Behaviors.DRIVERS[room.behavior_driver].new()
		for key in ["origin","habitat_type","temperament","catalog"]:
			if not room.get(key) is String or room[key].is_empty(): return fail("Нет описания среды")
		if not room.catalog.begins_with("res://") or not Species.integer(room.get("movement_speed"),400) or room.movement_speed<1 or not Species.integer(room.get("start_x"),9400) or room.start_x<48 or room.start_x>sizes[room.room_size]-48: return fail("Неверное движение")
		if not room.get("motion_profile") is Dictionary: return fail("Нет профиля движения")
		var motion: Dictionary=room.motion_profile
		if not number(motion.get("ground_y"),100,420) or not number(motion.get("body_radius"),1,48) or not number(motion.get("body_height"),1,100) or not number(motion.get("interaction_cooldown"),0.2,10): return fail("Неверная геометрия обитателя")
		for range_id in ["idle_duration_range","sleep_duration_range"]:
			var pair: Variant=motion.get(range_id)
			if not pair is Array or pair.size()!=2 or not number(pair[0],0.2,30) or not number(pair[1],0.2,30) or pair[1]<pair[0]: return fail("Неверная длительность поведения")
		var cat:=Renovation.new()
		if not cat.load_file(room.catalog) or cat.habitat_id!=room.habitat_id or cat.world_size.x!=sizes[room.room_size]: return fail("Неверный каталог среды: "+cat.error)
		for key in ["available_actions","preferred_objects","habits","rare_events","autonomy","decorative_slots","functional_slots","laboratory_slots"]:
			if not room.get(key) is Array: return fail("Отсутствует массив "+key)
		if room.habits.is_empty() or room.autonomy.is_empty(): return fail("Пустое поведение")
		for habit in room.habits:
			if habit not in driver.allowed_habits(): return fail("Неверная привычка")
		var actions: Dictionary={}
		for action in room.available_actions:
			if not Species.valid_id(action) or actions.has(action): return fail("Неверное действие")
			actions[action]=true
		for key in ["preferred_objects","decorative_slots","functional_slots","laboratory_slots"]:
			var seen: Dictionary={}
			for id in room[key]:
				if not cat.slots.has(id) or seen.has(id): return fail("Неверная ссылка предмета")
				seen[id]=true
		for slot in cat.slots.values():
			if slot.get("action","none")!="none" and not actions.has(slot.action): return fail("Неизвестное действие слота")
		for weight in room.autonomy:
			if not weight is Dictionary or not actions.has(weight.get("action")) or not number(weight.get("weight"),0.01,100) or not number(weight.get("repeat_after"),1,600): return fail("Неверный вес поведения")
		var events: Dictionary={}
		for event in room.rare_events:
			if not event is Dictionary or not Species.valid_id(event.get("event_id")) or events.has(event.event_id) or not number(event.get("cooldown"),15,600) or not number(event.get("duration"),0.5,8) or not number(event.get("weight"),0.01,100): return fail("Неверное редкое событие")
			if event.get("requires_slot","")!="" and not cat.slots.has(event.requires_slot): return fail("Неверная цель события")
			if event.event_id not in driver.allowed_events(): return fail("Неизвестное событие профиля")
			events[event.event_id]=true
		rooms[room.habitat_id]=room.duplicate(true)
		catalogs[room.habitat_id]=cat
	return true
static func number(value: Variant,low: float,high: float) -> bool:
	return (value is int or value is float) and is_finite(value) and value>=low and value<=high
