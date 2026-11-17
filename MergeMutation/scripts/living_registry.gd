extends RefCounted
const Catalog=preload("res://scripts/mutant_catalog.gd")
const MOTION_DRIVERS={"ground_horizontal":preload("res://scripts/habitat_ground_motion.gd")}
var assignments: Dictionary={}
var profiles: Dictionary={}
var stages: Dictionary={}
var objects: Dictionary={}
var world_width:=340.0
var error:=""
func load_files(complex_registry) -> bool:
	var values: Dictionary={}
	for file in ["habitats","profiles","stages","objects"]:
		var path: String="res://data/living/"+file+".json"
		if not FileAccess.file_exists(path): return fail("Конфигурация среды отсутствует")
		var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		if not data is Dictionary or not data.get(file) is Array: return fail("Неверная конфигурация среды")
		values[file]=data[file]
	return configure(values,complex_registry)
func fail(message: String) -> bool:
	error=message
	assignments.clear()
	profiles.clear()
	stages.clear()
	objects.clear()
	return false
func configure(data: Dictionary,complex_registry,display_width: float=340.0) -> bool:
	fail("")
	if not is_finite(display_width) or display_width<340 or display_width>4000: return fail("Неверная ширина среды")
	world_width=display_width
	for kind in ["habitats","profiles","stages","objects"]:
		if not data.get(kind) is Array: return fail("Отсутствует массив "+kind)
	for object in data.objects:
		if not object is Dictionary or not Catalog.valid_id(object.get("object_id")) or objects.has(object.object_id) or object.get("layer") not in ["far","objects","front","light"] or not object.get("solid") is bool or not Catalog.valid_id(object.get("type")): return fail("Неверный объект")
		if not object.get("rect") is Array or object.rect.size()!=4: return fail("Неверная геометрия объекта")
		for value in object.rect:
			if not (value is int or value is float) or not is_finite(value) or value<0: return fail("Неверные координаты")
		if object.rect[2]<=0 or object.rect[3]<=0 or object.rect[0]+object.rect[2]>world_width or object.rect[1]+object.rect[3]>420: return fail("Объект вне среды")
		objects[object.object_id]=object.duplicate(true)
	for stage in data.stages:
		if not stage is Dictionary or not Catalog.integer(stage.get("stage"),4) or stage.stage<1 or stages.has(int(stage.stage)) or not stage.get("name") is String or not stage.get("resident") is bool or not stage.get("objects") is Array or not stage.get("mountains") is bool or not stage.get("warm_light") is bool: return fail("Неверная стадия")
		var seen: Dictionary={}
		for id in stage.objects:
			if not objects.has(id) or seen.has(id): return fail("Неверная ссылка объекта")
			seen[id]=true
		stages[int(stage.stage)]=stage.duplicate(true)
	if stages.size()!=4 or stages[1].resident: return fail("Нужны четыре стадии и пустая первая")
	for profile in data.profiles:
		if not profile is Dictionary or not Catalog.valid_id(profile.get("profile_id")) or profiles.has(profile.profile_id) or not Catalog.available(profile.get("species_id","")) or not MOTION_DRIVERS.has(profile.get("movement_type")): return fail("Неподдерживаемый профиль передвижения")
		if not profile.get("allowed_behaviors") is Array or profile.allowed_behaviors.is_empty() or not profile.get("preferred_objects") is Array: return fail("Неверный набор поведения")
		for state in profile.allowed_behaviors:
			if state not in ["idle","walk","sleep","inspect","react","ram"]: return fail("Неизвестное поведение")
		for id in profile.preferred_objects:
			if not objects.has(id): return fail("Неизвестный интересующий объект")
		for key in ["movement_speed","interaction_cooldown","body_radius","body_height","ground_y","start_x"]:
			if not (profile.get(key) is int or profile.get(key) is float) or not is_finite(float(profile[key])) or profile[key]<=0 or profile[key]>(world_width if key=="start_x" else 420): return fail("Неверный параметр профиля")
		for key in ["idle_duration_range","sleep_duration_range","walk_range"]:
			if not profile.get(key) is Array or profile[key].size()!=2: return fail("Неверный диапазон")
			for value in profile[key]:
				if not (value is int or value is float) or not is_finite(value) or value<0: return fail("Неверный диапазон")
			if profile[key][0]>=profile[key][1]: return fail("Пустой диапазон")
		if profile.walk_range[0]<profile.body_radius or profile.walk_range[1]+profile.body_radius>world_width or profile.start_x<profile.walk_range[0] or profile.start_x>profile.walk_range[1]: return fail("Область прогулки вне среды")
		profiles[profile.profile_id]=profile.duplicate(true)
	for assignment in data.habitats:
		if not assignment is Dictionary or not Catalog.valid_id(assignment.get("habitat_id")) or assignments.has(assignment.habitat_id) or not profiles.has(assignment.get("behavior_profile")) or not Catalog.integer(assignment.get("default_stage"),4) or assignment.default_stage<1: return fail("Неверное назначение вольера")
		var room: Dictionary=complex_registry.get_habitat(assignment.habitat_id)
		if room.is_empty() or assignment.get("species_id")!=room.get("species_id") or profiles[assignment.behavior_profile].species_id!=assignment.species_id: return fail("Вид и вольер не совпадают")
		assignments[assignment.habitat_id]=assignment.duplicate(true)
	return true
func stage_objects(stage: int) -> Array:
	var result: Array=[]
	for id in stages[stage].objects: result.append(objects[id])
	return result
