extends Node3D
## Interiores de las casas del pueblo y del castillo. Se construyen lejos del
## mapa (como la mazmorra) y se entra por la puerta con F.

const Toon := preload("res://scripts/toon.gd")
const NPC := preload("res://scripts/npc.gd")
const PIECES := "res://assets/kaykit/dungeon/"
const CHARS := "res://assets/kaykit/characters/"
const BASE := Vector3(400, -150, 0)
const WALL_H := 5.0

## Cada casa: nombre, tipo de interior, edificio (relativo a la aldea) y lado
## de la puerta (hacia el camino).
const HOUSES := [
	{"name": "Posada La Jarra Dorada", "kind": "posada", "at": Vector2(-12, -2)},
	{"name": "Gremio de Aventureros", "kind": "gremio", "at": Vector2(13, 4)},
	{"name": "Herrería de Borin", "kind": "herreria", "at": Vector2(14, -12)},
	{"name": "Casa de Lila", "kind": "casa", "at": Vector2(-11, 13)},
	{"name": "Almacén del mercader", "kind": "almacen", "at": Vector2(-13, -16)},
	{"name": "Iglesia de Rivel", "kind": "iglesia", "at": Vector2(-20, 2)},
	{"name": "Casa del molinero", "kind": "casa", "at": Vector2(20, 14)},
]

## Salas: {name, door (fuera), exit (dentro), spawn, out_yaw, origin, size}.
var rooms: Array = []
var _world: Node
var _rng := RandomNumberGenerator.new()
var _wood: StandardMaterial3D
var _dark: StandardMaterial3D
var _plaster: StandardMaterial3D
var _stone: StandardMaterial3D
var _flames: Array = []


func build(world: Node) -> void:
	_world = world
	_rng.seed = 77
	_wood = _mat(Color(0.55, 0.36, 0.2))
	_dark = _mat(Color(0.3, 0.19, 0.1))
	_plaster = _mat(Color(0.92, 0.86, 0.74))
	_stone = _mat(Color(0.62, 0.62, 0.66))
	var i := 0
	for h in HOUSES:
		var local: Vector2 = h.at
		var side := -signf(local.x)
		var house: Vector2 = world.VILLAGE + local
		var door2: Vector2 = house + Vector2(side * 4.6, 0)
		var size: Vector2 = Vector2(16, 14) if h.kind in ["posada", "gremio", "iglesia"] else Vector2(12, 10)
		_add_room(h.name, h.kind, world.surface(door2.x, door2.y), world.surface(door2.x + side * 1.6, door2.y), -side * PI / 2.0, i, size)
		i += 1
	# El castillo: salón del trono.
	var c: Vector2 = Vector2(world.CASTLE.x, world.CASTLE.y + 14.5)
	_add_room("Salón del trono", "castillo", world.surface(c.x, c.y), world.surface(c.x, c.y + 2.0), PI, i, Vector2(18, 26))


func _process(delta: float) -> void:
	for f in _flames:
		f.light_energy = 2.2 + sin(Time.get_ticks_msec() * 0.013 + f.get_instance_id()) * 0.35 + randf() * 0.2


func _add_room(room_name: String, kind: String, door: Vector3, out: Vector3, out_yaw: float, index: int, size: Vector2) -> void:
	var o := BASE + Vector3(index * 50.0, 0, 0)
	var room := {"name": room_name, "kind": kind, "door": door, "out": out, "out_yaw": out_yaw,
		"origin": o, "size": size, "exit": o + Vector3(0, 0, size.y * 0.5 - 1.2),
		"spawn": o + Vector3(0, 0.3, size.y * 0.5 - 2.4)}
	rooms.append(room)
	_shell(o, size, kind)
	match kind:
		"posada":
			_posada(o, size)
		"gremio":
			_gremio(o, size)
		"herreria":
			_herreria(o, size)
		"casa":
			_casa(o, size)
		"almacen":
			_almacen(o, size)
		"iglesia":
			_iglesia(o, size)
		"castillo":
			_castillo(o, size)


