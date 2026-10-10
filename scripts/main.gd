extends Node3D
## Escena principal: cielo, luz, el mundo, el cristal del Sistema donde
## despierta el héroe, el héroe y la interfaz.

const PLAYER_SCRIPT := preload("res://scripts/player.gd")
const Toon := preload("res://scripts/toon.gd")
const WORLD_SCRIPT := preload("res://scripts/world.gd")

var _rng := RandomNumberGenerator.new()
var _crystal: Node3D
var _world: Node3D
var _crystal_y := 0.0
var _system_panel: PanelContainer
var _system_timer := 9.0
var _help_panel: PanelContainer
var _player: CharacterBody3D


func _ready() -> void:
	_rng.seed = 20261009
	_setup_input()
	_build_environment()
	_world = WORLD_SCRIPT.new()
	add_child(_world)
	_world.build()
	_build_crystal()
	_spawn_player()
	_build_hud()
	_spawn_enemies()
	var hud := preload("res://scripts/hud.gd").new()
	add_child(hud)
	hud.setup(_player)
	add_child(preload("res://scripts/debug_capture.gd").new())


# --- Controles -------------------------------------------------------------

func _setup_input() -> void:
	_bind("move_forward", [KEY_W, KEY_UP], [], [JOY_AXIS_LEFT_Y, -1.0])
	_bind("move_back", [KEY_S, KEY_DOWN], [], [JOY_AXIS_LEFT_Y, 1.0])
	_bind("move_left", [KEY_A, KEY_LEFT], [], [JOY_AXIS_LEFT_X, -1.0])
	_bind("move_right", [KEY_D, KEY_RIGHT], [], [JOY_AXIS_LEFT_X, 1.0])
	_bind("look_left", [], [], [JOY_AXIS_RIGHT_X, -1.0])
	_bind("look_right", [], [], [JOY_AXIS_RIGHT_X, 1.0])
	_bind("look_up", [], [], [JOY_AXIS_RIGHT_Y, -1.0])
	_bind("look_down", [], [], [JOY_AXIS_RIGHT_Y, 1.0])
	_bind("run", [KEY_SHIFT], [JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_SHOULDER])
	_bind("jump", [KEY_SPACE], [JOY_BUTTON_A])
	_bind("cheer", [KEY_G], [])
	_bind("toggle_help", [KEY_H], [JOY_BUTTON_BACK])
	_bind("fullscreen", [KEY_F11], [])
	_bind("attack_light", [KEY_J], [JOY_BUTTON_X], [], [MOUSE_BUTTON_LEFT])
	_bind("attack_heavy", [KEY_E, KEY_K], [JOY_BUTTON_Y])
	_bind("block", [KEY_L], [JOY_BUTTON_LEFT_SHOULDER], [], [MOUSE_BUTTON_RIGHT])
	_bind("dodge", [KEY_Q, KEY_CTRL], [JOY_BUTTON_B])
	_bind("magic", [KEY_R], [JOY_BUTTON_DPAD_UP])
	_bind("lock_on", [KEY_TAB], [JOY_BUTTON_RIGHT_STICK], [], [MOUSE_BUTTON_MIDDLE])
	_bind("status", [KEY_C], [JOY_BUTTON_START])
	for i in 4:
		_bind("weapon_%d" % (i + 1), [KEY_1 + i], [])


func _bind(action: String, keys: Array, buttons: Array, axis: Array = [], mouse: Array = []) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for b in buttons:
		var j := InputEventJoypadButton.new()
		j.button_index = b
		InputMap.action_add_event(action, j)
	if axis.size() == 2:
		var m := InputEventJoypadMotion.new()
		m.axis = axis[0]
		m.axis_value = axis[1]
		InputMap.action_add_event(action, m)
	for mb in mouse:
		var e := InputEventMouseButton.new()
		e.button_index = mb
		InputMap.action_add_event(action, e)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif event.is_action_pressed("toggle_help"):
		_help_panel.visible = not _help_panel.visible


# --- Mundo -----------------------------------------------------------------

func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.48, 0.92)
	sky_mat.sky_horizon_color = Color(0.70, 0.85, 1.0)
	sky_mat.sky_curve = 0.12
	sky_mat.ground_bottom_color = Color(0.30, 0.45, 0.35)
	sky_mat.ground_horizon_color = Color(0.70, 0.85, 1.0)
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.8
	env.tonemap_white = 6.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.84, 1.0)
	env.fog_density = 0.0028
	env.fog_aerial_perspective = 0.6
	env.fog_sky_affect = 0.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 0.85
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)


## Cristal del Sistema en el punto donde despierta el héroe.
func _build_crystal() -> void:
	var ground: Vector3 = _world.awakening_point() + Vector3(0, 0, -6.0)
	_crystal_y = ground.y + 3.2
	_crystal = Node3D.new()
	_crystal.position = Vector3(ground.x, _crystal_y, ground.z)
	var gem := MeshInstance3D.new()
	var shape := SphereMesh.new()
	shape.radial_segments = 4
	shape.rings = 2
	shape.radius = 0.55
	shape.height = 1.7
	gem.mesh = shape
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.65, 1.0, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.8, 1.0)
	mat.emission_energy_multiplier = 0.7
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	gem.mesh.surface_set_material(0, mat)
	_crystal.add_child(gem)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.45, 0.85, 1.0)
	glow.light_energy = 1.5
	glow.omni_range = 7.0
	_crystal.add_child(glow)
	add_child(_crystal)

	var base := _block(ground + Vector3(0, 0.15, 0), Vector3(3.0, 0.6, 3.0), Color(0.45, 0.47, 0.56))
	base.rotation_degrees.y = 45


