extends Node3D
## El mundo de la demo: colina del despertar, valle con río y puente, un
## pueblo junto al camino, molino, castillo sobre una colina lejana y
## montañas nevadas alrededor. Pasto alto con viento, flores y arboledas.

const Toon := preload("res://scripts/toon.gd")
const ModelUtil := preload("res://scripts/model_util.gd")
const TERRAIN_SHADER := preload("res://shaders/terrain.gdshader")
const GRASS_SHADER := preload("res://shaders/grass_blades.gdshader")
const WATER_SHADER := preload("res://shaders/water.gdshader")
const NATURE := "res://assets/kaykit/nature/"
const BUILD := "res://assets/kaykit/buildings/"

const HALF := 320.0
const STEP := 2.0
const WATER_LEVEL := 0.5

## Lugares clave (x, z).
const AWAKENING := Vector2(0, 6)
const CASTLE := Vector2(30, -215)
const CASTLE_HEIGHT := 22.0
const VILLAGE := Vector2(4, -98)
const VILLAGE_HEIGHT := 3.2
const WINDMILL := Vector2(-58, -118)
const BRIDGE := Vector2(0, -64.2)
## Arena de pelea: un claro llano al este del camino.
const ARENA := Vector2(34, -22)
const ARENA_RADIUS := 15.0
## Bosque Susurrante: zona densa y oscura en la colina del oeste.
const FOREST := Vector2(-112, -32)
const FOREST_RADIUS := 48.0
## Entrada de la mazmorra, en las colinas del este.
const DUNGEON_GATE := Vector2(96, -8)

## Zonas con nombre: [nombre, centro, radio]. Fuera de todas, la pradera.
const ZONES := [
	["Colina del Despertar", Vector2(0, 6), 22.0],
	["Arena de Entrenamiento", Vector2(34, -22), 19.0],
	["Aldea de Rivel", Vector2(4, -98), 42.0],
	["Castillo de Aurelia", Vector2(30, -215), 60.0],
	["Molino del Oeste", Vector2(-58, -118), 24.0],
	["Bosque Susurrante", Vector2(-112, -32), 52.0],
	["Puerta de la Mazmorra", Vector2(96, -8), 18.0],
]

## Gente del pueblo. `at` es relativo al centro de la aldea.
const VILLAGERS := [
	{"name": "Mira", "role": "Recepcionista del Gremio", "model": "res://assets/kaykit/characters/Rogue.glb", "at": Vector2(7, 9), "action": "guild",
		"lines": ["¡Bienvenido al Gremio de Aventureros de Rivel!",
			"¿Un viajero sin registro? Qué raro... Te trajo el Sistema, ¿verdad? Lo noto en tus ojos.",
			"Para aceptar encargos necesitas estar registrado. Empiezas en el rango F, el más bajo, y subes cumpliendo misiones hasta el rango S.",
			"Listo, ya eres aventurero del gremio. ¡Echa un vistazo al tablón!"]},
	{"name": "Tomás", "role": "Posadero · La Jarra Dorada", "model": "res://assets/kaykit/characters/Barbarian.glb", "at": Vector2(-6, 3), "action": "rest",
		"lines": ["¡Bienvenido a La Jarra Dorada! Pareces agotado, muchacho.",
			"Tengo una cama caliente arriba. Descansa: mañana será otro día."]},
	{"name": "Borin", "role": "Herrero", "model": "res://assets/kaykit/characters/Barbarian.glb", "gear": ["2H_Axe"], "at": Vector2(8, -16), "action": "smith",
		"lines": ["Esa arma que llevas... no la forjó nadie de este mundo.",
			"Tráeme oro y huesos de esqueleto y te la mejoraré.",
			"Dicen que en el fondo de la mazmorra duerme un rey hecho de huesos. Yo no me acercaría."]},
	{"name": "Pip", "role": "Mercader", "model": "res://assets/kaykit/characters/Rogue_Hooded.glb", "at": Vector2(-6, -21), "action": "shop",
		"lines": ["¡Pociones, mapas, recuerdos de la capital!",
			"Un consejo gratis: el bosque del oeste se pone feo de noche. Los esqueletos de allí lanzan magia.",
			"¿Qué te llevas?"]},
	{"name": "Abuelo Ered", "role": "Anciano de la aldea", "model": "res://assets/kaykit/characters/Mage.glb", "gear": ["2H_Staff"], "at": Vector2(-15, 8),
		"lines": ["Tú también despertaste junto al cristal azul, ¿eh?",
			"Hace cien años llegó otro como tú. Hablaba de ventanas flotantes y de \"niveles\".",
			"Subió y subió, venció al Rey Esqueleto... y un día simplemente desapareció.",
			"Algunos dicen que encontró la salida de este mundo. Otros, que el mundo lo borró."]},
	{"name": "Lila", "role": "", "model": "res://assets/kaykit/characters/Rogue.glb", "at": Vector2(3, -3), "height": 1.2,
		"lines": ["¿Eres un héroe de verdad? ¡Tienes una ventana brillante encima de la cabeza!",
			"Mi mamá no me deja salir del pueblo por los esqueletos. ¡Derrótalos a todos!"]},
]

## El camino de tierra: del despertar, cruza el río por el puente, atraviesa
## el pueblo y sube hasta la puerta del castillo.
const ROAD := [Vector2(0, 10), Vector2(4, -10), Vector2(-4, -32), Vector2(-2, -50),
	Vector2(0, -64), Vector2(2, -80), Vector2(4, -98), Vector2(10, -120),
	Vector2(18, -145), Vector2(25, -170), Vector2(29, -192)]

var _noise := FastNoiseLite.new()
var _ridge := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _awakening_height := 0.0
var _arena_height := 0.0


