extends RefCounted
## All sizes are longest VISIBLE silhouette edges, in 360x720 design pixels.
## High levels are capped below the initial 90px proposal to limit neighbour overlap.
const VISIBLE_PX := [0.0,52.0,54.0,56.0,58.0,62.0,68.0,72.0,76.0,80.0,84.0]
const COLLECTION_PX := 48.0
const ACTIVE_Z := 18
const OVERLAY_Z := 20
const PLAY_AREA := Rect2(10,139,340,389)
const REST_GUARD := 1.10
const PICK_GUARD := 1.32
const IDLE_OVERHANG := 12.0
const PICK_OVERHANG := 32.0
# Includes outlines, horns, crowns and tentacle caps; excludes the ground shadow.
const PROCEDURAL_BOUNDS := [Rect2(),Rect2(-25,-24,50,46),Rect2(-28,-33,56,56),Rect2(-23,-24,46,47),Rect2(-29,-28,58,57),Rect2(-29,-25,58,50),Rect2(-30,-21,60,42),Rect2(-24,-27,50,55),Rect2(-29,-29,58,58),Rect2(-24,-34,48,63),Rect2(-29,-38,58,63)]

static func pixels(level: int,collection: bool=false) -> float:
	return COLLECTION_PX if collection else VISIBLE_PX[clampi(level,1,10)]

static func visible_rect(level: int,source: Rect2,collection: bool=false) -> Rect2:
	var factor := pixels(level,collection)/maxf(source.size.x,source.size.y)
	var dimensions := source.size*factor
	return Rect2(-dimensions*0.5,dimensions)

static func clamp_center(center: Vector2,local_bounds: Rect2) -> Vector2:
	return Vector2(clampf(center.x,PLAY_AREA.position.x-local_bounds.position.x,PLAY_AREA.end.x-local_bounds.end.x),clampf(center.y,PLAY_AREA.position.y-local_bounds.position.y,PLAY_AREA.end.y-local_bounds.end.y))
