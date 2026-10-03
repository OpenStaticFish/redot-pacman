class_name ArcadeAudio
extends Node
## Original, procedural chip sounds. No external audio dependencies.

const SAMPLE_RATE: int = 22050
var muted: bool = false
var voices: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var music: AudioStreamPlayer
var voice_index: int = 0
var dot_index: int = 0


func _ready() -> void:
	for i in 12:
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -15.0
		add_child(voice)
		voices.append(voice)
	sounds["dot_a"] = _synthesize([Vector3(490, 0.065, 230)], 0.45)
	sounds["dot_b"] = _synthesize([Vector3(360, 0.065, 690)], 0.45)
	sounds["power"] = _synthesize([Vector3(330, 0.09, 330), Vector3(440, 0.09, 440), Vector3(660, 0.1, 660), Vector3(880, 0.22, 880)])
	sounds["ghost"] = _synthesize([Vector3(880, 0.08, 1300), Vector3(1320, 0.15, 1760)])
	sounds["hit"] = _synthesize([Vector3(600, 0.16, 350), Vector3(350, 0.2, 180), Vector3(180, 0.3, 50)])
	sounds["start"] = _synthesize([Vector3(262, 0.10, 262), Vector3(330, 0.10, 330), Vector3(392, 0.10, 392), Vector3(523, 0.25, 523)])
	sounds["fork"] = _synthesize([Vector3(660, 0.1, 660), Vector3(880, 0.1, 880), Vector3(1320, 0.2, 1320)])
	sounds["clear"] = _synthesize([Vector3(523, 0.1, 523), Vector3(659, 0.1, 659), Vector3(784, 0.1, 784), Vector3(1047, 0.3, 1047)])
	music = AudioStreamPlayer.new()
	music.stream = _make_music()
	music.volume_db = -25.0
	add_child(music)
	music.play()
	_set_volume()


func play_effect(kind: String) -> void:
	if muted:
		return
	if kind == "dot":
		dot_index += 1
		kind = "dot_a" if dot_index % 2 == 0 else "dot_b"
	if not sounds.has(kind):
		return
	var voice: AudioStreamPlayer = voices[voice_index]
	voice_index = (voice_index + 1) % voices.size()
	voice.stream = sounds[kind]
	voice.play()


func toggle_mute() -> void:
	muted = not muted
	_set_volume()


func _set_volume() -> void:
	if is_instance_valid(music):
		music.volume_db = -80.0 if muted else -25.0
	for voice: AudioStreamPlayer in voices:
		if muted:
			voice.stop()


func set_game_paused(paused: bool) -> void:
	if is_instance_valid(music):
		music.stream_paused = paused


func stop_all() -> void:
	# Stop active playback before the audio server tears down its mixing thread.
	for voice: AudioStreamPlayer in voices:
		voice.stop()
		voice.stream = null
	if is_instance_valid(music):
		music.stop()
		music.stream = null
	sounds.clear()


func _exit_tree() -> void:
	stop_all()


func _stream_from_bytes(bytes: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	return stream


func _synthesize(notes: Array[Vector3], brightness: float = 0.25) -> AudioStreamWAV:
	var duration: float = 0.0
	for note: Vector3 in notes:
		duration += note.y
	var bytes := PackedByteArray()
	bytes.resize(int(duration * SAMPLE_RATE) * 2)
	var sample_index: int = 0
	var phase: float = 0.0
	for note: Vector3 in notes:
		var count: int = int(note.y * SAMPLE_RATE)
		for i in count:
			var t: float = float(i) / SAMPLE_RATE
			var frequency: float = lerpf(note.x, note.z, t / note.y)
			phase += TAU * frequency / SAMPLE_RATE
			var envelope: float = minf(t / 0.004, 1.0) * minf((note.y - t) / 0.035, 1.0)
			var wave: float = sin(phase) + sin(phase * 2.0) * brightness
			if sample_index * 2 + 1 < bytes.size():
				bytes.encode_s16(sample_index * 2, int(wave * envelope * 15000.0))
			sample_index += 1
	return _stream_from_bytes(bytes)


func _make_music() -> AudioStreamWAV:
	var duration: float = 8.0
	var bytes := PackedByteArray()
	var samples: int = int(duration * SAMPLE_RATE)
	bytes.resize(samples * 2)
	var melody: Array[float] = [261.63, 329.63, 392.0, 523.25, 220.0, 261.63, 329.63, 440.0, 174.61, 220.0, 261.63, 349.23, 196.0, 246.94, 293.66, 392.0]
	var bass: Array[float] = [65.41, 55.0, 43.65, 49.0]
	for i in samples:
		var t: float = float(i) / SAMPLE_RATE
		var tick: int = int(t / 0.125)
		var local: float = fmod(t, 0.125)
		var note: float = melody[(tick / 4) % melody.size()]
		var arp: float = sin(TAU * note * t) * exp(-local * 22.0) * 0.18
		var low: float = sin(TAU * bass[int(t / 2.0) % 4] * t) * 0.22
		var beat: float = fmod(t, 0.5)
		var kick: float = sin(TAU * (48.0 * beat + 2.0 * (1.0 - exp(-beat * 35.0)))) * exp(-beat * 25.0) * 0.3
		var hat: float = sin(t * 43271.0) * sin(t * 21731.0) * exp(-local * 90.0) * 0.055
		bytes.encode_s16(i * 2, int(clampf(arp + low + kick + hat, -1.0, 1.0) * 24000.0))
	var stream: AudioStreamWAV = _stream_from_bytes(bytes)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = samples
	return stream
