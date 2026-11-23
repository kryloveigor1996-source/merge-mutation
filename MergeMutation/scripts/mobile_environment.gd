extends "res://scripts/habitat_environment.gd"
const UI=preload("res://scripts/mobile_ui.gd")
var camera
const Renovation=preload("res://scripts/renovation_art.gd")
const Ecosystem=preload("res://scripts/ecosystem_art.gd")
const Decoration=preload("res://scripts/environment_progression.gd")
var resident_pixels=128.0
func floor_offset() -> float:
	if camera==null or "y" in camera.axes: return 0
	return (camera.viewport.y*.82-camera.world_to_view(model.position).y)/camera.zoom
func slot_offset(slot: Dictionary) -> float:
	if camera==null or "y" in camera.axes: return 0
	var original=model.renovation.catalog.project_rect(slot,model.registry.world_width)
	if slot.slot_id in ["reservoir","laboratory","cabinets","lighting"]:
		return camera.view_to_world(Vector2(0,camera.viewport.y*.24)).y-original.position.y
	if slot.slot_id=="plants": return camera.view_to_world(Vector2(0,camera.viewport.y*.50)).y-original.position.y
	return floor_offset()
func project_rect(slot: Dictionary,field: String="rect") -> Rect2:
	var rect=model.renovation.catalog.project_rect(slot,model.registry.world_width,field)
	rect.position.y+=slot_offset(slot); return rect
func marker(slot: Dictionary) -> Vector2:
	return model.renovation.catalog.marker(slot,model.registry.world_width)+Vector2(0,slot_offset(slot))
func draw_layer(id: String) -> void:
	if camera==null: return
	var n=layers[id]; var view=camera.visible_size(); var left=camera.position.x; var top=camera.position.y
	var acid=model.profile.species_id=="slime"
	if id=="back":
		n.draw_rect(Rect2(camera.position,view),Color("20362f") if acid else Color("30382f"))
		for x in range(int(left/180)*180,int(left+view.x+180),180):
			if acid:
				var r=Rect2(x+24,top+view.y*.13,122,view.y*.55)
				n.draw_style_box(UI.box(Color("385b47"),Color("5d7c61")),r)
				for f in [.18,.4,.62,.82]: n.draw_arc(Vector2(r.get_center().x,r.position.y+r.size.y*f),18,0,TAU,24,Color("89b58b"),3)
			else:
				var base=top+view.y*.85
				n.draw_colored_polygon(PackedVector2Array([Vector2(x-50,base),Vector2(x,top+view.y*.3),Vector2(x+60,top+view.y*.12),Vector2(x+145,base)]),Color("465746"))
	if id=="ground":
		var y=315+floor_offset()
		n.draw_rect(Rect2(left,y,view.x,maxf(100,top+view.y-y)),Color("4c6950") if acid else Color("706850"))
		for x in range(int(left/75)*75,int(left+view.x),75): n.draw_circle(Vector2(x+20,y+34+(x%3)*9),5,Color("8fbf7f") if acid else Color("899277"))
	var room=model.renovation
	var visible=Rect2(camera.position,view).grow(40)
	for key in room.catalog.slots:
		var slot: Dictionary=room.catalog.slots[key]
		if slot.layer!=id: continue
		var choice: String=room.visual_choice(key)
		if choice.is_empty(): continue
		var rect=project_rect(slot)
		if visible.intersects(rect): Renovation.draw_design(n,slot.kind,room.catalog.design(key,choice),rect,model,key)
	if id=="objects":
		for key in room.offered():
			if room.preview_slot==key: continue
			var slot: Dictionary=room.catalog.slots[key]
			if visible.grow(40).has_point(marker(slot)):
				n.draw_set_transform(Vector2(0,slot_offset(slot))); Ecosystem.construction(n,model,slot); n.draw_set_transform(Vector2.ZERO)
	n.draw_set_transform(Vector2(0,floor_offset())); Decoration.draw(self,id); n.draw_set_transform(Vector2.ZERO)
	if id=="light" and not model.lighting_on: n.draw_rect(Rect2(camera.position,view),Color(0,0,0,.08))
func apply_camera() -> void:
	if camera==null or not is_instance_valid(world): return
	visible_width=camera.visible_size().x; camera_x=camera.position.x
	world.scale=Vector2.ONE*camera.zoom; world.position=-camera.position*camera.zoom
	for layer in layers.values(): layer.queue_redraw()
	pose_resident(0)
	queue_redraw()
func set_camera(value: float) -> void:
	if camera==null: super.set_camera(value); return
	camera.position=camera.clamp_point(Vector2(value,camera.position.y)); camera.target=camera.position
	apply_camera()
func pose_resident(delta: float) -> void:
	actor.pose(delta,world.scale)
	if not model.inhabited(): return
	var factor=maxf(1,resident_pixels/maxf(1,64*1.6*world.scale.x))
	actor.art.scale*=factor
	actor.art.position.y-=(factor-1)*32*1.6
	actor.position.y+=floor_offset()
func _process(delta: float) -> void:
	model.tick(delta); pose_resident(delta)
	for layer in layers.values(): layer.queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("1c302b") if model.profile.species_id=="slime" else Color("2d302d"))
	for y in range(20,int(size.y),64): draw_line(Vector2(0,y),Vector2(size.x,y),Color(1,1,1,.035),1)
	for x in [24,size.x-28]:
		draw_line(Vector2(x,0),Vector2(x,size.y),Color("52635d"),8)
		draw_line(Vector2(x-2,0),Vector2(x-2,size.y),Color("81938a"),1)