# --- Paredes, suelo, techo, ventanas y puerta -------------------------------

func _shell(o: Vector3, size: Vector2, kind: String) -> void:
	var w := size.x
	var d := size.y
	var wall_mat := _stone if kind in ["castillo", "iglesia", "herreria"] else _plaster
	var floor_mat := _mat(Color(0.5, 0.34, 0.2)) if kind != "castillo" else _mat(Color(0.7, 0.68, 0.66))
	_solid(o + Vector3(0, -0.25, 0), Vector3(w, 0.5, d), floor_mat)
	# Tablones del suelo.
	if kind != "castillo":
		for x in range(int(-w * 0.5) + 1, int(w * 0.5), 2):
			_mesh(o + Vector3(x, 0.01, 0), Vector3(0.05, 0.02, d), _dark)
	_solid(o + Vector3(0, WALL_H + 0.25, 0), Vector3(w, 0.5, d), _dark)
	_solid(o + Vector3(-w * 0.5 - 0.25, WALL_H * 0.5, 0), Vector3(0.5, WALL_H, d), wall_mat)
	_solid(o + Vector3(w * 0.5 + 0.25, WALL_H * 0.5, 0), Vector3(0.5, WALL_H, d), wall_mat)
	_solid(o + Vector3(0, WALL_H * 0.5, -d * 0.5 - 0.25), Vector3(w, WALL_H, 0.5), wall_mat)
	_solid(o + Vector3(0, WALL_H * 0.5, d * 0.5 + 0.25), Vector3(w, WALL_H, 0.5), wall_mat)
	# Vigas de madera.
	for x in range(int(-w * 0.5) + 2, int(w * 0.5) - 1, 4):
		_mesh(o + Vector3(x, WALL_H - 0.2, 0), Vector3(0.35, 0.35, d), _dark)
	if kind != "castillo":
		for z in [-d * 0.5 + 0.05, d * 0.5 - 0.05]:
			for x in range(int(-w * 0.5), int(w * 0.5) + 1, 4):
				_mesh(o + Vector3(x, WALL_H * 0.5, z), Vector3(0.3, WALL_H, 0.12), _dark)
	# Ventanas con luz de fuera.
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.75, 0.88, 1.0)
	glow.emission_enabled = true
	glow.emission = Color(0.7, 0.85, 1.0)
	glow.emission_energy_multiplier = 1.2
	for side in [-1.0, 1.0]:
		for z in [-d * 0.25, d * 0.2]:
			_mesh(o + Vector3(side * (w * 0.5 - 0.02), 2.6, z), Vector3(0.05, 1.4, 1.2), glow)
			_mesh(o + Vector3(side * (w * 0.5 - 0.06), 2.6, z), Vector3(0.06, 1.5, 0.1), _dark)
			_mesh(o + Vector3(side * (w * 0.5 - 0.06), 2.6, z), Vector3(0.06, 0.1, 1.3), _dark)
	# Puerta de salida.
	_mesh(o + Vector3(0, 1.3, d * 0.5 - 0.02), Vector3(2.0, 2.6, 0.1), _dark)
	_mesh(o + Vector3(0, 1.3, d * 0.5 - 0.05), Vector3(1.7, 2.4, 0.08), _wood)
	var label := Label3D.new()
	label.text = "Salida  (F)"
	label.font_size = 40
	label.outline_size = 8
	label.pixel_size = 0.006
	label.modulate = Color(1.0, 0.9, 0.6)
	label.position = o + Vector3(0, 3.0, d * 0.5 - 0.15)
	label.rotation.y = PI
	add_child(label)
	# Alfombra y luces cálidas.
	_mesh(o + Vector3(0, 0.02, d * 0.25), Vector3(2.4, 0.02, d * 0.4), _mat(Color(0.65, 0.15, 0.15)))
	for z in [-d * 0.25, d * 0.2]:
		_light(o + Vector3(0, WALL_H - 0.8, z), Color(1.0, 0.8, 0.55), 1.6, maxf(w, d) * 0.8)


