extends CanvasLayer
## Escenas cinematográficas: barras negras, cámara que se mueve sola,
## subtítulos y voz. Clic / F / Espacio pasa a la siguiente línea; Esc salta
## toda la escena.

const Data := preload("res://scripts/cinematics_data.gd")
const GOLD := Color(0.91, 0.76, 0.42)
const BAR := 120.0

var main: Node
var _cam: Camera3D
var _top: ColorRect
var _bottom: ColorRect
var _speaker: Label
var _text: Label
var _skip: Button
var _shots: Array = []
var _index := -1
var _time := 0.0
var _length := 0.0
var _done: Callable
var _playing := false
var _prev_cam: Camera3D
var _actors: Array = []
var _hidden_hud := false


func _ready() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("cinematic")
	_top = _bar()
	_top.anchor_right = 1.0
	_bottom = _bar()
	_bottom.anchor_top = 1.0
	_bottom.anchor_right = 1.0
	_bottom.anchor_bottom = 1.0
	_speaker = Label.new()
	_speaker.add_theme_font_size_override("font_size", 22)
	_speaker.add_theme_color_override("font_color", GOLD)
	_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speaker.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_speaker.offset_top = -112
	_speaker.offset_bottom = -82
	add_child(_speaker)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 24)
	_text.add_theme_color_override("font_color", Color(0.97, 0.95, 0.9))
	_text.add_theme_color_override("font_outline_color", Color.BLACK)
	_text.add_theme_constant_override("outline_size", 6)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_text.offset_left = 160
	_text.offset_right = -160
	_text.offset_top = -80
	_text.offset_bottom = -12
	add_child(_text)
	_skip = Button.new()
	_skip.text = "Saltar ▶▶"
	_skip.flat = true
	_skip.add_theme_font_size_override("font_size", 18)
	_skip.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	_skip.anchor_left = 1.0
	_skip.anchor_right = 1.0
	_skip.offset_left = -170
	_skip.offset_right = -20
	_skip.offset_top = 30
	_skip.offset_bottom = 80
	_skip.pressed.connect(skip)
	add_child(_skip)
	visible = false
	_cam = Camera3D.new()
	_cam.fov = 50.0
	_cam.process_mode = Node.PROCESS_MODE_ALWAYS


func _bar() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color.BLACK
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func is_playing() -> bool:
	return _playing


## Reproduce una escena. Cada toma: {from, to, look, look_to, speaker, voice,
## text, time, fov}. Las posiciones son del mundo.
func play(shots: Array, on_done: Callable = Callable(), actors: Array = []) -> void:
	if _playing:
		_finish(false)
	_shots = shots
	_done = on_done
	_index = -1
	_playing = true
	_actors = actors
	visible = true
	if _cam.get_parent() == null:
		main.add_child(_cam)
	_prev_cam = main.get_viewport().get_camera_3d()
	_cam.current = true
	# En grupo el mundo sigue (los amigos no deben quedarse congelados).
	var net := get_tree().get_first_node_in_group("net")
	get_tree().paused = net == null or not net.active()
	for a in _actors:
		_set_actor(a, true)
	main.set_ui_visible(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_top.offset_bottom = 0.0
	_bottom.offset_top = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_top, "offset_bottom", BAR, 0.6).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_bottom, "offset_top", -BAR, 0.6).set_trans(Tween.TRANS_CUBIC)
	_next()


## Los personajes de la escena siguen animándose aunque el mundo esté en pausa.
func _set_actor(a: Node, on: bool) -> void:
	if a == null or not is_instance_valid(a):
		return
	for l in a.find_children("*", "Label3D", true, false):
		l.visible = not on
	var anim: AnimationPlayer = a.find_child("AnimationPlayer", true, false)
	if anim:
		anim.process_mode = Node.PROCESS_MODE_ALWAYS if on else Node.PROCESS_MODE_INHERIT