func _init() -> void:
	_noise.seed = 7
	_noise.frequency = 0.006
	_noise.fractal_octaves = 4
	_ridge.seed = 11
	_ridge.frequency = 0.012
	_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_rng.seed = 20261009
	_awakening_height = _raw_height(AWAKENING.x, AWAKENING.y)
	_arena_height = _raw_height(ARENA.x, ARENA.y)


func build() -> void:
	_build_terrain()
	_build_water()
	_build_grass()
	_build_trees()
	_build_rocks()
	_build_castle()
	_build_village()
	_build_arena()
	_build_forest()
	_build_gate()
	_build_signs()
	_build_clouds()
	_build_village_life()


var _lamps: Array = []
var _fireflies: Array = []
var _night := false
var _check := 0.0


func _process(delta: float) -> void:
	_update_gate(delta)
	_check -= delta
	if _check > 0.0:
		return
	_check = 1.0
	var clock := get_tree().get_first_node_in_group("world_clock")
	if clock == null:
		return
	var night: bool = clock.is_night() or clock.time > 18.5 or clock.time < 6.5
	if night == _night:
		return
	_night = night
	for l in _lamps:
		l.light.visible = night
		l.mat.emission_energy_multiplier = 4.0 if night else 0.3
	for f in _fireflies:
		f.emitting = night


# --- Forma del terreno ----------------------------------------------------

func river_z(x: float) -> float:
	return -70.0 + 15.0 * sin(x * 0.015) + 6.0 * sin(x * 0.041 + 1.3)


func height(x: float, z: float) -> float:
	var h := _raw_height(x, z)
	h = _flatten(h, x, z, AWAKENING, _awakening_height, 7.0, 14.0)
	h = _flatten(h, x, z, ARENA, _arena_height, ARENA_RADIUS + 2.0, ARENA_RADIUS + 12.0)
	h = _flatten(h, x, z, CASTLE, CASTLE_HEIGHT, 38.0, 52.0)
	h = _flatten(h, x, z, VILLAGE, VILLAGE_HEIGHT, 24.0, 40.0)
	return h


func _raw_height(x: float, z: float) -> float:
	var n := _noise.get_noise_2d(x, z)
	var h := 3.5 + n * 7.0
	h += 7.0 * _bump(x, z, AWAKENING, 40.0)
	h += 16.0 * _bump(x, z, CASTLE, 60.0)
	h += 9.0 * _bump(x, z, Vector2(-125, -40), 45.0)
	h += 8.0 * _bump(x, z, Vector2(115, 5), 50.0)
	h += 6.0 * _bump(x, z, WINDMILL, 30.0)
	var dr := absf(z - river_z(x))
	var valley := exp(-dr * dr / (2.0 * 42.0 * 42.0))
	h = lerpf(h, 2.6 + n * 1.0, valley * 0.85)
	h = lerpf(h, -1.6, 1.0 - smoothstep(4.0, 10.0, dr))
	var r := Vector2(x, z).length()
	h += smoothstep(185.0, 290.0, r) * (30.0 + 38.0 * absf(_ridge.get_noise_2d(x, z)))
	return h


func _bump(x: float, z: float, c: Vector2, radius: float) -> float:
	var d2 := (x - c.x) * (x - c.x) + (z - c.y) * (z - c.y)
	return exp(-d2 / (2.0 * radius * radius))


func _flatten(h: float, x: float, z: float, c: Vector2, target: float, inner: float, outer: float) -> float:
	var d := Vector2(x, z).distance_to(c)
	return lerpf(target, h, smoothstep(inner, outer, d))


func road_distance(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := INF
	for i in ROAD.size() - 1:
		best = min(best, Geometry2D.get_closest_point_to_segment(p, ROAD[i], ROAD[i + 1]).distance_to(p))
	return best


func surface(x: float, z: float) -> Vector3:
	return Vector3(x, height(x, z), z)


func awakening_point() -> Vector3:
	return surface(AWAKENING.x, AWAKENING.y)


# --- Terreno --------------------------------------------------------------

func _build_terrain() -> void:
	var count := int(HALF * 2.0 / STEP) + 1
	var heights := PackedFloat32Array()
	heights.resize(count * count)
	for j in count:
		var z := -HALF + j * STEP
		for i in count:
			heights[j * count + i] = height(-HALF + i * STEP, z)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	verts.resize(count * count)
	normals.resize(count * count)
	for j in count:
		for i in count:
			var hl := heights[j * count + max(i - 1, 0)]
			var hr := heights[j * count + min(i + 1, count - 1)]
			var hd := heights[max(j - 1, 0) * count + i]
			var hu := heights[min(j + 1, count - 1) * count + i]
			verts[j * count + i] = Vector3(-HALF + i * STEP, heights[j * count + i], -HALF + j * STEP)
			normals[j * count + i] = Vector3(hl - hr, 2.0 * STEP, hd - hu).normalized()

	var indices := PackedInt32Array()
	indices.resize((count - 1) * (count - 1) * 6)
	var k := 0
	for j in count - 1:
		for i in count - 1:
			var a := j * count + i
			var b := a + 1
			var c := a + count
			var d := c + 1
			indices[k] = a; indices[k + 1] = b; indices[k + 2] = c
			indices[k + 3] = b; indices[k + 4] = d; indices[k + 5] = c
			k += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat := ShaderMaterial.new()
	mat.shader = TERRAIN_SHADER
	mat.set_shader_parameter("road_points", PackedVector2Array(ROAD))
	mat.set_shader_parameter("road_count", ROAD.size())
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)

	var faces := PackedVector3Array()
	faces.resize(indices.size())
	for f in indices.size():
		faces[f] = verts[indices[f]]
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)


func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(HALF * 2.0, HALF * 2.0)
	plane.subdivide_width = 1
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = mat
	mi.position.y = WATER_LEVEL
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# --- Pasto y flores -------------------------------------------------------

