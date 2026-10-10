extends Node
## Modo historia: capítulos con pasos (hablar, derrotar, recoger, jefe...).
## Guía al héroe con un rayo de luz en el mundo, una estrella en el mapa y el
## texto de objetivo en pantalla. Termina con Kaito, el Primer Héroe, en el
## Trono del Vacío, y el final del juego.

const ENEMY := preload("res://scripts/enemy.gd")
const Fx := preload("res://scripts/fx.gd")

const CHAPTERS := {
	1: "El despertar",
	2: "El Rey de Aurelia",
	3: "La mazmorra del Rey Esqueleto",
	4: "La verdad del Sistema",
	5: "El Trono del Vacío",
}

## Pasos de la historia. kind: talk, guild, kill, kill_zone, item, level,
## boss, story_kill, crystal, final, end.
const STEPS := [
	{"ch": 1, "kind": "talk", "npc": "Abuelo Ered", "goal": "Habla con el Abuelo Ered en la aldea",
		"lines": ["¡Por fin despiertas! Te encontré tirado junto al cristal azul.",
			"Hace cien años llegó otro como tú, con esas mismas ventanas brillantes que solo vosotros veis.",
			"Se llamaba Kaito. Venció al Rey Esqueleto y salvó el reino... y luego desapareció.",
			"Si quieres sobrevivir aquí, regístrate en el Gremio de Aventureros. Mira te ayudará."]},
	{"ch": 1, "kind": "guild", "npc": "Mira", "goal": "Regístrate en el Gremio de Aventureros con Mira"},
	{"ch": 1, "kind": "kill", "count": 3, "goal": "Derrota esqueletos en la pradera"},
	{"ch": 1, "kind": "talk", "npc": "Abuelo Ered", "goal": "Vuelve con el Abuelo Ered",
		"lines": ["¡Ja! Ya tumbas esqueletos como un veterano.",
			"Escucha: esta mañana llegó un mensajero del castillo. El Rey Aurelio quiere ver al viajero del cristal.",
			"Sube por el camino del norte. Las puertas se abrirán para ti."]},
	{"ch": 2, "kind": "talk", "npc": "Rey Aurelio", "goal": "Ve al castillo y habla con el Rey Aurelio",
		"lines": ["Así que tú eres el viajero del cristal azul. Te esperaba.",
			"Desde que llegaste, la oscuridad crece en el Bosque Susurrante. Los esqueletos ya lanzan magia.",
			"Mis exploradores vieron algo brillar en el corazón del bosque: un fragmento de cristal, como el tuyo.",
			"Investiga el bosque y tráeme lo que encuentres. El reino confía en ti, héroe."]},
	{"ch": 2, "kind": "kill_zone", "count": 5, "zone": "forest", "goal": "Limpia el Bosque Susurrante de enemigos"},
	{"ch": 2, "kind": "item", "goal": "Recoge el Fragmento del Sistema en el corazón del bosque"},
	{"ch": 2, "kind": "talk", "npc": "Hermana Elia", "goal": "Lleva el fragmento a la Hermana Elia, en la iglesia",
		"lines": ["Este fragmento... late. Como un corazón.",
			"Es una pieza del Sistema, el poder que os trae a este mundo y os muestra esas ventanas.",
			"Hay otro fragmento. Lo guarda el Rey Esqueleto en el fondo de su mazmorra, al este.",
			"Hazte más fuerte antes de bajar. Y que la luz te guíe."]},
	{"ch": 3, "kind": "level", "count": 5, "goal": "Hazte más fuerte: llega al nivel 5"},
	{"ch": 3, "kind": "boss", "goal": "Derrota al Rey Esqueleto en el fondo de la mazmorra"},
	{"ch": 3, "kind": "talk", "npc": "Rey Aurelio", "goal": "Lleva el segundo fragmento al Rey Aurelio",
		"lines": ["¡Has vencido al Rey Esqueleto! Igual que Kaito hace cien años...",
			"Pero hay algo que nunca conté a nadie. Kaito no desapareció.",
			"Sira, la archivista del gremio, guarda su diario. Ella sabrá qué significan estos fragmentos."]},
	{"ch": 4, "kind": "talk", "npc": "Sira", "goal": "Habla con Sira, la archivista del gremio",
		"lines": ["El diario de Kaito... Lo he leído mil veces.",
			"Kaito juntó los fragmentos para abrir la puerta de vuelta a su mundo. Pero la puerta no lleva a casa.",
			"Lleva al Trono del Vacío, el corazón del Sistema. Allí el Sistema lo atrapó y lo convirtió en su guardián.",
			"Él es quien despierta a los esqueletos. Y él te trajo aquí, para que alguien por fin lo libere.",
			"Cuidado: sus guardianes ya vienen a por ti. Los he visto rondar la arena."]},
	{"ch": 4, "kind": "story_kill", "count": 4, "goal": "Derrota a los guardianes del vacío en la arena"},
	{"ch": 4, "kind": "crystal", "goal": "Toca el Cristal del despertar con los dos fragmentos"},
	{"ch": 5, "kind": "final", "goal": "Derrota a Kaito, el Primer Héroe, en el Trono del Vacío"},
	{"ch": 5, "kind": "end", "goal": "Historia completada. ¡Explora Aurelia libremente!"},
]

