extends Node2D
## Short-lived deterministic particles; never uses the gameplay RNG.
var phase := 0.0
var discovery := false
var tint := Color("ffe699")

func _ready() -> void:
	var tween := create_tween()
	tween.tween_property(self,"phase",1.0,0.85 if discovery else 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(queue_free)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var color := Color(tint,1.0-phase)
	draw_arc(Vector2.ZERO,10+phase*45,0,TAU,40,color,3*(1-phase),true)
	var count := 20 if discovery else 12
	for i in range(count):
		var direction := Vector2.from_angle(TAU*i/count)
		var point := direction*(8+phase*(55 if discovery else 36))
		if discovery:
			draw_line(point-direction*5,point+direction*5,color,2,true)
			draw_line(point-direction.orthogonal()*3,point+direction.orthogonal()*3,color,2,true)
		else:
			draw_circle(point,3*(1-phase)+0.3,color)