func _can_grow(x: float, z: float, h: float) -> bool:
	if h < 1.8 or h > 24.0:
		return false
	if road_distance(x, z) < 2.8:
		return false
	if Vector2(x, z).distance_to(ARENA) < ARENA_RADIUS + 1.0:
		return false
	if Vector2(x, z).distance_to(CASTLE) < 40.0 or Vector2(x, z).distance_to(VILLAGE) < 22.0:
		return false
	return true


func _build_grass() -> void:
	var blade := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.07, 0, 0), Vector3(0.07, 0, 0), Vector3(-0.035, 0.55, 0), Vector3(0.035, 0.55, 0), Vector3(0, 1, 0)])
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(0, 0.55), Vector2(1, 0.55), Vector2(0.5, 1)])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 1, 3, 2, 2, 3, 4])
	blade.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)

	var spots: Array[Transform3D] = []
	var tints: Array[Color] = []
	var target := 45000 if preload("res://scripts/platform.gd").is_touch() else 150000
	var tries := 0
	while spots.size() < target and tries < target * 3:
		tries += 1
		# Más pasto cerca del despertar y del valle, menos lejos.
		var x := _rng.randf_range(-150.0, 150.0)
		var z := _rng.randf_range(-170.0, 60.0)
		var keep := 1.0 - smoothstep(60.0, 160.0, Vector2(x, z).distance_to(Vector2(0, -40)))
		if _rng.randf() > keep * 0.9 + 0.1:
			continue
		var h := height(x, z)
		if not _can_grow(x, z, h):
			continue
		var s := _rng.randf_range(0.28, 0.6)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(1.2, s, 1.2))
		spots.append(Transform3D(basis, Vector3(x, h - 0.05, z)))
		var v := _rng.randf_range(0.85, 1.12)
		tints.append(Color(v, v * _rng.randf_range(0.97, 1.05), v * 0.95))

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = blade
	mm.instance_count = spots.size()
	for i in spots.size():
		mm.set_instance_transform(i, spots[i])
		mm.set_instance_custom_data(i, tints[i])
	var mat := ShaderMaterial.new()
	mat.shader = GRASS_SHADER
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

	# Flores en manchas.
	var flower_colors := [Color(1, 1, 0.95), Color(1.0, 0.86, 0.3), Color(1.0, 0.62, 0.75), Color(0.65, 0.75, 1.0)]
	var fmesh := SphereMesh.new()
	fmesh.radius = 0.09
	fmesh.height = 0.12
	fmesh.radial_segments = 6
	fmesh.rings = 2
	var fmat := StandardMaterial3D.new()
	fmat.vertex_color_use_as_albedo = true
	fmat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	fmesh.material = fmat
	var flowers: Array[Transform3D] = []
	var fcolors: Array[Color] = []
	for patch in 70:
		var c := Vector2(_rng.randf_range(-130, 130), _rng.randf_range(-160, 50))
		var color: Color = flower_colors[_rng.randi() % flower_colors.size()]
		for f in _rng.randi_range(30, 90):
			var p := c + Vector2(_rng.randfn(0, 4.0), _rng.randfn(0, 4.0))
			var h := height(p.x, p.y)
			if not _can_grow(p.x, p.y, h):
				continue
			flowers.append(Transform3D(Basis(), Vector3(p.x, h + _rng.randf_range(0.35, 0.7), p.y)))
			fcolors.append(color)
	var fmm := MultiMesh.new()
	fmm.transform_format = MultiMesh.TRANSFORM_3D
	fmm.use_colors = true
	fmm.mesh = fmesh
	fmm.instance_count = flowers.size()
	for i in flowers.size():
		fmm.set_instance_transform(i, flowers[i])
		fmm.set_instance_color(i, fcolors[i])
	var fmmi := MultiMeshInstance3D.new()
	fmmi.multimesh = fmm
	fmmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fmmi)


# --- Árboles y rocas ------------------------------------------------------

const TREE_TINT := Color(0.78, 1.0, 0.62)
var _trees: Array[Vector2] = []


func _tree_ok(p: Vector2) -> bool:
	var h := height(p.x, p.y)
	if h < 2.2 or h > 26.0:
		return false
	if road_distance(p.x, p.y) < 7.0 or absf(p.y - river_z(p.x)) < 13.0:
		return false
	if p.distance_to(ARENA) < ARENA_RADIUS + 8.0 or p.distance_to(DUNGEON_GATE) < 14.0:
		return false
	if p.distance_to(AWAKENING) < 16.0 or p.distance_to(CASTLE) < 50.0 or p.distance_to(VILLAGE) < 30.0 or p.distance_to(WINDMILL) < 18.0:
		return false
	for t in _trees:
		if t.distance_to(p) < 5.5:
			return false
	return true


func _build_trees() -> void:
	# Arboledas pequeñas repartidas por las laderas.
	var groves := [Vector2(-38, 12), Vector2(42, -20), Vector2(-75, -30), Vector2(70, -45),
		Vector2(-30, -125), Vector2(60, -110), Vector2(-100, -90), Vector2(95, -150),
		Vector2(-60, 40), Vector2(55, 35), Vector2(-120, -10), Vector2(120, -60),
		Vector2(-85, -160), Vector2(-20, 55)]
	for g in groves:
		for t in _rng.randi_range(3, 7):
			var p: Vector2 = g + Vector2(_rng.randfn(0, 7.0), _rng.randfn(0, 7.0))
			if _tree_ok(p):
				_add_tree(p)
	# Árboles solitarios en los prados.
	var lone := 0
	while lone < 22:
		var p := Vector2(_rng.randf_range(-150, 150), _rng.randf_range(-180, 70))
		if _tree_ok(p):
			_add_tree(p)
			lone += 1


