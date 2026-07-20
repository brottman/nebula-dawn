extends Node
## SFX via generated tones + looping OGG music tracks.

enum MusicTrack { NONE, MENU, GAME }

var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _current_track: MusicTrack = MusicTrack.NONE
var _rng := RandomNumberGenerator.new()

var _menu_stream: AudioStream
var _game_stream: AudioStream


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
	_menu_stream = _load_looping("res://assets/audio/menu_theme.ogg")
	_game_stream = _load_looping("res://assets/audio/game_theme.ogg")


func _load_looping(path: String) -> AudioStream:
	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("Missing music: %s" % path)
		return null
	var copy := stream.duplicate()
	if copy is AudioStreamOggVorbis:
		(copy as AudioStreamOggVorbis).loop = true
	return copy


func play_menu_music() -> void:
	_set_music(MusicTrack.MENU, _menu_stream, -16.0)


func play_game_music() -> void:
	_set_music(MusicTrack.GAME, _game_stream, -14.0)


func stop_music() -> void:
	_current_track = MusicTrack.NONE
	if _music:
		_music.stop()


func _set_music(track: MusicTrack, stream: AudioStream, volume_db: float) -> void:
	if stream == null:
		return
	if _current_track == track and _music.playing:
		return
	_current_track = track
	_music.stream = stream
	_music.volume_db = volume_db
	_music.play()


func play_shoot() -> void:
	_play_blip(880.0, 0.04, -12.0)


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
