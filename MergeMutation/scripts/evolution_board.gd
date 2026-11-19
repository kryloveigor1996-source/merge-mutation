extends RefCounted
const Marks=preload("res://scripts/puzzle_marks.gd")
const W=preload("res://scripts/journey_widgets.gd")
const G=preload("res://scripts/evolution_geometry.gd")
static func draw_board(node: CanvasItem,session,portrait: bool,selected: int,elapsed: float) -> void:
	var cell=G.board(portrait).size.x/5
	for index in range(30):
		if index in session.config.blocked_cells: continue
		var p=G.center(index,portrait)
		var type: String=session.ground(index)
		var color: Color={"normal":Color("b9d9d1"),"rock":Color("a4a4a0"),"acid":Color("83df50"),"gap":Color("294c61")}[type]
		node.draw_style_box(W.box(color,10),Rect2(p-Vector2.ONE*(cell*.46),Vector2.ONE*(cell*.92)))
		if type=="rock": node.draw_polyline(PackedVector2Array([p+Vector2(-12,-24),p+Vector2(6,-3),p+Vector2(-5,8),p+Vector2(12,24)]),W.INK,3)
		elif type=="acid":
			for i in range(3): node.draw_circle(p+Vector2(-14+i*14,10+sin(elapsed*2+i)*4),3,Color("d5ff8e"))
		elif type=="gap": node.draw_line(p+Vector2(-15,-10),p+Vector2(10,8),Color("112d3e"),6)
		if index==selected: node.draw_arc(p,cell*.43,0,TAU,32,Color.WHITE,3)
	if not session.get("fixed_objects") is Dictionary: return
	for object in session.config.objects:
		var index: int=session.crates[object.id] if object.type=="crate" else int(object.cell)
		var p=G.center(index,portrait)
		match object.type:
			"portal":
				for r in [0.36,0.28,0.20]: node.draw_arc(p,cell*r,0,TAU,32,Color("5d90db"),3)
			"plate": node.draw_style_box(W.box(Color("edc457") if session.circuit_on_for_plate(object.id) else Color("9a956d"),4),Rect2(p+Vector2(-cell*.35,cell*.22),Vector2(cell*.7,cell*.13)))
			"gate":
				var on: bool=session.circuit_on(object.get("channel",""))
				node.draw_rect(Rect2(p-Vector2.ONE*cell*.41,Vector2.ONE*cell*.82),Color("53bf94") if on else Color("6b8094"),false,4)
				if not on:
					for x in [-.22,0,.22]: node.draw_line(p+Vector2(cell*x,-cell*.4),p+Vector2(cell*x,cell*.4),W.INK,4)
			"crate":
				var r=Rect2(p-Vector2.ONE*cell*.31,Vector2.ONE*cell*.62)
				node.draw_style_box(W.box(Color("bb9867"),5),r)
				node.draw_line(r.position,r.end,Color("ead5a0"),5)
				node.draw_line(Vector2(r.end.x,r.position.y),Vector2(r.position.x,r.end.y),Color("ead5a0"),5)
			"sample":
				if not session.collected.has(object.id): node.draw_colored_polygon(PackedVector2Array([p+Vector2(0,-cell*.2),p+Vector2(cell*.16,0),p+Vector2(0,cell*.2),p+Vector2(-cell*.16,0)]),Color("ffe979"))
			"equipment","hidden":
				if object.type=="hidden" and not session.revealed.has(object.id): continue
				node.draw_style_box(W.box(Color("70cb9e") if session.activated.has(object.id) else Color("ad9ad1"),6),Rect2(p-Vector2.ONE*cell*.24,Vector2.ONE*cell*.48))
				node.draw_string(ThemeDB.fallback_font,p+Vector2(-9,7),"✓" if session.activated.has(object.id) else "⚙",HORIZONTAL_ALIGNMENT_LEFT,-1,22,W.INK)
			"anomaly":
				if session.cleared.has(object.id):
					node.draw_arc(p,cell*.25,0,TAU,32,Color("6bc89b"),3)
				else:
					for i in range(5): node.draw_circle(p+Vector2.from_angle(i*TAU/5+elapsed*.5)*cell*.14,cell*.17,Color("d98da7"))
static func draw_targets(node: CanvasItem,session,portrait: bool,selected: int) -> void:
	if selected<0 or session.status!="active": return
	var cell=G.board(portrait).size.x/5
	Marks.selected(node,G.center(selected,portrait),cell*.43)
	for index in session.preview_actions(selected):
		var target: Dictionary=session.preview_actions(selected)[index]
		var object: Dictionary=session.object_at(index)
		Marks.target(node,G.center(index,portrait),cell*.43,Marks.category(target.kind,object.get("type","")=="portal"),target.cost)
