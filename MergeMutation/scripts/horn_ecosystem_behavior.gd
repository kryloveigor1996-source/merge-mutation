extends RefCounted
func allowed_states() -> Array: return ["idle","walk","sleep","inspect","react","ram"]
func allowed_habits() -> Array: return ["curl","guard","listen"]
func allowed_events() -> Array: return ["dust_sneeze","monument_push","proud_ram"]
func can_event(model,id: String) -> bool:
	if id=="proud_ram": return model.hit_count>0 and model.simulation_time-model.last_successful_ram<3
	if id=="monument_push":
		var slot: Dictionary=model.renovation.catalog.slots.cabinets
		return absf(model.renovation.catalog.project_rect(slot,model.registry.world_width).get_center().x-model.position.x)<=110
	return true
func arrived(model,action: String) -> void:
	model.feedback={"sleep":"Тихий час в ущелье","mineral_feed":"Хрустящие минералы!","lab_scan":"Интересно, что измеряет эта штука?","monument":"Кажется, тяжеловат...","inspect_trophy":"Достойный трофей!","play":"Этот валун сам себя не перекатит."}.get(action,model.feedback)
	model.feedback_left=2.5
func completed(model,action: String) -> void:
	if action=="ram" and model.stone_broken: model.request_rare("proud_ram")
	if action=="monument": model.request_rare("monument_push")
func event_text(id: String) -> String:
	return {"dust_sneeze":"Апчхи! Каменная пыль!","monument_push":"Ни на миллиметр... Так и задумано.","proud_ram":"Вот это были рога!"}.get(id,"")
func pose(actor,_delta: float) -> void:
	var m=actor.model
	if m.rest_variant=="curl" and m.behavior=="inspect": actor.art.scale*=Vector2(1.12,0.83)
	elif m.rest_variant=="guard" and m.behavior=="inspect": actor.art.position.y-=3
	elif m.rest_variant=="listen" and m.behavior=="inspect": actor.art.rotation=sin(m.elapsed*3)*0.07
	match m.rare_event:
		"dust_sneeze":
			actor.art.position.x+=sin(m.rare_elapsed*28)*5
			actor.art.scale*=Vector2(1.08,0.92)
		"monument_push": actor.art.rotation=-0.16; actor.art.position.x+=sin(m.rare_elapsed*9)*4
		"proud_ram": actor.art.position.y-=absf(sin(m.rare_elapsed*3))*8
func draw(actor) -> bool:
	if actor.model.rare_event=="proud_ram":
		for i in range(5): actor.draw_circle(Vector2.from_angle(-PI+i*PI/4)*62+Vector2(0,-28),3,Color("ffe287"))
	if actor.model.rare_event=="dust_sneeze":
		for i in range(6): actor.draw_circle(Vector2(28+i*6,-40+(i%3)*7),2,Color("d8cba6"))
	return false
