extends Node
## Original synthesized placeholder sounds. Drop optional WAV/OGG files into assets/audio.
const EVENTS := ["spawn", "select", "merge", "discover"]
var enabled := true
var players: Dictionary = {}
var streams: Dictionary = {}

func _ready() -> void:
	for i in range(EVENTS.size()):
		var event: String = EVENTS[i]
		var player := AudioStreamPlayer.new()
		player.volume_db = -15.0
		add_child(player)
		players[event] = player
		var stream: AudioStream
		for extension in ["wav","ogg"]:
			var path := "res://assets/audio/%s.%s" % [event,extension]
			if ResourceLoader.exists(path):
				stream = load(path) as AudioStream
				break
		if stream == null:
			stream = make_tone(i)
		streams[event] = stream
		player.stream = stream

func make_tone(kind: int) -> AudioStreamWAV:
	var duration := 0.09 if kind == 1 else 0.28 + kind*0.055
	var sample_rate := 22050
	var count := int(duration*sample_rate)
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	var phase := 0.0
	for i in range(count):
		var t := float(i)/sample_rate
		var progress := t/duration
		var base := [420.0,620.0,520.0,740.0][kind] as float
		var frequency := base*(1.0+0.6*progress)
		phase += TAU*frequency/sample_rate
		var envelope := minf(t/0.01,1.0)*pow(1.0-progress,2)
		var sample := int((sin(phase)+sin(phase*2)*0.18)*envelope*12000)
		bytes.encode_s16(i*2,sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = bytes
	return stream

func play_event(event: String) -> void:
	if enabled and players.has(event):
		(players[event] as AudioStreamPlayer).play()

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		for player: AudioStreamPlayer in players.values():
			player.stop()
