extends Node
## Explicit touch/wheel handling for text/list scrolls with mouse emulation disabled.
var container: ScrollContainer
var enabled: Callable
var tapped: Callable
var pointer=-99
var start=Vector2.ZERO
var last=Vector2.ZERO
var travel=0.0
static func attach(target: ScrollContainer,gate: Callable,on_tap: Callable=Callable()):
	var handler=load("res://scripts/evolution_touch_scroll.gd").new()
	handler.container=target; handler.enabled=gate; handler.tapped=on_tap
	target.add_child(handler)
	return handler
func _input(event: InputEvent) -> void:
	if not is_instance_valid(container) or not container.is_visible_in_tree() or not enabled.call(): pointer=-99; return
	var down=false
	var up=false
	var motion=false
	var id=-99
	var point=Vector2.ZERO
	if event is InputEventScreenTouch:
		if event.index!=0: return
		if event.canceled:
			pointer=-99
			return
		point=event.position; id=event.index; down=event.pressed; up=not down
	elif event is InputEventScreenDrag:
		if event.index!=0: return
		point=event.position; id=event.index; motion=true
	elif event is InputEventMouseButton:
		point=event.position; id=-2
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var local=container.get_global_transform_with_canvas().affine_inverse()*point
			if event.pressed and Rect2(Vector2.ZERO,container.size).has_point(local):
				container.scroll_vertical+=72 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -72
				get_viewport().set_input_as_handled()
			return
		if event.button_index!=MOUSE_BUTTON_LEFT: return
		down=event.pressed; up=not down
	elif event is InputEventMouseMotion: point=event.position; id=-2; motion=true
	else: return
	point=container.get_global_transform_with_canvas().affine_inverse()*point
	if down and pointer==-99 and Rect2(Vector2.ZERO,container.size).has_point(point):
		pointer=id; start=point; last=point; travel=0
		get_viewport().set_input_as_handled()
	elif pointer==id and motion:
		travel+=point.distance_to(last)
		if travel>12: container.scroll_vertical-=roundi(point.y-last.y)
		last=point
		get_viewport().set_input_as_handled()
	elif pointer==id and up:
		pointer=-99
		if maxf(travel,point.distance_to(start))<12 and Rect2(Vector2.ZERO,container.size).has_point(point) and tapped.is_valid(): tapped.call(point)
		get_viewport().set_input_as_handled()