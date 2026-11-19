extends RefCounted
const DESIGN:=Vector2(960,540)
const BOARD:=Rect2(320,82,320,384)
const CELL:=64.0
static func portrait_regression() -> bool:
	return "--portrait-regression" in OS.get_cmdline_user_args()
static func ecosystem_legacy() -> bool:
	return portrait_regression() or "--ecosystem-legacy" in OS.get_cmdline_user_args() or "--habitat-stage-regression" in OS.get_cmdline_user_args()
static func fit(available: Rect2) -> Rect2:
	var factor:=minf(available.size.x/DESIGN.x,available.size.y/DESIGN.y)
	return Rect2(available.position+(available.size-DESIGN*factor)*0.5,DESIGN*factor)
static func center(index: int) -> Vector2:
	return BOARD.position+Vector2(index%5,floori(index/5.0))*CELL+Vector2.ONE*32
static func cell_at(point: Vector2) -> int:
	if not BOARD.has_point(point): return -1
	return int((point.x-BOARD.position.x)/CELL)+5*int((point.y-BOARD.position.y)/CELL)
static func place(node: Control,rect: Rect2) -> void:
	node.custom_minimum_size=Vector2.ZERO
	node.position=rect.position
	node.size=rect.size