# --- Tipos de sala -----------------------------------------------------------

func _posada(o: Vector3, size: Vector2) -> void:
	var w := size.x
	var d := size.y
	# Barra con barriles detrás.
	_solid(o + Vector3(-w * 0.5 + 2.2, 0.55, -d * 0.15), Vector3(1.0, 1.1, d * 0.5), _wood)
	for i in 3:
		_prop("barrel_large", o + Vector3(-w * 0.5 + 0.9, 0, -d * 0.35 + i * 1.6), 0.9)
	for p in [Vector3(1.5, 0, -3), Vector3(4.5, 0, 0.5), Vector3(1, 0, 3.5), Vector3(5, 0, -4.5)]:
		_table(o + p)
	_fireplace(o + Vector3(w * 0.5 - 1.0, 0, -d * 0.2), -PI / 2.0)
	_prop("banner_patternA_red", o + Vector3(0, 1.5, -d * 0.5 + 0.3), 1.0)
	_npc("Rosa", "Camarera", CHARS + "Rogue.glb", o + Vector3(-w * 0.5 + 3.4, 0, -d * 0.1), [
		"¡Bienvenido a La Jarra Dorada! Siéntate donde quieras.",
		"Los aventureros cuentan que de noche salen más esqueletos del bosque.",
		"Si buscas descansar, habla con Tomás, el posadero, en la puerta."])
	_npc("Viajero", "", CHARS + "Barbarian.glb", o + Vector3(4.5, 0, 1.8), [
		"Vengo de la capital. Dicen que el rey no sale del castillo desde hace meses.",
		"¿Un héroe con ventanas brillantes? ¡Ja! Como el de la leyenda."])


func _gremio(o: Vector3, size: Vector2) -> void:
	var w := size.x
	var d := size.y
	_solid(o + Vector3(0, 0.55, -d * 0.5 + 2.2), Vector3(w * 0.5, 1.1, 1.0), _wood)
	_board(o + Vector3(-w * 0.5 + 0.35, 0, 0), PI / 2.0)
	_board(o + Vector3(w * 0.5 - 0.35, 0, 1.0), -PI / 2.0)
	for p in [Vector3(-3, 0, 2), Vector3(3, 0, 3)]:
		_table(o + p)
	for x in [-4.0, 4.0]:
		_prop("banner_patternA_red", o + Vector3(x, 1.5, -d * 0.5 + 0.3), 1.0)
	_prop("chest_gold", o + Vector3(w * 0.5 - 1.2, 0, -d * 0.5 + 1.2), 1.0)
	_prop("sword_shield", o + Vector3(0, 2.4, -d * 0.5 + 0.3), 1.2)
	_npc("Kael", "Aventurero rango B", CHARS + "Knight.glb", o + Vector3(-3, 0, 3.3), [
		"Novato, ¿eh? Todos empezamos en el rango F.",
		"Consejo: usa tu poder especial cuando te rodeen. Y no te olvides de esquivar.",
		"El Rey Esqueleto de la mazmorra... yo no he podido con él. Quizá tú sí."])
	_npc("Sira", "Archivista", CHARS + "Mage.glb", o + Vector3(2.5, 0, -d * 0.5 + 1.2), [
		"Aquí guardamos el registro de todos los aventureros.",
		"Hace cien años hubo uno sin pasado, como tú. Su nombre se borró del libro."])


