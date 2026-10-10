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

## El camino de tierra: del despertar, cruza el río por el puente, atraviesa
## el pueblo y sube hasta la puerta del castillo.
const ROAD := [Vector2(0, 10), Vector2(4, -10), Vector2(-4, -32), Vector2(-2, -50),
	Vector2(0, -64), Vector2(2, -80), Vector2(4, -98), Vector2(10, -120),
	Vector2(18, -145), Vector2(25, -170), Vector2(29, -192)]

var _noise := FastNoiseLite.new()
var _ridge := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _awakening_height := 0.0


func _init() -> void:
	_noise.seed = 7
	_noise.frequency = 0.006
	_noise.fractal_octaves = 4
	_ridge.seed = 11
	_ridge.frequency = 0.012
	_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_rng.seed = 20261009
	_awakening_height = _raw_height(AWAKENING.x, AWAKENING.y)


func build() -> void:
	_build_terrain()
	_build_water()
	_build_grass()
	_build_trees()
	_build_rocks()
	_build_castle()
	_build_village()
	_build_clouds()


# --- Forma del terreno ----------------------------------------------------

func river_z(x: float) -> float:
	return -70.0 + 15.0 * sin(x * 0.015) + 6.0 * sin(x * 0.041 + 1.3)


func height(x: float, z: float) -> float:
	var h := _raw_height(x, z)
	h = _flatten(h, x, z, AWAKENING, _awakening_height, 7.0, 14.0)
	h = _flatten(h, x, z, CASTLE, CASTLE_HEIGHT, 30.0, 46.0)
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
	var target := 150000
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
	var holder := _place(NATURE + kind + ".gltf", surface(p.x, p.y) - Vector3(0, 0.2, 0), _rng.randf_range(6.5, 9.0), 0.025, TREE_TINT)
	holder.rotation.y = _rng.randf() * TAU
	_add_cylinder(surface(p.x, p.y) + Vector3(0, 2, 0), 0.6, 4.0)


func _build_rocks() -> void:
	var placed := 0
	while placed < 28:
		var p := Vector2(_rng.randf_range(-140, 140), _rng.randf_range(-170, 60))
		var h := height(p.x, p.y)
		if h < 1.0 or road_distance(p.x, p.y) < 4.0 or p.distance_to(AWAKENING) < 12.0:
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

func _build_castle() -> void:
	var c := Vector3(CASTLE.x, CASTLE_HEIGHT, CASTLE.y)
	_place(BUILD + "building_castle_blue.gltf", c, 11.0, 0.02).rotation.y = PI
	_add_box(c + Vector3(0, 8, 0), Vector3(16, 16, 16))
	# Muralla en anillo con torres.
	var radius := 26.0
	var segments := 16
	for i in segments:
		var a := TAU * i / segments
		var pos := c + Vector3(cos(a) * radius, 0, sin(a) * radius)
		var gate := i == 4
		var wall := _place(BUILD + ("wall_straight_gate.gltf" if gate else "wall_straight.gltf"), pos, 6.0, 0.02)
		wall.rotation.y = -a + PI / 2.0
		if i % 4 == 2:
			_place(BUILD + "building_tower_A_blue.gltf", pos, 7.0, 0.02)
		if not gate:
			_add_box(pos + Vector3(0, 3, 0), Vector3(10.5, 6, 2.5), -a + PI / 2.0)
	for p in [Vector3(-12, 0, -8), Vector3(12, 0, -10), Vector3(-14, 0, 10), Vector3(14, 0, 9)]:
		_place(BUILD + "building_home_A_blue.gltf", c + p, 6.0, 0.02).rotation.y = _rng.randf() * TAU
	_place(BUILD + "flag_blue.gltf", c + Vector3(0, 0, 22), 6.0, 0.02)


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

	# Puente sobre el río, en el cruce del camino.
	var bridge := _place(BUILD + "building_bridge_A.gltf", Vector3(BRIDGE.x, WATER_LEVEL + 0.2, BRIDGE.y), 9.0, 0.02)
	bridge.rotation.y = PI / 2.0
	_add_box(Vector3(BRIDGE.x, WATER_LEVEL + 1.0, BRIDGE.y), Vector3(5, 0.6, 22))


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