const FINAL_ARENA := Vector3(0, -400, 400)

var main: Node
var player: Node
var hud: Node
var world: Node
var interiors: Node
var _beacon: MeshInstance3D
var _fragment: Node3D
var _guardians_spawned := false
var _arena_built := false
var final_boss: Node3D
var in_final := false
var _last_ch := 0


func setup(m: Node, p: Node, h: Node, w: Node, i: Node) -> void:
	main = m
	player = p
	hud = h
	world = w
	interiors = i
	add_to_group("story_listeners")
	add_to_group("boss_listeners")
	_beacon = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.6
	cyl.bottom_radius = 0.9
	cyl.height = 60.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.35, 0.28)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.3)
	mat.emission_energy_multiplier = 1.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cyl.material = mat
	_beacon.mesh = cyl
	_beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main.add_child(_beacon)
	_last_ch = step().ch
	_enter_step.call_deferred(false)


func step() -> Dictionary:
	return STEPS[clampi(int(player.story), 0, STEPS.size() - 1)]


func chapter_title() -> String:
	return "Capítulo %d · %s" % [step().ch, CHAPTERS[step().ch]]


func is_complete() -> bool:
	return step().kind == "end"


## Líneas especiales de historia si este personaje es el objetivo actual.
func _client() -> bool:
	var net := get_tree().get_first_node_in_group("net")
	return net != null and net.is_client()


func lines_for(npc_name: String) -> Array:
	if _client():
		return []
	var s := step()
	if s.kind == "talk" and s.npc == npc_name:
		return s.lines
	return []


func on_talk_finished(npc_name: String) -> void:
	var s := step()
	if s.kind == "talk" and s.npc == npc_name:
		advance()


func on_story_kill(enemy: Node) -> void:
	var s := step()
	match s.kind:
		"kill":
			_count_up(s)
		"kill_zone":
			if Vector2(enemy.global_position.x, enemy.global_position.z).distance_to(world.FOREST) < world.FOREST_RADIUS + 15.0:
				_count_up(s)
		"story_kill":
			if enemy.has_meta("story"):
				_count_up(s)


func on_boss_defeated(boss: Node) -> void:
	if boss.kind == "final":
		_ending()
	elif step().kind == "boss":
		player.add_item("fragmento", 1)
		advance()


func _count_up(s: Dictionary) -> void:
	player.story_count += 1
	if player.story_count >= int(s.count):
		advance()
	else:
		hud.show_system("%s  (%d/%d)" % [s.goal, player.story_count, s.count], 2.0)


func advance() -> void:
	player.story = mini(int(player.story) + 1, STEPS.size() - 1)
	player.story_count = 0
	_enter_step(true)
	main.save_game()


