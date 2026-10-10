extends Node3D
## Caballo: se monta con F y corre mucho más que el héroe a pie. Está hecho
## de formas redondeadas (cápsulas y esferas) con patas de dos tramos que
## se doblan al trotar y al galopar.

## Altura del lomo, donde se sienta el jinete.
const SADDLE_HEIGHT := 1.82
const BODY_Y := 1.42

var ridden := false
var coat_color := Color(0.55, 0.34, 0.19)
var _legs: Array = []
var _neck: Node3D
var _head: Node3D
var _tail: Node3D
var _torso: Node3D
var _phase := 0.0
var _speed := 0.0
var _body: StaticBody3D
var _coat: StandardMaterial3D
var _dark: StandardMaterial3D


func _ready() -> void:
	add_to_group("horses")
	_coat = _mat(coat_color)
	_dark = _mat(Color(0.14, 0.09, 0.06))
	var light := _mat(coat_color.lightened(0.35))
	var leather := _mat(Color(0.42, 0.22, 0.1))
	var red := _mat(Color(0.72, 0.13, 0.12))
	var gold := _mat(Color(0.95, 0.78, 0.3))

	_torso = Node3D.new()
	_torso.position = Vector3(0, BODY_Y, 0)
	add_child(_torso)
	# Cuerpo: un barril con pecho y grupa redondos.
	_capsule(_torso, Vector3.ZERO, Vector3(PI / 2, 0, 0), 0.33, 1.8, _coat)
	_sphere(_torso, Vector3(0, 0.04, 0.6), 0.37, _coat, Vector3(0.95, 1.08, 1.0))
	_sphere(_torso, Vector3(0, 0.06, -0.62), 0.38, _coat, Vector3(1.0, 1.0, 1.05))
	_sphere(_torso, Vector3(0, -0.16, 0.05), 0.29, light, Vector3(1.0, 0.7, 2.2))
	# Silla de montar, manta y estribos.
	_box(_torso, Vector3(0, 0.3, 0.0), Vector3(0.78, 0.05, 0.85), red)
	_box(_torso, Vector3(0, 0.36, -0.02), Vector3(0.52, 0.1, 0.6), leather)
	_box(_torso, Vector3(0, 0.45, 0.26), Vector3(0.3, 0.14, 0.1), leather)
	_box(_torso, Vector3(0, 0.43, -0.3), Vector3(0.48, 0.12, 0.08), leather)
	for x in [-0.47, 0.47]:
		_box(_torso, Vector3(x * 0.85, 0.0, 0.0), Vector3(0.03, 0.6, 0.05), leather)
		_box(_torso, Vector3(x * 0.85, -0.32, 0.0), Vector3(0.1, 0.04, 0.16), gold)

	# Cuello y cabeza.
	_neck = Node3D.new()
	_neck.position = Vector3(0, 0.2, 0.8)
	_neck.rotation.x = -0.75
	_torso.add_child(_neck)
	_capsule(_neck, Vector3(0, 0, 0.36), Vector3(PI / 2, 0, 0), 0.2, 0.95, _coat)
	_sphere(_neck, Vector3(0, -0.02, 0.0), 0.27, _coat, Vector3(0.9, 1.0, 1.0))
	for i in 6:
		_box(_neck, Vector3(0, 0.2, 0.05 + i * 0.13), Vector3(0.08, 0.14 + (i % 2) * 0.05, 0.15), _dark)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.0, 0.78)
	_head.rotation.x = 1.25
	_neck.add_child(_head)
	_capsule(_head, Vector3(0, 0, 0.22), Vector3(PI / 2, 0, 0), 0.19, 0.62, _coat)
	_sphere(_head, Vector3(0, -0.02, 0.5), 0.17, light, Vector3(1.05, 0.95, 1.1))
	_sphere(_head, Vector3(0.08, 0.0, 0.62), 0.03, _dark)
	_sphere(_head, Vector3(-0.08, 0.0, 0.62), 0.03, _dark)
	for x in [-0.15, 0.15]:
		_sphere(_head, Vector3(x, 0.08, 0.12), 0.05, _dark)
		var ear := _capsule(_head, Vector3(x * 0.7, 0.22, -0.02), Vector3(-0.3, 0, x * 1.2), 0.045, 0.22, _coat)
		ear.scale = Vector3(1, 1, 0.6)
	_box(_head, Vector3(0, 0.2, 0.06), Vector3(0.08, 0.1, 0.18), _dark)
	# Bridas.
	_box(_head, Vector3(0, -0.02, 0.35), Vector3(0.4, 0.04, 0.04), leather)
	_box(_head, Vector3(0, 0.06, 0.2), Vector3(0.39, 0.03, 0.03), leather)

	# Cola.
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.22, -0.95)
	_tail.rotation.x = 0.5
	_torso.add_child(_tail)
	_capsule(_tail, Vector3(0, -0.35, -0.05), Vector3(0.15, 0, 0), 0.1, 0.8, _dark)
	_capsule(_tail, Vector3(0, -0.6, -0.12), Vector3(0.3, 0, 0), 0.12, 0.5, _dark)

	# Patas: muslo, caña y casco; el pie va unido a la rodilla.
	for p in [Vector3(-0.17, -0.12, 0.6), Vector3(0.17, -0.12, 0.6), Vector3(-0.17, -0.12, -0.62), Vector3(0.17, -0.12, -0.62)]:
		var hip := Node3D.new()
		hip.position = p
		_torso.add_child(hip)
		_capsule(hip, Vector3(0, -0.28, 0), Vector3.ZERO, 0.12, 0.7, _coat)
		var knee := Node3D.new()
		knee.position = Vector3(0, -0.6, 0)
		hip.add_child(knee)
		_capsule(knee, Vector3(0, -0.3, 0), Vector3.ZERO, 0.065, 0.62, _coat)
		_capsule(knee, Vector3(0, -0.58, 0.01), Vector3.ZERO, 0.08, 0.16, light)
		_cylinder(knee, Vector3(0, -0.7, 0.02), 0.085, 0.1, 0.1, _dark)
		_legs.append({"hip": hip, "knee": knee, "front": p.z > 0.0})

	var label := Label3D.new()
	label.text = "Caballo  (F montar)"
	label.font_size = 34
	label.outline_size = 8
	label.pixel_size = 0.005
	label.modulate = Color(1.0, 0.92, 0.6)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 2.7
	label.name = "Label"
	add_child(label)
	_body = StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.8, 1.6, 2.2)
	col.shape = shape
	col.position.y = 0.8
	_body.add_child(col)
	add_child(_body)