func _herreria(o: Vector3, size: Vector2) -> void:
	var w := size.x
	var d := size.y
	_fireplace(o + Vector3(0, 0, -d * 0.5 + 1.0), 0.0, Color(1.0, 0.45, 0.15))
	# Yunque.
	_solid(o + Vector3(1.5, 0.4, 0), Vector3(0.6, 0.8, 0.6), _stone)
	_mesh(o + Vector3(1.5, 0.95, 0), Vector3(1.2, 0.3, 0.5), _mat(Color(0.25, 0.25, 0.28)))
	_prop("sword_shield", o + Vector3(-w * 0.5 + 0.3, 2.2, -1.5), 1.2, PI / 2.0)
	_prop("sword_shield", o + Vector3(-w * 0.5 + 0.3, 2.2, 1.5), 1.2, PI / 2.0)
	_prop("barrel_large", o + Vector3(w * 0.5 - 1.0, 0, 2), 0.9)
	_prop("crates_stacked", o + Vector3(w * 0.5 - 1.2, 0, -2.5), 0.8)
	_npc("Tobi", "Aprendiz de herrero", CHARS + "Barbarian.glb", o + Vector3(-1.5, 0, 0.5), [
		"¡Cuidado, que el horno quema!",
		"El maestro Borin dice que con huesos de esqueleto el acero aguanta el doble."])


func _casa(o: Vector3, size: Vector2) -> void:
	var w := size.x
	var d := size.y
	# Cama.
	_solid(o + Vector3(-w * 0.5 + 1.4, 0.3, -d * 0.5 + 1.8), Vector3(1.8, 0.6, 3.0), _wood)
	_mesh(o + Vector3(-w * 0.5 + 1.4, 0.65, -d * 0.5 + 2.1), Vector3(1.7, 0.15, 2.4), _mat(Color(0.3, 0.45, 0.8)))
	_mesh(o + Vector3(-w * 0.5 + 1.4, 0.7, -d * 0.5 + 0.75), Vector3(1.2, 0.2, 0.5), _mat(Color(0.95, 0.95, 0.9)))
	_table(o + Vector3(1.5, 0, -0.5))
	_prop("chest", o + Vector3(w * 0.5 - 1.0, 0, -d * 0.5 + 1.0), 1.0)
	_fireplace(o + Vector3(w * 0.5 - 0.8, 0, 1.0), -PI / 2.0)
	# Estantería.
	_solid(o + Vector3(-w * 0.5 + 0.4, 1.2, 2.0), Vector3(0.6, 2.4, 2.0), _dark)
	for y in [0.6, 1.3, 2.0]:
		for z in [1.4, 1.9, 2.4]:
			_mesh(o + Vector3(-w * 0.5 + 0.75, y, z), Vector3(0.3, 0.4, 0.3), _mat(Color(_rng.randf_range(0.4, 0.9), _rng.randf_range(0.2, 0.6), 0.25)))


func _almacen(o: Vector3, size: Vector2) -> void:
	var w := size.x
	var d := size.y
	for i in 4:
		_prop("crates_stacked", o + Vector3(-w * 0.5 + 1.3, 0, -d * 0.5 + 1.3 + i * 2.2), 0.9)
		_prop("barrel_large", o + Vector3(w * 0.5 - 1.0, 0, -d * 0.5 + 1.2 + i * 2.0), 0.9)
	_prop("chest_gold", o + Vector3(0, 0, -d * 0.5 + 1.0), 1.0)
	_table(o + Vector3(0, 0, 0.5))


func _iglesia(o: Vector3, size: Vector2) -> void:
	var w := size.x
	var d := size.y
	# Bancos a los dos lados del pasillo.
	for z in range(-2, 5, 2):
		for side in [-1.0, 1.0]:
			_solid(o + Vector3(side * 3.6, 0.35, z), Vector3(4.0, 0.7, 0.8), _wood)
	# Altar con velas y una vidriera.
	_solid(o + Vector3(0, 0.6, -d * 0.5 + 1.8), Vector3(3.0, 1.2, 1.2), _stone)
	for x in [-1.0, 0.0, 1.0]:
		var candle := _mesh(o + Vector3(x, 1.4, -d * 0.5 + 1.8), Vector3(0.12, 0.4, 0.12), _mat(Color(1, 0.95, 0.85)))
		candle.name = "vela"
	_light(o + Vector3(0, 2.0, -d * 0.5 + 2.0), Color(1.0, 0.85, 0.5), 2.0, 8.0, true)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.5, 0.6, 1.0)
	glass.emission_enabled = true
	glass.emission = Color(0.55, 0.45, 1.0)
	glass.emission_energy_multiplier = 1.6
	_mesh(o + Vector3(0, 3.0, -d * 0.5 + 0.02), Vector3(2.4, 3.0, 0.05), glass)
	for x in [-w * 0.5 + 1.0, w * 0.5 - 1.0]:
		_prop("pillar_decorated", o + Vector3(x, 0, -d * 0.25), 1.0)
		_prop("pillar_decorated", o + Vector3(x, 0, d * 0.15), 1.0)
	_npc("Hermana Elia", "Sacerdotisa", CHARS + "Mage.glb", o + Vector3(0, 0, -d * 0.5 + 3.2), [
		"La luz te guía, viajero.",
		"El cristal azul donde despertaste... dicen que es un fragmento del mismo Sistema.",
		"Reza si quieres, pero sobre todo sube de nivel. Este mundo premia a los fuertes."])


