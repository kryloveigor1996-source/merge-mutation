extends SceneTree
## Offline authoring utility. Requires the user-supplied local reference PNGs.
## No color key, redraw, AI reconstruction, runtime dependency or paid API.
const SOURCES := {2:"eyeball_reference.png",3:"horned_reference.png",4:"bubble_reference.png",5:"shell_reference.png",6:"wing_reference.png"}
const MAX_EXTENT := 216

func _initialize() -> void:
	for level: int in SOURCES:
		var source_path: String = "res://assets/references/"+SOURCES[level]
		var bytes := FileAccess.get_file_as_bytes(source_path)
		var image := Image.new()
		if bytes.is_empty() or image.load_png_from_buffer(bytes)!=OK:
			printerr("Missing or invalid reference: ",source_path)
			quit(1)
			return
		image.convert(Image.FORMAT_RGBA8)
		var transparent_pixels := 0
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x,y).a==0:
					transparent_pixels+=1
		print(source_path," size=",image.get_size()," format=",image.get_format()," alpha_zero_pixels=",transparent_pixels)
		# The source already has real alpha. Clear invisible alpha noise only;
		# never remove black pupils, cream eyes, white highlights or dark outlines.
		var has_transparency := false
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x,y).a<0.01:
					image.set_pixel(x,y,Color.TRANSPARENT)
					has_transparency = true
		if not has_transparency:
			printerr("Reference has no alpha: extract a clean mask before processing.")
			quit(1)
			return
		var bounds := image.get_used_rect()
		var character := image.get_region(bounds)
		character.fix_alpha_edges()
		var factor := float(MAX_EXTENT)/maxf(bounds.size.x,bounds.size.y)
		var dimensions := Vector2i(roundi(bounds.size.x*factor),roundi(bounds.size.y*factor))
		character.resize(dimensions.x,dimensions.y,Image.INTERPOLATE_LANCZOS)
		var output := Image.create(256,256,false,Image.FORMAT_RGBA8)
		output.fill(Color.TRANSPARENT)
		var origin := Vector2i(floori((256-dimensions.x)*0.5),floori((256-dimensions.y)*0.5))
		output.blit_rect(character,Rect2i(Vector2i.ZERO,dimensions),origin)
		output.fix_alpha_edges()
		var destination := "res://assets/mutants/mutant_lv%d.png" % level
		if output.save_png(destination)!=OK:
			printerr("Cannot save: ",destination)
			quit(1)
			return
		print(destination," source_bounds=",bounds," output_bounds=",output.get_used_rect()," size=",output.get_size())
	quit()
