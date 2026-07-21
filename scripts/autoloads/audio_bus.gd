extends Node
## SFX via generated tones + looping mission MP3s.

const MENU_MUSIC := "res://assets/audio/Menu.mp3"
const MISSION_MUSIC := [
	"res://assets/audio/Interceptor_Run.mp3", # 1-1 Planetary Ascent
	"res://assets/audio/Against_the_Solar_Wind.mp3", # 1-2 Asteroid Belt
	"res://assets/audio/Zero_G_Intercept.mp3", # 1-3 Nebula Anomaly
	"res://assets/audio/Hull_Breach_Protocol.mp3", # 1-4 Cybernetic Hive
	"res://assets/audio/Gravity_Override.mp3", # 1-5 Flagship Core
]
const ENDLESS_MUSIC := "res://assets/audio/Last_Sector_Approach.mp3"

var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _current_path: String = ""
var _stream_cache: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Master"
	add_child(_music)


func play_menu_music() -> void:
	_play_path(MENU_MUSIC, -16.0)


func play_game_music() -> void:
	if GameState.mode == GameState.Mode.ENDLESS:
		_play_path(ENDLESS_MUSIC, -12.0)
		return
	var idx := clampi(GameState.current_mission_index, 0, MISSION_MUSIC.size() - 1)
	_play_path(MISSION_MUSIC[idx], -12.0)


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


func play_shoot(freq: float = 880.0) -> void:
	_play_blip(freq, 0.04, -12.0)


func play_enemy_shoot() -> void:
	_play_blip(320.0, 0.06, -14.0)


func play_hit() -> void:
	_play_blip(180.0, 0.08, -8.0)


func play_explode() -> void:
	_play_noise(0.18, -6.0)


func play_pickup() -> void:
	_play_blip(660.0, 0.05, -10.0)
	_play_blip(990.0, 0.08, -12.0)


func play_ui() -> void:
	_play_blip(520.0, 0.05, -14.0)


func play_player_hurt() -> void:
	_play_blip(140.0, 0.12, -4.0)


func _get_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return _players[0]


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
	p.play()


func _play_noise(duration: float, volume_db: float) -> void:
	var sample_rate := 22050.0
	var frames := int(sample_rate * duration)
	var data := PackedVector2Array()
	data.resize(frames)
	for i in frames:
		var env := 1.0 - (float(i) / float(frames))
		var sample := (_rng.randf() * 2.0 - 1.0) * env * 0.25
		data[i] = Vector2(sample, sample)
	var stream := AudioStreamWAV.new()
	stream.mix_rate = int(sample_rate)
	stream.stereo = true
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.data = _pcm16(data)
	var p := _get_player()
	p.stream = stream
	p.volume_db = volume_db
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
