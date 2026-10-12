extends Node
## Sonido del juego: buses (Música, Efectos, Voces), efectos sueltos en 2D o
## en 3D y música que cambia sola según dónde está el héroe y qué pasa.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/musica/"
## Volumen de cada pista (dB) para que todas suenen parecido.
const MUSIC_GAIN := {"titulo": -5.0, "aldea": -9.0, "pradera": -9.0, "noche": -7.0, "combate": -5.0,
	"jefe": -5.0, "mazmorra": -6.0, "final": -5.0, "fin": -7.0}
## Efectos con variantes: nombre -> cuántas hay (swing_0, swing_1...).
const VARIANTS := {"swing": 3, "hit": 3, "step_grass": 4, "step_stone": 3, "hoof": 2}

var main: Node
var _cache := {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current := ""
var _forced := ""
var _check := 0.0
var _combat_hold := 0.0
var _voice: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Musica", "Efectos", "Voces"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	_music_a = _player("Musica")
	_music_b = _player("Musica")
	_voice = _player("Voces")
	add_to_group("audio")


func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	return p


func _load(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


func _sfx_stream(name_: String) -> AudioStream:
	if VARIANTS.has(name_):
		name_ = "%s_%d" % [name_, randi() % int(VARIANTS[name_])]
	return _load(SFX_DIR + name_ + ".ogg")


## Efecto en pantalla (interfaz, recompensas).
func ui(name_: String, volume_db := 0.0, pitch := 1.0) -> void:
	var stream := _sfx_stream(name_)
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = "Efectos"
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## Efecto en un punto del mundo: suena más bajo cuanto más lejos.
func at(name_: String, pos: Vector3, volume_db := 0.0, pitch_jitter := 0.08) -> void:
	var stream := _sfx_stream(name_)
	if stream == null or main == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = "Efectos"
	p.volume_db = volume_db
	p.unit_size = 8.0
	p.max_distance = 60.0
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	main.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


## Voz de una escena. Devuelve cuánto dura (0 si no hay grabación).
func voice(path: String) -> float:
	_voice.stop()
	var stream := _load(path)
	if stream == null:
		return 0.0
	_voice.stream = stream
	_voice.play()
	return stream.get_length()


func stop_voice() -> void:
	_voice.stop()


## Fuerza una pista (título, final...). "" vuelve a la música automática.
func force_music(track: String) -> void:
	_forced = track
	if track != "":
		_play_music(track)


func _play_music(track: String, fade := 1.8) -> void:
	if track == _current:
		return
	_current = track
	var stream := _load(MUSIC_DIR + track + ".ogg")
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	var old := _music_a
	_music_a = _music_b
	_music_b = old
	var gain: float = MUSIC_GAIN.get(track, -8.0)
	_music_a.stream = stream
	_music_a.volume_db = -40.0
	_music_a.play()
	var tw := create_tween().set_parallel()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_music_a, "volume_db", gain, fade)
	tw.tween_property(_music_b, "volume_db", -40.0, fade)
	tw.chain().tween_callback(_music_b.stop)


func _process(delta: float) -> void:
	if _forced != "" or main == null or main._player == null:
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.5
	_play_music(_pick_track())


func _pick_track() -> String:
	var player: Node3D = main._player
	if main.story() and main.story().is_final_area():
		var fb: Node = main.story().final_boss
		return "final" if fb and is_instance_valid(fb) and fb.is_alive() else "fin"
	# ¿Algún enemigo persiguiendo al héroe?
	var boss_near := false
	var fighting := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive():
			continue
		var d: float = e.global_position.distance_to(player.global_position)
		if d < 22.0 and e.is_chasing():
			fighting = true
			if e.is_boss():
				boss_near = true
	if boss_near:
		return "jefe"
	if fighting:
		_combat_hold = 4.0
		return "combate"
	if _combat_hold > 0.0:
		_combat_hold -= 0.5
		return _current
	if main.in_dungeon():
		return "mazmorra"
	if main.indoor_name() != "":
		return "aldea"
	if main.is_night():
		return "noche"
	if main.near_village():
		return "aldea"
	return "pradera"
