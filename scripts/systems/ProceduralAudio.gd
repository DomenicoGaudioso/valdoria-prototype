extends Node

## ProceduralAudio - lightweight WebAudio-style fallback for Godot.
## It creates original ambience and SFX at runtime, so the prototype has sound
## without external or protected audio assets.

const MIX_RATE := 22050
const BUFFER_CHUNK := 256

var _enabled: bool = false
var _music_time: float = 0.0
var _combat_intensity: float = 0.0
var _voices: Array[Dictionary] = []

var _music_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _music_playback: AudioStreamGeneratorPlayback
var _sfx_playback: AudioStreamGeneratorPlayback


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player = _make_generator_player("ProceduralMusic", -24.0, 0.9)
	_sfx_player = _make_generator_player("ProceduralSfx", -10.0, 0.35)
	add_child(_music_player)
	add_child(_sfx_player)


func _process(delta: float) -> void:
	if not _enabled:
		return
	_combat_intensity = max(0.0, _combat_intensity - delta * 0.2)
	_fill_music()
	_fill_sfx()


func start_after_user_gesture() -> void:
	if _enabled:
		return
	_enabled = true
	_music_player.play()
	_sfx_player.play()
	_music_playback = _music_player.get_stream_playback() as AudioStreamGeneratorPlayback
	_sfx_playback = _sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	play_cue("audio_start")


func set_combat_intensity(value: float) -> void:
	_combat_intensity = clamp(value, 0.0, 1.0)


func play_cue(cue: String) -> void:
	if not _enabled and cue != "audio_start":
		return

	match cue:
		"audio_start":
			_add_voice(110.0, 0.25, 0.18, "rise")
		"attack":
			set_combat_intensity(0.85)
			_add_voice(170.0, 0.16, 0.28, "slash")
			_add_voice(520.0, 0.12, 0.12, "spark")
		"enemy_attack":
			set_combat_intensity(0.65)
			_add_voice(95.0, 0.22, 0.22, "growl")
		"enemy_hurt":
			set_combat_intensity(0.5)
			_add_voice(260.0, 0.12, 0.12, "crack")
		"enemy_death":
			set_combat_intensity(0.75)
			_add_voice(70.0, 0.45, 0.28, "fall")
		"equip":
			_add_voice(330.0, 0.18, 0.15, "spark")
			_add_voice(660.0, 0.20, 0.08, "spark")
		"portal":
			_add_voice(55.0, 0.7, 0.24, "rise")
		"level_up":
			_add_voice(220.0, 0.35, 0.18, "rise")
			_add_voice(440.0, 0.45, 0.12, "rise")
		_:
			_add_voice(180.0, 0.12, 0.10, "spark")


func _make_generator_player(node_name: String, volume_db: float, buffer_length: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.volume_db = volume_db
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = buffer_length
	player.stream = stream
	return player


func _add_voice(freq: float, duration: float, amp: float, shape: String) -> void:
	_voices.append({
		"freq": freq,
		"duration": duration,
		"amp": amp,
		"shape": shape,
		"t": 0.0,
	})


func _fill_music() -> void:
	if not _music_playback:
		return
	while _music_playback.can_push_buffer(BUFFER_CHUNK):
		var frames := PackedVector2Array()
		for i in range(BUFFER_CHUNK):
			var pulse := 0.5 + 0.5 * sin(_music_time * TAU * (0.42 + _combat_intensity * 0.45))
			var drone := sin(_music_time * TAU * 55.0) * 0.055
			drone += sin(_music_time * TAU * 82.5) * 0.025
			var high := sin(_music_time * TAU * 220.0) * 0.012 * pulse * _combat_intensity
			var sample := (drone + high) * (0.75 + _combat_intensity * 0.45)
			frames.append(Vector2(sample, sample))
			_music_time += 1.0 / float(MIX_RATE)
		_music_playback.push_buffer(frames)


func _fill_sfx() -> void:
	if not _sfx_playback:
		return
	while _sfx_playback.can_push_buffer(BUFFER_CHUNK):
		var frames := PackedVector2Array()
		for i in range(BUFFER_CHUNK):
			var sample := 0.0
			for v in _voices:
				var t: float = float(v["t"])
				var duration: float = max(float(v["duration"]), 0.001)
				var age: float = clamp(t / duration, 0.0, 1.0)
				var env: float = pow(1.0 - age, 1.7)
				var freq: float = float(v["freq"])
				var amp: float = float(v["amp"])
				var shape: String = str(v["shape"])
				match shape:
					"slash":
						sample += (randf() * 2.0 - 1.0) * amp * env
						sample += sin(t * TAU * (freq + age * 900.0)) * amp * env * 0.4
					"spark":
						sample += sin(t * TAU * (freq + sin(t * 70.0) * 45.0)) * amp * env
					"growl":
						sample += sin(t * TAU * (freq - age * 35.0)) * amp * env
						sample += (randf() * 2.0 - 1.0) * amp * env * 0.35
					"fall":
						sample += sin(t * TAU * (freq * (1.0 - age * 0.55))) * amp * env
					"rise":
						sample += sin(t * TAU * (freq + age * freq * 1.8)) * amp * env
					_:
						sample += sin(t * TAU * freq) * amp * env
				v["t"] = t + 1.0 / float(MIX_RATE)
			sample = clamp(sample, -0.85, 0.85)
			frames.append(Vector2(sample, sample))
		_prune_voices()
		_sfx_playback.push_buffer(frames)


func _prune_voices() -> void:
	for i in range(_voices.size() - 1, -1, -1):
		if _voices[i]["t"] >= _voices[i]["duration"]:
			_voices.remove_at(i)
