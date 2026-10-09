extends Node3D
## Escena del prototipo: un prado de prueba con cielo, luz, árboles, rocas,
## plataformas para saltar, el héroe y la interfaz.

const NATURE := "res://assets/kaykit/nature/"
const PLAYER_SCRIPT := preload("res://scripts/player.gd")
const GRASS_SHADER := preload("res://shaders/grass.gdshader")

const TREES := ["tree_single_A", "tree_single_B", "trees_A_large", "trees_A_medium",
	"trees_B_large", "trees_B_medium"]
const ROCKS := ["rock_single_A", "rock_single_B", "rock_single_C", "rock_single_D", "rock_single_E"]
const MOUNTAINS := ["mountain_A_grass_trees", "mountain_B_grass_trees", "hill_single_A",
	"hill_single_B", "hill_single_C"]

const WORLD_SIZE := 240.0
const CLEAR_RADIUS := 14.0

var _rng := RandomNumberGenerator.new()
var _crystal: Node3D
var _clouds: Array[Node3D] = []
var _system_panel: PanelContainer
var _system_timer := 9.0
var _help_panel: PanelContainer


func _ready() -> void:
	_rng.seed = 20261009
	_setup_input()
	_build_environment()
	_build_ground()
	_build_crystal()
	_build_platforms()
	_scatter_nature()
	_build_clouds()
	_spawn_player()
	_build_hud()
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
	_bind("cheer", [KEY_G], [JOY_BUTTON_Y])
	_bind("toggle_help", [KEY_H], [JOY_BUTTON_BACK])
	_bind("fullscreen", [KEY_F11], [])


func _bind(action: String, keys: Array, buttons: Array, axis: Array = []) -> void:
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
	env.fog_density = 0.004
	env.fog_aerial_perspective = 0.4
	env.fog_sky_affect = 0.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 0.85
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)


func _build_ground() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(WORLD_SIZE * 2.0, 2.0, WORLD_SIZE * 2.0)
	shape.shape = slab
	shape.position.y = -1.0
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(WORLD_SIZE * 2.0, WORLD_SIZE * 2.0)
	mesh.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = GRASS_SHADER
	mesh.material_override = mat
	body.add_child(mesh)
	add_child(body)


## Cristal del Sistema en el punto donde despierta el héroe.
func _build_crystal() -> void:
	_crystal = Node3D.new()
	_crystal.position = Vector3(0, 3.2, -4.5)
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

	var base := _block(Vector3(0, 0.25, -4.5), Vector3(3.0, 0.5, 3.0), Color(0.45, 0.47, 0.56))
	base.rotation_degrees.y = 45


## Plataformas de piedra para practicar saltos.
func _build_platforms() -> void:
	var stone := Color(0.42, 0.44, 0.52)
	var steps := [
		[Vector3(9, 0.5, 2), Vector3(3, 1.0, 3)],
		[Vector3(12.5, 1.0, 4.5), Vector3(3, 2.0, 3)],
		[Vector3(15.5, 1.6, 8), Vector3(3, 3.2, 3)],
		[Vector3(15.5, 2.3, 12.5), Vector3(3, 4.6, 3)],
		[Vector3(12, 3.0, 16), Vector3(4, 6.0, 4)],
	]
	for s in steps:
		_block(s[0], s[1], stone)
	_block(Vector3(-10, 0.4, 6), Vector3(6, 0.8, 4), stone.darkened(0.1))
	_block(Vector3(-14, 1.2, 8), Vector3(3, 2.4, 3), stone)


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