func _add_tree(p: Vector2) -> void:
	_trees.append(p)
	var kind := "tree_single_A" if _rng.randf() < 0.6 else "tree_single_B"
	var f := _rng.randf_range(6.5, 9.0)
	var holder := _place(NATURE + kind + ".gltf", surface(p.x, p.y) - Vector3(0, 0.2, 0), f, 0.025, TREE_TINT)
	holder.rotation.y = _rng.randf() * TAU
	_add_cylinder(surface(p.x, p.y) + Vector3(0, 2, 0), 0.6, 4.0)
	_fade_near_camera(holder)


func _build_rocks() -> void:
	var placed := 0
	while placed < 28:
		var p := Vector2(_rng.randf_range(-140, 140), _rng.randf_range(-170, 60))
		var h := height(p.x, p.y)
		if h < 1.0 or road_distance(p.x, p.y) < 4.0 or p.distance_to(AWAKENING) < 12.0 or p.distance_to(ARENA) < ARENA_RADIUS + 6.0:
			continue
		var kind: String = ["rock_single_A", "rock_single_B", "rock_single_C", "rock_single_D", "rock_single_E"][_rng.randi() % 5]
		var f := _rng.randf_range(5.0, 11.0)
		var holder := _place(NATURE + kind + ".gltf", Vector3(p.x, h - 0.15, p.y), f, 0.03)
		holder.rotation.y = _rng.randf() * TAU
		var body := StaticBody3D.new()
		body.position = Vector3(p.x, h + f * 0.03, p.y)
		var col := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = f * 0.14
		col.shape = sphere
		body.add_child(col)
		add_child(body)
		placed += 1


# --- Castillo y pueblo ----------------------------------------------------

var castle_doors: Array = []
var _gate_blocker: CollisionShape3D
var _gate_open := 0.0


func _build_castle() -> void:
	var c := Vector3(CASTLE.x, CASTLE_HEIGHT, CASTLE.y)
	_place(BUILD + "building_castle_blue.gltf", c, 11.0, 0.02).rotation.y = PI
	_add_box(c + Vector3(0, 8, -1), Vector3(19, 16, 22))
	# Muralla cuadrada: 5 tramos por lado, torres en las esquinas y la puerta
	# en el centro del lado sur, mirando a la aldea.
	var scale := 5.0
	var piece := 2.0 * scale
	var half := piece * 2.5
	for side in 4:
		var yaw := side * PI / 2.0
		var basis := Basis(Vector3.UP, yaw)
		for i in 5:
			var local := Vector3(-half + piece * (i + 0.5), 0, half)
			var pos := c + basis * local
			pos.y = minf(height(pos.x, pos.z), CASTLE_HEIGHT + 1.0) - 0.2
			var gate := side == 0 and i == 2
			var wall := _place(BUILD + ("wall_straight_gate.gltf" if gate else "wall_straight.gltf"), pos, scale, 0.02)
			wall.rotation.y = yaw
			if gate:
				_setup_gate(wall, pos, yaw)
			else:
				_add_box(pos + Vector3(0, 3, 0), Vector3(piece + 0.2, 6, 2.6), yaw)
		var corner := c + basis * Vector3(half, 0, half)
		corner.y = minf(height(corner.x, corner.z), CASTLE_HEIGHT + 1.0) - 0.2
		_place(BUILD + "building_tower_A_blue.gltf", corner, 7.0, 0.02)
		_add_cylinder(corner + Vector3(0, 4, 0), 3.4, 8.0)
	for p in [Vector3(-14, 0, -12), Vector3(14, 0, -12), Vector3(-15, 0, 12), Vector3(15, 0, 12)]:
		var hp: Vector3 = c + p
		hp.y = height(hp.x, hp.z)
		_place(BUILD + "building_home_A_blue.gltf", hp, 6.0, 0.02).rotation.y = PI if p.z < 0 else 0.0
		_add_box(hp + Vector3(0, 3, 0), Vector3(5, 6, 5))
	for x in [-6.0, 6.0]:
		_place(BUILD + "flag_blue.gltf", c + Vector3(x, 0, half - 4), 6.0, 0.02)


func _setup_gate(wall: Node3D, pos: Vector3, yaw: float) -> void:
	for door in wall.find_children("*_door_*", "MeshInstance3D", true, false):
		castle_doors.append(door)
	# Los lados del portón tienen colisión; el hueco solo mientras está cerrado.
	for sx in [-1.0, 1.0]:
		_add_box(pos + Basis(Vector3.UP, yaw) * Vector3(sx * 3.6, 3.5, 0), Vector3(2.8, 7, 2.6), yaw)
	var body := StaticBody3D.new()
	body.position = pos + Vector3(0, 2.5, 0)
	body.rotation.y = yaw
	_gate_blocker = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.6, 5, 0.8)
	_gate_blocker.shape = box
	body.add_child(_gate_blocker)
	add_child(body)
	var label := Label3D.new()
	label.text = "Castillo de Aurelia"
	label.font_size = 64
	label.outline_size = 12
	label.pixel_size = 0.01
	label.modulate = Color(1.0, 0.9, 0.6)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = pos + Vector3(0, 9.0, 0)
	add_child(label)


## Las puertas del castillo se abren cuando el héroe se acerca.
func _update_gate(delta: float) -> void:
	if castle_doors.is_empty():
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var gate_pos := Vector3(CASTLE.x, player.global_position.y, CASTLE.y + 25.0)
	var near := player.global_position.distance_to(gate_pos) < 14.0
	var before := _gate_open
	_gate_open = move_toward(_gate_open, 1.0 if near else 0.0, delta * 0.8)
	if (before == 0.0 and _gate_open > 0.0) or (before == 1.0 and _gate_open < 1.0):
		var audio := get_tree().get_first_node_in_group("audio")
		if audio:
			audio.at("gate", gate_pos + Vector3(0, 3, 0), 2.0)
	var angle := smoothstep(0.0, 1.0, _gate_open) * deg_to_rad(100.0)
	for door in castle_doors:
		door.rotation.y = angle if String(door.name).ends_with("left") else -angle
	_gate_blocker.disabled = _gate_open > 0.5


