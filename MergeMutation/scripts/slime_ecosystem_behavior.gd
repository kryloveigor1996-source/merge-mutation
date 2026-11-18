extends RefCounted
func allowed_states() -> Array: return ["idle","walk","sleep","inspect","react"]
func allowed_habits() -> Array: return ["jelly_rest","bubble_rest"]
func allowed_events() -> Array: return ["bubble_splat"]
func can_event(_model,_id: String) -> bool: return true
func arrived(model,action: String) -> void:
	if action=="acid_sleep":
		model.remaining=6
		model.sleep_duration=6
	model.feedback={"acid_sleep":"Растворяюсь... тихий час","plasma_feed":"Плазма усвоена!","acid_bath":"Приятная кислотная ванна","biochemical_scan":"Биохимический анализ","inspect_channels":"Куда течёт этот ручеёк?","inspect_plants":"Щекотно!"}.get(action,model.feedback)
	model.feedback_left=2.5
func completed(_model,_action: String) -> void: pass
func event_text(id: String) -> String:
	return "Плюх! Слишком жидкое настроение." if id=="bubble_splat" else ""
func pose(actor,_delta: float) -> void:
	var m=actor.model
	if m.behavior=="inspect" and m.rest_variant=="jelly_rest": actor.art.scale*=Vector2(1.1,0.85)
	elif m.behavior=="inspect" and m.rest_variant=="bubble_rest": actor.art.position.y-=sin(m.elapsed*3)*3
	if m.behavior=="walk":
		actor.art.scale*=Vector2(1+sin(m.elapsed*7)*0.11,1-sin(m.elapsed*7)*0.09)
	if m.action_semantic=="plasma_feed" and m.behavior=="inspect":
		actor.art.scale*=Vector2.ONE*(1+sin(m.elapsed*2)*0.14)
		actor.art.modulate=Color(0.8,1,0.85)
	if m.action_semantic=="acid_bath" and m.behavior=="inspect":
		actor.art.scale*=Vector2(1.16,0.7)
		actor.art.modulate=Color(0.8,1,0.7)
	if m.action_semantic=="acid_sleep" and m.behavior=="sleep":
		var phase: float=m.elapsed
		var amount: float=clampf(phase/1.3,0,1) if phase<3.9 else clampf((6-phase)/2.1,0,1)
		actor.art.scale*=Vector2(1+amount*0.22,maxf(0.08,1-amount*0.92))
		actor.art.position.y+=amount*20
		actor.art.modulate.a=1-amount
		actor.closed_eyes=amount>=0.99
		actor.sleep_dissolved=actor.closed_eyes
	elif actor.sleep_dissolved:
		var wake: float=clampf(actor.wake_left/0.5,0,1)
		actor.art.modulate.a=1-wake
		actor.art.scale*=Vector2(1+wake*0.2,1-wake*0.9)
		if wake==0: actor.sleep_dissolved=false
	if m.rare_event=="bubble_splat":
		actor.art.scale*=Vector2(1.25,0.55+absf(sin(m.rare_elapsed*4))*0.3)
func draw(actor) -> bool:
	if actor.closed_eyes:
		for x in [-12,12]: actor.draw_arc(Vector2(x,-46),7,0,PI,16,Color("243e42"),3)
		for i in range(3): actor.draw_arc(Vector2(-22+i*22,-55-sin(actor.model.elapsed*2+i)*8),3,0,TAU,12,Color("baf4a7"),1)
		return true
	if actor.model.rare_event=="bubble_splat":
		for i in range(4): actor.draw_circle(Vector2(-32+i*21,-65+sin(actor.model.rare_elapsed*6+i)*8),4,Color("b9ef96"))
	return false
