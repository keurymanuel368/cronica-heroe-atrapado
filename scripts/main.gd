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
var _clock: Node
var _hud: CanvasLayer
var _sun: DirectionalLight3D
var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _autosave := 90.0
## La ayuda de controles se oculta sola (H la vuelve a mostrar).
var _help_timer := 40.0
var _zone_timer := 0.0
var _zone := ""
var _dungeon: Node3D
var _in_dungeon := false
var _interiors: Node3D
var _big_map: Control
## Sala en la que está el héroe ({} si está fuera).
var _inside: Dictionary = {}
var _boss_defeated := false
var _menus: CanvasLayer
var _escort: Node3D

const SaveGame := preload("res://scripts/savegame.gd")
const NPC_SCRIPT := preload("res://scripts/npc.gd")


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
	_spawn_villagers()
	_dungeon = preload("res://scripts/dungeon.gd").new()
	add_child(_dungeon)
	_dungeon.build()
	_interiors = preload("res://scripts/interiors.gd").new()
	add_child(_interiors)
	_interiors.build(_world)
	for p in [_world.VILLAGE + Vector2(-5, 27), _world.AWAKENING + Vector2(7, 3), Vector2(36, -182), _world.VILLAGE + Vector2(5, 27)]:
		var horse := Node3D.new()
		horse.set_script(preload("res://scripts/horse.gd"))
		horse.position = _world.surface(p.x, p.y)
		horse.rotation.y = randf() * TAU
		add_child(horse)
	add_to_group("boss_listeners")
	_clock = preload("res://scripts/daynight.gd").new()
	_clock.sun = _sun
	_clock.env = _env
	_clock.sky = _sky_mat
	add_child(_clock)
	var loaded := false
	var fresh := "--new" in OS.get_cmdline_user_args() or "--at-arena" in OS.get_cmdline_user_args()
	if not fresh and SaveGame.exists():
		loaded = SaveGame.load_into(_player, _clock)
		_boss_defeated = SaveGame.flag("boss_defeated")
		if _boss_defeated and _dungeon.boss:
			_dungeon.boss.queue_free.call_deferred()
	if "--in-dungeon" in OS.get_cmdline_user_args():
		_enter_dungeon.call_deferred()
	_clock.apply()
	_hud = preload("res://scripts/hud.gd").new()
	add_child(_hud)
	_hud.main = self
	_hud.setup(_player, loaded)
	var minimap := Control.new()
	minimap.set_script(preload("res://scripts/minimap.gd"))
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.offset_left = -244
	minimap.offset_right = -24
	minimap.offset_top = 24
	minimap.offset_bottom = 244
	_hud.add_child(minimap)
	minimap.setup(_world, _player, self)
	_big_map = Control.new()
	_big_map.set_script(preload("res://scripts/minimap.gd"))
	_big_map.full = true
	_big_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	_big_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big_map.visible = "--map" in OS.get_cmdline_user_args()
	_hud.add_child(_big_map)
	_big_map.setup(_world, _player, self, minimap.texture())
	_menus = preload("res://scripts/menus.gd").new()
	_menus.player = _player
	_menus.main = self
	add_child(_menus)
	_spawn_pickups()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--menu="):
			open_menu.call_deferred(arg.trim_prefix("--menu="))
	if _player.quests.has("q5") and not _player.quest_ready("q5"):
		on_quest_accepted("q5")
	if loaded:
		_system_timer = 0.0
		_system_panel.visible = false
		_hud.show_system("Partida cargada. Bienvenido de vuelta, Héroe.", 4.0)
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
	_bind("map", [KEY_M], [])
	_bind("fullscreen", [KEY_F11], [])
	_bind("attack_light", [KEY_J], [JOY_BUTTON_X], [], [MOUSE_BUTTON_LEFT])
	_bind("attack_heavy", [KEY_E, KEY_K], [JOY_BUTTON_Y])
	_bind("block", [KEY_L], [JOY_BUTTON_LEFT_SHOULDER], [], [MOUSE_BUTTON_RIGHT])
	_bind("dodge", [KEY_Q, KEY_CTRL], [JOY_BUTTON_B])
	_bind("magic", [KEY_R], [])
	_bind("lock_on", [KEY_TAB], [JOY_BUTTON_RIGHT_STICK], [], [MOUSE_BUTTON_MIDDLE])
	_bind("status", [KEY_C], [JOY_BUTTON_START])
	_bind("interact", [KEY_F], [JOY_BUTTON_DPAD_DOWN])
	_bind("save_game", [KEY_F5], [])
	_bind("cycle_element", [KEY_T], [JOY_BUTTON_DPAD_RIGHT])
	_bind("use_potion", [KEY_Z], [JOY_BUTTON_DPAD_LEFT])
	_bind("use_ether", [KEY_X], [])
	_bind("skills_menu", [KEY_V], [])
	_bind("inventory", [KEY_I], [])
	_bind("special", [KEY_1], [JOY_BUTTON_DPAD_UP])
	_bind("ultimate", [KEY_2], [])
	_bind("cycle_weapon", [KEY_3], [])


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
	elif event.is_action_pressed("map"):
		_big_map.visible = not _big_map.visible
	elif event.is_action_pressed("toggle_help"):
		_help_panel.visible = not _help_panel.visible
	elif event.is_action_pressed("skills_menu") and not _menus.is_open():
		open_menu("skills")
	elif event.is_action_pressed("inventory") and not _menus.is_open():
		open_menu("inventory")
	elif event.is_action_pressed("save_game"):
		save_game()
		_hud.show_system("Partida guardada.", 2.5)


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
	_sky_mat = sky_mat

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
	_env = env
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
	_sun = sun


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
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--at="):
			var xz := arg.trim_prefix("--at=").split(",")
			_player.global_position = _world.surface(float(xz[0]), float(xz[1])) + Vector3(0, 0.5, 0)
	if "--at-arena" in OS.get_cmdline_user_args():
		_player.global_position = _world.surface(_world.ARENA.x - 9.0, _world.ARENA.y) + Vector3(0, 0.5, 0)