func _castillo(o: Vector3, size: Vector2) -> void:
	var w := size.x
	var d := size.y
	_mesh(o + Vector3(0, 0.03, 0), Vector3(3.0, 0.03, d - 2.0), _mat(Color(0.7, 0.1, 0.12)))
	for z in range(int(-d * 0.5) + 4, int(d * 0.5) - 2, 5):
		for side in [-1.0, 1.0]:
			_prop("pillar_decorated", o + Vector3(side * (w * 0.5 - 2.5), 0, z), 1.2)
			_prop("banner_patternA_red", o + Vector3(side * (w * 0.5 - 0.3), 1.6, z + 2.5), 1.2, -side * PI / 2.0)
			_prop("torch_mounted", o + Vector3(side * (w * 0.5 - 0.3), 2.2, z), 1.0, -side * PI / 2.0)
			_light(o + Vector3(side * (w * 0.5 - 1.0), 2.6, z), Color(1.0, 0.7, 0.4), 1.8, 7.0, true)
	# Estrado y trono dorado.
	_solid(o + Vector3(0, 0.3, -d * 0.5 + 2.5), Vector3(7.0, 0.6, 4.0), _stone)
	var gold := _mat(Color(0.95, 0.75, 0.25))
	gold.metallic = 0.6
	_solid(o + Vector3(0, 1.2, -d * 0.5 + 1.6), Vector3(1.8, 1.2, 1.2), gold)
	_mesh(o + Vector3(0, 2.6, -d * 0.5 + 1.1), Vector3(1.8, 2.4, 0.3), gold)
	_mesh(o + Vector3(0, 1.85, -d * 0.5 + 1.7), Vector3(1.4, 0.15, 1.0), _mat(Color(0.6, 0.1, 0.15)))
	_npc("Rey Aurelio", "Rey de Aurelia", CHARS + "Knight.glb", o + Vector3(0, 0.6, -d * 0.5 + 3.0), [
		"Así que tú eres el viajero del cristal azul.",
		"Hace cien años otro como tú salvó este reino del Rey Esqueleto.",
		"Ahora el Rey Esqueleto ha vuelto, y los monstruos crecen cada noche.",
		"Sube de rango en el gremio, hazte fuerte... y quizá encuentres la salida que buscas."])
	_npc("Guardia", "Guardia real", CHARS + "Knight.glb", o + Vector3(-3, 0, d * 0.5 - 4.0), [
		"Muestra respeto ante Su Majestad."])
	_npc("Guardia", "Guardia real", CHARS + "Knight.glb", o + Vector3(3, 0, d * 0.5 - 4.0), [
		"El castillo está a salvo mientras yo esté aquí."])


# --- Piezas ------------------------------------------------------------------

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	return m


