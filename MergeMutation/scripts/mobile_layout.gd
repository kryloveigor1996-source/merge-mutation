extends RefCounted
var extent=Vector2(540,960)
var safe=Rect2(0,0,540,960)
var factor=1.0
var portrait=true
var touch=84.0
var density=1.0
var usable_dp=360.0
var text_scale=1.0
var density_source="desktop scenario"
var applied_text_scale=1.0
func configure(canvas: Rect2,physical: Vector2,safe_pixels: Rect2,pixel_density: float,tall: bool) -> bool:
	var previous=extent
	var previous_touch=touch
	var previous_font=applied_text_scale
	applied_text_scale=text_scale
	portrait=tall; density=maxf(.5,pixel_density)
	var usable=canvas
	if physical.x>0 and physical.y>0 and safe_pixels.size.x>0 and safe_pixels.size.y>0:
		usable=Rect2(canvas.position+safe_pixels.position*canvas.size/physical,safe_pixels.size*canvas.size/physical).intersection(canvas)
	if usable.size.x<=0 or usable.size.y<=0: usable=canvas
	safe=usable
	factor=maxf(.01,usable.size.x/540.0 if tall else usable.size.y/540.0)
	extent=usable.size/factor
	usable_dp=(safe_pixels.size.x if safe_pixels.size.x>0 else physical.x)/density
	if usable_dp<1: usable_dp=360 if tall else 640
	touch=maxf(84*text_scale,48.0*extent.x/usable_dp)
	return previous.distance_to(extent)>.5 or absf(previous_touch-touch)>.5 or absf(previous_font-text_scale)>.01
func board(sandbox: bool=false) -> Rect2:
	if portrait:
		var top=touch*2+40
		var width=maxf(150,minf(extent.x-40,(extent.y-top-touch-68-(touch+12 if sandbox else 0))/1.2))
		return Rect2((extent.x-width)*.5,top,width,width*1.2)
	var left=clampf(extent.x*.24,200,300)
	var width=maxf(150,minf((extent.y-touch-28-(touch+28 if sandbox else 16))/1.2,extent.x-left-220))
	return Rect2(left+(extent.x-left-220-width)*.5,touch+28,width,width*1.2)
func center(index: int,sandbox: bool=false) -> Vector2:
	var r=board(sandbox); var cell=r.size.x/5
	return r.position+Vector2(index%5,floori(index/5.0))*cell+Vector2.ONE*cell*.5
func cell_at(point: Vector2,sandbox: bool=false) -> int:
	var r=board(sandbox)
	if not r.has_point(point): return -1
	return int((point.x-r.position.x)/(r.size.x/5))+5*int((point.y-r.position.y)/(r.size.x/5))
static func density_from_bridge(bridge) -> Dictionary:
	var resources=bridge.wrap("android.content.res.Resources")
	if resources==null or bridge.get_exception()!=null: return {}
	var system=resources.getSystem()
	if system==null or bridge.get_exception()!=null: return {}
	var metrics=system.getDisplayMetrics()
	if metrics==null or bridge.get_exception()!=null: return {}
	# JavaObject exposes methods, not Java instance fields. Use public reflection methods.
	var java_class=metrics.getClass()
	if java_class==null or bridge.get_exception()!=null: return {}
	var density_field=java_class.getField("density")
	if density_field==null or bridge.get_exception()!=null: return {}
	var amount=density_field.getFloat(metrics)
	if bridge.get_exception()!=null: return {}
	var scaled_field=java_class.getField("scaledDensity")
	if scaled_field==null or bridge.get_exception()!=null: return {}
	var scaled=scaled_field.getFloat(metrics)
	if bridge.get_exception()!=null: return {}
	return density_values(amount,scaled)
static func density_values(amount: Variant,scaled: Variant) -> Dictionary:
	if not (amount is float or amount is int) or not is_finite(float(amount)) or float(amount)<=0: return {}
	var font_scale=1.0
	if (scaled is float or scaled is int) and is_finite(float(scaled)) and float(scaled)>0: font_scale=maxf(1,float(scaled)/float(amount))
	return {"density":float(amount),"font_scale":font_scale,"source":"Android DisplayMetrics reflection"}
static func android_density() -> Dictionary:
	if OS.has_feature("android") and Engine.has_singleton("JavaClassWrapper"):
		var measured=density_from_bridge(Engine.get_singleton("JavaClassWrapper"))
		if not measured.is_empty(): return measured
	return {"density":maxf(1,DisplayServer.screen_get_dpi()/160.0) if OS.has_feature("android") else 1.0,"font_scale":1.0,"source":"DPI fallback" if OS.has_feature("android") else "desktop scenario"}
