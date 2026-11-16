extends Node2D
const Sizes = preload("res://scripts/mutant_sizes.gd")
## Levels 1–6 use named PNG sprites; levels 7–10 retain numbered optional slots.
## All fallback shapes below are original, drawn with Godot primitives.

const PALETTE := [Color("8ee85c"), Color("58d9ec"), Color("ffbe61"), Color("ff8fba"), Color("749cff"), Color("c899ff"), Color("55dcc5"), Color("ff9868"), Color("a7db55"), Color("ec9cff")]
const SPRITES := {1:"res://assets/mutants/slime_lv1.png",2:"res://assets/mutants/mutant_lv2.png",3:"res://assets/mutants/mutant_lv3.png",4:"res://assets/mutants/mutant_lv4.png",5:"res://assets/mutants/mutant_lv5.png",6:"res://assets/mutants/mutant_lv6.png"}
var level := 1
var texture: Texture2D
var animation: Tween
var source_bounds := Rect2(-28,-28,56,56)
var collection_mode := false
static var alpha_cache: Dictionary = {}

func setup(value: int,collection: bool=false) -> void:
	level = clampi(value, 1, 10)
	collection_mode=collection
	texture = null
	var path: String = SPRITES.get(level,"res://assets/mutants/%02d.png" % level)
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	if texture:
		if not alpha_cache.has(path):
			var image := texture.get_image()
			if image.is_compressed():
				image.decompress()
			alpha_cache[path]=Rect2(image.get_used_rect())
		source_bounds=alpha_cache[path]
	else:
		source_bounds=Sizes.PROCEDURAL_BOUNDS[level]
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	queue_redraw()

func visible_rect() -> Rect2:
	return Sizes.visible_rect(level,source_bounds,collection_mode)

func shadow_rect() -> Rect2:
	var width := minf(Sizes.pixels(level,collection_mode)*0.78,58.0)
	return Rect2(-width*0.5,visible_rect().end.y-6,width,9)

func render_bounds() -> Rect2:
	return visible_rect().merge(shadow_rect())

func guarded_bounds(picked: bool=false) -> Rect2:
	var factor: float = Sizes.PICK_GUARD if picked else Sizes.REST_GUARD
	if not picked:
		return Transform2D(0,Vector2.ONE*factor,0,Vector2.ZERO)*render_bounds()
	return (Transform2D(-0.09,Vector2.ONE*factor,0,Vector2.ZERO)*render_bounds()).merge(Transform2D(0.09,Vector2.ONE*factor,0,Vector2.ZERO)*render_bounds())

