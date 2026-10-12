extends CanvasLayer
## Pantalla de título: la cámara vuela sobre Aurelia mientras suena el tema
## principal. Continuar, nueva partida, jugar con amigos, ajustes y salir.

const SaveGame := preload("res://scripts/savegame.gd")
const GOLD := Color(0.91, 0.76, 0.42)
const RUNE := Color(1.0, 0.86, 0.55)

var main: Node
var _cam: Camera3D
var _angle := 0.0
var _box: VBoxContainer
var _confirm_new := false
var _new_button: Button
var _center := Vector3.ZERO


func _ready() -> void:
	layer = 4
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.01, 0.0, 0.88))
	grad.set_color(1, Color(0.02, 0.01, 0.0, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	shade.texture = gt
	shade.anchor_bottom = 1.0
	shade.anchor_right = 0.6
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_box = VBoxContainer.new()
	_box.anchor_top = 0.5
	_box.anchor_bottom = 0.5
	_box.offset_left = 90
	_box.offset_right = 640
	_box.offset_top = -300
	_box.offset_bottom = 320
	_box.add_theme_constant_override("separation", 12)
	add_child(_box)
	var top := _label("【 SISTEMA 】", 20, Color(0.55, 0.85, 1.0))
	_box.add_child(top)
	var t1 := _label("CRÓNICA DEL", 46, GOLD)
	var t2 := _label("HÉROE ATRAPADO", 64, GOLD)
	for t in [t1, t2]:
		t.add_theme_constant_override("outline_size", 14)
		t.add_theme_color_override("font_outline_color", Color(0.18, 0.09, 0.03))
		_box.add_child(t)
	_box.add_child(_label("Un mundo que no es un sueño. Una salida que nadie encontró.", 18, Color(0.95, 0.9, 0.8)))
	var gap := Control.new()
	gap.custom_minimum_size.y = 26
	_box.add_child(gap)
	if SaveGame.exists():
		_button("Continuar", _continue)
	_new_button = _button("Nueva partida", _new_game)
	_button("Jugar con amigos", _friends)
	_button("Ajustes", _settings)
	if not OS.has_feature("mobile"):
		_button("Salir", func(): get_tree().quit())
	var ver := _label("Versión %s  ·  Creado por Manuel y Claude" % FileAccess.get_file_as_string("res://version.txt").strip_edges(), 15, Color(0.85, 0.8, 0.7, 0.8))
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = 24
	ver.offset_top = -40
	add_child(ver)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(380, 56)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.add_theme_font_size_override("font_size", 24)
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.3, 0.18, 0.08, 0.75) if state == "normal" else Color(0.55, 0.35, 0.14, 0.95)
		sb.border_color = GOLD if state != "normal" else Color(0.75, 0.55, 0.28, 0.7)
		sb.border_width_left = 4
		sb.border_width_bottom = 2
		sb.set_corner_radius_all(3)
		sb.content_margin_left = 22
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", Color(1.0, 0.94, 0.8))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.pressed.connect(func():
		_sfx("ui_click")
		cb.call())
	_box.add_child(b)
	return b


func _sfx(n: String) -> void:
	main.audio().ui(n)


func open() -> void:
	visible = true
	get_tree().paused = true
	main.set_ui_visible(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	main.audio().force_music("titulo")
	if _cam == null:
		_cam = Camera3D.new()
		_cam.fov = 55.0
		_cam.process_mode = Node.PROCESS_MODE_ALWAYS
		main.add_child(_cam)
		var w: Node = main._world
		_center = (w.surface(w.CASTLE.x, w.CASTLE.y) + w.surface(w.VILLAGE.x, w.VILLAGE.y)) * 0.5
	_cam.current = true


func _process(delta: float) -> void:
	if not visible or _cam == null:
		return
	if not get_tree().paused and not main._menus.is_open():
		get_tree().paused = true
	_angle += delta * 0.035
	_cam.global_position = _center + Vector3(sin(_angle) * 85.0, 30.0, cos(_angle) * 85.0)
	_cam.look_at(_center + Vector3(0, 6, 0), Vector3.UP)


func _close() -> void:
	visible = false
	get_tree().paused = false
	main.set_ui_visible(true)
	main._player._camera.current = true
	main.audio().force_music("")
	if not main._touch:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _cam:
		_cam.queue_free()
		_cam = null


func _continue() -> void:
	main._hud.fade(_close)


func _new_game() -> void:
	if SaveGame.exists() and not _confirm_new:
		_confirm_new = true
		_new_button.text = "¿Borrar la partida? Pulsa otra vez"
		return
	main.start_new_game()


func _friends() -> void:
	_continue()
	main._net.toggle_panel.call_deferred()


func _settings() -> void:
	main._menus.settings_back = "title"
	main._menus.open("settings")
