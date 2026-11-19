extends RefCounted
## Derived environment layers: no independent save, currency or input handlers.
const LAYERS=["back","walls","far","ground","small","objects","front","light","atmosphere"]
const KINDS=["crack","sensor","rock","fossil","shards","dust","pipe","panel","film","fungus","vine","bubbles"]
static var config: Dictionary={}
static var textures: Dictionary={}
static func validate(data: Variant) -> bool:
	if not data is Dictionary or data.get("version")!=1 or not data.get("habitats") is Dictionary: return false
	for room in data.habitats.values():
		if not room is Array or room.is_empty(): return false
		var previous:=-1.0
		for item in room:
			if not item is Dictionary or not item.get("threshold") is float and not item.get("threshold") is int: return false
			if item.threshold<previous or item.threshold<0 or item.threshold>100 or item.get("layer") not in LAYERS or item.get("kind") not in KINDS: return false
			if not item.get("positions") is Array or not item.get("color") is String or not Color.html_is_valid(item.color): return false
			for point in item.positions:
				if not point is Array or point.size()!=2: return false
				for value in point:
					if not (value is int or value is float) or not is_finite(float(value)) or value<0 or value>940: return false
			if item.get("texture","")!="" and (not item.texture is String or not ResourceLoader.exists(item.texture,"Texture2D")): return false
			previous=item.threshold
	return true
static func layers(room,data: Dictionary={}) -> Array:
	if data.is_empty():
		if config.is_empty():
			var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/environment_progression.json"))
			if not validate(raw): return []
			config=raw
		data=config
	var progress: float=100.0*room.installed.size()/maxi(1,room.catalog.slots.size())
	var result: Array=[]
	for item in data.get("habitats",{}).get(room.catalog.habitat_id,[]):
		if progress>=float(item.threshold): result.append(item)
	return result
static func draw(env,id: String) -> void:
	if "--living-world-legacy" in OS.get_cmdline_user_args(): return
	var n: CanvasItem=env.layers[id]
	for item in layers(env.model.renovation):
		if item.layer!=id: continue
		for point in item.positions:
			var p:=Vector2(point[0],point[1])
			if p.x<env.camera_x-90 or p.x>env.camera_x+env.visible_width+90: continue
			var asset: String=item.get("texture","")
			if not asset.is_empty():
				if not textures.has(asset): textures[asset]=load(asset)
				n.draw_texture_rect(textures[asset],Rect2(p-Vector2(32,32),Vector2(64,64)),false)
				continue
			var color:=Color(item.color)
			var time: float=env.model.simulation_time
			match item.kind:
				"crack":
					n.draw_polyline(PackedVector2Array([p,p+Vector2(15,20),p+Vector2(6,38),p+Vector2(21,59)]),color,3)
				"sensor":
					n.draw_rect(Rect2(p,Vector2(24,18)),color)
					n.draw_circle(p+Vector2(12,9),4,Color("ffe695"))
					n.draw_polyline(PackedVector2Array([p+Vector2(12,18),p+Vector2(12,40),p+Vector2(60,40)]),color,2)
				"rock":
					n.draw_colored_polygon(PackedVector2Array([p,p+Vector2(12,-55),p+Vector2(40,-90),p+Vector2(69,0)]),color)
					n.draw_line(p+Vector2(40,-85),p+Vector2(35,-20),color.lightened(0.2),4)
				"fossil":
					n.draw_arc(p,19,PI,TAU,22,color,4)
					for x in [-10,0,10]: n.draw_line(p+Vector2(x,-10),p+Vector2(x,6),color,3)
				"shards":
					for i in range(5):
						var q:=p+Vector2(i*5,-i%3*7)
						n.draw_colored_polygon(PackedVector2Array([q,q+Vector2(4,-12),q+Vector2(8,0)]),color)
				"dust":
					for i in range(5): n.draw_circle(p+Vector2(i*13+sin(time+i)*5,sin(time*0.4+i)*17),1.7,Color(color,0.45))
				"pipe":
					n.draw_polyline(PackedVector2Array([p,p+Vector2(0,65),p+Vector2(110,65)]),color,8)
					for x in [30,70,100]: n.draw_line(p+Vector2(x,59),p+Vector2(x,71),color.lightened(0.3),3)
				"panel":
					n.draw_style_box(preload("res://scripts/journey_widgets.gd").box(color,5),Rect2(p,Vector2(70,44)))
					for i in range(3): n.draw_circle(p+Vector2(15+i*18,20),4,Color("d7f4a9"))
				"film":
					for i in range(4): n.draw_circle(p+Vector2(i*13,sin(i)*11),10+i*2,Color(color,0.25))
				"fungus":
					for i in range(3):
						var q:=p+Vector2(i*13,0)
						n.draw_line(q,q+Vector2(0,-22-i*5),color.darkened(0.3),3)
						n.draw_arc(q+Vector2(0,-22-i*5),9,PI,TAU,18,color,6)
				"vine":
					for i in range(6):
						var q:=p+Vector2(sin(i)*7,i*18)
						n.draw_line(q,q+Vector2(0,20),color.darkened(0.2),2)
						n.draw_circle(q+Vector2(7,6),5,color)
				"bubbles":
					for i in range(3):
						var rise: float=fmod(time*12+i*22,72)
						n.draw_arc(p+Vector2(i*12,-rise),3+i,0,TAU,18,Color(color,0.5),1.5)