## Al empezar un paso: tarjeta de capítulo nuevo, aparecer objetos o enemigos.
func _enter_step(announce: bool) -> void:
	var s := step()
	if s.ch != _last_ch or not announce:
		_last_ch = s.ch
		if announce or int(player.story) == 0:
			hud.show_chapter("Capítulo %d" % s.ch, CHAPTERS[s.ch])
	if announce:
		hud.show_system("Nuevo objetivo:\n" + s.goal, 4.0)
	match s.kind:
		"item":
			_spawn_fragment()
		"story_kill":
			_spawn_guardians()
		"boss":
			if main.boss_is_defeated():
				player.add_item("fragmento", 1)
				advance.call_deferred()
		"final", "crystal":
			_paint_crystal(Color(0.7, 0.3, 1.0))
	if s.kind == "end":
		_paint_crystal(Color(0.5, 0.85, 1.0))


func _process(_delta: float) -> void:
	if player == null:
		return
	if _client():
		_beacon.visible = false
		return
	var s := step()
	match s.kind:
		"guild":
			if player.guild_member:
				advance()
		"level":
			if player.level >= int(s.count):
				advance()
		"item":
			if _fragment and player.global_position.distance_to(_fragment.global_position) < 2.2:
				_fragment.queue_free()
				_fragment = null
				player.add_item("fragmento", 1)
				Fx.number(player.get_parent(), player.global_position + Vector3(0, 2.4, 0), "¡Fragmento del Sistema!", Color(0.8, 0.6, 1.0), 56)
				advance()
	if _fragment:
		_fragment.rotation.y += _delta * 1.5
	var target = objective_position()
	_beacon.visible = target != null and main.indoor_name() == "" and not main.in_dungeon() and not in_final
	if _beacon.visible:
		_beacon.global_position = target + Vector3(0, 30.0, 0)


## Dónde está el objetivo en el mundo exterior (null si no hay lugar).
func objective_position():
	var s := step()
	match s.kind:
		"talk", "guild":
			for npc in get_tree().get_nodes_in_group("npcs"):
				if npc.npc_name == s.npc:
					if npc.global_position.x > 300.0:
						for room in interiors.rooms:
							if room.origin.distance_to(npc.global_position) < 40.0:
								return room.door
					return npc.global_position
		"kill":
			return world.surface(-30, -95)
		"kill_zone":
			return world.surface(world.FOREST.x, world.FOREST.y)
		"item":
			return _fragment.global_position if _fragment else null
		"boss":
			return world.surface(world.DUNGEON_GATE.x, world.DUNGEON_GATE.y)
		"story_kill":
			return world.surface(world.ARENA.x, world.ARENA.y)
		"crystal", "final":
			return world.awakening_point()
	return null


func tracker_text() -> String:
	if _client():
		return "GRUPO · La historia avanza en la partida del anfitrión.\nAyúdale en sus misiones (P: ventana del grupo)."
	var s := step()
	var text: String = s.goal
	if s.has("count") and s.kind != "level":
		text += "  (%d/%d)" % [player.story_count, s.count]
	if s.kind == "level":
		text += "  (nivel %d/%d)" % [player.level, s.count]
	var target = objective_position()
	if target != null and main.indoor_name() == "" and not main.in_dungeon() and not in_final:
		text += "  ·  %d m" % int(player.global_position.distance_to(target))
	return "HISTORIA · %s\n%s" % [chapter_title(), text]


# --- Fragmento, guardianes y cristal ------------------------------------------

func _spawn_fragment() -> void:
	if _fragment:
		return
	_fragment = Node3D.new()
	var gem := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.6, 1.0, 0.6)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.5, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.4, 1.0)
	mat.emission_energy_multiplier = 3.0
	prism.material = mat
	gem.mesh = prism
	gem.position.y = 1.2
	_fragment.add_child(gem)
	var light := OmniLight3D.new()
	light.light_color = Color(0.7, 0.4, 1.0)
	light.light_energy = 3.0
	light.omni_range = 8.0
	light.position.y = 1.5
	_fragment.add_child(light)
	main.add_child(_fragment)
	_fragment.global_position = world.surface(world.FOREST.x + 4.0, world.FOREST.y + 4.0)


