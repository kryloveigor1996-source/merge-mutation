extends Node2D
## Presentation adapter: replace procedural poses with frame animations here later.
const Art=preload("res://scripts/mutant_art.gd")
var art: Node2D
var model
var last_state:=""
var wake_left:=0.0
var facing_scale:=1.0
func setup(value) -> void:
	model=value
	art=Art.new()
	art.setup_form({"species_id":model.profile.species_id,"evolution_stage":1})
	add_child(art)
func pose(delta: float,world_scale: Vector2) -> void:
	visible=model.inhabited()
	if not visible: return
	if last_state=="sleep" and model.behavior!="sleep": wake_left=0.5
	last_state=model.behavior
	wake_left=maxf(0,wake_left-delta)
	position=model.position
	facing_scale=move_toward(facing_scale,model.facing,delta*9)
	var breathe:=sin(model.elapsed*2.6)*0.018
	var squash:=Vector2(1-breathe,1+breathe)
	var shift:=Vector2(0,-35)
	rotation=0
	match model.behavior:
		"walk":
			shift.y-=absf(sin(model.elapsed*9))*3
			rotation=sin(model.elapsed*9)*0.025
		"sleep":
			squash=Vector2(1.04,0.94+sin(model.elapsed*1.5)*0.012)
			shift.y+=4
		"inspect": rotation=sin(model.elapsed*2)*0.045
		"react":
			shift.y-=sin(clampf(model.elapsed/0.8,0,1)*PI)*18
		"ram":
			if model.elapsed<0.4:
				shift.x=-model.facing*model.elapsed*12
				squash=Vector2(1.02,0.97)
			elif model.elapsed<0.7: shift.x=model.facing*sin((model.elapsed-0.4)/0.3*PI)*11
	if wake_left>0: shift.y+=wake_left*5
	var unit:=minf(world_scale.x,world_scale.y)
	art.scale=Vector2(unit/world_scale.x,unit/world_scale.y)*squash*1.6
	art.scale.x*=1 if facing_scale>=0 else -1
	art.position=shift
	queue_redraw()
func _draw() -> void:
	if model==null or not model.inhabited(): return
	if model.behavior=="sleep":
		draw_string(ThemeDB.fallback_font,Vector2(18,-78-sin(model.elapsed)*4),"Z z",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("eff1ce"))
	elif model.behavior=="react":
		for i in range(3): draw_circle(Vector2.from_angle(-PI*0.8+i*0.65)*50+Vector2(0,-25),2.5,Color("ffe589"))
