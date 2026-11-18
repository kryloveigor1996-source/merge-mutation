extends RefCounted
## Replace any design with a PNG via its optional texture field. IDs remain unchanged.
const W=preload("res://scripts/journey_widgets.gd")
static var textures: Dictionary={}
static func panel(n: CanvasItem,r: Rect2,color: Color,radius: int=10) -> void: n.draw_style_box(W.box(color,radius),r)
static func poly(n: CanvasItem,points: Array,color: Color) -> void: n.draw_colored_polygon(PackedVector2Array(points),color)
static func oval(n: CanvasItem,r: Rect2,color: Color) -> void:
	var points:=PackedVector2Array()
	for i in range(40): points.append(r.get_center()+Vector2.from_angle(i*TAU/40)*r.size*0.5)
	n.draw_colored_polygon(points,color)
static func draw_layer(env,id: String) -> void:
	var n: Node2D=env.layers[id]
	var m=env.model
	var width: float=m.registry.world_width
	if id=="back":
		n.draw_rect(Rect2(0,0,width,420),Color("8e9694"))
		for y in range(0,316,52): n.draw_line(Vector2(0,y),Vector2(width,y),Color("788581"),2)
		for x in range(0,int(width),160): n.draw_line(Vector2(x,0),Vector2(x,315),Color("7d8986"),2)
	if id=="ground":
		n.draw_rect(Rect2(0,315,width,105),Color("93938a"))
		n.draw_line(Vector2(0,315),Vector2(width,315),Color("697773"),6)
	var room=m.renovation
	var visible:=Rect2(env.camera_x,0,env.visible_width,420).grow(20)
	for key in room.catalog.slots:
		var slot: Dictionary=room.catalog.slots[key]
		if slot.layer!=id: continue
		var choice: String=room.visual_choice(key)
		if choice.is_empty(): continue
		var design: Dictionary=room.catalog.design(key,choice)
		var rect: Rect2=room.catalog.project_rect(slot,width)
		if not visible.intersects(rect): continue
		draw_design(n,slot.kind,design,rect,m,key)
	if id=="back":
		for x in [18.0,width-82]:
			n.draw_line(Vector2(x,4),Vector2(x,265),Color("455a61"),12)
			n.draw_line(Vector2(x-2,4),Vector2(x-2,265),Color("b8c4bd"),4)
			for y in [36,170]: panel(n,Rect2(x-10,y,20,10),Color("b1b6a1"),2)
		panel(n,Rect2(width-145,74,48,65),Color("435b64"),5)
		n.draw_rect(Rect2(width-139,82,36,24),Color("9acbb4"))
	if id=="light":
		var has_light:=false
		for key in room.installed:
			if room.catalog.slots[key].interaction=="light": has_light=true
		if has_light and not m.lighting_on: n.draw_rect(Rect2(0,0,width,420),Color(0.04,0.09,0.12,0.22))
		if not m.action_slot.is_empty() and m.feedback_left>0:
			var slot: Dictionary=room.catalog.slots[m.action_slot]
			var p: Vector2=room.catalog.project_rect(slot,width).get_center()
			if visible.has_point(p):
				for i in range(5): n.draw_circle(p+Vector2.from_angle(i*TAU/5)*(14+sin(m.elapsed*8)*4),2,Color("ffdf83"))
