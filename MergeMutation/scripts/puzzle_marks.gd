extends RefCounted
## Action glyph and cost are separate, so colour is never the only indication.
static func category(kind: String,portal: bool=false) -> String:
	if portal: return "portal"
	if kind=="merge": return "merge"
	if kind in ["activate","push"]: return "mechanism"
	if kind in ["break","jump","reveal","neutralize"]: return "ability"
	return "move"
static func glyph(kind: String) -> String:
	return {"move":"→","merge":"+","ability":"!","mechanism":"#","portal":"◎"}[kind]
static func selected(node: CanvasItem,p: Vector2,radius: float) -> void:
	for direction in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
		var corner=p+direction*radius
		for axis in [Vector2(direction.x,0),Vector2(0,direction.y)]:
			node.draw_line(corner,corner-axis*radius*.35,Color("173647"),7)
			node.draw_line(corner,corner-axis*radius*.35,Color.WHITE,3)
static func target(node: CanvasItem,p: Vector2,radius: float,kind: String,cost: int) -> void:
	var color: Color={"move":Color("65d5ef"),"merge":Color("ffe477"),"ability":Color("ffb08b"),"mechanism":Color("d7b5ff"),"portal":Color("a4e7c8")}[kind]
	node.draw_rect(Rect2(p-Vector2.ONE*radius,Vector2.ONE*radius*2),Color("173647"),false,5)
	node.draw_rect(Rect2(p-Vector2.ONE*radius,Vector2.ONE*radius*2),color,false,2)
	for side in [-1,1]:
		var center=p+Vector2(side*(radius-9),-radius+10)
		node.draw_circle(center,12,Color("173647"))
		var text=glyph(kind) if side<0 else str(cost)
		node.draw_string(ThemeDB.fallback_font,center+Vector2(-5,5),text,HORIZONTAL_ALIGNMENT_LEFT,-1,15,color)