func set_ridden(on: bool) -> void:
	ridden = on
	get_node("Label").visible = not on
	_body.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT


func animate(speed: float, _delta: float) -> void:
	_speed = speed


## Paso, trote o galope según la velocidad: las patas avanzan en diagonal y
## doblan la rodilla al levantarse; el cuerpo sube y baja.
func _process(delta: float) -> void:
	if not ridden:
		_speed = move_toward(_speed, 0.0, delta * 10.0)
	var gallop := _speed > 12.0
	var rate := clampf(_speed * 0.75, 0.0, 15.0)
	_phase += delta * rate
	var amp := clampf(_speed / 10.0, 0.0, 0.75)
	for i in _legs.size():
		var leg: Dictionary = _legs[i]
		var offset := 0.0
		if gallop:
			offset = [0.0, 0.4, PI, PI + 0.4][i]
		else:
			offset = 0.0 if i == 0 or i == 3 else PI
		var s := sin(_phase + offset)
		leg.hip.rotation.x = s * amp
		var lift := maxf(0.0, cos(_phase + offset)) * amp * 1.6
		leg.knee.rotation.x = lift if leg.front else lift * 0.6
	var bob := absf(sin(_phase)) * amp * (0.09 if gallop else 0.05)
	_torso.position.y = BODY_Y + bob
	_torso.rotation.x = sin(_phase * (1.0 if gallop else 2.0)) * amp * (0.06 if gallop else 0.02)
	var idle := sin(Time.get_ticks_msec() * 0.0012) * 0.06 if _speed < 0.5 else 0.0
	_neck.rotation.x = -0.75 + sin(_phase) * amp * 0.12 + idle
	_tail.rotation.x = 0.5 + amp * 0.7 + sin(_phase * 0.7) * 0.12


# --- Piezas ------------------------------------------------------------------

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.roughness = 0.8
	return m


func _add(parent: Node3D, mesh: Mesh, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _capsule(parent: Node3D, pos: Vector3, rot: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(height, radius * 2.0)
	m.radial_segments = 16
	m.rings = 6
	m.material = mat
	return _add(parent, m, pos, rot)


func _sphere(parent: Node3D, pos: Vector3, radius: float, mat: Material, stretch := Vector3.ONE) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 16
	m.rings = 8
	m.material = mat
	var mi := _add(parent, m, pos)
	mi.scale = stretch
	return mi


func _cylinder(parent: Node3D, pos: Vector3, top: float, bottom: float, height: float, mat: Material) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.material = mat
	return _add(parent, m, pos)


func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	m.material = mat
	return _add(parent, m, pos)
