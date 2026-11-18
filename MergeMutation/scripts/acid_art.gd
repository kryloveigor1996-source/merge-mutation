extends RefCounted
const D=preload("res://scripts/ecosystem_drawing.gd")
const INK=Color("345f62")
static func draw(n: CanvasItem,kind: String,v: String,r: Rect2,m=null,_slot_id: String="") -> void:
	if kind=="acid_channels":
		var color: Color={"pipes":Color("659f91"),"trenches":Color("749c73"),"glass":Color("a9d6c6")}[v]
		D.box(n,r,color,6)
		n.draw_line(r.position+Vector2(7,r.size.y*0.5),r.end-Vector2(7,r.size.y*0.5),Color("c0ef80"),8 if v!="glass" else 4)
		for x in range(int(r.position.x)+20,int(r.end.x),80):
			if v=="pipes": n.draw_rect(Rect2(x,r.position.y-4,7,r.size.y+8),INK)
			elif v=="trenches": n.draw_line(Vector2(x,r.position.y),Vector2(x+14,r.end.y),Color("9ec188"),3)
			else: n.draw_arc(Vector2(x,r.get_center().y),9,0,TAU,18,Color("daf0c0"),2)
		return
	n.draw_set_transform(r.position,0,r.size/Vector2(120,100))
	match kind:
		"acid_bed":
			if v=="basin":
				D.oval(n,Rect2(0,19,120,78),Color("689b8b"))
				D.oval(n,Rect2(9,24,102,55),Color("b4e16f"))
				for x in [27,62,94]: n.draw_arc(Vector2(x,53),8,0,TAU,20,Color("e1f2a1"),2)
			elif v=="gel_nest":
				D.poly(n,[Vector2(1,77),Vector2(13,27),Vector2(51,12),Vector2(103,20),Vector2(120,82),Vector2(58,99)],Color("89bda2"))
				D.oval(n,Rect2(12,30,97,43),Color("bcdf87"))
				for x in [15,105]: n.draw_circle(Vector2(x,34),12,Color("bad7a1"))
			else:
				n.draw_arc(Vector2(60,55),46,PI,TAU,32,Color("a4d7c2"),9)
				D.oval(n,Rect2(3,49,114,47),Color("628f89"))
				D.oval(n,Rect2(13,52,94,25),Color("c1e788"))
				for x in [23,54,86]: n.draw_circle(Vector2(x,23),6,Color("d8f1c1"))
		"plasma_feeder":
			if v=="vessel":
				D.oval(n,Rect2(4,31,112,65),Color("7aabaa"))
				D.oval(n,Rect2(13,33,94,39),Color("cad48b"))
			elif v=="dripper":
				D.box(n,Rect2(50,2,52,59),Color("9dc8c2"),8)
				n.draw_rect(Rect2(57,10,37,35),Color("d4e393"))
				n.draw_line(Vector2(74,59),Vector2(45,94),Color("9ac4be"),6)
				n.draw_circle(Vector2(49,82),7,Color("d9e78f"))
			else:
				D.box(n,Rect2(7,72,106,22),Color("5f8d91"),5)
				n.draw_line(Vector2(60,75),Vector2(60,13),INK,9)
				for y in [17,33,49,65]: n.draw_arc(Vector2(60,y),29,0,TAU,24,Color("c0dc8c"),5)
		"acid_reservoir":
			if v=="fountain":
				D.oval(n,Rect2(0,53,120,44),Color("649b8c"))
				n.draw_line(Vector2(60,72),Vector2(60,14),Color("a9df9b"),12)
				for side in [-1,1]: n.draw_arc(Vector2(60+side*23,44),26,PI,TAU,20,Color("bae99e"),6)
			elif v=="tank":
				D.box(n,Rect2(2,4,116,92),Color("8bc2ba"),7)
				n.draw_rect(Rect2(11,29,98,59),Color("acd27e"))
				for x in [27,79]: n.draw_arc(Vector2(x,51),9,0,TAU,18,Color("d8eeb3"),3)
			else:
				D.poly(n,[Vector2(0,97),Vector2(18,59),Vector2(42,71),Vector2(74,52),Vector2(120,97)],Color("6f9f82"))
				for i in range(3): n.draw_line(Vector2(50+i*12,79),Vector2(42+i*20,5+i%2*18),Color("b9df80"),7)
		"toxic_plants":
			if v=="reeds":
				for x in [20,44,70,99]:
					n.draw_line(Vector2(60,98),Vector2(x,10+x%3*10),Color("4f9277"),5)
					D.oval(n,Rect2(x-8,3+x%3*10,16,29),Color("afd28e"))
			elif v=="fungi":
				for i in range(3):
					var p:=Vector2(23+i*37,26+i%2*22)
					n.draw_line(p,Vector2(p.x,95),Color("abc7a4"),8)
					n.draw_arc(p,23,PI,TAU,24,Color("a3deac"),15)
					n.draw_circle(p+Vector2(-6,-8),3,Color("e7f2c3"))
			else:
				for i in range(4): n.draw_polyline(PackedVector2Array([Vector2(60,100),Vector2(18+i*27,64),Vector2(7+i*34,23),Vector2(24+i*22,4)]),Color("78b99c"),7)
		"slime_laboratory":
			if v=="centrifuge":
				D.box(n,Rect2(5,45,110,50),Color("6b9eaa"),9)
				n.draw_circle(Vector2(60,39),36,Color("add6c4"))
				for i in range(4): n.draw_line(Vector2(60,39),Vector2(60,39)+Vector2.from_angle(i*TAU/4)*26,Color("6c9b91"),5)
			elif v=="analyzer":
				D.box(n,Rect2(3,2,114,94),Color("7399a7"),7)
				n.draw_rect(Rect2(14,11,92,42),Color("b4dcaa"))
				for x in [27,56,85]: D.box(n,Rect2(x-7,64,17,25),Color("d8e29e"),5)
			else:
				D.oval(n,Rect2(12,3,96,28),Color("b3d2c7"))
				D.box(n,Rect2(15,16,90,74),Color("72b5a1"),12)
				n.draw_line(Vector2(32,25),Vector2(32,77),Color("d2ebaf"),5)
				for x in [47,72]: n.draw_arc(Vector2(x,58),11,0,TAU,20,Color("cae7a9"),3)
	if m!=null and m.action_semantic=="acid_bath":
		for x in [30,65,94]: n.draw_arc(Vector2(x,10+sin(m.elapsed*4+x)*5),4,0,TAU,14,Color("d7f0ac"),2)
	n.draw_set_transform(Vector2.ZERO)
