extends Node
## Scroll owns a gesture until release; taps dispatch once, native editors/sliders pass through.
var container: ScrollContainer
var enabled: Callable
var tapped: Callable
var horizontal_control: Control
var horizontal_swipe: Callable
var pointer=-99
var start=Vector2.ZERO
var last=Vector2.ZERO
var travel=0.0
var horizontal=false
static func attach(target: ScrollContainer,gate: Callable,on_tap: Callable=Callable()):
	var handler=load("res://scripts/mobile_scroll.gd").new()
	handler.container=target; handler.enabled=gate; handler.tapped=on_tap; target.add_child(handler); return handler
func control_at(node: Node,point: Vector2,editors: bool=false):
	var children=node.get_children(); children.reverse()
	for child in children:
		if child is Control and child.is_visible_in_tree():
			var found=control_at(child,point,editors)
			if found!=null: return found
	if node is Control and node.is_visible_in_tree() and Rect2(Vector2.ZERO,node.size).has_point(node.get_global_transform_with_canvas().affine_inverse()*point):
		if editors and (node is Range or node is LineEdit or node is OptionButton): return node
		if not editors and node is BaseButton and not node.disabled: return node
	return null
func _input(event: InputEvent) -> void:
	var viewport=get_viewport()
	if viewport==null: return
	if not is_instance_valid(container) or not container.is_visible_in_tree() or not enabled.call(): pointer=-99; return
	var point=Vector2.ZERO; var down=false; var up=false; var motion=false; var id=-99
	if event is InputEventScreenTouch:
		if event.index!=0 or event.canceled: pointer=-99; return
		point=event.position; id=0; down=event.pressed; up=not down
	elif event is InputEventScreenDrag:
		if event.index!=0: pointer=-99; return
		point=event.position; id=0; motion=true
	elif event is InputEventMouseButton:
		point=event.position; id=-2
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			if event.pressed and Rect2(Vector2.ZERO,container.size).has_point(container.get_global_transform_with_canvas().affine_inverse()*point):
				container.scroll_vertical+=72 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -72; viewport.set_input_as_handled()
			return
		if event.button_index!=MOUSE_BUTTON_LEFT: return
		down=event.pressed; up=not down
	elif event is InputEventMouseMotion: point=event.position; id=-2; motion=true
	else: return
	var local=container.get_global_transform_with_canvas().affine_inverse()*point
	if down and Rect2(Vector2.ZERO,container.size).has_point(local):
		if control_at(container,point,true)!=null: pointer=-99; return
		pointer=id; start=local; last=local; travel=0
		horizontal=is_instance_valid(horizontal_control) and Rect2(Vector2.ZERO,horizontal_control.size).has_point(horizontal_control.get_global_transform_with_canvas().affine_inverse()*point)
		viewport.set_input_as_handled()
	elif pointer==id and motion:
		travel+=local.distance_to(last)
		if travel>12 and not (horizontal and absf(local.x-start.x)>absf(local.y-start.y)*1.3): container.scroll_vertical-=roundi(local.y-last.y)
		last=local; viewport.set_input_as_handled()
	elif pointer==id and up:
		pointer=-99
		var delta=local-start
		if horizontal and absf(delta.x)>48 and absf(delta.x)>absf(delta.y)*1.3 and horizontal_swipe.is_valid(): horizontal_swipe.call(delta)
		elif maxf(travel,delta.length())<12 and Rect2(Vector2.ZERO,container.size).has_point(local):
			if tapped.is_valid(): tapped.call(local)
			else:
				var button=control_at(container,point)
				if button!=null: button.pressed.emit()
		viewport.set_input_as_handled()
