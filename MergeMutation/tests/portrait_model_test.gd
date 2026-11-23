extends SceneTree
const Layout=preload("res://scripts/mobile_layout.gd")
const Camera=preload("res://scripts/mobile_camera.gd")
const Preferences=preload("res://scripts/mobile_preferences.gd")
var checks=0
var failures=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
class FakeBridge extends RefCounted:
	var failed=false
	var fields=[]
	var key=""
	func wrap(_name): return self
	func get_exception(): return self if failed else null
	func getSystem(): return self
	func getDisplayMetrics(): return self
	func getClass(): return self
	func getField(name): key=name; fields.append(name); return self
	func getFloat(_object): return 3.0 if key=="density" else 4.05
func run() -> void:
	var bridge=FakeBridge.new()
	var measured=Layout.density_from_bridge(bridge)
	check(is_equal_approx(measured.density,3),"reflection density value")
	check(is_equal_approx(measured.font_scale,1.35),"reflection scaledDensity ratio")
	check(bridge.fields==["density","scaledDensity"],"bridge uses Java getField/getFloat methods")
	bridge.failed=true
	check(Layout.density_from_bridge(bridge).is_empty(),"Java exception requests fallback")
	for invalid in [null,"bad",0,-1,INF,NAN]: check(Layout.density_values(invalid,3).is_empty(),"invalid native density rejected")
	check(Layout.density_values(3,null).font_scale==1,"missing native font scale safe")
	var sizes=[Vector2(360,640),Vector2(360,720),Vector2(360,800),Vector2(412,915),Vector2(540,960),Vector2(540,1170),Vector2(540,1200)]
	var report=[]
	for source in sizes:
		for tall in [true,false]:
			var pixels=source if tall else Vector2(source.y,source.x)
			for insets in [Vector4(0,0,0,0),Vector4(12,24,0,20),Vector4(24,16,12,24)]:
				for font in [1.0,1.35]:
					var safe=Rect2(insets.x,insets.y,pixels.x-insets.x-insets.z,pixels.y-insets.y-insets.w)
					var g=Layout.new(); g.text_scale=font; g.configure(Rect2(Vector2.ZERO,pixels),pixels,safe,1,tall)
					check(g.safe.is_equal_approx(safe),"safe area converted once")
					check((g.extent*g.factor).distance_to(safe.size)<.01,"full useful height and width")
					check(g.touch*g.factor>=48,"minimum 48dp in known density scenario")
					var board=g.board()
					check(is_equal_approx(board.size.y/6,board.size.x/5),"square cells")
					check(Rect2(Vector2.ZERO,g.extent).encloses(board),"board bounds")
					if tall: check(board.end.y<=g.extent.y-g.touch-64+.1,"board leaves action dock")
					for index in range(30): check(g.cell_at(g.center(index))==index,"cell round trip")
					report.append({"pixels":[pixels.x,pixels.y],"portrait":tall,"safe":[safe.position.x,safe.position.y,safe.size.x,safe.size.y],"logical":[g.extent.x,g.extent.y],"target_dp":g.touch*g.factor,"board":[board.position.x,board.position.y,board.size.x,board.size.y],"font_scale":font})
	var g=Layout.new(); g.configure(Rect2(0,0,540,1170),Vector2(1080,2340),Rect2(0,72,1080,2196),3,true)
	check(g.touch*g.factor*2/3>=48,"physical px, logical units and dp stay distinct")
	var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/habitat_views.json"))
	for id in config.rooms:
		var profile: Dictionary=config.rooms[id]; var width=940.0
		var c=Camera.new(); c.configure(profile,Rect2(0,0,width,420),Vector2(508,900))
		check(is_equal_approx(c.visible_size().x/width,profile.view_fraction),"individual initial view fraction")
		for point in [Vector2(-1000,-1000),Vector2(0,0),Vector2(width,420),Vector2(width*3,5000)]:
			c.focus(point,true)
			check(c.position==c.clamp_point(c.position),"camera bounds")
			check(c.view_to_world(c.world_to_view(point)).distance_to(point)<.01,"camera inverse")
		c.focus(Vector2(width*.5,210),true)
		c.set_zoom(c.zoom*1.1)
		var ratio=c.zoom_ratio
		c.configure(profile,Rect2(0,0,width,420),Vector2(380,600),true)
		check(is_equal_approx(c.zoom_ratio,ratio),"resize preserves relative user zoom")
		check(is_equal_approx(c.zoom,c.auto_zoom*ratio),"resize recalculates width-based zoom")
		var incompatible=c.snapshot(); incompatible.bounds_width=width*2
		check(not c.restore(incompatible),"expanded world ignores stale camera bounds")
		var before=c.snapshot(); c.pan(Vector2(-70,100)); check(c.position.y==c.clamp_point(Vector2.ZERO).y,"flat rooms do not scroll vertically")
		check(c.restore(before),"versioned camera preferences restore")
		check(not c.restore({"version":1,"x":"bad","y":0,"zoom":1}),"invalid saved camera rejected")
	var c=Camera.new(); c.configure({"axes":["x","y"],"zoom_min":.5,"zoom_max":2,"view_fraction":.6},Rect2(0,0,1800,2400),Vector2(500,700)); c.focus(Vector2(900,1500),true)
	var start=c.position; c.pan(Vector2(80,100)); check(c.position.x!=start.x and c.position.y!=start.y,"future multilevel camera supports both axes")
	c.focus(Vector2(1700,2200)); var target=c.target; c.tick(.05); c.pan(Vector2(20,20)); c.tick(1); check(c.position!=target and not c.transitioning,"manual pan cancels smooth auto-focus")
	var pref=Preferences.new(); var path="res://.godot/pr23-preferences-"+str(Time.get_ticks_usec())+".cfg"; pref.setup(path); check(pref.portrait,"new profile portrait")
	var file=ConfigFile.new(); file.set_value("presentation","portrait",false); file.set_value("audio","music",.37); file.save(path)
	pref.setup(path); check(not pref.portrait,"saved landscape preserved"); pref.save(); file.load(path); check(is_equal_approx(file.get_value("audio","music"),.37),"audio settings retained")
	var output=FileAccess.open("res://.godot/pr23-layout-metrics.json",FileAccess.WRITE); output.store_string(JSON.stringify(report,"	")); output.close()
	print("Portrait model checks: %d; failures: %d" % [checks,failures]); quit(1 if failures else 0)
