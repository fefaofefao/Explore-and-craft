extends Node
## Autoload "Audio": efeitos (WAV gerados em tools/gen_audio.py) e música ambiente por bioma, com volume das configurações.

var _players: Array = []
var _music: AudioStreamPlayer
var _cache: Dictionary = {}
var _current_music := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	_music.finished.connect(func(): _music.play())


func _stream(name: String) -> AudioStream:
	if _cache.has(name):
		return _cache[name]
	var path := "res://assets/audio/%s.wav" % name
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
	elif ResourceLoader.exists(path.replace(".wav", ".ogg")):
		s = load(path.replace(".wav", ".ogg"))
	_cache[name] = s
	return s


func play(name: String, pitch_var: float = 0.08) -> void:
	var s := _stream(name)
	if s == null:
		return
	var vol := float(Game.settings.get("sfx", 0.9))
	if vol <= 0.01:
		return
	for p in _players:
		if not p.playing:
			p.stream = s
			p.volume_db = linear_to_db(vol)
			p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
			p.play()
			return


func play_music(name: String) -> void:
	if name == _current_music:
		return
	_current_music = name
	var s := _stream("music_" + name)
	if s == null:
		_music.stop()
		return
	_music.stream = s
	update_volume()
	_music.play()


func update_volume() -> void:
	var v := float(Game.settings.get("music", 0.7))
	_music.volume_db = linear_to_db(maxf(v, 0.0001)) - 6.0
	_music.stream_paused = v <= 0.01


func vibrate(ms: int = 30) -> void:
	if Game.settings.get("vibration", true) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