func _build_village() -> void:
	var v := Vector3(VILLAGE.x, VILLAGE_HEIGHT, VILLAGE.y)
	var houses := [
		["building_tavern_blue", Vector3(-12, 0, -2), PI / 2.0],
		["building_home_A_blue", Vector3(13, 0, 4), -PI / 2.0],
		["building_home_B_blue", Vector3(-11, 0, 13), PI / 2.0],
		["building_blacksmith_blue", Vector3(14, 0, -12), -PI / 2.0],
		["building_market_blue", Vector3(-13, 0, -16), PI / 2.0],
		["building_church_blue", Vector3(-20, 0, 2), PI / 2.0],
		["building_home_B_blue", Vector3(20, 0, 14), -PI / 2.0],
		["building_well_blue", Vector3(6, 0, -6), 0.0],
	]
	for h in houses:
		var pos: Vector3 = v + h[1]
		pos.y = height(pos.x, pos.z)
		_place(BUILD + h[0] + ".gltf", pos, 6.5, 0.02).rotation.y = h[2]
		if h[0] != "building_well_blue":
			_add_box(pos + Vector3(0, 3, 0), Vector3(7, 6, 7))
	for prop in [["barrel", Vector3(-7, 0, 3)], ["crate_A_big", Vector3(9, 0, -3)], ["sack", Vector3(-7, 0, -8)], ["tent", Vector3(10, 0, 16)]]:
		var p: Vector3 = v + prop[1]
		p.y = height(p.x, p.z)
		_place(BUILD + prop[0] + ".gltf", p, 4.5, 0.02).rotation.y = _rng.randf() * TAU

	# Molino en su loma, con campos de trigo.
	var w := surface(WINDMILL.x, WINDMILL.y)
	_place(BUILD + "building_windmill_blue.gltf", w, 8.0, 0.02).rotation.y = 0.6
	_add_box(w + Vector3(0, 4, 0), Vector3(7, 8, 7))
	for f in [Vector2(14, 6), Vector2(-12, 10), Vector2(10, -14), Vector2(-14, -10)]:
		var p: Vector2 = WINDMILL + f
		_place(BUILD + "building_grain.gltf", surface(p.x, p.y) - Vector3(0, 0.3, 0), 7.0, 0.0)

	# Puente de madera sobre el río, en el cruce del camino.
	_build_bridge()


## Puente: tablones en arco de orilla a orilla, con barandillas. Cada tramo
## sigue la altura del terreno en las puntas, así se sube caminando.
func _build_bridge() -> void:
	var half := 17.0
	var width := 4.6
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.55, 0.36, 0.2)
	wood.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.38, 0.24, 0.13)
	dark.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	var points: Array[Vector3] = []
	var steps := 34
	for i in steps + 1:
		var z := BRIDGE.y - half + 2.0 * half * i / steps
		var d := absf(z - BRIDGE.y) / half
		var arch := WATER_LEVEL + 1.4 + 0.9 * (1.0 - d * d)
		# Los extremos bajan suavemente hasta el suelo: se sube caminando.
		var ground := height(BRIDGE.x, z) - 0.08
		var y := maxf(lerpf(arch, ground, smoothstep(0.6, 1.0, d)), ground)
		points.append(Vector3(BRIDGE.x, y, z))
	for i in steps:
		var a := points[i]
		var b := points[i + 1]
		var mid := (a + b) * 0.5
		var length := a.distance_to(b)
		var tilt := atan2(b.y - a.y, b.z - a.z)
		var plank := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(width, 0.25, length + 0.05)
		pm.material = wood if i % 2 == 0 else dark
		plank.mesh = pm
		plank.position = mid
		plank.rotation.x = -tilt
		add_child(plank)
		var body := StaticBody3D.new()
		body.position = mid - Vector3(0, 0.1, 0)
		body.rotation.x = -tilt
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(width, 0.4, length + 0.1)
		col.shape = box
		body.add_child(col)
		add_child(body)
		# Barandillas a los dos lados.
		for side in [-1.0, 1.0]:
			if i % 2 == 0:
				var post := MeshInstance3D.new()
				var postm := BoxMesh.new()
				postm.size = Vector3(0.18, 1.1, 0.18)
				postm.material = dark
				post.mesh = postm
				post.position = a + Vector3(side * (width * 0.5 - 0.1), 0.6, 0)
				add_child(post)
			var rail := MeshInstance3D.new()
			var railm := BoxMesh.new()
			railm.size = Vector3(0.12, 0.12, length + 0.05)
			railm.material = wood
			rail.mesh = railm
			rail.position = mid + Vector3(side * (width * 0.5 - 0.1), 1.1, 0)
			rail.rotation.x = -tilt
			add_child(rail)
			_add_box(mid + Vector3(side * (width * 0.5 - 0.1), 0.8, 0), Vector3(0.2, 1.2, length))


