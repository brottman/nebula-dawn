extends Node
## Sampled SFX + looping mission MP3s, with Music/SFX buses for volume.

const MENU_MUSIC := "res://assets/audio/Menu.mp3"
const MISSION_MUSIC := [
	"res://assets/audio/Interceptor_Run.mp3", # 1-1
	"res://assets/audio/Against_the_Solar_Wind.mp3", # 1-2
	"res://assets/audio/Zero_G_Intercept.mp3", # 1-3
	"res://assets/audio/Hull_Breach_Protocol.mp3", # 1-4
	"res://assets/audio/Gravity_Override.mp3", # 1-5
	"res://assets/audio/Orbital_Strike_Pattern.mp3", # 2-1 Mirror Field
	"res://assets/audio/Against_the_Solar_Wind.mp3", # 2-2 Ion Storm
	"res://assets/audio/Zero_G_Intercept.mp3", # 2-3 Phantom Wake
	"res://assets/audio/Hull_Breach_Protocol.mp3", # 2-4 Scrap Gauntlet
	"res://assets/audio/Last_Sector_Approach.mp3", # 2-5 Dawn Gate
]
const ENDLESS_MUSIC := "res://assets/audio/Last_Sector_Approach.mp3"

const SFX_PATHS := {
	"shoot": "res://assets/audio/sfx/shoot.wav",
	"enemy_shoot": "res://assets/audio/sfx/enemy_shoot.wav",
	"hit": "res://assets/audio/sfx/hit.wav",
	"explode": "res://assets/audio/sfx/explode.wav",
	"pickup": "res://assets/audio/sfx/pickup.wav",
	"ui": "res://assets/audio/sfx/ui.wav",
	"hurt": "res://assets/audio/sfx/hurt.wav",
	"bomb": "res://assets/audio/sfx/bomb.wav",
}

var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _current_path: String = ""
var _stream_cache: Dictionary = {}
var _sfx_cache: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_ensure_buses()
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_preload_sfx()
	apply_volumes()


func _ensure_buses() -> void:
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		var mi := AudioServer.bus_count - 1
		AudioServer.set_bus_name(mi, "Music")
		AudioServer.set_bus_send(mi, "Master")
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		var si := AudioServer.bus_count - 1
		AudioServer.set_bus_name(si, "SFX")
		AudioServer.set_bus_send(si, "Master")


func apply_volumes() -> void:
	_ensure_buses()
	var music_db := linear_to_db(clampf(GameState.music_volume, 0.0001, 1.0)) if GameState.music_volume > 0.001 else -80.0
	var sfx_db := linear_to_db(clampf(GameState.sfx_volume, 0.0001, 1.0)) if GameState.sfx_volume > 0.001 else -80.0
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), music_db)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), sfx_db)


func _preload_sfx() -> void:
	for key in SFX_PATHS.keys():
		var stream := load(SFX_PATHS[key])
		if stream:
			_sfx_cache[key] = stream


func play_menu_music() -> void:
	_play_path(MENU_MUSIC, -4.0)


func play_game_music() -> void:
	if GameState.mode == GameState.Mode.ENDLESS:
		_play_path(ENDLESS_MUSIC, 0.0)
		return
	var idx := clampi(GameState.current_mission_index, 0, MISSION_MUSIC.size() - 1)
	_play_path(MISSION_MUSIC[idx], 0.0)


func stop_music() -> void:
	_current_path = ""
	if _music:
		_music.stop()


func _play_path(path: String, volume_db: float) -> void:
	if path == _current_path and _music.playing:
		return
	var stream := _get_looping_stream(path)
	if stream == null:
		return
	_current_path = path
	_music.stream = stream
	_music.volume_db = volume_db
	_music.play()


func _get_looping_stream(path: String) -> AudioStream:
	if _stream_cache.has(path):
		return _stream_cache[path]
	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("Missing music: %s" % path)
		return null
	var copy := stream.duplicate()
	if copy is AudioStreamOggVorbis:
		(copy as AudioStreamOggVorbis).loop = true
	elif copy is AudioStreamMP3:
		(copy as AudioStreamMP3).loop = true
	_stream_cache[path] = copy
	return copy


func play_shoot(_freq: float = 880.0) -> void:
	_play_sfx("shoot", -10.0, 0.06)


func play_enemy_shoot() -> void:
	_play_sfx("enemy_shoot", -12.0, 0.05)


func play_hit() -> void:
	_play_sfx("hit", -8.0, 0.08)


func play_explode() -> void:
	_play_sfx("explode", -4.0, 0.04)


func play_pickup() -> void:
	_play_sfx("pickup", -8.0, 0.03)


func play_ui() -> void:
	_play_sfx("ui", -12.0, 0.02)


func play_player_hurt() -> void:
	_play_sfx("hurt", -2.0, 0.03)


func play_bomb() -> void:
	_play_sfx("bomb", -3.0, 0.02)


func play_graze() -> void:
	## High, soft blip for near-miss grazes (procedural, no sample needed).
	_play_blip(1240.0, 0.06, -16.0)


func _get_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return _players[0]


func _play_sfx(key: String, volume_db: float, pitch_jitter: float = 0.0) -> void:
	var stream: AudioStream = _sfx_cache.get(key)
	if stream == null:
		# Fallback procedural blip if sample missing.
		_play_blip(440.0, 0.05, volume_db)
		return
	var p := _get_player()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + _rng.randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func _play_blip(freq: float, duration: float, volume_db: float) -> void:
	var sample_rate := 22050.0
	var frames := int(sample_rate * duration)
	var data := PackedVector2Array()
	data.resize(frames)
	for i in frames:
		var t := float(i) / sample_rate
		var env := 1.0 - (float(i) / float(frames))
		var sample := sin(TAU * freq * t) * env * 0.35
		data[i] = Vector2(sample, sample)
	var stream := AudioStreamWAV.new()
	stream.mix_rate = int(sample_rate)
	stream.stereo = true
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.data = _pcm16(data)
	var p := _get_player()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0
	p.play()


func _pcm16(samples: PackedVector2Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 4)
	var i := 0
	for s in samples:
		var l := clampi(int(s.x * 32767.0), -32768, 32767)
		var r := clampi(int(s.y * 32767.0), -32768, 32767)
		bytes[i] = l & 0xFF
		bytes[i + 1] = (l >> 8) & 0xFF
		bytes[i + 2] = r & 0xFF
		bytes[i + 3] = (r >> 8) & 0xFF
		i += 4
	return bytes
