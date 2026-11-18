extends RefCounted
## One-dimensional ground driver, not the universal locomotion model for other species.
static func segment(x: float,profile: Dictionary,objects: Array) -> Vector2:
	var low: float=profile.walk_range[0]
	var high: float=profile.walk_range[1]
	for object in objects:
		if not object.solid: continue
		var r: Array=object.get("collision_rect",object.rect)
		if r[1]>=profile.ground_y or r[1]+r[3]<=profile.ground_y-profile.body_height: continue
		var left: float=r[0]-profile.body_radius
		var right: float=r[0]+r[2]+profile.body_radius
		if x<=left: high=minf(high,left)
		elif x>=right: low=maxf(low,right)
		elif x-left<right-x: high=minf(high,left)
		else: low=maxf(low,right)
	return Vector2(low,high)
static func advance(x: float,target: float,delta: float,profile: Dictionary,objects: Array) -> float:
	var limits:=segment(x,profile,objects)
	return clampf(move_toward(x,clampf(target,limits.x,limits.y),profile.movement_speed*delta),limits.x,limits.y)
static func initial_position(profile: Dictionary,objects: Array) -> Vector2:
	var limits:=segment(profile.start_x,profile,objects)
	return Vector2(clampf(profile.start_x,limits.x,limits.y),profile.ground_y)
static func constrain_target(position: Vector2,requested: Vector2,profile: Dictionary,objects: Array) -> Vector2:
	var limits:=segment(position.x,profile,objects)
	return Vector2(clampf(requested.x,limits.x,limits.y),profile.ground_y)
static func random_target(position: Vector2,rng: RandomNumberGenerator,profile: Dictionary,objects: Array) -> Vector2:
	var limits:=segment(position.x,profile,objects)
	return Vector2(rng.randf_range(limits.x,limits.y),profile.ground_y)
static func advance_position(position: Vector2,target: Vector2,delta: float,profile: Dictionary,objects: Array) -> Vector2:
	return Vector2(advance(position.x,target.x,delta,profile,objects),profile.ground_y)
