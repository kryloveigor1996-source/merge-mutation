extends SceneTree
const Manager=preload("res://scripts/music_manager.gd")
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures+=1; printerr("FAIL: ",label)
func run() -> void:
	var path:="res://.godot/audio-test-"+str(Time.get_ticks_usec())+".cfg"
	var old:=ConfigFile.new()
	old.set_value("audio","enabled",false)
	old.set_value("unrelated","keep",42)
	old.save(path)
	var manager:=Manager.new()
	manager.settings_path=path
	manager.handle_lifecycle=false
	root.add_child(manager)
	check(manager.volumes.sfx==0,"old mute migrated without muting music")
	check(manager.config.tracks.size()==9,"seven arrangements and two jingles")
	var bytes:=0
	for id in manager.config.tracks:
		var entry: Dictionary=manager.config.tracks[id]
		var stream=manager.stream(id)
		check(stream is AudioStreamOggVorbis,"OGG decoded "+id)
		check(absf(stream.get_length()-entry.duration)<0.05,"exact duration "+id)
		check(stream.loop==entry.loop,"music loops, jingles once "+id)
		bytes+=FileAccess.get_file_as_bytes(entry.path).size()
	check(bytes<15*1024*1024,"mobile soundtrack under 15 MiB")
	manager.context("complex")
	check(manager.current=="complex_theme" and manager.starts==1,"startup music")
	await create_timer(0.3).timeout
	var position: float=manager.players[manager.active].get_playback_position()
	for i in range(20): manager.context("complex")
	check(manager.starts==1,"ordinary panels never restart same location")
	manager.context("portals")
	for key in ["puzzles","habitat_slime","habitat_horn","bestiary","sandbox"]: manager.context(key)
	check(manager.starts==2,"rapid navigation coalesces transitions")
	await create_timer(3.2).timeout
	check(manager.current=="sandbox_theme","latest rapid destination wins")
	check(manager.positions.complex_theme>=position,"departure position retained")
	var voices:=0
	for player in manager.players:
		if player.playing: voices+=1
	check(voices==1,"only one background after crossfade")
	for key in ["puzzles","habitat_slime","habitat_horn","bestiary","complex"]:
		manager.context(key)
		await create_timer(1.6).timeout
		check(manager.current==manager.config.locations[key],"location music "+key)
	check(manager.players[manager.active].get_playback_position()>position,"return resumes position")
	manager.event("victory")
	manager.event("discovery")
	await create_timer(0.4).timeout
	check(manager.jingle.playing and manager.event_queue.size()==1,"events queued instead of overlapping")
	check(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Background"))<-8,"background ducks during event")
	manager.suspend(true)
	check(manager.jingle.stream_paused and manager.players[manager.active].stream_paused,"Android lifecycle pause method")
	manager.suspend(false)
	check(not manager.jingle.stream_paused,"lifecycle resumes")
	await create_timer(10.0).timeout
	check(manager.event_queue.is_empty() and not manager.jingle.playing,"both jingles complete once")
	check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Background")))<0.1,"duck restored")
	for id in ["master","music","sfx"]: manager.set_volume(id,0.23)
	check(AudioServer.get_bus_send(AudioServer.get_bus_index("Background"))=="Music","background routed through independent music bus")
	check(manager.players.size()==2 and manager.jingle.bus=="Music","bounded player pool")
	manager.free()
	var reloaded:=Manager.new()
	reloaded.settings_path=path
	reloaded.handle_lifecycle=false
	root.add_child(reloaded)
	for id in reloaded.volumes: check(is_equal_approx(reloaded.volumes[id],0.23),"volume persisted "+id)
	old.load(path)
	check(old.get_value("unrelated","keep")==42,"existing settings preserved")
	reloaded.context("complex")
	reloaded.context("portals")
	reloaded.suspend(true)
	await create_timer(0.1).timeout
	reloaded.suspend(false)
	await create_timer(1.7).timeout
	check(reloaded.current=="portal_theme","crossfade survives suspension")
	reloaded.free()
	print("Adaptive audio checks: %d; failures: %d" % [checks,failures])
	quit(1 if failures else 0)