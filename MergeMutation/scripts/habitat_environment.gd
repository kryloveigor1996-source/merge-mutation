extends Control
const Actor=preload("res://scripts/habitat_actor.gd")
const W=preload("res://scripts/journey_widgets.gd")
var model
var world: Node2D
var actor
var layers: Dictionary={}
var active:=false
func setup(value,area_size: Vector2) -> void:
	model=value
	size=area_size
	clip_contents=true
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	world=Node2D.new()
	world.scale=area_size/Vector2(340,420)
	add_child(world)
	for id in ["back","far","ground","objects","mutant","front","light"]:
		var layer:=Node2D.new()
		layer.name=id.capitalize()
		world.add_child(layer)
		layers[id]=layer
		if id!="mutant": layer.draw.connect(func(): draw_layer(id))
	actor=Actor.new()
	actor.setup(model)
	layers.mutant.add_child(actor)
	model.stage_changed.connect(refresh)
	refresh()
	set_active(false)
func refresh() -> void:
	actor.pose(0,world.scale)
	for id in layers:
		if id!="mutant": layers[id].queue_redraw()
func set_active(value: bool) -> void:
	active=value
	set_process(value)
func _process(delta: float) -> void:
	model.tick(delta)
	actor.pose(delta,world.scale)
	layers.objects.queue_redraw()
	layers.light.queue_redraw()
func draw_layer(id: String) -> void:
	var node: Node2D=layers[id]
	var stage: Dictionary=model.registry.stages[model.stage]
	if id=="back":
		node.draw_rect(Rect2(0,0,340,420),Color("8eaca6") if stage.mountains else Color("7c9296"))
		for y in range(25,310,48): node.draw_line(Vector2(0,y),Vector2(340,y),Color("6e858a"),2)
		node.draw_line(Vector2(12,8),Vector2(12,290),Color("d2b985"),7)
		node.draw_line(Vector2(24,8),Vector2(24,130),Color("536b76"),4)
	elif id=="ground":
		node.draw_rect(Rect2(0,315,340,105),Color("a58c70"))
		node.draw_line(Vector2(0,315),Vector2(340,315),Color("c6b49a"),6)
		for i in range(16): node.draw_circle(Vector2(13+i*23,336+(i%3)*24),3+i%3,Color("85735e"))
	for object in model.objects():
		if object.layer!=id: continue
		var a: Array=object.rect
		var r:=Rect2(a[0],a[1],a[2],a[3])
		match object.type:
			"monitor":
				node.draw_style_box(W.box(Color("40596a"),5),r)
				node.draw_rect(r.grow(-7),Color("a1e0ad"))
				node.draw_polyline(PackedVector2Array([r.position+Vector2(8,35),r.position+Vector2(19,27),r.position+Vector2(28,45),r.position+Vector2(39,31)]),Color("388c74"),2)
			"bench":
				node.draw_rect(r,Color("6d7373"))
				node.draw_line(r.position+Vector2(0,8),r.position+Vector2(r.size.x,8),Color("d3bb94"),5)
			"plant":
				var base:=Vector2(r.get_center().x,r.end.y)
				for i in range(5):
					var tip:=base+Vector2((i-2)*r.size.x*0.22,-r.size.y*(0.5+0.1*i))
					node.draw_line(base,tip,Color("4e8061"),4)
					node.draw_circle(tip,6,Color("95bf6f"))
			"boulder": node.draw_style_box(W.box(Color("77817f"),15),r)
			"ridge":
				for i in range(3):
					var p:=r.position+Vector2(i*86,0)
					node.draw_colored_polygon(PackedVector2Array([p+Vector2(-20,180),p+Vector2(48,0+i*22),p+Vector2(110,180)]),Color("647b7c"))
			"vine":
				node.draw_line(r.position,r.end,Color("5b8b65"),5)
				for i in range(6): node.draw_circle(r.position+Vector2(i*4,i*30),8,Color("9dbb6c"))
			"lamp":
				node.draw_rect(r,Color("ffe59e"))
				node.draw_circle(Vector2(r.get_center().x,260),125,Color(1,0.91,0.6,0.045))
			"training":
				# The visible steel foundation remains solid while the stone is rubble.
				node.draw_rect(Rect2(r.position.x-5,r.end.y,r.size.x+10,10),Color("50626a"))
				if not model.stone_broken:
					node.draw_style_box(W.box(Color("a0a7a0"),14),r)
					node.draw_polyline(PackedVector2Array([r.position+Vector2(20,0),r.position+Vector2(32,23),r.position+Vector2(17,35),r.end-Vector2(13,0)]),Color("647375"),3)
				else:
					for i in range(4): node.draw_circle(Vector2(r.position.x+5+i*14,r.end.y-8),7,Color("9ba19a"))
			_: node.draw_style_box(W.box(Color("8b9695"),6),r) # Unknown visuals stay visible, especially when solid.
	if id=="light":
		node.draw_line(Vector2(0,0),Vector2(340,0),Color("d7e8d4"),4)
		if model.behavior=="ram" and model.elapsed>=0.55 and model.elapsed<0.8:
			for i in range(7): node.draw_circle(Vector2(265,315)+Vector2.from_angle(i*TAU/7)*(model.elapsed-0.5)*130,3,Color("ffe6a0"))