## Arena: suelo de tierra, círculo de postes de piedra y estandartes.
func _build_arena() -> void:
	var c := surface(ARENA.x, ARENA.y)
	var floor_mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = ARENA_RADIUS
	disc.bottom_radius = ARENA_RADIUS
	disc.height = 0.1
	disc.radial_segments = 48
	var dirt := StandardMaterial3D.new()
	dirt.albedo_color = Color(0.62, 0.5, 0.36)
	dirt.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	disc.material = dirt
	floor_mesh.mesh = disc
	floor_mesh.position = c + Vector3(0, 0.02, 0)
	add_child(floor_mesh)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.62, 0.64, 0.7)
	stone.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	var count := 20
	for i in count:
		var a := TAU * i / count
		var p := ARENA + Vector2(cos(a), sin(a)) * (ARENA_RADIUS + 0.6)
		# Deja una entrada mirando al camino (al oeste).
		if absf(wrapf(a - PI, -PI, PI)) < 0.35:
			continue
		var post := MeshInstance3D.new()
		var box := BoxMesh.new()
		var tall := 2.4 if i % 2 == 0 else 1.5
		box.size = Vector3(0.8, tall, 0.8)
		box.material = stone
		post.mesh = box
		post.position = surface(p.x, p.y) + Vector3(0, tall * 0.5 - 0.1, 0)
		post.rotation.y = -a
		add_child(post)
		Toon.apply(post, 0.03)
		_add_box(post.position, box.size, -a)
		if i % 5 == 0:
			_banner(surface(p.x, p.y) + Vector3(0, tall, 0))


func _banner(base: Vector3) -> void:
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.05
	pm.bottom_radius = 0.05
	pm.height = 2.6
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.4, 0.26, 0.15)
	pm.material = wood
	pole.mesh = pm
	pole.position = base + Vector3(0, 1.3, 0)
	add_child(pole)
	var flag := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.05, 1.0, 0.7)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.75, 0.15, 0.18)
	red.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	fm.material = red
	flag.mesh = fm
	flag.position = base + Vector3(0, 2.1, 0.38)
	add_child(flag)


## Bosque Susurrante: árboles muy juntos y más oscuros, con un claro en medio.
func _build_forest() -> void:
	var placed: Array[Vector2] = []
	var tries := 0
	while placed.size() < 170 and tries < 6000:
		tries += 1
		var p := FOREST + Vector2(_rng.randfn(0, FOREST_RADIUS * 0.5), _rng.randfn(0, FOREST_RADIUS * 0.5))
		var d := p.distance_to(FOREST)
		if d > FOREST_RADIUS or d < 9.0:
			continue
		var h := height(p.x, p.y)
		if h < 2.2 or absf(p.y - river_z(p.x)) < 12.0 or road_distance(p.x, p.y) < 6.0:
			continue
		var ok := true
		for q in placed:
			if q.distance_to(p) < 4.6:
				ok = false
				break
		if not ok:
			continue
		for q in _trees:
			if q.distance_to(p) < 4.6:
				ok = false
				break
		if not ok:
			continue
		placed.append(p)
		_trees.append(p)
		var kind := "tree_single_B" if _rng.randf() < 0.65 else "tree_single_A"
		var f := _rng.randf_range(7.5, 11.0)
		var holder := _place(NATURE + kind + ".gltf", surface(p.x, p.y) - Vector3(0, 0.2, 0), f, 0.025, Color(0.55, 0.78, 0.5))
		holder.rotation.y = _rng.randf() * TAU
		_add_cylinder(surface(p.x, p.y) + Vector3(0, 2, 0), 0.6, 4.0)
		_fade_near_camera(holder)
	# Hongos brillantes en el suelo del bosque.
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.6, 0.9, 1.0)
	glow.emission_enabled = true
	glow.emission = Color(0.4, 0.8, 1.0)
	glow.emission_energy_multiplier = 1.5
	var cap := SphereMesh.new()
	cap.radius = 0.18
	cap.height = 0.2
	cap.material = glow
	for i in 60:
		var p := FOREST + Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * FOREST_RADIUS * 0.8
		var m := MeshInstance3D.new()
		m.mesh = cap
		m.position = surface(p.x, p.y) + Vector3(0, 0.08, 0)
		add_child(m)


## Entrada de la mazmorra: un arco de piedra con antorchas en la ladera.
func _build_gate() -> void:
	var c := surface(DUNGEON_GATE.x, DUNGEON_GATE.y)
	var arch := _place("res://assets/kaykit/dungeon/wall_arched.glb", c, 1.4, 0.02)
	arch.rotation.y = PI / 2.0
	for side in [-1.0, 1.0]:
		var pos := c + Vector3(0, 0, side * 3.6)
		var pillar := _place("res://assets/kaykit/dungeon/pillar_decorated.glb", pos, 1.4, 0.02)
		pillar.rotation.y = PI / 2.0
		_add_box(pos + Vector3(0, 2.8, 0), Vector3(2.4, 5.6, 2.4))
		var torch := _place("res://assets/kaykit/dungeon/torch_mounted.glb", pos + Vector3(-1.3, 3.2, 0), 1.2, 0.0)
		torch.rotation.y = -PI / 2.0
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.6, 0.25)
		light.light_energy = 1.6
		light.omni_range = 6.0
		light.position = pos + Vector3(-1.6, 3.8, 0)
		add_child(light)
	# Fondo oscuro dentro del arco, como si fuera la boca de una cueva.
	var dark := MeshInstance3D.new()
	var quad := BoxMesh.new()
	quad.size = Vector3(0.2, 4.6, 4.2)
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.02, 0.02, 0.04)
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = black
	dark.mesh = quad
	dark.position = c + Vector3(0.4, 2.3, 0)
	add_child(dark)


## Letreros con el nombre de cada edificio importante.
func _build_signs() -> void:
	var v := Vector3(VILLAGE.x, VILLAGE_HEIGHT, VILLAGE.y)
	for sign in [["GREMIO DE AVENTUREROS", Vector3(13, 0, 4)], ["POSADA · LA JARRA DORADA", Vector3(-12, 0, -2)],
			["HERRERÍA", Vector3(14, 0, -12)], ["TIENDA", Vector3(-13, 0, -16)]]:
		var p: Vector3 = v + sign[1]
		var label := Label3D.new()
		label.text = sign[0]
		label.font_size = 96
		label.outline_size = 22
		label.pixel_size = 0.012
		label.modulate = Color(1.0, 0.86, 0.45)
		label.outline_modulate = Color(0.1, 0.06, 0.04)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(p.x, height(p.x, p.z) + 9.0, p.z)
		add_child(label)
	var guild := v + Vector3(13, 0, 4)
	for side in [-1.0, 1.0]:
		var fp := guild + Vector3(-4.5, 0, side * 3.5)
		fp.y = height(fp.x, fp.z)
		_place(BUILD + "flag_blue.gltf", fp, 6.0, 0.02)


