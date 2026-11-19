extends Node
signal volumes_changed
var settings_path:="user://merge_mutation_settings.cfg"
var config: Dictionary={}
var volumes: Dictionary={"master":0.8,"music":0.75,"sfx":0.8}
var players: Array[AudioStreamPlayer]=[]
var jingle: AudioStreamPlayer
var positions: Dictionary={}
var current:=""
var desired:=""
var active:=0
var transition: Tween
var duck_tween: Tween
var event_queue: Array=[]
var suspended:=false
var handle_lifecycle:=true
var starts:=0
func _ready() -> void:
	config=JSON.parse_string(FileAccess.get_file_as_string("res://data/music.json"))
	for id in ["Music","SFX","Background"]:
		if AudioServer.get_bus_index(id)<0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,id)
	AudioServer.set_bus_send(AudioServer.get_bus_index("Background"),"Music")
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Background"),0)
	for i in range(2):
		var player:=AudioStreamPlayer.new()
		player.bus="Background"
		add_child(player)
		players.append(player)
	jingle=AudioStreamPlayer.new()
	jingle.bus="Music"
	jingle.volume_db=-7
	add_child(jingle)
	jingle.finished.connect(next_event)
	load_settings()
func load_settings() -> void:
	var file:=ConfigFile.new()
	if file.load(settings_path)==OK:
		for id in volumes:
			var fallback: float=0.0 if id=="sfx" and file.get_value("audio","enabled",true)==false else float(volumes[id])
			var value: Variant=file.get_value("audio",id,fallback)
			if (value is float or value is int) and is_finite(float(value)): volumes[id]=clampf(float(value),0,1)
	apply_volumes()
func apply_volumes() -> void:
	for id in volumes:
		var bus: String={"master":"Master","music":"Music","sfx":"SFX"}[id]
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus),linear_to_db(maxf(0.0001,volumes[id])))
		AudioServer.set_bus_mute(AudioServer.get_bus_index(bus),volumes[id]==0)
func set_volume(id: String,value: float) -> void:
	if not volumes.has(id) or not is_finite(value): return
	volumes[id]=clampf(value,0,1)
	apply_volumes()
	var file:=ConfigFile.new()
	file.load(settings_path)
	for key in volumes: file.set_value("audio",key,volumes[key])
	file.set_value("audio","enabled",volumes.sfx>0)
	file.save(settings_path)
	volumes_changed.emit()
func stream(id: String) -> AudioStream:
	var entry: Dictionary=config.tracks.get(id,{})
	if entry.is_empty() or not ResourceLoader.exists(entry.path): return null
	var value: AudioStream=load(entry.path)
	if value is AudioStreamOggVorbis: value.loop=entry.loop
	return value
func context(location: String) -> void:
	var id: String=config.locations.get(location,"complex_theme")
	desired=id
	if id==current or suspended: return
	if transition!=null and transition.is_running(): return
	var value:=stream(id)
	if value==null: return
	var old:=active
	var next:=1-active
	if not current.is_empty(): positions[current]=players[old].get_playback_position()
	players[next].stop()
	players[next].stream=value
	players[next].volume_db=-60 if not current.is_empty() else float(config.background_db)
	players[next].play(float(positions.get(id,0)))
	starts+=1
	var previous:=current
	current=id
	active=next
	if previous.is_empty(): return
	transition=create_tween().set_parallel(true)
	transition.tween_property(players[next],"volume_db",float(config.background_db),float(config.crossfade_seconds))
	transition.tween_property(players[old],"volume_db",-60.0,float(config.crossfade_seconds))
	transition.finished.connect(func():
		players[old].stop()
		if desired!=current:
			for location_key in config.locations:
				if config.locations[location_key]==desired:
					context(location_key)
					break
	)
func event(id: String) -> void:
	if not config.events.has(id): return
	event_queue.append(config.events[id])
	if not jingle.playing: next_event()
func next_event() -> void:
	if event_queue.is_empty():
		duck(0)
		return
	var id: String=event_queue.pop_front()
	jingle.stream=stream(id)
	if jingle.stream==null:
		next_event()
		return
	duck(float(config.duck_db))
	jingle.play()
func duck(value: float) -> void:
	if duck_tween!=null: duck_tween.kill()
	var index:=AudioServer.get_bus_index("Background")
	duck_tween=create_tween()
	duck_tween.tween_method(func(db: float): AudioServer.set_bus_volume_db(index,db),AudioServer.get_bus_volume_db(index),value,0.35)
func suspend(value: bool) -> void:
	suspended=value
	for player in players: player.stream_paused=value
	jingle.stream_paused=value
	for tween in [transition,duck_tween]:
		if tween!=null and tween.is_valid():
			if value: tween.pause()
			else: tween.play()
	if not value and desired!=current:
		for key in config.locations:
			if config.locations[key]==desired: context(key); break
func _notification(what: int) -> void:
	if not is_node_ready() or not handle_lifecycle: return
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT]: suspend(true)
	elif what in [NOTIFICATION_APPLICATION_RESUMED,NOTIFICATION_APPLICATION_FOCUS_IN]: suspend(false)