func _scatter_nature() -> void:
	# Bosque alrededor del prado.
	for i in 140:
		var pos := _random_spot(CLEAR_RADIUS + 6.0, WORLD_SIZE * 0.42)
		if abs(pos.x) < 5.0 and pos.z < 0.0:
			continue
		var tree := _place(TREES[_rng.randi() % TREES.size()], pos, _rng.randf_range(6.0, 8.5))
		_add_trunk_collision(tree, pos)
	# Rocas sueltas.
	for i in 45:
		var pos := _random_spot(CLEAR_RADIUS, WORLD_SIZE * 0.4)
		var factor := _rng.randf_range(5.0, 10.0)
		var rock := _place(ROCKS[_rng.randi() % ROCKS.size()], pos, factor)
		_add_rock_collision(rock, pos, factor * 0.15)
	# Montañas lejanas formando un anillo.
	for i in 18:
		var angle := TAU * i / 18.0 + _rng.randf_range(-0.1, 0.1)
		var dist := WORLD_SIZE * _rng.randf_range(0.8, 0.95)
		var pos := Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		_place(MOUNTAINS[_rng.randi() % MOUNTAINS.size()], pos, _rng.randf_range(22.0, 32.0), 0.0)


func _random_spot(min_r: float, max_r: float) -> Vector3:
	var angle := _rng.randf() * TAU
	var r := sqrt(_rng.randf_range(min_r * min_r, max_r * max_r))
	return Vector3(cos(angle) * r, 0, sin(angle) * r)


## Coloca un modelo del paquete de naturaleza. Sus piezas están hechas para
## un tablero pequeño, así que se agrandan con un factor uniforme.
func _place(model_name: String, pos: Vector3, factor: float, outline := 0.03) -> Node3D:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = _rng.randf() * TAU
	var model: Node3D = (load(NATURE + model_name + ".gltf") as PackedScene).instantiate()
	holder.add_child(model)
	model.scale = Vector3.ONE * factor
	Toon.apply(model, outline / factor)
	add_child(holder)
	return holder


func _add_trunk_collision(tree: Node3D, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos + Vector3(0, 2, 0)
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.7
	cyl.height = 4.0
	col.shape = cyl
	body.add_child(col)
	add_child(body)


func _add_rock_collision(rock: Node3D, pos: Vector3, height: float) -> void:
	var body := StaticBody3D.new()
	body.position = pos + Vector3(0, height * 0.35, 0)
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = height * 0.55
	col.shape = sphere
	body.add_child(col)
	add_child(body)


func _build_clouds() -> void:
	for i in 14:
		var pos := _random_spot(10.0, WORLD_SIZE * 0.55)
		pos.y = _rng.randf_range(38.0, 55.0)
		var name := "cloud_big" if i % 2 == 0 else "cloud_small"
		var holder := Node3D.new()
		holder.position = pos
		var model: Node3D = (load(NATURE + name + ".gltf") as PackedScene).instantiate()
		holder.add_child(model)
		model.scale = Vector3.ONE * _rng.randf_range(2.5, 4.0)
		Toon.apply(model, 0.0)
		add_child(holder)
		_clouds.append(holder)


func _spawn_player() -> void:
	var player := CharacterBody3D.new()
	player.set_script(PLAYER_SCRIPT)
	player.name = "Hero"
	player.position = Vector3(0, 0.1, 2.0)
	add_child(player)


func _process(delta: float) -> void:
	if _crystal:
		_crystal.rotation.y += delta * 0.8
		_crystal.position.y = 3.2 + sin(Time.get_ticks_msec() * 0.0015) * 0.25
	for c in _clouds:
		c.position.x += delta * 1.2
		if c.position.x > WORLD_SIZE * 0.6:
			c.position.x = -WORLD_SIZE * 0.6
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
	title.add_child(_label("Fase 1 · Prototipo", 16, rune))
	layer.add_child(title)

	_help_panel = PanelContainer.new()
	_help_panel.add_theme_stylebox_override("panel", _panel_style())
	_help_panel.anchor_top = 1.0
	_help_panel.anchor_bottom = 1.0
	_help_panel.offset_left = 24
	_help_panel.offset_top = -268
	_help_panel.offset_bottom = -24
	var help := VBoxContainer.new()
	help.add_child(_label("CONTROLES", 15, rune))
	for line in [
		"W A S D   Moverse",
		"Shift   Correr",
		"Espacio   Saltar",
		"Ratón   Girar la cámara (clic para empezar)",
		"Rueda   Acercar o alejar",
		"G   Celebrar",
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