func _mesh(pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	add_child(mi)
	return mi


func _solid(pos: Vector3, size: Vector3, mat: Material) -> void:
	_mesh(pos, size, mat)
	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	body.add_child(col)
	add_child(body)


func _prop(piece: String, pos: Vector3, factor: float, yaw := 0.0) -> Node3D:
	var model: Node3D = (load(PIECES + piece + ".glb") as PackedScene).instantiate()
	model.position = pos
	model.rotation.y = yaw
	model.scale = Vector3.ONE * factor
	add_child(model)
	Toon.apply(model, 0.0)
	return model


func _light(pos: Vector3, color: Color, energy: float, light_range: float, flicker := false) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	add_child(l)
	if flicker:
		_flames.append(l)


func _table(pos: Vector3) -> void:
	_solid(pos + Vector3(0, 0.8, 0), Vector3(1.8, 0.12, 1.2), _wood)
	for x in [-0.75, 0.75]:
		for z in [-0.45, 0.45]:
			_mesh(pos + Vector3(x, 0.4, z), Vector3(0.12, 0.8, 0.12), _dark)
	for side in [-1.0, 1.0]:
		_mesh(pos + Vector3(side * 1.3, 0.25, 0), Vector3(0.5, 0.5, 0.5), _dark)
	# Jarras.
	_mesh(pos + Vector3(-0.3, 0.98, 0.1), Vector3(0.18, 0.25, 0.18), _mat(Color(0.85, 0.7, 0.35)))
	_mesh(pos + Vector3(0.4, 0.98, -0.2), Vector3(0.18, 0.25, 0.18), _mat(Color(0.85, 0.7, 0.35)))


func _fireplace(pos: Vector3, yaw: float, color := Color(1.0, 0.55, 0.2)) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	add_child(holder)
	var parts := [[Vector3(-1.0, 0.8, 0), Vector3(0.4, 1.6, 0.9)], [Vector3(1.0, 0.8, 0), Vector3(0.4, 1.6, 0.9)],
		[Vector3(0, 1.8, 0), Vector3(2.6, 0.5, 1.0)], [Vector3(0, 3.4, -0.1), Vector3(1.6, 2.8, 0.8)]]
	for p in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = p[1]
		bm.material = _stone
		mi.mesh = bm
		mi.position = p[0]
		holder.add_child(mi)
	var fire := MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.45
	fm.height = 0.7
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.material = mat
	fire.mesh = fm
	fire.position = Vector3(0, 0.35, 0.05)
	holder.add_child(fire)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.2
	light.omni_range = 8.0
	light.position = Vector3(0, 0.8, 0.8)
	holder.add_child(light)
	_flames.append(light)
	var body := StaticBody3D.new()
	body.position = pos + Vector3(0, 1, 0)
	body.rotation.y = yaw
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.6, 2, 1.0)
	col.shape = box
	body.add_child(col)
	add_child(body)


func _board(pos: Vector3, yaw: float) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	add_child(holder)
	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(3.0, 1.8, 0.1)
	bm.material = _wood
	board.mesh = bm
	board.position = Vector3(0, 2.2, 0)
	holder.add_child(board)
	var paper := _mat(Color(0.95, 0.88, 0.7))
	var pin := _mat(Color(0.85, 0.15, 0.12))
	for i in 7:
		var p := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.55, 0.5, 0.02)
		pm.material = paper
		p.mesh = pm
		p.position = Vector3(-1.1 + (i % 4) * 0.72, 2.6 - (i / 4) * 0.75, 0.07)
		p.rotation.z = _rng.randf_range(-0.15, 0.15)
		holder.add_child(p)
		var dot := MeshInstance3D.new()
		var dm := SphereMesh.new()
		dm.radius = 0.04
		dm.height = 0.08
		dm.material = pin
		dot.mesh = dm
		dot.position = p.position + Vector3(0, 0.2, 0.03)
		holder.add_child(dot)


func _npc(npc_name: String, role: String, model: String, pos: Vector3, lines: Array) -> void:
	var npc := Node3D.new()
	npc.set_script(NPC)
	npc.npc_name = npc_name
	npc.role = role
	npc.model_path = model
	npc.lines = lines
	if model.ends_with("Knight.glb"):
		npc.gear = ["1H_Sword", "Badge_Shield", "Knight_Helmet"]
	npc.position = pos
	add_child(npc)