func _spawn_guardians() -> void:
	if _guardians_spawned:
		return
	_guardians_spawned = true
	var kinds := ["warrior", "mage", "warrior", "mage"]
	for i in kinds.size():
		var a := TAU * i / kinds.size()
		var p: Vector2 = world.ARENA + Vector2(cos(a), sin(a)) * 6.0
		var e := CharacterBody3D.new()
		e.set_script(ENEMY)
		e.kind = kinds[i]
		e.once = true
		e.tint = Color(0.6, 0.4, 0.9)
		e.title = "Guardián del vacío"
		e.set_meta("story", true)
		e.home = world.surface(p.x, p.y)
		e.position = e.home + Vector3(0, 0.5, 0)
		main.add_child(e)


func _paint_crystal(color: Color) -> void:
	var crystal: Node3D = main._crystal
	if crystal == null:
		return
	for mi in crystal.find_children("*", "MeshInstance3D", true, false):
		var mat = mi.get_active_material(0)
		if mat is StandardMaterial3D:
			mat = mat.duplicate()
			mat.albedo_color = Color(color, mat.albedo_color.a)
			mat.emission = color
			mi.material_override = mat
	for l in crystal.find_children("*", "OmniLight3D", true, false):
		l.light_color = color


func portal_prompt() -> String:
	var s := step()
	if in_final:
		if player.global_position.distance_to(FINAL_ARENA + Vector3(0, 0, 18)) < 3.5:
			return "Volver al Cristal del despertar"
		return ""
	if _client() and player.global_position.distance_to(world.awakening_point()) < 5.0:
		return "Entrar al Trono del Vacío (con el grupo)"
	if s.kind in ["crystal", "final"] and player.global_position.distance_to(world.awakening_point()) < 5.0:
		return "Tocar el cristal" if s.kind == "crystal" else "Entrar al Trono del Vacío"
	return ""


func use_portal() -> void:
	var s := step()
	if in_final:
		_leave_final()
		return
	if _client():
		_enter_final()
		return
	if s.kind == "crystal":
		hud.show_system("Los dos fragmentos se funden con el cristal.\nUna puerta morada se abre hacia el Trono del Vacío...", 5.0)
		advance()
		return
	if s.kind == "final":
		_enter_final()


# --- Trono del Vacío -------------------------------------------------------

