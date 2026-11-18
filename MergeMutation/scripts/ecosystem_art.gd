extends RefCounted
const Canyon=preload("res://scripts/canyon_art.gd")
const Acid=preload("res://scripts/acid_art.gd")
const D=preload("res://scripts/ecosystem_drawing.gd")
const Visuals=preload("res://scripts/ecosystem_visuals.gd")
static func draw(n: CanvasItem,kind: String,visual: String,rect: Rect2,model,slot_id: String) -> void:
	if kind in ["acid_bed","plasma_feeder","acid_reservoir","toxic_plants","acid_channels","slime_laboratory"]: Acid.draw(n,kind,visual,rect,model,slot_id)
	else: Canyon.draw(n,kind,visual,rect,model,slot_id)
static func base(n: CanvasItem,id: String,model) -> void:
	var width: float=model.registry.world_width
	var acid: bool=model.ecology.habitat_type=="biochemical_wetland"
	if id=="back":
		n.draw_rect(Rect2(0,0,width,420),Color("729e93") if acid else Color("8d9082"))
		for x in range(50,int(width),180):
			if acid:
				D.box(n,Rect2(x,35,122,221),Color("89b8a2"),25)
				for y in [81,150,212]: n.draw_arc(Vector2(x+65,y),18,0,TAU,22,Color("acd7b4"),3)
			else:
				D.poly(n,[Vector2(x-40,315),Vector2(x,170),Vector2(x+60,85),Vector2(x+132,315)],Color("78877b"))
	if id=="ground":
		n.draw_rect(Rect2(0,315,width,105),Color("7daa83") if acid else Color("aaa084"))
		for x in range(24,int(width),75):
			if acid: D.oval(n,Rect2(x,350+(x%2)*30,40,17),Color("a4d586"))
			else: n.draw_circle(Vector2(x,350+x%53),4,Color("818c79"))
static func construction(n: CanvasItem,model,slot: Dictionary) -> void:
	var p: Vector2=model.renovation.catalog.marker(slot,model.registry.world_width)
	var r:=Rect2(p-Vector2(32,27),Vector2(64,54))
	match slot.get("construction","crate"):
		"crate":
			D.box(n,r,Color("bc9b68"),5)
			for x in [r.position.x+9,r.end.x-9]: n.draw_line(Vector2(x,r.position.y+3),Vector2(x,r.end.y-3),Color("826f55"),4)
			n.draw_line(r.position+Vector2(7,7),r.end-Vector2(7,7),Color("e0c997"),5)
		"covered":
			D.poly(n,[r.position+Vector2(-4,54),r.position+Vector2(7,8),r.position+Vector2(28,-9),r.position+Vector2(61,17),r.end+Vector2(7,0)],Color("b6c2af"))
			n.draw_line(r.position+Vector2(28,-6),r.end-Vector2(14,0),Color("829a91"),3)
		"site":
			D.box(n,Rect2(r.position.x-4,r.position.y+18,72,36),Color("9fa998"),4)
			for i in range(4): n.draw_line(r.position+Vector2(i*17,20),r.position+Vector2(i*17+15,48),Color("d8c287"),5)
	n.draw_circle(p+Vector2(22,-20),11,Color("ffe098"))
	n.draw_string(ThemeDB.fallback_font,p+Vector2(17,-15),"+",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("375b60"))
