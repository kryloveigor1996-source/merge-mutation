extends SceneTree
const Art = preload("res://scripts/mutant_art.gd")
const PATH := "res://assets/mutants/slime_lv1.png"
var checks := 0
var failures := 0

func check(condition: bool,message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ",message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var bytes := FileAccess.get_file_as_bytes(PATH)
	check(bytes.size()>1000,"PNG exists")
	check(bytes[24]==8 and bytes[25]==6,"PNG is 8-bit RGBA, not RGB with a fake background")
	var image := Image.new()
	check(image.load_png_from_buffer(bytes)==OK,"source PNG decodes without export-only image loading")
	check(image.get_size()==Vector2i(256,256),"exact 256x256 dimensions")
	check(image.get_format()==Image.FORMAT_RGBA8,"RGBA8 pixel format")
	var bounds := image.get_used_rect()
	check(bounds.position.x>=12 and bounds.position.y>=12 and bounds.end.x<=244 and bounds.end.y<=244,"transparent padding on every side")
	var empty_border := true
	var transparent := 0
	var semitransparent := 0
	for y in range(256):
		for x in range(256):
			var alpha := image.get_pixel(x,y).a
			if alpha==0:
				transparent += 1
			elif alpha<1:
				semitransparent += 1
			if (x<12 or y<12 or x>=244 or y>=244) and alpha!=0:
				empty_border = false
	check(empty_border,"all border pixels are truly alpha zero")
	check(transparent>30000 and semitransparent>100,"transparent exterior and antialiased alpha are present")
	check(image.get_pixel(128,20).a==0 and image.get_pixel(20,128).a==0,"no rectangular matte around the character")
	var art := Art.new()
	art.setup(1)
	root.add_child(art)
	check(art.texture!=null and art.texture.resource_path==PATH,"level 1 loads the named slime sprite")
	check(art.texture.get_size()==Vector2(256,256),"import preserves texture resolution")
	check(art.texture.get_image().has_mipmaps(),"mipmaps are imported for small-cell rendering")
	check(art.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,"illustration uses mipmapped filtering")
	# The visible alpha bounds must stay in a 64x64 cell at rest and when lifted.
	var visible := Rect2(Vector2(bounds.position)/256*56-Vector2(28,28),Vector2(bounds.size)/256*56)
	for cell_size in [62,64]:
		for lifted in [false,true]:
			var transform := Transform2D(-0.09 if lifted else 0.0,Vector2.ONE*(1.17 if lifted else 1.0),0,Vector2.ONE*cell_size*0.5)
			var fits := true
			for point in [visible.position,Vector2(visible.end.x,visible.position.y),visible.end,Vector2(visible.position.x,visible.end.y)]:
				if not Rect2(0,0,cell_size,cell_size).has_point(transform*point):
					fits = false
			check(fits,"%dx%d bounds while lifted=%s" % [cell_size,cell_size,lifted])
	art.pop()
	await create_timer(0.5).timeout
	check(art.scale.is_equal_approx(Vector2.ONE),"PNG retains spawn animation")
	art.lift()
	await create_timer(0.22).timeout
	check(art.scale.x>1.1,"PNG retains selection bounce")
	art.settle()
	await create_timer(0.22).timeout
	check(art.scale.is_equal_approx(Vector2.ONE),"PNG returns to resting scale")
	for level in range(2,11):
		art.setup(level)
		if level<=6:
			check(art.texture!=null and art.texture.resource_path==Art.SPRITES[level],"named PNG retained for level %d" % level)
		else:
			check(art.texture==null,"procedural fallback retained for level %d" % level)
	art.setup(1)
	check(art.texture!=null,"switching back restores PNG")
	art.free()
	print("Slime sprite checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
