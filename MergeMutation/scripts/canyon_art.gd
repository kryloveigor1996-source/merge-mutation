extends RefCounted
const D=preload("res://scripts/ecosystem_drawing.gd")
const INK=Color("3c5154")
static func draw(n: CanvasItem,kind: String,v: String,r: Rect2,m=null,slot_id: String="") -> void:
	if kind=="canyon_walls":
		n.draw_rect(r,{"sandstone":Color("b39a77"),"basalt":Color("66717a"),"rift":Color("827a9a")}[v])
		for x in range(0,int(r.size.x),150):
			if v=="sandstone":
				D.poly(n,[Vector2(x,315),Vector2(x+25,76),Vector2(x+85,25),Vector2(x+148,315)],Color("9f856b"))
				for y in [145,210,270]: n.draw_line(Vector2(x+20,y),Vector2(x+110,y-12),Color("c9b58a"),4)
			elif v=="basalt":
				for i in range(3): D.box(n,Rect2(x+i*48,50+i*18,42,265-i*18),Color("505f6b"),3)
			else:
				D.poly(n,[Vector2(x,315),Vector2(x+44,60),Vector2(x+95,130),Vector2(x+148,315)],Color("676181"))
				n.draw_polyline(PackedVector2Array([Vector2(x+12,260),Vector2(x+55,130),Vector2(x+70,235),Vector2(x+110,275)]),Color("b9c4eb"),5)
		return
	if kind=="canyon_floor":
		n.draw_rect(r,{"stony":Color("a7a28c"),"hot_sand":Color("d2b27a"),"obsidian":Color("505b6d")}[v])
		for x in range(0,int(r.size.x),60):
			if v=="stony":
				D.oval(n,Rect2(x+4,340,28,17),Color("7f8f89"))
				D.oval(n,Rect2(x+30,388,23,14),Color("c0b99c"))
			elif v=="hot_sand":
				for y in [337,369,402]: n.draw_arc(Vector2(x+28,y),22,0.2,2.7,20,Color("b99a6f"),2)
			else: D.poly(n,[Vector2(x,385),Vector2(x+20,330),Vector2(x+32,377),Vector2(x+57,400)],Color("8b95a5"))
		return
	var shift:=Vector2.ZERO
	if m!=null and m.action_slot==slot_id and m.action_kind=="play": shift.x=sin(m.elapsed*6)*7
	n.draw_set_transform(r.position+shift,0,r.size/Vector2(120,100))
	match kind:
		"horn_nest":
			if v=="stone_nest":
				D.oval(n,Rect2(0,32,120,62),Color("87948b"))
				D.oval(n,Rect2(15,38,90,39),Color("596e6c"))
				for i in range(6): n.draw_circle(Vector2(8+i*21,79+(i%2)*8),9,Color("afae92"))
			elif v=="thermal":
				D.poly(n,[Vector2(0,98),Vector2(10,26),Vector2(42,2),Vector2(100,12),Vector2(120,98)],Color("856f67"))
				D.oval(n,Rect2(22,36,79,61),Color("d29165"))
				for i in range(3): n.draw_arc(Vector2(35+i*25,26),12,PI,TAU,16,Color("efc189"),3)
			else:
				D.oval(n,Rect2(3,60,114,37),Color("998f78"))
				for x in [20,45,75,100]: n.draw_arc(Vector2(x,66),31,PI,TAU,18,Color("d4c8a6"),7)
		"mineral_feeder":
			if v=="ore":
				for i in range(6): D.poly(n,[Vector2(i*18,92),Vector2(i*18+12,15+(i%3)*15),Vector2(i*18+29,92)],Color("9eb7b0") if i%2 else Color("b8a47a"))
			elif v=="bowl":
				D.oval(n,Rect2(1,27,118,68),Color("8f9d91"))
				D.oval(n,Rect2(12,31,96,40),Color("4a625e"))
				for x in [29,52,78]: n.draw_circle(Vector2(x,48),9,Color("c6b881"))
			else:
				D.box(n,Rect2(35,0,65,81),Color("a4beb9"),8)
				n.draw_rect(Rect2(45,8,45,40),Color("668e96"))
				D.box(n,Rect2(5,72,110,24),Color("566f78"),6)
				for x in [34,60,87]: n.draw_circle(Vector2(x,82),6,Color("d2c995"))
		"horn_training":
			if m!=null and m.stone_broken:
				if v=="target":
					D.box(n,Rect2(8,70,104,24),Color("7f98a8"),7)
					n.draw_circle(Vector2(75,75),18,Color("d6a482"))
				else:
					for i in range(5): D.poly(n,[Vector2(i*24,98),Vector2(i*24+9,66+i%2*14),Vector2(i*24+23,98)],Color("7f9298") if v=="boulder" else Color("b4b9e0"))
			elif v=="boulder":
				D.poly(n,[Vector2(1,98),Vector2(8,29),Vector2(45,1),Vector2(95,8),Vector2(120,63),Vector2(113,98)],Color("81928b"))
				n.draw_polyline(PackedVector2Array([Vector2(58,5),Vector2(43,40),Vector2(70,64),Vector2(56,92)]),INK,4)
			elif v=="growing":
				for i in range(3):
					var x:=float(10+i*35)
					D.poly(n,[Vector2(x,98),Vector2(x+8,25-i%2*20),Vector2(x+25,1+i%2*35),Vector2(x+36,75)],Color("b2c8de") if i%2 else Color("8da8c8"))
			else:
				D.box(n,Rect2(47,46,26,52),Color("4d6879"),5)
				for radius in [40,29,16]: n.draw_circle(Vector2(60,40),radius,Color("c89075") if radius!=29 else Color("eee0ac"))
			n.draw_rect(Rect2(0,95,120,5),INK)
		"horn_monument":
			if v=="ancestor":
				D.poly(n,[Vector2(20,98),Vector2(28,10),Vector2(71,1),Vector2(101,20),Vector2(108,98)],Color("8c9b91"))
				n.draw_arc(Vector2(66,42),17,0,TAU,24,INK,4)
				n.draw_line(Vector2(45,71),Vector2(90,71),INK,4)
			elif v=="crystal":
				D.poly(n,[Vector2(12,85),Vector2(45,7),Vector2(68,0),Vector2(110,72),Vector2(74,98)],Color("a0a5d4"))
				n.draw_line(Vector2(68,4),Vector2(61,89),Color("d5e6ed"),5)
			else:
				D.box(n,Rect2(30,0,60,98),Color("819aaa"),4)
				for y in [14,42,70]: D.poly(n,[Vector2(15,y),Vector2(105,y),Vector2(95,y+17),Vector2(25,y+17)],Color("b5c5bf"))
		"horn_trophies":
			if v=="fossils":
				D.box(n,Rect2(2,7,116,88),Color("a99c7d"),10)
				for i in range(6): n.draw_circle(Vector2(27+i*11,44+sin(i)*14),7,Color("ded0aa"))
				n.draw_arc(Vector2(82,40),15,0,TAU,22,Color("ddd0a9"),5)
			elif v=="antlers":
				for side in [-1,1]:
					var center:=Vector2(60,92)
					n.draw_polyline(PackedVector2Array([center,center+Vector2(side*22,-34),center+Vector2(side*43,-76)]),Color("d5c7a0"),8)
					for i in range(3): n.draw_line(center+Vector2(side*(22+i*7),-34-i*14),center+Vector2(side*(5+i*7),-55-i*14),Color("d5c7a0"),6)
			else:
				for x in [18,64]:
					n.draw_line(Vector2(x,0),Vector2(x,100),INK,4)
					D.poly(n,[Vector2(x,8),Vector2(x+44,14),Vector2(x+40,67),Vector2(x+22,54),Vector2(x,70)],Color("bb8b76") if x==18 else Color("7b91ad"))
		"horn_lighting":
			var lit: bool=m==null or m.lighting_on
			var glow:=Color("f4d18a") if lit else Color("667674")
			if v=="thermal":
				for x in [25,95]:
					n.draw_line(Vector2(x,100),Vector2(x,35),Color("79695d"),10)
					D.poly(n,[Vector2(x-14,46),Vector2(x-6,1),Vector2(x+4,24),Vector2(x+13,45),Vector2(x,60)],glow)
			elif v=="minerals":
				for x in [18,60,100]: D.poly(n,[Vector2(x-15,89),Vector2(x,5),Vector2(x+18,77)],glow)
			else:
				n.draw_line(Vector2(0,10),Vector2(120,10),INK,7)
				for x in [23,96]:
					n.draw_circle(Vector2(x,42),23,Color("617e8c"))
					n.draw_circle(Vector2(x,42),15,glow)
		"horn_toy":
			if v=="rolling_rock":
				n.draw_circle(Vector2(60,53),43,Color("9ba69a"))
				n.draw_polyline(PackedVector2Array([Vector2(53,16),Vector2(42,43),Vector2(73,66),Vector2(59,89)]),INK,4)
			elif v=="bone_ring":
				n.draw_arc(Vector2(60,51),36,0,TAU,32,Color("d8c9a3"),15)
				for i in range(6): n.draw_circle(Vector2(60,51)+Vector2.from_angle(i*TAU/6)*37,9,Color("d8c9a3"))
			else:
				for y in [35,60,80]:
					n.draw_line(Vector2(35,y),Vector2(3,y+13),INK,5)
					n.draw_line(Vector2(85,y),Vector2(117,y+13),INK,5)
				D.oval(n,Rect2(25,8,70,83),Color("8b9f91"))
				n.draw_line(Vector2(60,15),Vector2(60,84),INK,3)
				for x in [45,76]: n.draw_circle(Vector2(x,16),5,Color("decb95"))
		"horn_laboratory":
			if v=="seismograph":
				D.box(n,Rect2(5,12,110,80),Color("6b8791"),7)
				n.draw_rect(Rect2(14,22,92,43),Color("bad4bf"))
				n.draw_polyline(PackedVector2Array([Vector2(18,44),Vector2(35,45),Vector2(43,28),Vector2(58,61),Vector2(70,35),Vector2(99,43)]),Color("517b74"),3)
			elif v=="magnet":
				n.draw_arc(Vector2(60,43),36,0,PI,32,Color("a4b4b2"),18)
				for x in [24,96]: n.draw_line(Vector2(x,20),Vector2(x,47),Color("9f7584"),15)
				for x in [43,72]: D.poly(n,[Vector2(x,89),Vector2(x+9,61),Vector2(x+24,91)],Color("a6a1c2"))
			else:
				D.box(n,Rect2(4,0,112,95),Color("667f94"),14)
				D.oval(n,Rect2(13,13,94,52),Color("abd7d4"))
				n.draw_line(Vector2(22,42),Vector2(100,42),Color("d0e9ae"),4)
				for x in [32,60,88]: n.draw_circle(Vector2(x,81),5,Color("b4d8c0"))
	n.draw_set_transform(Vector2.ZERO)
