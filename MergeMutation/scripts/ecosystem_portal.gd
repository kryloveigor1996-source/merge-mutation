extends "res://scripts/landscape_portal.gd"
const Chrome=preload("res://scripts/app_chrome.gd")
var chrome: Control
func mount_chrome() -> void:
	chrome=Chrome.new()
	chrome.setup(game,"portals")
	add_child(chrome)
func build_hub() -> void:
	super.build_hub()
	get_node("PortalBack").hide()
	get_node("PortalCollection").hide()
	for child in get_children():
		if child is Label and child.position.y==468: L.place(child,Rect2(20,454,600,24))
	mount_chrome()
func open_map(id: String) -> bool:
	if not super.open_map(id): return false
	L.place(map_scroll,Rect2(280,72,660,400))
	scroll_target=clampf(scroll_target,0,maxf(0,map_model.height()-400))
	get_node("MapCollection").hide()
	for child in get_children():
		if child is Label:
			var y: float=84 if child.position.y<80 else (160 if child.position.y<150 else 224)
			L.place(child,Rect2(20,y,230,100 if child==hint else 60))
	mount_chrome()
	return true
func open_preview(world_id: String,level_id: String) -> bool:
	var ok:=super.open_preview(world_id,level_id)
	if ok and is_instance_valid(chrome): chrome.hide()
	return ok
func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(chrome): chrome.visible=visible and not is_instance_valid(preview) and not is_instance_valid(lab_view.story_screen)
