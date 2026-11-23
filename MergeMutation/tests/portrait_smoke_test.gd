extends "res://tests/landscape_ui_test.gd"
func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await create_timer(.2).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://.godot/pr23-"+name+".png")==OK,"shot "+name)
func run() -> void:
	game=Scene.instantiate(); game.save_path="res://.godot/pr23-smoke-"+str(Time.get_ticks_usec())+".json"; game.audio_settings_path=game.save_path+".cfg"
	var fixture={"schema_version":2,"coins":777,"merges":42,"cells":[],"discoveries":["slime:1","horn:1"],"active_species":"slime","campaign":{"version":1,"completed":[1,2,3,4,5,6,7,8,9,10],"claimed":[1,2,3,4,5,6,7,8,9,10],"stars":10}}
	var file=FileAccess.open(game.save_path,FileAccess.WRITE); file.store_string(JSON.stringify(fixture)); file.close()
	root.size=Vector2i(540,1170); root.content_scale_size=Vector2i(540,1170); root.add_child(game)
	game.music.handle_lifecycle=false; game.music.set_volume("master",0)
	await process_frame
	await process_frame
	game.view.preferences.hints=false; game.journey_state.seen.swamp_activation=true
	game.view.layout()
	await process_frame
	await process_frame
	check(game.view.portrait_mode,"default portrait")
	await shot("complex")
	game.view.complex_ui.open_living("habitat_slime")
	await process_frame
	await shot("slime")
	var habitat=game.view.complex_ui.detail
	check(habitat.mode=="observation","observation default")
	var slot=habitat.room_state.offered()[0]
	habitat.open_design(slot)
	await process_frame
	await shot("design")
	habitat.close_front_panel(); game.view.complex_ui.close_living()
	game.view.complex_ui.open_living("habitat_horn")
	await process_frame
	game.view.complex_ui.detail.show_zones()
	await process_frame
	await shot("horn")
	game.view.complex_ui.close_living()
	game.view.show_panel("collection")
	await process_frame
	await shot("bestiary")
	game.view.overlay.show_entry("slime")
	await process_frame
	await shot("dossier")
	game.view.handle_back(); game.view.handle_back()
	game.open_portals()
	await process_frame
	await shot("portals")
	game.open_world_map("laboratory")
	await process_frame
	await shot("map")
	game.view.portal_ui.open_preview("laboratory","lab_01")
	await process_frame
	await shot("preview")
	game.view.open_evolution(); var screen=game.view.experiment_ui; screen.start_trial(9)
	await process_frame
	await shot("puzzle")
	tap(screen,screen.center(10)); tap(screen,screen.center(15))
	await create_timer(.25).timeout
	check(screen.session.moves_used==1,"tap merge action")
	screen.leave(); game.start_level(1,false)
	await process_frame
	await shot("classic")
	game.view.show_panel("settings")
	await process_frame
	await shot("settings")
	game.free()
	print("Portrait smoke checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)
