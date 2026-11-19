extends RefCounted
const WIDE=Vector2(960,540)
const TALL=Vector2(540,960)
static func design(portrait: bool) -> Vector2: return TALL if portrait else WIDE
static func board(portrait: bool) -> Rect2: return Rect2(20,208,500,600) if portrait else Rect2(320,82,320,384)
static func center(index: int,portrait: bool) -> Vector2:
	var r=board(portrait)
	var cell=r.size.x/5
	return r.position+Vector2(index%5,floori(index/5.0))*cell+Vector2.ONE*cell*0.5
static func cell_at(point: Vector2,portrait: bool) -> int:
	var r=board(portrait)
	if not r.has_point(point): return -1
	return int((point.x-r.position.x)/(r.size.x/5))+5*int((point.y-r.position.y)/(r.size.x/5))
static func fit(available: Rect2,portrait: bool) -> Rect2:
	var d=design(portrait)
	var factor=minf(available.size.x/d.x,available.size.y/d.y)
	return Rect2(available.position+(available.size-d*factor)*0.5,d*factor)