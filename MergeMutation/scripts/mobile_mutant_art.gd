extends "res://scripts/mutant_art.gd"
var presentation_factor=1.0
func guarded_bounds(picked: bool=false) -> Rect2:
	var rect=super.guarded_bounds(picked)
	return Rect2(rect.position*presentation_factor,rect.size*presentation_factor)
func pop(start_scale: float=.05) -> void:
	if animation: animation.kill()
	scale=Vector2.ONE*presentation_factor*start_scale
	animation=create_tween(); animation.tween_property(self,"scale",Vector2.ONE*presentation_factor,.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
func lift() -> void:
	if animation: animation.kill()
	animation=create_tween().set_parallel(true)
	animation.tween_property(self,"scale",Vector2.ONE*presentation_factor*1.17,.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	animation.tween_property(self,"rotation",-.09,.15)
func settle() -> void:
	if animation: animation.kill()
	animation=create_tween().set_parallel(true)
	animation.tween_property(self,"scale",Vector2.ONE*presentation_factor,.18); animation.tween_property(self,"rotation",0,.18)
