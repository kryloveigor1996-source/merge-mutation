extends "res://tests/landscape_ui_test.gd"
const UI=preload("res://scripts/mobile_ui.gd")
var reports: Array=[]
func inspect_controls(node: Node,label: String) -> void:
	if node is Control and not node.is_visible_in_tree(): return
	if node is BaseButton or node is HSlider or node is LineEdit:
		var scrolled=false; var parent=node.get_parent()
		while parent!=null and parent!=game.view:
			if parent is ScrollContainer: scrolled=true; break
			parent=parent.get_parent()
		if not scrolled:
			var rect=Rect2(node.get_global_transform_with_canvas()*Vector2.ZERO,node.size*node.get_global_transform_with_canvas().get_scale())
			check(Rect2(Vector2.ZERO,game.size).grow(1).encloses(rect),label+" bounds "+str(node.name)+" "+str(rect))
		check(node.size.x+1>=game.view.geometry.touch and node.size.y+1>=game.view.geometry.touch,label+" touch minimum "+str(node.name)+" "+str(node.size))
	for child in node.get_children(): inspect_controls(child,label)
func resize_ui(pixels: Vector2,tall: bool,font: float=1.0,insets: bool=false) -> void:
	game.view.test_font_scale=font
	game.view.set_portrait(tall)
	root.content_scale_size=Vector2i(pixels); root.size=Vector2i(pixels)
	await process_frame
	await process_frame
	var density=pixels.x/360 if tall else pixels.y/360
	game.view.test_density=density
	game.view.test_safe=Rect2(Vector2(12,24)*density,pixels-Vector2(24,48)*density) if insets else Rect2(Vector2.ZERO,pixels)
	game.view.layout()
	await process_frame
	await process_frame
	check((game.view.geometry.extent*game.view.geometry.factor).distance_to(game.view.geometry.safe.size)<1,"no fixed-height letterboxing")
func run() -> void:
	game=Scene.instantiate(); game.save_path="res://.godot/pr23-layout-"+str(Time.get_ticks_usec())+".json"; game.audio_settings_path=game.save_path+".cfg"
	var fixture={"schema_version":2,"coins":777,"merges":42,"cells":[],"discoveries":["slime:1","horn:1"],"active_species":"slime","campaign":{"version":1,"completed":[1,2,3,4,5,6,7,8,9,10],"claimed":[1,2,3,4,5,6,7,8,9,10],"stars":10}}
	var file=FileAccess.open(game.save_path,FileAccess.WRITE); file.store_string(JSON.stringify(fixture)); file.close(); root.add_child(game)
	game.music.handle_lifecycle=false; game.music.set_volume("master",0)
	game.journey_state.seen.swamp_activation=true
	await process_frame
	await process_frame
	game.view.preferences.hints=false
	var sizes=[Vector2(360,640),Vector2(360,720),Vector2(360,800),Vector2(412,915),Vector2(540,960),Vector2(540,1170),Vector2(540,1200)]
	for original in sizes:
		for tall in [true,false]:
			var pixels=original if tall else Vector2(original.y,original.x)
			for safe in [false,true]:
				await resize_ui(pixels,tall,1,safe)
				game.view.open_complex(); await process_frame
				inspect_controls(game.view.complex_ui,"complex")
				var ui=game.view.complex_ui
				ui.show_lift(); await process_frame; inspect_controls(ui.modal,"lift"); ui.close_modal()
				check(ui.active_floors.size()<ui.registry.floors.size(),"complex culling retained")
				ui.open_living("habitat_slime"); await process_frame
				var detail=ui.detail
				check(detail.mode=="observation" and detail.design_panel==null and detail.zones==null,"observation has no persistent panels")
				check(is_equal_approx(detail.environment.world.scale.x,detail.environment.world.scale.y),"room art isotropic")
				inspect_controls(detail,"slime observation")
				var slot=detail.room_state.offered()[0] if not detail.room_state.offered().is_empty() else detail.room_state.installed.keys()[0]
				detail.open_design(slot); await process_frame; inspect_controls(detail,"slime arrangement"); detail.close_front_panel()
				reports.append({"pixels":[pixels.x,pixels.y],"portrait":tall,"safe":safe,"logical":[game.view.geometry.extent.x,game.view.geometry.extent.y],"touch_dp":game.view.geometry.touch*game.view.geometry.factor/density_for(pixels,tall),"room_view_fraction":detail.camera.visible_size().x/detail.model.registry.world_width,"observation_height":detail.environment.size.y})
				ui.close_living(); ui.open_living("habitat_horn"); await process_frame
				detail=ui.detail; detail.show_zones(); await process_frame; check(detail.mode=="observation","small rooms do not open unnecessary zone panel"); inspect_controls(detail,"horn observation"); detail.close_front_panel(); ui.close_living()
				game.view.show_panel("collection"); await process_frame; inspect_controls(game.view.overlay,"archive")
				game.view.overlay.show_entry("slime"); await process_frame; inspect_controls(game.view.overlay,"dossier")
				game.view.show_panel("settings"); await process_frame; inspect_controls(game.view.overlay,"settings")
				game.view.handle_back(); check(game.view.panel_kind=="collection","settings restores archive"); game.view.handle_back(); game.view.handle_back()
				game.open_portals(); await process_frame; inspect_controls(game.view.portal_ui,"portals")
				game.open_world_map("laboratory"); await process_frame; inspect_controls(game.view.portal_ui,"map")
				game.view.portal_ui.open_preview("laboratory","lab_01"); await process_frame; inspect_controls(game.view.portal_ui.preview,"preview"); game.view.portal_ui.close_preview()
				game.view.open_evolution(); var screen=game.view.experiment_ui; screen.start_trial(9); await process_frame; inspect_controls(screen,"puzzle")
				screen.chrome.show_goals(); await process_frame; inspect_controls(screen.chrome.modal,"expanded goals"); game.view.handle_back(); check(screen.chrome.modal==null,"Back closes details before level")
				screen.leave(); await process_frame
	# Accessibility typography, short/long text and the same composition, not a smaller whole canvas.
	for tall in [true,false]:
		await resize_ui(Vector2(540,960) if tall else Vector2(960,540),tall,1.35,true)
		game.view.show_panel("collection"); await process_frame; game.view.overlay.show_entry("slime"); await process_frame; inspect_controls(game.view.overlay,"large text dossier")
		game.view.handle_back(); game.view.handle_back()
		game.view.open_evolution(); var screen=game.view.experiment_ui; screen.start_trial(10); await process_frame; inspect_controls(screen,"large text puzzle"); screen.leave(); await process_frame
	var output=FileAccess.open("res://.godot/pr23-runtime-metrics.json",FileAccess.WRITE); output.store_string(JSON.stringify(reports,"	")); output.close()
	game.free(); print("Portrait layout checks: %d; failures: %d" % [checks,failures]); quit(1 if failures else 0)
func density_for(pixels: Vector2,tall: bool) -> float: return pixels.x/360 if tall else pixels.y/360
