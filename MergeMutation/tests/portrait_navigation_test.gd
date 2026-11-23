extends "res://tests/portrait_layout_test.gd"
func run() -> void:
	game=Scene.instantiate(); game.save_path="res://.godot/pr23-nav-"+str(Time.get_ticks_usec())+".json"; game.audio_settings_path=game.save_path+".cfg"
	var fixture={"schema_version":2,"coins":777,"merges":42,"cells":[],"discoveries":["slime:1","horn:1"],"active_species":"slime","campaign":{"version":1,"completed":[1,2,3,4,5,6,7,8,9,10],"claimed":[1,2,3,4,5,6,7,8,9,10],"stars":10}}
	var file=FileAccess.open(game.save_path,FileAccess.WRITE); file.store_string(JSON.stringify(fixture)); file.close(); var original_hash=FileAccess.get_sha256(game.save_path)
	root.add_child(game); game.music.handle_lifecycle=false; game.music.set_volume("master",0); game.journey_state.seen.swamp_activation=true
	await process_frame
	await process_frame
	game.view.preferences.hints=false
	check(FileAccess.get_sha256(game.save_path+".pre-core-loop-"+original_hash.substr(0,12)+".bak")==original_hash,"old v2 profile backup exact")
	for tall in [true,false]:
		await resize_ui(Vector2(540,1170) if tall else Vector2(1170,540),tall)
		game.view.open_complex(); await process_frame
		var ui=game.view.complex_ui
		for id in ["habitat_slime","habitat_horn"]:
			check(ui.open_living(id),"real habitat opens")
			await process_frame
			var detail=ui.detail
			check(detail.mode=="observation" and detail.zones==null and detail.design_panel==null,"observation unencumbered")
			var world_before=detail.model.position
			var guard=0
			while not detail.room_state.offered().is_empty() and guard<20:
				var key=detail.room_state.offered()[0]; var slot: Dictionary=detail.room_state.catalog.slots[key]
				check(detail.open_design(key),"every construction site opens "+key)
				await process_frame
				detail.focus_object(key,true); detail.environment.apply_camera()
				var point=detail.camera.world_to_view(detail.environment.marker(slot))
				check(Rect2(Vector2.ZERO,detail.environment.size).has_point(point),"construction is reachable in camera "+key+str(point))
				check(detail.mode=="arrangement" and not detail.environment.is_processing(),"preview suspends simulation")
				var before=game.progression.balance(); var expected=int(slot.cost)
				press_button(detail.confirm_button)
				await process_frame
				check(detail.room_state.installed.has(key) and game.progression.balance()==before-expected,"real exact price "+key)
				check(detail.mode=="observation" and detail.design_panel==null,"confirmation frees room area")
				guard+=1
			check(detail.room_state.installed.size()==detail.room_state.catalog.slots.size(),"all installed identifiers retained")
			for key in detail.room_state.installed:
				check(detail.open_design(key),"installed object remains configurable "+key)
				await process_frame
				var before=game.progression.balance()
				var designs: Array=detail.room_state.catalog.slots[key].designs
				detail.select_design(designs.back().design_id)
				press_button(detail.confirm_button); await process_frame
				check(game.progression.balance()==before and detail.room_state.installed[key]==designs.back().design_id,"installed design change is free")
			# Pause and rotation during an actual preview retain its IDs and wallet.
			var key=detail.room_state.installed.keys()[0]; detail.open_design(key); await process_frame
			var choice=detail.chosen_design; var balance=game.progression.balance()
			game.view.set_portrait(not tall); game.view.set_portrait(tall)
			check(detail.chosen_slot==key and detail.chosen_design==choice and game.progression.balance()==balance,"orientation preserves preview")
			game._notification(Node.NOTIFICATION_APPLICATION_PAUSED); await process_frame
			var elapsed=detail.model.simulation_time; await create_timer(.1).timeout
			check(is_equal_approx(detail.model.simulation_time,elapsed),"paused habitat does not tick")
			game._notification(Node.NOTIFICATION_APPLICATION_RESUMED); detail.close_front_panel(); await process_frame
			await process_frame
			check(detail.environment.is_processing(),"observation resumes")
			# Exercise the same presentation against a large, isolated fixture. Production S rooms stay S.
			if id=="habitat_horn":
				var old_width=detail.model.registry.world_width
				detail.model.registry.world_width=2820; detail.reflow(); detail.show_zones(); await process_frame
				check(detail.mode=="zones" and is_instance_valid(detail.zones),"large room exposes zone overview")
				inspect_controls(detail,"large room zones")
				detail.close_front_panel(); detail.camera.focus(Vector2(2400,300),true)
				var camera_before=detail.camera.position
				drag(detail.environment,Vector2(200,150),Vector2(320,150))
				check(detail.camera.position.x<camera_before.x and detail.design_panel==null,"camera swipe never installs")
				detail.show_zones(); await process_frame
				var close=detail.zones.find_child("CloseZones",true,false); press_button(close); await process_frame
				check(detail.mode=="observation","zone sheet closes without leaving habitat")
				detail.model.registry.world_width=old_width; detail.reflow()
			ui.close_living(); await process_frame
		game.view.show_panel("collection"); await process_frame
		var archive=game.view.overlay
		archive.query.text="сли"; archive.query.text_changed.emit("сли"); await process_frame
		check(archive.cards.size()==1 and archive.cards.has("slime"),"search filters known names")
		archive.query.text=""; archive.filter.select(2); archive.filter_index=2; archive.refresh_list(); await process_frame
		for key in archive.cards: check(not game.species_known(key),"unknown filter does not reveal known entries")
		archive.show_entry("slime"); await process_frame
		game.view.show_panel("settings"); await process_frame
		var settings=game.view.overlay
		var slider=settings.find_child("Volume_music",true,false); var before_volume=game.music.volumes.music
		tap(slider,Vector2(slider.size.x*.31,slider.size.y*.5))
		check(absf(game.music.volumes.music-.31)<.06 and game.music.volumes.music!=before_volume,"real native touch audio slider")
		game.view.set_portrait(not tall); game.view.set_portrait(tall)
		game.view.handle_back(); await process_frame
		check(game.view.overlay==archive and archive.showing_dossier and archive.selected=="slime","settings and orientation restore exact dossier")
		game.view.handle_back(); game.view.handle_back()
		game.open_portals(); await process_frame
		var portal=game.view.portal_ui
		for repeat in range(20):
			drag(portal.carousel,Vector2(180,150),Vector2(320,150),repeat%2==0)
			await process_frame
			check(portal.page=="hub" and not portal.entering,"rapid door swipes cannot enter")
		var lab=portal.find_child("LaboratoryStand",true,false)
		var old_world=portal.selected
		drag(lab,Vector2(100,130),Vector2(100,30))
		check(portal.page=="hub","vertical hall scroll cannot open map")
		portal.hub_scroll.scroll_vertical=0; await process_frame
		press_button(lab); await create_timer(.2).timeout
		check(portal.page=="map" and portal.selected=="laboratory","lab is entered via stand")
		check(portal.open_preview("laboratory","lab_01"),"real preview opens")
		await process_frame
		var before_coins=game.coins; var before_bio=game.progression.balance()
		game.view.handle_back(); check(portal.preview==null and portal.page=="map","Back closes preview")
		check(game.coins==before_coins and game.progression.balance()==before_bio,"navigation never awards")
		check(not portal.open_preview("toxic_swamp","toxic_swamp_01"),"demo node cannot launch through preview")
		game.view.close_navigation()
	var coins=game.coins; var balance=game.progression.balance(); var installations=game.progression.data.duplicate(true); var path=game.save_path; var cfg=game.audio_settings_path
	game.free(); game=Scene.instantiate(); game.save_path=path; game.audio_settings_path=cfg; root.add_child(game)
	await process_frame
	await process_frame
	check(game.coins==coins and game.progression.balance()==balance and game.progression.data.habitats==installations.habitats and game.progression.data.observations==installations.observations and game.progression.data.claimed_levels==installations.claimed_levels,"restart preserves economy, observations and installations")
	game.free(); print("Portrait navigation checks: %d; failures: %d" % [checks,failures]); quit(1 if failures else 0)
