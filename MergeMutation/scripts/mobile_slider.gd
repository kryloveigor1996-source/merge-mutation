extends HSlider
## Native touch with mouse emulation disabled; mouse remains handled by HSlider.
var touch_tracking=false
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.index!=0: touch_tracking=false; return
		if event.canceled: touch_tracking=false; accept_event(); return
		if event.pressed: touch_tracking=true
		elif not touch_tracking: return
		else: touch_tracking=false
		value=min_value+(max_value-min_value)*clampf((event.position.x-12)/maxf(1,size.x-24),0,1)
		accept_event()
	elif event is InputEventScreenDrag and event.index==0 and touch_tracking:
		value=min_value+(max_value-min_value)*clampf((event.position.x-12)/maxf(1,size.x-24),0,1); accept_event()