func _next() -> void:
	_index += 1
	if _index >= _shots.size():
		_finish(true)
		return
	var s: Dictionary = _shots[_index]
	_time = 0.0
	var text: String = s.get("text", "")
	_speaker.text = s.get("speaker", "")
	_text.text = text
	var voice_len := 0.0
	var audio := main.audio() as Node
	if text != "" and s.has("voice"):
		voice_len = audio.voice(Data.voice_path(s.voice, text))
	_length = maxf(float(s.get("time", 3.0)), voice_len + 0.7)
	if text != "" and voice_len == 0.0:
		_length = maxf(_length, 1.5 + text.length() / 16.0)
	_cam.fov = float(s.get("fov", 50.0))
	if s.has("anim") and s.has("actor") and is_instance_valid(s.actor):
		var anim: AnimationPlayer = s.actor.find_child("AnimationPlayer", true, false)
		if anim and anim.has_animation(s.anim):
			anim.play(s.anim, 0.2)
			anim.queue("Idle")
	_place(0.0)


func _place(t: float) -> void:
	var s: Dictionary = _shots[_index]
	var k := smoothstep(0.0, 1.0, clampf(t, 0.0, 1.0))
	var from: Vector3 = s.from
	var to: Vector3 = s.get("to", from)
	var look: Vector3 = s.look
	var look_to: Vector3 = s.get("look_to", look)
	_cam.global_position = from.lerp(to, k)
	var target := look.lerp(look_to, k)
	if _cam.global_position.distance_to(target) > 0.01:
		_cam.look_at(target, Vector3.UP)


func _process(delta: float) -> void:
	if not _playing:
		return
	_time += delta
	_place(_time / maxf(_length, 0.01))
	if _time >= _length:
		_next()


func _input(event: InputEvent) -> void:
	if not _playing:
		return
	if event.is_action_pressed("ui_cancel"):
		skip()
	elif event.is_action_pressed("interact") or event.is_action_pressed("jump") or event.is_action_pressed("attack_light") \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed):
		if _time > 0.3:
			_next()
	else:
		return
	get_viewport().set_input_as_handled()


func skip() -> void:
	if _playing:
		_finish(true)


func _finish(call_done: bool) -> void:
	_playing = false
	main.audio().stop_voice()
	for a in _actors:
		_set_actor(a, false)
	_actors = []
	var tw := create_tween().set_parallel()
	tw.tween_property(_top, "offset_bottom", 0.0, 0.5)
	tw.tween_property(_bottom, "offset_top", 0.0, 0.5)
	tw.chain().tween_callback(func(): visible = _playing)
	_speaker.text = ""
	_text.text = ""
	if _prev_cam and is_instance_valid(_prev_cam):
		_prev_cam.current = true
	main.set_ui_visible(true)
	get_tree().paused = false
	if not main._touch:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if call_done and _done.is_valid():
		var cb := _done
		_done = Callable()
		cb.call()


# --- Escenas ya armadas --------------------------------------------------------

## Conversación con un personaje: primeros planos y planos por encima del hombro.
func talk(npc: Node3D, speaker: String, lines: Array, on_done: Callable) -> void:
	var player: Node3D = main._player
	var voice: String = Data.VOICE_OF.get(speaker, speaker)
	var to_player := player.global_position - npc.global_position
	to_player.y = 0
	if to_player.length() < 0.1:
		to_player = Vector3(0, 0, 1)
	var dir := to_player.normalized()
	_face(npc, player.global_position)
	_face(player, npc.global_position)
	var right := dir.cross(Vector3.UP).normalized()
	var h: Variant = npc.get("height")
	var head := npc.global_position + Vector3(0, (float(h) if h != null else 1.75) * 0.88, 0)
	var shots: Array = []
	for i in lines.size():
		var s := {"speaker": speaker, "voice": voice, "text": lines[i], "time": 3.0, "fov": 40.0, "actor": npc,
			"anim": "Interact" if i % 2 == 0 else "Idle"}
		if i % 2 == 0:
			# De lado, para no meter la cámara dentro del héroe.
			s.from = head + (dir * 0.8 + right * 1.6).normalized() * 2.4 + Vector3(0, 0.05, 0)
			s.to = head + (dir * 0.8 + right * 1.6).normalized() * 2.0
			s.look = head
		else:
			var shoulder := player.global_position + Vector3(0, 1.75, 0) + dir * 1.3 - right * 0.75
			s.from = shoulder
			s.to = shoulder + dir * -0.25
			s.look = head - Vector3(0, 0.1, 0)
			s.fov = 46.0
		shots.append(s)
	play(shots, on_done, [npc])


