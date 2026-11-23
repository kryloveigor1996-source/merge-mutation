extends RefCounted
## Presentation only. World and collision coordinates never change with the camera.
var bounds=Rect2(0,0,940,420)
var viewport=Vector2(500,600)
var position=Vector2.ZERO
var target=Vector2.ZERO
var zoom=1.0
var auto_zoom=1.0
var zoom_ratio=1.0
var profile: Dictionary={}
var axes: Array=["x"]
var transitioning=false
func configure(value: Dictionary,world_bounds: Rect2,area: Vector2,preserve: bool=false) -> void:
	var center=position+visible_size()*.5
	profile=value.duplicate(true); bounds=world_bounds; viewport=area
	axes=profile.get("axes",["x"])
	var desired=area.x/maxf(1,bounds.size.x*float(profile.get("view_fraction",.8)))
	auto_zoom=clampf(desired,float(profile.get("zoom_min",.4)),float(profile.get("zoom_max",1.5)))
	if not preserve: zoom_ratio=1.0
	zoom=clampf(auto_zoom*zoom_ratio,float(profile.get("zoom_min",.4)),float(profile.get("zoom_max",1.5)))
	position=clamp_point(center-visible_size()*.5) if preserve else clamp_point(position); target=clamp_point(target)
func visible_size() -> Vector2: return viewport/maxf(.01,zoom)
func clamp_point(value: Vector2) -> Vector2:
	var available=visible_size()
	var result=value
	for axis in [0,1]:
		var start=bounds.position[axis]; var length=bounds.size[axis]
		if available[axis]>=length: result[axis]=start+(length-available[axis])*.5
		else: result[axis]=clampf(value[axis],start,start+length-available[axis])
	if "y" not in axes: result.y=bounds.end.y-available.y
	return result
func focus(point: Vector2,immediate: bool=false) -> void:
	target=clamp_point(point-visible_size()*.5); transitioning=not immediate
	if immediate: position=target
func pan(delta: Vector2) -> void:
	transitioning=false
	var offset=delta/zoom
	if "x" not in axes: offset.x=0
	if "y" not in axes: offset.y=0
	position=clamp_point(position-offset); target=position
func set_zoom(value: float,focus_point: Vector2=Vector2.INF) -> void:
	var center=position+visible_size()*.5 if focus_point==Vector2.INF else focus_point
	zoom=clampf(value,float(profile.get("zoom_min",.4)),float(profile.get("zoom_max",1.5)))
	zoom_ratio=zoom/maxf(.01,auto_zoom)
	focus(center,true)
func tick(delta: float) -> void:
	if transitioning:
		position=clamp_point(position.lerp(target,1-exp(-delta*10)))
		if position.distance_to(target)<.2: position=target; transitioning=false
func world_to_view(point: Vector2) -> Vector2: return (point-position)*zoom
func view_to_world(point: Vector2) -> Vector2: return point/zoom+position
func snapshot() -> Dictionary: return {"version":1,"x":position.x,"y":position.y,"zoom":zoom,"zoom_ratio":zoom_ratio,"bounds_width":bounds.size.x,"bounds_height":bounds.size.y}
func restore(data: Dictionary) -> bool:
	if data.get("version")!=1: return false
	if data.has("bounds_width") and not is_equal_approx(float(data.bounds_width),bounds.size.x): return false
	if data.has("bounds_height") and not is_equal_approx(float(data.bounds_height),bounds.size.y): return false
	for key in ["x","y","zoom"]:
		if not (data.get(key) is int or data.get(key) is float) or not is_finite(float(data[key])): return false
	zoom=clampf(data.zoom,float(profile.get("zoom_min",.4)),float(profile.get("zoom_max",1.5)))
	zoom_ratio=zoom/maxf(.01,auto_zoom)
	if data.get("zoom_ratio") is float or data.get("zoom_ratio") is int:
		if is_finite(float(data.zoom_ratio)) and float(data.zoom_ratio)>0: zoom_ratio=float(data.zoom_ratio)
	position=clamp_point(Vector2(data.x,data.y)); target=position; transitioning=false; return true
