extends CanvasLayer
## Controles táctiles para celular y tablet: joystick a la izquierda, cámara
## arrastrando el dedo por la derecha y botones redondos para cada acción.

const MOVE_ACTIONS := ["move_left", "move_right", "move_forward", "move_back"]
const STICK_RADIUS := 110.0
const LOOK_SPEED := 0.006

## [acción, texto, x desde la derecha, y desde abajo, radio]
const ACTION_BUTTONS := [
	["attack_light", "ATACAR", 175, 175, 88],
	["attack_heavy", "FUERTE", 330, 110, 54],
	["dodge", "ESQUIVAR", 305, 265, 52],
	["jump", "SALTAR", 130, 330, 54],
	["block", "BLOQUEO", 460, 70, 44],
	["special", "PODER", 440, 200, 46],
	["ultimate", "DESPERTAR", 285, 400, 46],
	["magic", "MAGIA", 130, 470, 44],
	["interact", "HABLAR", 580, 190, 48],
	["use_potion", "POCIÓN", 430, 340, 40],
	["lock_on", "FIJAR", 585, 330, 40],
	["run", "CORRER", 590, 70, 42],
]
## Botones pequeños arriba al centro: [acción, texto]
const MENU_BUTTONS := [
	["map", "Mapa"], ["party", "Grupo"], ["status", "Estado"], ["inventory", "Inventario"],
	["skills_menu", "Habilidades"], ["cycle_weapon", "Arma"], ["cycle_element", "Elemento"],
	["save_game", "Guardar"],
]

var player: Node3D
var _stick_index := -1
var _stick_center := Vector2.ZERO
var _stick_vec := Vector2.ZERO
var _look_index := -1
var _buttons: Array = []
var _font: Font
var _draw: Control
var _run_toggle := false


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = ThemeDB.fallback_font
	_draw = Control.new()
	_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw.draw.connect(_paint)
	add_child(_draw)
	for b in ACTION_BUTTONS:
		_buttons.append({"action": b[0], "text": b[1], "rx": float(b[2]), "ry": float(b[3]), "r": float(b[4]), "index": -1, "menu": false})
	for i in MENU_BUTTONS.size():
		var b: Array = MENU_BUTTONS[i]
		_buttons.append({"action": b[0], "text": b[1], "slot": i, "r": 38.0, "index": -1, "menu": true})


func _screen() -> Vector2:
	return _draw.get_viewport_rect().size


func _center(b: Dictionary) -> Vector2:
	var s := _screen()
	if b.menu:
		var count := MENU_BUTTONS.size()
		var gap := 88.0
		return Vector2(s.x * 0.5 - gap * (count - 1) * 0.5 + gap * int(b.slot), 46)
	return Vector2(s.x - float(b.rx), s.y - float(b.ry))


func _process(_delta: float) -> void:
	var paused := get_tree().paused
	_draw.visible = not paused
	if paused:
		_release_all()
	_draw.queue_redraw()


func _input(event: InputEvent) -> void:
	if not _draw.visible:
		return
	# El juego recibe la posición en píxeles reales; se pasa a la del lienzo.
	var to_canvas := _draw.get_viewport().get_final_transform().affine_inverse()
	if event is InputEventScreenTouch:
		var pos: Vector2 = to_canvas * event.position
		if event.pressed:
			var b := _button_at(pos)
			if not b.is_empty():
				b.index = event.index
				_press(b, true)
			elif pos.x < _screen().x * 0.42 and pos.y > _screen().y * 0.4 and _stick_index == -1:
				_stick_index = event.index
				_stick_center = pos
				_stick_vec = Vector2.ZERO
			elif _look_index == -1:
				_look_index = event.index
		else:
			for b in _buttons:
				if b.index == event.index:
					b.index = -1
					_press(b, false)
			if event.index == _stick_index:
				_stick_index = -1
				_stick_vec = Vector2.ZERO
				_apply_stick()
			if event.index == _look_index:
				_look_index = -1
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == _stick_index:
			var pos: Vector2 = to_canvas * event.position
			var off := pos - _stick_center
			if off.length() > STICK_RADIUS:
				# El joystick sigue al dedo si se sale del círculo.
				_stick_center = pos - off.limit_length(STICK_RADIUS)
				off = off.limit_length(STICK_RADIUS)
			_stick_vec = off / STICK_RADIUS
			_apply_stick()
		elif event.index == _look_index and player:
			var rel: Vector2 = to_canvas.basis_xform(event.relative)
			player.touch_look(rel * LOOK_SPEED)
		get_viewport().set_input_as_handled()


func _button_at(pos: Vector2) -> Dictionary:
	for b in _buttons:
		if pos.distance_to(_center(b)) <= float(b.r) * 1.1:
			return b
	return {}


func _press(b: Dictionary, on: bool) -> void:
	if b.action == "run":
		if on:
			_run_toggle = not _run_toggle
			if _run_toggle:
				Input.action_press("run")
			else:
				Input.action_release("run")
		return
	var e := InputEventAction.new()
	e.action = b.action
	e.pressed = on
	e.strength = 1.0 if on else 0.0
	Input.parse_input_event(e)


func _apply_stick() -> void:
	var v := _stick_vec
	var values := [maxf(-v.x, 0.0), maxf(v.x, 0.0), maxf(-v.y, 0.0), maxf(v.y, 0.0)]
	for i in 4:
		if values[i] > 0.05:
			Input.action_press(MOVE_ACTIONS[i], values[i])
		else:
			Input.action_release(MOVE_ACTIONS[i])


func _release_all() -> void:
	if _stick_index != -1:
		_stick_index = -1
		_stick_vec = Vector2.ZERO
		_apply_stick()
	_look_index = -1
	for b in _buttons:
		if b.index != -1:
			b.index = -1
			_press(b, false)


func _paint() -> void:
	var s := _screen()
	# Joystick: aparece donde se apoya el dedo; si no, una guía tenue.
	var base := _stick_center if _stick_index != -1 else Vector2(200, s.y - 200)
	var alpha := 0.55 if _stick_index != -1 else 0.25
	_draw.draw_circle(base, STICK_RADIUS, Color(0.12, 0.08, 0.04, alpha * 0.8))
	_draw.draw_arc(base, STICK_RADIUS, 0, TAU, 48, Color(0.91, 0.76, 0.42, alpha), 4.0, true)
	_draw.draw_circle(base + _stick_vec * STICK_RADIUS, 48, Color(0.91, 0.76, 0.42, alpha + 0.2))
	for b in _buttons:
		var c := _center(b)
		var r: float = b.r
		var held: bool = b.index != -1 or (b.action == "run" and _run_toggle)
		var fill := Color(0.55, 0.38, 0.16, 0.85) if held else Color(0.16, 0.10, 0.05, 0.6)
		_draw.draw_circle(c, r, fill)
		_draw.draw_arc(c, r, 0, TAU, 40, Color(0.91, 0.76, 0.42, 0.9), 3.0, true)
		var size := 12 if b.menu else (22 if r > 80 else 15)
		var text: String = b.text
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		_draw.draw_string_outline(_font, c + Vector2(-w * 0.5, size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.8))
		_draw.draw_string(_font, c + Vector2(-w * 0.5, size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1.0, 0.93, 0.75))