func _face(node: Node3D, at: Vector3) -> void:
	var d := at - node.global_position
	d.y = 0
	if d.length() < 0.01:
		return
	if node.has_method("face_yaw"):
		node.face_yaw(atan2(-d.x, -d.z))
		var m: Node3D = node.get("_model")
		if m:
			m.rotation.y = atan2(d.x, d.z)
	else:
		var m2: Node3D = node.get("_model")
		if m2:
			m2.global_rotation.y = atan2(d.x, d.z)
		else:
			node.global_rotation.y = atan2(d.x, d.z)


## Introducción al empezar una partida nueva.
func intro(on_done: Callable) -> void:
	var w: Node = main._world
	var crystal: Vector3 = w.awakening_point()
	var castle: Vector3 = w.surface(w.CASTLE.x, w.CASTLE.y)
	var village: Vector3 = w.surface(w.VILLAGE.x, w.VILLAGE.y)
	var forest: Vector3 = w.surface(w.FOREST.x, w.FOREST.y)
	var hero: Vector3 = main._player.global_position
	var t: Array = Data.INTRO
	var n := "Narrador"
	play([
		{"from": crystal + Vector3(-60, 45, 40), "to": crystal + Vector3(-20, 40, 10), "look": castle, "look_to": castle, "speaker": "", "voice": n, "text": t[0], "time": 6.0, "fov": 55.0},
		{"from": castle + Vector3(-40, 18, 60), "to": castle + Vector3(-15, 12, 48), "look": castle + Vector3(0, 10, 0), "speaker": "", "voice": n, "text": t[1], "time": 6.0},
		{"from": forest + Vector3(25, 14, 25), "to": forest + Vector3(10, 8, 12), "look": forest + Vector3(0, 3, 0), "speaker": "", "voice": n, "text": t[2], "time": 7.0},
		{"from": crystal + Vector3(8, 5, 8), "to": crystal + Vector3(4, 3, 5), "look": crystal + Vector3(0, 2.5, 0), "speaker": "", "voice": n, "text": t[3], "time": 4.5},
		{"from": hero + Vector3(2.5, 2.2, 3.0), "to": hero + Vector3(1.2, 1.7, 2.0), "look": hero + Vector3(0, 1.2, 0), "speaker": "", "voice": n, "text": t[4], "time": 5.0, "fov": 42.0},
	], on_done, [main._player])


## Voz del narrador anunciando el capítulo (sin parar el juego).
func chapter_voice(ch: int) -> void:
	if Data.CHAPTERS.has(ch):
		main.audio().voice(Data.voice_path("Narrador", Data.CHAPTERS[ch]))


## Kaito aparece en el Trono del Vacío.
func kaito_intro(kaito: Node3D, on_done: Callable) -> void:
	var p: Vector3 = main._player.global_position
	var k := kaito.global_position
	var mid := (p + k) * 0.5
	var lines: Array = Data.KAITO_INTRO
	var sp := "Kaito · El Primer Héroe"
	play([
		{"from": mid + Vector3(18, 9, 0), "to": mid + Vector3(12, 6, 6), "look": k + Vector3(0, 2, 0), "speaker": sp, "voice": "Kaito", "text": lines[0], "time": 4.0, "fov": 50.0},
		{"from": k + Vector3(1.0, 2.0, 3.2), "to": k + Vector3(0.6, 1.9, 2.6), "look": k + Vector3(0, 1.7, 0), "speaker": sp, "voice": "Kaito", "text": lines[1], "time": 4.0, "fov": 38.0},
		{"from": p + Vector3(-1.2, 1.9, 2.4), "to": p + Vector3(-1.0, 1.8, 1.6), "look": k + Vector3(0, 1.6, 0), "speaker": sp, "voice": "Kaito", "text": lines[2], "time": 4.0, "fov": 44.0},
		{"from": k + Vector3(0, 1.2, 5.0), "to": k + Vector3(0, 1.6, 3.0), "look": k + Vector3(0, 1.8, 0), "speaker": sp, "voice": "Kaito", "text": lines[3], "time": 3.0, "fov": 40.0, "actor": kaito, "anim": "2H_Melee_Attack_Spin"},
	], on_done, [kaito])