func _block(center: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = center
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	body.add_child(col)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	bm.material = mat
	body.add_child(mesh)
	Toon.apply(mesh, 0.04)
	add_child(body)
	return body


func _spawn_player() -> void:
	_player = CharacterBody3D.new()
	_player.set_script(PLAYER_SCRIPT)
	_player.name = "Hero"
	_player.position = _world.awakening_point() + Vector3(0, 0.3, 2.0)
	add_child(_player)
	if "--at-arena" in OS.get_cmdline_user_args():
		_player.global_position = _world.surface(_world.ARENA.x - 9.0, _world.ARENA.y) + Vector3(0, 0.5, 0)


## Esqueletos en la arena y grupos sueltos por los campos.
func _spawn_enemies() -> void:
	var groups := [
		[_world.ARENA, ["minion", "minion", "minion", "warrior"], 7.0],
		[Vector2(-34, -30), ["minion", "minion"], 5.0],
		[Vector2(40, -52), ["minion", "warrior"], 5.0],
		[Vector2(-30, -95), ["minion", "minion", "minion"], 6.0],
	]
	for g in groups:
		var center: Vector2 = g[0]
		var kinds: Array = g[1]
		for i in kinds.size():
			var a := TAU * i / kinds.size()
			var p: Vector2 = center + Vector2(cos(a), sin(a)) * float(g[2]) * 0.6
			var e := CharacterBody3D.new()
			e.set_script(preload("res://scripts/enemy.gd"))
			e.kind = kinds[i]
			e.home = _world.surface(p.x, p.y)
			e.position = e.home + Vector3(0, 0.5, 0)
			add_child(e)


func _process(delta: float) -> void:
	if _crystal:
		_crystal.rotation.y += delta * 0.8
		_crystal.position.y = _crystal_y + sin(Time.get_ticks_msec() * 0.0015) * 0.25
	for c in get_tree().get_nodes_in_group("clouds"):
		c.position.x += delta * 1.5
		if c.position.x > 300.0:
			c.position.x = -300.0
	if _system_panel and _system_timer > 0.0:
		_system_timer -= delta
		if _system_timer < 1.5:
			_system_panel.modulate.a = max(_system_timer / 1.5, 0.0)
		if _system_timer <= 0.0:
			_system_panel.visible = false


# --- Interfaz --------------------------------------------------------------

func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.16, 0.31, 0.78)
	sb.border_color = Color(0.44, 0.83, 1.0, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.shadow_color = Color(0.44, 0.83, 1.0, 0.25)
	sb.shadow_size = 8
	return sb


func _label(text: String, size: int, color := Color(0.91, 0.95, 1.0)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.1))
	l.add_theme_constant_override("outline_size", 4)
	return l


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var gold := Color(0.91, 0.76, 0.42)
	var rune := Color(0.44, 0.83, 1.0)

	var title := VBoxContainer.new()
	title.position = Vector2(24, 20)
	title.add_child(_label("CRÓNICA DEL HÉROE ATRAPADO", 26, gold))
	var version := FileAccess.get_file_as_string("res://version.txt").strip_edges()
	title.add_child(_label("Fase 2 · Combate · versión %s" % version, 16, rune))
	layer.add_child(title)

	_help_panel = PanelContainer.new()
	_help_panel.add_theme_stylebox_override("panel", _panel_style())
	_help_panel.anchor_top = 1.0
	_help_panel.anchor_bottom = 1.0
	_help_panel.offset_left = 24
	_help_panel.offset_top = -24
	_help_panel.offset_bottom = -24
	_help_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var help := VBoxContainer.new()
	help.add_child(_label("CONTROLES", 15, rune))
	for line in [
		"W A S D   Moverse",
		"Shift   Correr",
		"Espacio   Saltar",
		"Ratón   Girar la cámara (clic para empezar)",
		"Clic izquierdo   Ataque ligero (combo)",
		"E   Ataque fuerte   ·   Clic derecho   Bloquear",
		"Q o Ctrl   Esquivar   ·   R   Bola de fuego",
		"Tab   Fijar objetivo   ·   C   Ventana de estado",
		"1 2 3 4   Cambiar de arma   ·   G   Celebrar",
		"F11   Pantalla completa   ·   Esc   Soltar el ratón",
		"H   Ocultar esta ayuda",
	]:
		help.add_child(_label(line, 15))
	_help_panel.add_child(help)
	layer.add_child(_help_panel)

	_system_panel = PanelContainer.new()
	_system_panel.add_theme_stylebox_override("panel", _panel_style())
	_system_panel.anchor_left = 0.5
	_system_panel.anchor_right = 0.5
	_system_panel.offset_left = -330
	_system_panel.offset_right = 330
	_system_panel.offset_top = 90
	var sys := VBoxContainer.new()
	var head := _label("【 SISTEMA 】", 18, rune)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sys.add_child(head)
	var msg := _label("Bienvenido, Héroe. Has despertado dentro de un mundo desconocido.\nSube de nivel para encontrar la salida.", 18)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sys.add_child(msg)
	_system_panel.add_child(sys)
	layer.add_child(_system_panel)
