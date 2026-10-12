extends RefCounted
## Ajustes del jugador (volúmenes, cámara, gráficos). Se guardan aparte de la
## partida, en user://ajustes.cfg.

const PATH := "user://ajustes.cfg"
const DEFAULTS := {
	"general": 80, "musica": 70, "efectos": 80, "voces": 90,
	"sensibilidad": 100, "calidad": 1, "pantalla_completa": false, "ayuda": true,
}
const QUALITY := ["Baja", "Media", "Alta"]

static var values := {}


static func load_all() -> void:
	values = DEFAULTS.duplicate()
	if preload("res://scripts/platform.gd").is_touch():
		values.calidad = 0
		values.ayuda = false
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for k in DEFAULTS:
			values[k] = cfg.get_value("ajustes", k, values[k])


static func save_all() -> void:
	var cfg := ConfigFile.new()
	for k in values:
		cfg.set_value("ajustes", k, values[k])
	cfg.save(PATH)


static func get_value(key: String) -> Variant:
	if values.is_empty():
		load_all()
	return values.get(key, DEFAULTS.get(key))


static func set_value(key: String, value: Variant, main: Node = null) -> void:
	if values.is_empty():
		load_all()
	values[key] = value
	save_all()
	if main:
		apply(main, key == "calidad" or key == "pantalla_completa")


static func _bus(name_: String, percent: float) -> void:
	var i := AudioServer.get_bus_index(name_)
	if i == -1:
		return
	AudioServer.set_bus_mute(i, percent <= 0.0)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(percent, 0.01) / 100.0))


static func apply(main: Node, graphics := true) -> void:
	if values.is_empty():
		load_all()
	_bus("Master", float(values.general))
	_bus("Musica", float(values.musica))
	_bus("Efectos", float(values.efectos))
	_bus("Voces", float(values.voces))
	if main._player:
		main._player.look_sensitivity = float(values.sensibilidad) / 100.0
	if not graphics:
		return
	var q := int(values.calidad)
	var vp: Viewport = main.get_viewport()
	vp.msaa_3d = Viewport.MSAA_2X if q == 2 else Viewport.MSAA_DISABLED
	var phone := OS.has_feature("mobile") and q == 0
	vp.scaling_3d_scale = (0.6 if phone else 0.75) if q == 0 else 1.0
	RenderingServer.directional_shadow_atlas_set_size([1024, 2048, 4096][q], true)
	RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM][q])
	if main._sun:
		main._sun.directional_shadow_max_distance = [45.0, 70.0, 100.0][q]
		main._sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if q == 0 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		# Las sombras son lo que más cuesta en el celular: fuera en calidad baja.
		main._sun.shadow_enabled = not phone
	if main._world:
		main._world.set_quality(q)
	# Límite de imágenes por segundo: no gasta de más (y en el celular, batería).
	Engine.max_fps = 30 if OS.has_feature("mobile") and q == 0 else 60
	if main._env:
		main._env.glow_enabled = q > 0
	if not OS.has_feature("mobile"):
		var full: bool = values.pantalla_completa
		var mode := DisplayServer.window_get_mode()
		var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		if full != is_full:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED)