func _build_clouds() -> void:
	for i in 12:
		var angle := _rng.randf() * TAU
		var dist := _rng.randf_range(60.0, 260.0)
		var pos := Vector3(cos(angle) * dist, _rng.randf_range(75.0, 110.0), sin(angle) * dist)
		var cloud := _place(NATURE + ("cloud_big.gltf" if i % 3 else "cloud_small.gltf"), pos, _rng.randf_range(9.0, 16.0), 0.0)
		cloud.rotation.y = _rng.randf() * TAU
		cloud.add_to_group("clouds")


# --- Utilidades -----------------------------------------------------------

func _place(path: String, pos: Vector3, factor: float, outline: float, tint := Color.WHITE) -> Node3D:
	var holder := Node3D.new()
	holder.position = pos
	var model: Node3D = (load(path) as PackedScene).instantiate()
	model.scale = Vector3.ONE * factor
	holder.add_child(model)
	Toon.apply(model, outline / factor if outline > 0.0 else 0.0, tint)
	add_child(holder)
	return holder


func _add_box(center: Vector3, size: Vector3, yaw := 0.0) -> void:
	var body := StaticBody3D.new()
	body.position = center
	body.rotation.y = yaw
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	body.add_child(col)
	add_child(body)


## Los árboles se vuelven transparentes cuando la cámara se acerca mucho,
## para que las hojas no tapen al héroe.
func _fade_near_camera(holder: Node3D) -> void:
	for mi in holder.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_surface_override_material(i) as StandardMaterial3D
			if mat == null:
				continue
			mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
			mat.distance_fade_min_distance = 3.0
			mat.distance_fade_max_distance = 8.0
			if mat.next_pass:
				var outline := (mat.next_pass as StandardMaterial3D).duplicate() as StandardMaterial3D
				outline.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
				outline.distance_fade_min_distance = 3.0
				outline.distance_fade_max_distance = 8.0
				mat.next_pass = outline


func _add_cylinder(center: Vector3, radius: float, h: float) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = h
	col.shape = cyl
	body.add_child(col)
	add_child(body)


# --- Vida del pueblo: farolas, vallas, cajas, tablón y luciérnagas -------

func _build_village_life() -> void:
	var v := Vector3(VILLAGE.x, 0, VILLAGE.y)
	# Farolas a lo largo del camino y la plaza; se encienden de noche.
	var lamp_spots := [Vector2(-3, 8), Vector2(5, -2), Vector2(-4, -12), Vector2(5, -20), Vector2(-3, 20),
		Vector2(3, 32), Vector2(-2, 46), Vector2(6, -32)]
	for p in lamp_spots:
		_add_lamp(VILLAGE + p)
	for p in [Vector2(-2, -64), Vector2(2, -46), Vector2(-6, -24), Vector2(6, -8)]:
		_add_lamp(p)
	# Vallas de madera en las afueras del pueblo.
	for side in [-1.0, 1.0]:
		for i in 12:
			var p := VILLAGE + Vector2(side * 26.0, -21.0 + i * 3.6)
			_fence(surface(p.x, p.y), 0.0)
	for i in 5:
		for side in [-1.0, 1.0]:
			var p := VILLAGE + Vector2(side * (8.0 + i * 3.6), 26.0)
			_fence(surface(p.x, p.y), PI / 2.0)
	# Mercadillo: cajas, sacos y barriles junto al mercader y la herrería.
	var props := [["barrel", Vector2(-9, -19)], ["barrel", Vector2(-10, -20)], ["crate_A_big", Vector2(-6, -19)],
		["sack", Vector2(-5, -17)], ["crate_A_big", Vector2(11, -15)], ["barrel", Vector2(11, -9)],
		["sack", Vector2(-9, 1)], ["barrel", Vector2(-8, 5)], ["crate_A_big", Vector2(16, 8)], ["sack", Vector2(17, 9)],
		["flag_blue", Vector2(17, 1)], ["flag_blue", Vector2(-17, -8)]]
	for prop in props:
		var p: Vector2 = VILLAGE + prop[1]
		_place(BUILD + prop[0] + ".gltf", surface(p.x, p.y), 4.0 if prop[0] != "flag_blue" else 5.0, 0.02).rotation.y = _rng.randf() * TAU
	# Flores de colores en la pradera del pueblo.
	_build_flowers()
	# Tablón del gremio junto a Mira.
	_build_board(VILLAGE + Vector2(10.5, 9.5))
	# Luciérnagas de noche en el bosque, en el río y en el pueblo.
	for p in [FOREST, FOREST + Vector2(25, 20), FOREST + Vector2(-20, -25), Vector2(10, -64), VILLAGE + Vector2(0, 20)]:
		_add_fireflies(surface(p.x, p.y))


## Tramo de valla de 3,6 m centrado en `pos` (el modelo trae el centro desplazado).
func _fence(pos: Vector3, yaw: float) -> void:
	var holder := _place(BUILD + "fence_wood_straight.gltf", pos, 3.1, 0.02)
	holder.get_child(0).position.x = 1.05 * 3.1
	holder.rotation.y = yaw