## Kaito vencido y narración final.
func ending(kaito: Node3D, on_done: Callable) -> void:
	var p: Vector3 = main._player.global_position
	var k: Vector3 = kaito.global_position if kaito and is_instance_valid(kaito) else p + Vector3(0, 0, -4)
	var lines: Array = Data.KAITO_END
	var sp := "Kaito · El Primer Héroe"
	var shots: Array = []
	for i in lines.size():
		var close := i % 2 == 0
		shots.append({"from": (k + Vector3(1.2, 1.4, 2.8)) if close else (p + Vector3(-1.1, 1.8, 2.2)),
			"to": (k + Vector3(0.8, 1.3, 2.2)) if close else (p + Vector3(-0.9, 1.7, 1.8)),
			"look": k + Vector3(0, 1.0, 0), "speaker": sp, "voice": "Kaito", "text": lines[i], "time": 3.5, "fov": 40.0})
	var w: Node = main._world
	var castle: Vector3 = w.surface(w.CASTLE.x, w.CASTLE.y)
	var village: Vector3 = w.surface(w.VILLAGE.x, w.VILLAGE.y)
	var e: Array = Data.ENDING
	shots.append({"from": village + Vector3(-50, 30, 50), "to": village + Vector3(-30, 22, 30), "look": village, "speaker": "", "voice": "Narrador", "text": e[0], "time": 6.0, "fov": 55.0})
	shots.append({"from": castle + Vector3(50, 25, 70), "to": castle + Vector3(30, 18, 50), "look": castle + Vector3(0, 10, 0), "speaker": "", "voice": "Narrador", "text": e[1], "time": 6.0, "fov": 55.0})
	shots.append({"from": w.awakening_point() + Vector3(-12, 6, 12), "to": w.awakening_point() + Vector3(-6, 4, 6), "look": w.awakening_point() + Vector3(0, 2.5, 0), "speaker": "", "voice": "Narrador", "text": e[2], "time": 7.0, "fov": 50.0})
	play(shots, on_done, [kaito] if kaito else [])


## Un jefe se presenta (Rey Esqueleto y los guardianes de los sellos).
func boss_intro(boss: Node3D) -> void:
	if not Data.BOSS_LINES.has(boss.kind):
		return
	var voice: String = Data.BOSS_LINES[boss.kind][0]
	var lines: Array = Data.BOSS_LINES[boss.kind][1]
	var name_: String = boss.data.name
	var h: float = float(boss.data.height)
	var b := boss.global_position
	var p: Vector3 = main._player.global_position
	var dir := (p - b)
	dir.y = 0
	dir = dir.normalized() if dir.length() > 0.1 else Vector3(0, 0, 1)
	var side := dir.cross(Vector3.UP)
	play([
		{"from": b + dir * (h * 2.2) + Vector3(0, h * 0.25, 0), "to": b + dir * (h * 1.4) + Vector3(0, h * 0.55, 0), "look": b + Vector3(0, h * 0.62, 0), "speaker": name_, "voice": voice, "text": lines[0], "time": 4.0, "fov": 45.0},
		{"from": b + dir * h + side * h * 0.5 + Vector3(0, h * 0.4, 0), "to": b + dir * h * 0.9 + Vector3(0, h * 0.6, 0), "look": b + Vector3(0, h * 0.6, 0), "speaker": name_, "voice": voice, "text": lines[1], "time": 3.0, "fov": 40.0, "actor": boss, "anim": "Cheer"},
	], Callable(), [boss])