static func draw_design(n: CanvasItem,kind: String,d: Dictionary,r: Rect2,m=null,slot_id: String="") -> void:
	var asset: String=d.get("texture","")
	if not asset.is_empty() and ResourceLoader.exists(asset):
		if not textures.has(asset): textures[asset]=load(asset)
		var texture: Texture2D=textures[asset]
		if texture!=null:
			var fitted: Vector2=texture.get_size()*minf(r.size.x/texture.get_width(),r.size.y/texture.get_height())
			n.draw_texture_rect(texture,Rect2(r.get_center()-fitted*0.5,fitted),false)
			return
	var v: String=d.visual
	if kind=="walls":
		n.draw_rect(r,{"rock":Color("718582"),"nature":Color("95bda1"),"future":Color("4c687c")}[v])
		for x in range(0,int(r.size.x),150):
			if v=="rock":
				poly(n,[Vector2(x,315),Vector2(x+24,110),Vector2(x+90,55),Vector2(x+147,315)],Color("607773"))
				n.draw_line(Vector2(x+24,110),Vector2(x+95,185),Color("aac0a4"),3)
			elif v=="nature":
				n.draw_circle(Vector2(x+65,140),68,Color("78a88d"))
				n.draw_line(Vector2(x+65,140),Vector2(x+60,315),Color("4f7f67"),14)
			else:
				panel(n,Rect2(x+12,36,126,230),Color("668a9e"),6)
				n.draw_line(Vector2(x+30,58),Vector2(x+30,240),Color("84e4d4"),4)
		return
	if kind=="floor":
		n.draw_rect(r,{"stone":Color("a7aa98"),"sand":Color("c4b18a"),"metal":Color("607e8b")}[v])
		for x in range(0,int(r.size.x),64):
			if v=="stone":
				panel(n,Rect2(x+2,322,59,40),Color("c1c4aa"),4)
				panel(n,Rect2(x+2,367,59,47),Color("adb39d"),4)
			elif v=="sand":
				for i in range(4): n.draw_circle(Vector2(x+12+i*13,330+i*23),2,Color("aa9670"))
			else:
				n.draw_line(Vector2(x,319),Vector2(x,420),Color("a2c5c8"),3)
				n.draw_line(Vector2(x+10,370),Vector2(x+48,340),Color("3e5d70"),3)
		return
	var offset:=Vector2.ZERO
	if m!=null and m.action_slot==slot_id and m.action_kind=="play" and m.behavior=="react": offset.y=-absf(sin(m.elapsed*9))*8
	n.draw_set_transform(r.position+offset,0,r.size/Vector2(120,100))
	match kind:
		"bed":
			if v=="cave":
				poly(n,[Vector2(1,94),Vector2(9,32),Vector2(42,4),Vector2(84,8),Vector2(116,53),Vector2(118,94)],Color("738681"))
				n.draw_circle(Vector2(62,67),31,Color("354e55"))
				panel(n,Rect2(30,81,65,13),Color("b9b59a"),6)
			elif v=="cushion":
				panel(n,Rect2(4,40,112,55),Color("7b656f"),18)
				panel(n,Rect2(10,46,100,40),Color("dea2aa"),18)
				panel(n,Rect2(12,36,31,30),Color("f0d9b6"),10)
				for x in [55,73,91]: n.draw_line(Vector2(x,55),Vector2(x,80),Color("b66f8b"),2)
			else:
				panel(n,Rect2(1,8,118,86),Color("c5ded8"),30)
				panel(n,Rect2(19,22,85,54),Color("477c91"),24)
				n.draw_arc(Vector2(62,48),28,PI,TAU,24,Color("9fe8e1"),3)
				for x in [36,53,70]: n.draw_line(Vector2(x,85),Vector2(x+9,85),W.INK,2)
		"feeder":
			if v=="auto":
				panel(n,Rect2(38,0,48,70),Color("97aeb9"),8)
				n.draw_rect(Rect2(46,8,32,40),Color("b5dfe0"))
				for p in [Vector2(53,18),Vector2(66,32),Vector2(59,41)]: n.draw_circle(p,4,Color("e5b763"))
				panel(n,Rect2(12,70,96,28),Color("546d79"),10)
			elif v=="bowl":
				poly(n,[Vector2(4,40),Vector2(116,40),Vector2(95,96),Vector2(24,96)],Color("919d91"))
				oval(n,Rect2(7,22,106,39),Color("495d5c"))
				for x in [25,44,63,82]: n.draw_circle(Vector2(x,40),7,Color("d9b56a"))
			else:
				panel(n,Rect2(9,35,102,58),Color("a77855"),8)
				for x in [28,50,72,94]: n.draw_line(Vector2(x,41),Vector2(x-5,89),Color("765440"),3)
				oval(n,Rect2(9,19,102,36),Color("d2b476"))
		"training":
			var broken: bool=m!=null and m.stone_broken
			if broken and v!="target":
				for i in range(5): poly(n,[Vector2(i*22,98),Vector2(i*22+10,74-i%2*10),Vector2(i*22+20,98)],Color("8ba39d") if v=="boulder" else Color("92d6ef"))
			elif v=="boulder":
				poly(n,[Vector2(4,96),Vector2(0,44),Vector2(20,6),Vector2(75,0),Vector2(113,37),Vector2(119,96)],Color("8b9a93"))
				n.draw_polyline(PackedVector2Array([Vector2(56,3),Vector2(44,33),Vector2(69,58),Vector2(53,90)]),Color("526971"),4)
			elif v=="crystal":
				poly(n,[Vector2(12,65),Vector2(38,8),Vector2(77,0),Vector2(111,51),Vector2(78,97),Vector2(34,97)],Color("7ec5e0"))
				poly(n,[Vector2(38,8),Vector2(77,0),Vector2(68,76),Vector2(34,97)],Color("c0f4f1"))
				n.draw_line(Vector2(68,76),Vector2(111,51),Color("4d83b2"),3)
			else:
				panel(n,Rect2(48,50,24,48),Color("546f80"),4)
				n.draw_circle(Vector2(60,42 if not broken else 68),35,Color("d9976a"))
				n.draw_circle(Vector2(60,42 if not broken else 68),24,Color("f6e3b1"))
				n.draw_circle(Vector2(60,42 if not broken else 68),12,Color("b95f68"))
			n.draw_rect(Rect2(0,95,120,5),Color("4c6371"))
		"cabinets":
			if v=="wood":
				panel(n,Rect2(2,4,116,92),Color("ac865d"),4)
				for x in [12,60]: panel(n,Rect2(x,12,46,77),Color("c39a6d"),3)
				for x in [49,69]: n.draw_circle(Vector2(x,53),3,W.INK)
			elif v=="metal":
				panel(n,Rect2(8,3,104,94),Color("849ba5"),4)
				for y in [13,40,67]:
					panel(n,Rect2(13,y,94,24),Color("adc2be"),3)
					n.draw_line(Vector2(50,y+10),Vector2(70,y+10),W.INK,3)
			else:
				poly(n,[Vector2(16,0),Vector2(104,0),Vector2(120,89),Vector2(100,99),Vector2(0,90)],Color("60778f"))
				for x in [20,67]:
					panel(n,Rect2(x,12,32,72),Color("7cbbb9"),10)
					n.draw_line(Vector2(x+8,22),Vector2(x+8,74),Color("d0f2c8"),3)
		"plants":
			if v=="cactus":
				for x in [24,61,94]:
					panel(n,Rect2(x-8,24+(x%3)*8,16,68),Color("60957c"),8)
					n.draw_line(Vector2(x,59),Vector2(x-13,45),Color("60957c"),8)
					n.draw_circle(Vector2(x,26+(x%3)*8),6,Color("e3c180"))
			elif v=="fern":
				for i in range(9):
					var tip:=Vector2(60+(i-4)*12,15+absf(i-4)*12)
					n.draw_line(Vector2(60,96),tip,Color("4f866d"),3)
					oval(n,Rect2(tip-Vector2(8,4),Vector2(24,12)),Color("8db777"))
			else:
				for i in range(3):
					var p:=Vector2(20+i*37,35+(i%2)*27)
					n.draw_line(p,p+Vector2(0,50),Color("b9d3b8"),8)
					n.draw_arc(p+Vector2(0,5),21,PI,TAU,24,Color("8ed7bb"),15)
					n.draw_circle(p+Vector2(-5,-3),3,Color("f6edbd"))
		"lighting":
			var lit: bool=m==null or m.lighting_on
			var glow:=Color("ffe6a0") if lit else Color("718381")
			if v=="torch":
				for x in [28,94]:
					n.draw_line(Vector2(x,98),Vector2(x,45),Color("755c4c"),9)
					poly(n,[Vector2(x-12,47),Vector2(x-6,10),Vector2(x+5,31),Vector2(x+12,45),Vector2(x,60)],glow)
			elif v=="lamp":
				n.draw_rect(Rect2(3,3,114,13),Color("718b93"))
				for x in [20,60,100]:
					n.draw_line(Vector2(x,16),Vector2(x,45),W.INK,3)
					poly(n,[Vector2(x-17,77),Vector2(x-10,43),Vector2(x+10,43),Vector2(x+17,77)],glow)
			else:
				panel(n,Rect2(0,1,120,98),Color("4f6779"),12)
				n.draw_polyline(PackedVector2Array([Vector2(14,74),Vector2(37,22),Vector2(61,74),Vector2(85,22),Vector2(108,74)]),glow,7)
		"toy":
			if v=="ball":
				n.draw_circle(Vector2(60,51),45,Color("de986f"))
				n.draw_arc(Vector2(60,51),31,0,TAU,32,Color("f7dda8"),6)
				poly(n,[Vector2(40,37),Vector2(76,37),Vector2(60,67)],Color("769fbc"))
			elif v=="tire":
				n.draw_circle(Vector2(60,51),46,Color("405460"))
				n.draw_circle(Vector2(60,51),26,Color("91a49a"))
				for i in range(10): n.draw_line(Vector2(60,51)+Vector2.from_angle(i*TAU/10)*35,Vector2(60,51)+Vector2.from_angle(i*TAU/10)*44,Color("799596"),3)
			else:
				panel(n,Rect2(23,30,74,60),Color("b2bfa5"),9)
				panel(n,Rect2(31,2,58,35),Color("728fa1"),8)
				for x in [45,75]: n.draw_circle(Vector2(x,17),5,Color("c2f0d6"))
				for x in [32,77]: n.draw_rect(Rect2(x,88,12,12),W.INK)
				n.draw_line(Vector2(60,1),Vector2(60,-9),Color("deae71"),3)
		"water":
			if v=="pool":
				oval(n,Rect2(0,5,120,90),Color("8c9e91"))
				oval(n,Rect2(12,18,96,61),Color("6cb5c4"))
				for i in range(6): n.draw_circle(Vector2(7+i*21,77+(i%2)*12),6,Color("b4bc9f"))
			elif v=="pond":
				poly(n,[Vector2(0,58),Vector2(18,13),Vector2(75,0),Vector2(116,33),Vector2(120,80),Vector2(62,99),Vector2(20,88)],Color("5f9f9f"))
				oval(n,Rect2(17,24,87,48),Color("8bced1"))
				for x in [12,105]: n.draw_line(Vector2(x,71),Vector2(x-7,20),Color("8da66d"),5)
			else:
				panel(n,Rect2(1,4,118,92),Color("7e9daa"),5)
				n.draw_rect(Rect2(10,20,100,65),Color("85cbd6"))
				for y in [30,50,70]: n.draw_line(Vector2(91,y),Vector2(108,y),W.INK,2)
	n.draw_set_transform(Vector2.ZERO)
