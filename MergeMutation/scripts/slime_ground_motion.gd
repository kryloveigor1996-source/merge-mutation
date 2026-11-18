extends "res://scripts/habitat_ground_motion.gd"
const Ground=preload("res://scripts/habitat_ground_motion.gd")
static func advance_position(position: Vector2,target: Vector2,delta: float,profile: Dictionary,objects: Array) -> Vector2:
	var speed_pulse:=0.82+0.18*sin(position.x*0.045)
	return Ground.advance_position(position,target,delta*speed_pulse,profile,objects)
