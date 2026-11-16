extends Node

## 音效播放器（autoload: Sfx）。音频文件缺失时静默，不报错。

const DIR := "res://assets/audio/"

var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _cache: Dictionary = {}
var muted := false


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Master"
	_music.volume_db = -14.0
	add_child(_music)


func _stream(name: String) -> AudioStream:
	if _cache.has(name):
		return _cache[name]
	var path := DIR + name + ".wav"
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
	_cache[name] = s
	return s


func play(name: String, pitch := 1.0, vol := -4.0) -> void:
	if muted:
		return
	var s := _stream(name)
	if s == null:
		return
	for p in _players:
		if not p.playing:
			p.stream = s
			p.pitch_scale = pitch
			p.volume_db = vol
			p.play()
			return


func play_music(name: String, vol := -16.0) -> void:
	var path := DIR + "music_" + name + ".ogg"
	if not ResourceLoader.exists(path):
		path = DIR + "music_" + name + ".wav"
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamWAV:
		var w := stream as AudioStreamWAV
		if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(w.data.size() / 2)
	if _music.stream == stream and _music.playing:
		return
	_music.stream = stream
	_music.volume_db = vol
	_music.play()


func stop_music() -> void:
	_music.stop()