func _build_final_arena() -> void:
	if _arena_built:
		return
	_arena_built = true
	var root := Node3D.new()
	main.add_child(root)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.22, 0.18, 0.32)
	floor_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	var disk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 24.0
	cyl.bottom_radius = 18.0
	cyl.height = 3.0
	cyl.radial_segments = 48
	cyl.material = floor_mat
	disk.mesh = cyl
	disk.position = FINAL_ARENA + Vector3(0, -1.5, 0)
	root.add_child(disk)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 24.0
	shape.height = 3.0
	col.shape = shape
	body.add_child(col)
	body.position = disk.position
	root.add_child(body)
	# Muro invisible para no caerse.
	for i in 24:
		var a := TAU * i / 24.0
		var wall := StaticBody3D.new()
		var wc := CollisionShape3D.new()
		var wb := BoxShape3D.new()
		wb.size = Vector3(7.0, 8.0, 1.0)
		wc.shape = wb
		wall.add_child(wc)
		wall.position = FINAL_ARENA + Vector3(cos(a) * 24.5, 4.0, sin(a) * 24.5)
		wall.rotation.y = -a + PI / 2.0
		root.add_child(wall)
	# Anillo de runas y cristales morados.
	var rune := StandardMaterial3D.new()
	rune.albedo_color = Color(0.7, 0.4, 1.0)
	rune.emission_enabled = true
	rune.emission = Color(0.65, 0.35, 1.0)
	rune.emission_energy_multiplier = 2.5
	rune.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 15.0
	torus.outer_radius = 15.6
	torus.material = rune
	ring.mesh = torus
	ring.scale = Vector3(1, 0.05, 1)
	ring.position = FINAL_ARENA + Vector3(0, 0.05, 0)
	root.add_child(ring)
	for i in 8:
		var a := TAU * i / 8.0
		var spike := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(1.6, 5.0 + (i % 3) * 1.5, 1.6)
		prism.material = rune
		spike.mesh = prism
		spike.position = FINAL_ARENA + Vector3(cos(a) * 21.0, 2.5, sin(a) * 21.0)
		root.add_child(spike)
		var light := OmniLight3D.new()
		light.light_color = Color(0.7, 0.4, 1.0)
		light.light_energy = 2.5
		light.omni_range = 14.0
		light.position = spike.position + Vector3(0, 2.0, 0)
		root.add_child(light)
	var top := OmniLight3D.new()
	top.light_color = Color(0.9, 0.85, 1.0)
	top.light_energy = 2.0
	top.omni_range = 40.0
	top.position = FINAL_ARENA + Vector3(0, 14, 0)
	root.add_child(top)
	# Trono roto al fondo.
	var throne := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(4.0, 6.0, 1.5)
	tb.material = floor_mat
	throne.mesh = tb
	throne.position = FINAL_ARENA + Vector3(0, 3.0, -20.0)
	root.add_child(throne)
	# Portal de salida.
	var exit := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.3
	tm.outer_radius = 1.6
	tm.material = rune
	exit.mesh = tm
	exit.rotation.x = PI / 2.0
	exit.position = FINAL_ARENA + Vector3(0, 1.7, 21.0)
	root.add_child(exit)


func _enter_final() -> void:
	_build_final_arena()
	in_final = true
	main.set_indoors(true)
	player.global_position = FINAL_ARENA + Vector3(0, 0.5, 16)
	player.spawn_point = FINAL_ARENA + Vector3(0, 0.5, 16)
	player.velocity = Vector3.ZERO
	player.face_yaw(0.0)
	hud.show_zone("Trono del Vacío")
	if _client():
		return
	if final_boss == null or not is_instance_valid(final_boss):
		final_boss = CharacterBody3D.new()
		final_boss.set_script(ENEMY)
		final_boss.kind = "final"
		final_boss.once = true
		final_boss.home = FINAL_ARENA + Vector3(0, 0, -10)
		final_boss.position = final_boss.home + Vector3(0, 0.5, 0)
		main.add_child(final_boss)
		hud.show_dialog("Kaito · El Primer Héroe", [
			"Otro más... El Sistema nunca se cansa de traer héroes.",
			"Yo también quise volver a casa. Junté los fragmentos y abrí esta puerta.",
			"Pero solo hay una salida: vencer al guardián del Trono. Y ahora el guardián soy yo.",
			"¡Muéstrame si eres más fuerte que yo hace cien años!"])
	elif not final_boss.is_alive():
		pass


func _leave_final() -> void:
	in_final = false
	main.set_indoors(false)
	player.global_position = world.awakening_point() + Vector3(0, 0.5, 3.0)
	player.spawn_point = world.awakening_point() + Vector3(0, 0.3, 2.0)
	player.velocity = Vector3.ZERO
	player.face_yaw(0.0)


func _ending() -> void:
	advance()
	await get_tree().create_timer(2.5).timeout
	hud.show_dialog("Kaito · El Primer Héroe", [
		"Así que... esto es perder. Qué ligero me siento.",
		"Cien años encerrado en este trono. Gracias por liberarme, héroe.",
		"Escucha: el Sistema no es tu enemigo. Solo busca a alguien digno de proteger este mundo.",
		"La puerta a tu mundo está abierta. Tú decides si cruzarla... o quedarte en Aurelia.",
		"Adiós, amigo. Cuida de ellos por mí."], func(): hud.show_ending())


## En un invitado: el anfitrión venció a Kaito y todos ven el final.
func client_ending() -> void:
	player.story = STEPS.size() - 2
	_ending()


func is_final_area() -> bool:
	return in_final
