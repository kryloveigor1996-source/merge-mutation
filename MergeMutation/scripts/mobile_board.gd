extends RefCounted
const UI=preload("res://scripts/mobile_ui.gd")
const Marks=preload("res://scripts/puzzle_marks.gd")
static func draw(node: CanvasItem,session,layout) -> void:
	var area=layout.board(); var cell=area.size.x/5
	for index in range(30):
		var p=layout.center(index); var blocked=index in session.config.blocked_cells
		var type: String=session.ground(index) if session.has_method("ground") else "normal"
		var color: Color={"normal":Color("26393b"),"rock":Color("515859"),"acid":Color("41682c"),"gap":Color("0b1118")}.get(type,UI.PANEL)
		node.draw_style_box(UI.box(Color("141e22") if blocked else color),Rect2(p-Vector2.ONE*(cell*.46),Vector2.ONE*(cell*.92)))
		if blocked: continue
		if type=="rock": node.draw_polyline(PackedVector2Array([p+Vector2(-12,-24),p+Vector2(6,-3),p+Vector2(-5,8),p+Vector2(12,24)]),UI.MUTED,3)
		if type=="acid":
			for i in range(3): node.draw_circle(p+Vector2(-14+i*14,10),3,UI.BIO)
		if type=="gap": node.draw_line(p+Vector2(-15,-10),p+Vector2(10,8),Color.BLACK,6)
		if not session.has_method("object_at"): continue
		var object: Dictionary=session.object_at(index)
		var kind: String=object.get("type","")
		match kind:
			"portal":
				for r in [.32,.24]: node.draw_arc(p,cell*r,0,TAU,48,UI.PURPLE,3)
			"crate":
				var r=Rect2(p-Vector2.ONE*cell*.30,Vector2.ONE*cell*.60)
				node.draw_style_box(UI.box(Color("887c5b")),r); node.draw_line(r.position,r.end,UI.INK,3)
			"plate": node.draw_rect(Rect2(p+Vector2(-cell*.3,cell*.2),Vector2(cell*.6,cell*.12)),UI.BIO if session.circuit_on_for_plate(object.id) else UI.LINE)
			"gate":
				if not session.circuit_on(object.get("channel","")):
					for x in [-.22,0,.22]: node.draw_line(p+Vector2(cell*x,-cell*.4),p+Vector2(cell*x,cell*.4),UI.MUTED,4)
			"sample":
				if not session.collected.has(object.id): node.draw_circle(p,cell*.12,UI.BIO)
			"equipment","hidden":
				if kind=="hidden" and not session.revealed.has(object.id): continue
				node.draw_string(ThemeDB.fallback_font,p+Vector2(-12,10),"✓" if session.activated.has(object.id) else "⚙",HORIZONTAL_ALIGNMENT_LEFT,-1,30,UI.PURPLE)
			"anomaly":
				if not session.cleared.has(object.id):
					for i in range(5): node.draw_circle(p+Vector2.from_angle(i*TAU/5)*cell*.14,cell*.14,Color("865b79"))
static func targets(node: CanvasItem,session,layout,selected: int) -> void:
	if selected<0 or session.status!="active": return
	var radius=layout.board().size.x/5*.43
	Marks.selected(node,layout.center(selected),radius)
	if session.has_method("preview_actions"):
		var actions=session.preview_actions(selected)
		for index in actions:
			var action: Dictionary=actions[index]
			Marks.target(node,layout.center(index),radius,Marks.category(action.kind,session.object_at(index).get("type")=="portal"),action.cost)
	else:
		for action in session.legal_actions()+session.corridor_actions(selected):
			if action.get("source",-1)==selected: Marks.target(node,layout.center(action.index),radius,Marks.category(action.kind),int(action.get("cost",1)))
