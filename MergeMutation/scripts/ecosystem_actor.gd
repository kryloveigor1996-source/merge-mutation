extends "res://scripts/habitat_actor.gd"
var closed_eyes:=false
var sleep_dissolved:=false
func pose(delta: float,world_scale: Vector2) -> void:
	closed_eyes=false
	art.modulate=Color.WHITE
	art.rotation=0
	super.pose(delta,world_scale)
	model.species_behavior.pose(self,delta)
	queue_redraw()
func _draw() -> void:
	if model.species_behavior.draw(self): return
	super._draw()
