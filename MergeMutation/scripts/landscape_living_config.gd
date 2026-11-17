extends RefCounted
const Registry=preload("res://scripts/living_registry.gd")
const ZONES=["west","central","east"]
static func zones(width: float) -> Dictionary:
	var result: Dictionary={}
	for i in range(ZONES.size()): result[ZONES[i]]=Rect2(i*width/3,0,width/3,420)
	return result
static func build(base,complex_registry,mode: String):
	var panoramic:=mode=="panorama"
	var width:=2350.0 if panoramic else 940.0
	var data: Dictionary={"habitats":base.assignments.values().duplicate(true),"profiles":base.profiles.values().duplicate(true),"stages":base.stages.values().duplicate(true),"objects":base.objects.values().duplicate(true)}
	var positions: Dictionary={"monitor":Vector2(2100 if panoramic else 780,76),"bench":Vector2(350 if panoramic else 80,280),"fern":Vector2(150 if panoramic else 60,312),"grass":Vector2(1100 if panoramic else 430,365),"training_rock":Vector2(1700 if panoramic else 650,292),"ridge":Vector2(900 if panoramic else 130,80),"boulder":Vector2(1300 if panoramic else 420,226),"vine":Vector2(2270 if panoramic else 880,24),"lamp":Vector2(1500 if panoramic else 450,16)}
	for object in data.objects:
		var point: Vector2=positions[object.object_id]
		object.rect[0]=point.x
		object.rect[1]=point.y
		if object.type=="ridge": object.rect[2]=650
	for profile in data.profiles:
		profile.start_x=700 if panoramic else 360
		profile.walk_range=[48,width-48]
		profile.movement_speed=80 if panoramic else 58
	var result:=Registry.new()
	return result if result.configure(data,complex_registry,width) else null