func pop(start_scale: float = 0.05) -> void:
	if animation:
		animation.kill()
	scale = Vector2.ONE * start_scale
	animation = create_tween()
	animation.tween_property(self, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func lift() -> void:
	if animation:
		animation.kill()
	animation = create_tween().set_parallel(true)
	animation.tween_property(self, "scale", Vector2(1.17, 1.17), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	animation.tween_property(self, "rotation", -0.09, 0.15)

func settle() -> void:
	if animation:
		animation.kill()
	animation = create_tween().set_parallel(true)
	animation.tween_property(self, "scale", Vector2.ONE, 0.18)
	animation.tween_property(self, "rotation", 0.0, 0.18)

func blob(points: PackedVector2Array, color: Color) -> void:
	draw_colored_polygon(points, color)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color("233e50"), 2.0, true)

func disk(pos: Vector2, radius: float, color: Color) -> void:
	draw_circle(pos, radius + 1.4, Color("233e50"))
	draw_circle(pos, radius, color)

func _draw() -> void:
	var shadow := shadow_rect()
	draw_set_transform(shadow.get_center(),0,Vector2(1,shadow.size.y/shadow.size.x))
	draw_circle(Vector2.ZERO,shadow.size.x*0.5,Color(0.08,0.23,0.29,0.22))
	draw_set_transform(Vector2.ZERO)
	if texture:
		draw_texture_rect_region(texture,visible_rect(),source_bounds)
		return
	var factor := Sizes.pixels(level,collection_mode)/maxf(source_bounds.size.x,source_bounds.size.y)
	draw_set_transform(-source_bounds.get_center()*factor,0,Vector2.ONE*factor)
	var color: Color = PALETTE[level - 1]
	# A unique silhouette for each of the ten evolutions.
	match level:
		1: # Little pear-shaped slime.
			blob(PackedVector2Array([Vector2(-23,14),Vector2(-20,0),Vector2(-12,-18),Vector2(0,-23),Vector2(13,-17),Vector2(21,0),Vector2(24,14),Vector2(13,20),Vector2(-13,20)]),color)
		2: # One-eyed floating orb with antenna.
			draw_line(Vector2(0,-15),Vector2(5,-28),Color("233e50"),3,true)
			disk(Vector2(5,-27),4,Color("ffdf78"))
			disk(Vector2.ZERO,21,color)
			disk(Vector2(-21,5),5,color)
			disk(Vector2(21,5),5,color)
		3: # Pointed-eared hornling.
			blob(PackedVector2Array([Vector2(-22,15),Vector2(-21,-23),Vector2(-8,-13),Vector2(8,-13),Vector2(21,-23),Vector2(22,15),Vector2(0,22)]),color)
		4: # Bubble cloud, asymmetric lobes.
			for part in [Vector3(-14,0,13),Vector3(0,-12,14),Vector3(15,-2,12),Vector3(4,10,17)]:
				disk(Vector2(part.x,part.y),part.z,color)
		5: # Armored turtle shell.
			for side in [-1,1]:
				disk(Vector2(side*20,15),7,color.darkened(0.1))
			disk(Vector2.ZERO,23,color)
			draw_arc(Vector2(0,2),16,PI,TAU,20,color.darkened(0.3),4,true)
			draw_line(Vector2(0,-21),Vector2(0,-13),Color("dae8ff"),3,true)
		6: # Bat-winged oval.
			for side in [-1,1]:
				blob(PackedVector2Array([Vector2(side*10,0),Vector2(side*29,-19),Vector2(side*27,6),Vector2(side*17,13)]),color.darkened(0.18))
			disk(Vector2(0,0),19,color)
		7: # Squid with four dangling tentacles.
			for x in [-18,-6,6,18]:
				draw_line(Vector2(x,10),Vector2(x+3,25-abs(x)*0.2),Color("233e50"),8,true)
				draw_line(Vector2(x,10),Vector2(x+3,25-abs(x)*0.2),color,5,true)
			disk(Vector2(0,-3),22,color)
		8: # Three-eyed spiky chimera.
			var points := PackedVector2Array()
			for i in range(16):
				points.append(Vector2.from_angle(i*TAU/16) * (26.0 if i%2==0 else 18.0))
			blob(points,color)
		9: # Tiny dinosaur, dorsal plates and feet.
			for x in [-13,0,13]:
				blob(PackedVector2Array([Vector2(x-7,-12),Vector2(x,-29),Vector2(x+7,-12)]),Color("ffdc78"))
			disk(Vector2.ZERO,22,color)
			for side in [-1,1]:
				disk(Vector2(side*13,20),7,color)
		10: # Royal mutant with horns, crown and star aura.
			for side in [-1,1]:
				blob(PackedVector2Array([Vector2(side*12,-8),Vector2(side*27,-25),Vector2(side*24,1)]),Color("ffde8a"))
			disk(Vector2.ZERO,22,color)
			blob(PackedVector2Array([Vector2(-12,-17),Vector2(-16,-29),Vector2(-4,-24),Vector2(0,-33),Vector2(5,-24),Vector2(16,-29),Vector2(12,-17)]),Color("ffda69"))
	# Cheeks, eyes and smile tie the cast together.
	draw_circle(Vector2(-14,7),4,Color(1,0.45,0.6,0.45))
	draw_circle(Vector2(14,7),4,Color(1,0.45,0.6,0.45))
	var eye_positions: Array[Vector2] = [Vector2(-8,-3),Vector2(8,-3)]
	if level == 2:
		eye_positions = [Vector2(0,-3)]
	elif level == 8:
		eye_positions = [Vector2(-12,-2),Vector2(0,-9),Vector2(12,-2)]
	for eye in eye_positions:
		disk(eye,8 if level==2 else 6.3,Color("fffdf2"))
		draw_circle(eye+Vector2(1,1),3.2,Color("233e50"))
		draw_circle(eye+Vector2(0,-1),1.2,Color.WHITE)
	draw_arc(Vector2(0,7),5.5,0.1,PI-0.1,12,Color("233e50"),2,true)
	draw_circle(Vector2(-9,-13),3,Color(1,1,1,0.28))
