extends RefCounted
## Commit one short primary-pointer click on release, never on press or motion.
const MAX_TRAVEL=12.0
const MAX_SECONDS=0.45
var active=false
var origin=Vector2.ZERO
var previous=Vector2.ZERO
var travel=0.0
var started=0
var touch=false
var secondary: Dictionary={}
func cancel() -> void:
	active=false; secondary.clear()
func feed(event: InputEvent) -> Dictionary:
	var point=Vector2.ZERO
	var down=false
	var up=false
	var motion=false
	var screen=event is InputEventScreenTouch or event is InputEventScreenDrag
	if screen and event.index!=0:
		if event is InputEventScreenTouch:
			if event.pressed and not event.canceled: secondary[event.index]=true
			else: secondary.erase(event.index)
		active=false
		return {}
	if not secondary.is_empty(): active=false; return {}
	if event is InputEventScreenTouch:
		if event.canceled: cancel(); return {}
		point=event.position; down=event.pressed; up=not down
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		point=event.position; down=event.pressed; up=not down
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		point=event.position; motion=true
	else: return {}
	if down:
		if active: cancel(); return {}
		active=true; touch=screen; origin=point; previous=point; travel=0; started=Time.get_ticks_msec()
	elif active and screen==touch:
		travel+=point.distance_to(previous); previous=point
		if motion: return {}
		if up:
			active=false
			if travel<=MAX_TRAVEL and Time.get_ticks_msec()-started<=MAX_SECONDS*1000:
				return {"origin":origin,"point":point}
	return {}