## Gente del pueblo con la que se puede hablar.
func _spawn_villagers() -> void:
	for v in _world.VILLAGERS:
		var npc := Node3D.new()
		npc.set_script(NPC_SCRIPT)
		npc.npc_name = v.name
		npc.role = v.role
		npc.model_path = v.model
		npc.gear = v.get("gear", [])
		npc.lines = v.lines
		npc.action = v.get("action", "")
		npc.height = v.get("height", 1.75)
		var at: Vector2 = _world.VILLAGE + v.at
		npc.position = _world.surface(at.x, at.y)
		add_child(npc)


## Esqueletos en la arena y grupos sueltos por los campos.
func _spawn_enemies() -> void:
	var groups := [
		[_world.ARENA, ["minion", "minion", "minion", "warrior"], 7.0],
		[Vector2(-34, -30), ["minion", "minion"], 5.0],
		[Vector2(40, -52), ["minion", "warrior"], 5.0],
		[Vector2(-30, -95), ["minion", "minion", "minion"], 6.0],
		[Vector2(-112, -32), ["rogue", "mage", "rogue"], 6.0],
		[Vector2(-95, -12), ["mage", "minion"], 5.0],
		[Vector2(-125, -55), ["rogue", "rogue", "mage"], 6.0],
		[Vector2(70, -10), ["warrior", "minion"], 5.0],
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


func save_game() -> void:
	if not _player.is_alive():
		return
	# Dentro de la mazmorra se guarda en la entrada, para volver al mundo.
	var pos := _player.global_position
	if _in_dungeon:
		pos = _gate_point() + Vector3(-4, 0, 0)
	elif not _inside.is_empty():
		pos = _inside.out
	SaveGame.save(_player, _clock, pos, {"boss_defeated": _boss_defeated})


func _gate_point() -> Vector3:
	return _world.surface(_world.DUNGEON_GATE.x, _world.DUNGEON_GATE.y)


## Puertas que el héroe puede usar con F: [texto, acción] o vacío.
func portal_prompt() -> String:
	if _player.horse:
		return "Bajar del caballo"
	if not _inside.is_empty():
		if _player.global_position.distance_to(_inside.exit) < 3.0:
			return "Salir: " + _inside.name
		return ""
	if not _in_dungeon:
		var h := _near_horse()
		if h:
			return "Montar a caballo"
		var room := _near_door()
		if not room.is_empty():
			return "Entrar: " + room.name
	if _in_dungeon:
		if _player.global_position.distance_to(_dungeon.start) < 3.5:
			return "Salir de la mazmorra"
	elif _player.global_position.distance_to(_gate_point()) < 5.0:
		return "Entrar a la mazmorra"
	return ""


func _near_horse() -> Node3D:
	for h in get_tree().get_nodes_in_group("horses"):
		if not h.ridden and h.global_position.distance_to(_player.global_position) < 3.0:
			return h
	return null


func _near_door() -> Dictionary:
	for room in _interiors.rooms:
		var d: Vector3 = room.door - _player.global_position
		d.y *= 0.3
		if d.length() < 3.2:
			return room
	return {}


func indoor_name() -> String:
	return "" if _inside.is_empty() else String(_inside.name)


func _enter_room(room: Dictionary) -> void:
	_inside = room
	_clock.indoors = true
	_player.global_position = room.spawn
	_player.spawn_point = room.spawn
	_player.velocity = Vector3.ZERO
	_player.face_yaw(0.0)
	_hud.show_zone(room.name)


func _exit_room() -> void:
	var room := _inside
	_inside = {}
	_clock.indoors = false
	_player.global_position = room.out + Vector3(0, 0.4, 0)
	_player.spawn_point = _world.awakening_point() + Vector3(0, 0.3, 2.0)
	_player.velocity = Vector3.ZERO
	_player.face_yaw(room.out_yaw)


func use_portal() -> void:
	if _player.horse:
		_player.dismount()
		return
	if not _inside.is_empty():
		_exit_room()
		return
	if not _in_dungeon:
		var h := _near_horse()
		if h:
			_player.mount(h)
			return
		var room := _near_door()
		if not room.is_empty():
			_enter_room(room)
			return
	if _in_dungeon:
		_exit_dungeon()
	else:
		_enter_dungeon()


func _enter_dungeon() -> void:
	_in_dungeon = true
	_clock.indoors = true
	_player.global_position = _dungeon.start + Vector3(0, 0.5, -2.0)
	_player.spawn_point = _dungeon.start + Vector3(0, 0.5, -2.0)
	_player.velocity = Vector3.ZERO
	_player.face_yaw(0.0)
	if "--at-boss" in OS.get_cmdline_user_args():
		_player.global_position = _dungeon.boss.global_position + Vector3(0, 0.5, 12)
	_hud.show_zone("Mazmorra del Rey Esqueleto")
	_zone = "Mazmorra del Rey Esqueleto"


func _exit_dungeon() -> void:
	_in_dungeon = false
	_clock.indoors = false
	_player.global_position = _gate_point() + Vector3(-5, 0.5, 0)
	_player.spawn_point = _world.awakening_point() + Vector3(0, 0.3, 2.0)
	_player.velocity = Vector3.ZERO
	_player.face_yaw(PI / 2.0)


func open_menu(kind: String) -> void:
	_menus.open(kind)


func hud_message(text: String) -> void:
	_hud.show_system(text, 5.0)


func in_dungeon() -> bool:
	return _in_dungeon


func boss_is_defeated() -> bool:
	return _boss_defeated


## Hierbas en la pradera y hongos lunares en el bosque.
func _spawn_pickups() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var placed := 0
	while placed < 30:
		var x := rng.randf_range(-70, 70)
		var z := rng.randf_range(-60, 30)
		var h: float = _world.height(x, z)
		if h < 2.0 or _world.road_distance(x, z) < 3.0 or Vector2(x, z).distance_to(_world.ARENA) < 18.0:
			continue
		_add_pickup("hierba", _world.surface(x, z))
		placed += 1
	placed = 0
	while placed < 20:
		var p: Vector2 = _world.FOREST + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 40.0
		if _world.height(p.x, p.y) < 2.2:
			continue
		_add_pickup("hongo", _world.surface(p.x, p.y))
		placed += 1


func _add_pickup(item: String, at: Vector3) -> void:
	var p := Node3D.new()
	p.set_script(preload("res://scripts/pickup.gd"))
	p.item = item
	p.position = at
	add_child(p)


func on_quest_accepted(id: String) -> void:
	if id != "q5" or _escort:
		return
	_escort = Node3D.new()
	_escort.set_script(preload("res://scripts/escort.gd"))
	_escort.world = _world
	var start: Vector2 = _world.VILLAGE + Vector2(-4, -2)
	_escort.position = _world.surface(start.x, start.y)
	_escort.goal = _world.surface(_world.WINDMILL.x, _world.WINDMILL.y)
	_escort.on_arrive = _escort_arrived
	_escort.on_ambush = _escort_ambush
	add_child(_escort)
	_hud.show_system("Bram te espera en la plaza de la aldea.\nLlévalo hasta el molino del oeste.", 5.0)


func _escort_ambush(at: Vector3) -> void:
	_hud.show_system("¡Emboscada! Protege a Bram.", 3.0)
	for i in 3:
		var a := TAU * i / 3.0
		var e := CharacterBody3D.new()
		e.set_script(preload("res://scripts/enemy.gd"))
		e.kind = "minion" if i < 2 else "rogue"
		e.once = true
		var p := Vector2(at.x, at.z) + Vector2(cos(a), sin(a)) * 9.0
		e.home = _world.surface(p.x, p.y)
		e.position = e.home + Vector3(0, 0.5, 0)
		add_child(e)


func _escort_arrived() -> void:
	if _player.quests.has("q5"):
		_player.quests["q5"] = 1
		_player.stats_changed.emit()
	_hud.show_system("Bram llegó sano y salvo al molino.\nVuelve al gremio para cobrar la misión.", 5.0)
	var bram := _escort
	_escort = null
	get_tree().create_timer(8.0).timeout.connect(func(): bram.queue_free())


func on_boss_defeated(_boss: Node) -> void:
	_boss_defeated = true
	_hud.show_system("¡Derrotaste al Rey Esqueleto!\nEl Sistema registra tu hazaña. Una grieta de luz se abre en el cielo...", 7.0)
	save_game()


## El posadero deja dormir: vida y maná al máximo, amanece y se guarda.
func rest() -> void:
	if _clock.time > 7.0:
		_clock.day += 1
	_clock.time = 7.0
	_player.hp = _player.max_hp
	_player.mp = _player.max_mp
	_player.stats_changed.emit()
	save_game()


## Nombre de la zona donde está el héroe, para el aviso al entrar.
func zone_at(p: Vector3) -> String:
	var flat := Vector2(p.x, p.z)
	for z in _world.ZONES:
		if flat.distance_to(z[1]) < float(z[2]):
			return z[0]
	return "Pradera de Lumen"


func _process(delta: float) -> void:
	_autosave -= delta
	if _help_timer > 0.0:
		_help_timer -= delta
		if _help_timer <= 0.0:
			_help_panel.visible = false
	if _autosave <= 0.0:
		_autosave = 90.0
		save_game()
	_zone_timer -= delta
	if _zone_timer <= 0.0 and _hud:
		_zone_timer = 0.5
		var z := "Mazmorra del Rey Esqueleto" if _in_dungeon else (String(_inside.name) if not _inside.is_empty() else zone_at(_player.global_position))
		if z != _zone:
			if _zone != "":
				_hud.show_zone(z)
			_zone = z
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
	sb.bg_color = Color(0.2, 0.12, 0.06, 0.82)
	sb.border_color = Color(0.78, 0.58, 0.3, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.shadow_color = Color(0, 0, 0, 0.45)
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
	var rune := Color(1.0, 0.86, 0.55)

	var title := VBoxContainer.new()
	title.position = Vector2(24, 20)
	title.add_child(_label("CRÓNICA DEL HÉROE ATRAPADO", 26, gold))
	var version := FileAccess.get_file_as_string("res://version.txt").strip_edges()
	title.add_child(_label("Mundo vivo · versión %s" % version, 16, rune))
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
		"Q o Ctrl   Esquivar",
		"Tab   Fijar objetivo   ·   C   Ventana de estado",
		"1   Poder especial   ·   2   Despertar",
		"3   Cambiar de arma   ·   G   Celebrar",
		"M   Mapa   ·   F   Caballo / casas",
		"F   Hablar / Entrar   ·   F5   Guardar partida",
		"R   Lanzar magia   ·   T   Cambiar elemento",
		"Z   Poción   ·   X   Éter   ·   I   Inventario",
		"V   Árbol de habilidades",
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