func _add_lamp(p: Vector2) -> void:
	var base := surface(p.x, p.y)
	if base.y < WATER_LEVEL:
		return
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.25, 0.18, 0.12)
	var post := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.12
	cyl.height = 3.2
	cyl.material = wood
	post.mesh = cyl
	post.position = base + Vector3(0, 1.6, 0)
	add_child(post)
	var arm := MeshInstance3D.new()
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.7, 0.08, 0.08)
	arm_mesh.material = wood
	arm.mesh = arm_mesh
	arm.position = base + Vector3(0.3, 3.1, 0)
	add_child(arm)
	var glass := MeshInstance3D.new()
	var lantern := BoxMesh.new()
	lantern.size = Vector3(0.32, 0.42, 0.32)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.45)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.72, 0.35)
	mat.emission_energy_multiplier = 0.3
	lantern.material = mat
	glass.mesh = lantern
	glass.position = base + Vector3(0.6, 2.82, 0)
	add_child(glass)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.45)
	light.light_energy = 2.2
	light.omni_range = 9.0
	light.position = glass.position
	light.visible = false
	add_child(light)
	_add_cylinder(base + Vector3(0, 1.6, 0), 0.15, 3.2)
	_lamps.append({"light": light, "mat": mat})


func _build_flowers() -> void:
	var colors := [Color(0.95, 0.35, 0.45), Color(1.0, 0.85, 0.3), Color(0.7, 0.5, 1.0), Color(1.0, 1.0, 1.0)]
	for c in colors:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var quad := SphereMesh.new()
		quad.radius = 0.12
		quad.height = 0.18
		quad.radial_segments = 6
		quad.rings = 3
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		mat.emission_enabled = true
		mat.emission = c
		mat.emission_energy_multiplier = 0.15
		quad.material = mat
		mm.mesh = quad
		var spots: Array = []
		var tries := 0
		while spots.size() < 260 and tries < 3000:
			tries += 1
			var p := Vector2(_rng.randf_range(-90, 90), _rng.randf_range(-150, 30))
			var h := height(p.x, p.y)
			if h < WATER_LEVEL + 0.3 or h > 16.0 or road_distance(p.x, p.y) < 3.0 or p.distance_to(VILLAGE) < 20.0 or p.distance_to(FOREST) < FOREST_RADIUS:
				continue
			spots.append(Vector3(p.x, h + 0.12, p.y))
		mm.instance_count = spots.size()
		for i in spots.size():
			mm.set_instance_transform(i, Transform3D(Basis(), spots[i]))
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(inst)


## Tablón de madera con papeles clavados (el de los encargos del gremio).
func _build_board(p: Vector2) -> void:
	var base := surface(p.x, p.y)
	var holder := Node3D.new()
	holder.position = base
	holder.rotation.y = -PI / 2.0
	add_child(holder)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.27, 0.15)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.26, 0.16, 0.08)
	for x in [-1.3, 1.3]:
		var leg := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.18, 2.6, 0.18)
		lm.material = dark
		leg.mesh = lm
		leg.position = Vector3(x, 1.3, 0)
		holder.add_child(leg)
	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.6, 1.5, 0.12)
	bm.material = wood
	board.mesh = bm
	board.position = Vector3(0, 1.75, 0)
	holder.add_child(board)
	var roof := MeshInstance3D.new()
	var rm := PrismMesh.new()
	rm.size = Vector3(3.0, 0.45, 0.6)
	rm.material = dark
	roof.mesh = rm
	roof.position = Vector3(0, 2.75, 0)
	holder.add_child(roof)
	var paper_mat := StandardMaterial3D.new()
	paper_mat.albedo_color = Color(0.95, 0.88, 0.7)
	var pin_mat := StandardMaterial3D.new()
	pin_mat.albedo_color = Color(0.85, 0.15, 0.12)
	var spots := [Vector2(-0.85, 2.05), Vector2(-0.1, 2.1), Vector2(0.75, 2.0), Vector2(-0.6, 1.4), Vector2(0.3, 1.45), Vector2(0.95, 1.4)]
	for sp in spots:
		var paper := MeshInstance3D.new()
		var pm := QuadMesh.new()
		pm.size = Vector2(0.55, 0.5)
		pm.material = paper_mat
		paper.mesh = pm
		paper.position = Vector3(sp.x, sp.y, 0.07)
		paper.rotation.z = _rng.randf_range(-0.15, 0.15)
		holder.add_child(paper)
		var pin := MeshInstance3D.new()
		var pinm := SphereMesh.new()
		pinm.radius = 0.04
		pinm.height = 0.08
		pinm.material = pin_mat
		pin.mesh = pinm
		pin.position = Vector3(sp.x, sp.y + 0.2, 0.09)
		holder.add_child(pin)
	var label := Label3D.new()
	label.text = "ENCARGOS"
	label.font_size = 48
	label.outline_size = 10
	label.pixel_size = 0.006
	label.modulate = Color(1.0, 0.9, 0.6)
	label.position = Vector3(0, 3.1, 0.1)
	holder.add_child(label)
	_add_box(base + Vector3(0, 1.3, 0), Vector3(0.4, 2.6, 2.8))


func _add_fireflies(at: Vector3) -> void:
	var f := GPUParticles3D.new()
	f.amount = 60
	f.lifetime = 4.0
	f.emitting = false
	f.visibility_aabb = AABB(Vector3(-20, -2, -20), Vector3(40, 8, 40))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(16, 1.5, 16)
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 2.0
	f.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	var qm := StandardMaterial3D.new()
	qm.albedo_color = Color(0.85, 1.0, 0.4)
	qm.emission_enabled = true
	qm.emission = Color(0.8, 1.0, 0.35)
	qm.emission_energy_multiplier = 4.0
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = qm
	f.draw_pass_1 = quad
	f.position = at + Vector3(0, 1.5, 0)
	add_child(f)
	_fireflies.append(f)
