extends Node3D
## Caballo: se monta con F y corre mucho más que el héroe a pie. Está hecho
## de piezas simples y mueve las patas según la velocidad.

const SADDLE_HEIGHT := 1.25

var ridden := false
var _legs: Array[Node3D] = []
var _head: Node3D
var _tail: Node3D
var _phase := 0.0
var _speed := 0.0
var _body: StaticBody3D


func _ready() -> void:
	add_to_group("horses")
	var coat := _mat(Color(0.52, 0.33, 0.2))
	var mane := _mat(Color(0.18, 0.12, 0.08))
	var saddle := _mat(Color(0.7, 0.15, 0.12))
	var white := _mat(Color(0.95, 0.92, 0.88))
	_box(self, Vector3(0, 1.25, 0), Vector3(0.75, 0.75, 1.9), coat)
	_box(self, Vector3(0, 1.66, -0.05), Vector3(0.8, 0.1, 0.8), saddle)
	_box(self, Vector3(0, 1.45, 0.25), Vector3(0.82, 0.5, 0.12), saddle)
	var neck := Node3D.new()
	neck.position = Vector3(0, 1.45, 0.85)
	neck.rotation.x = -0.7
	add_child(neck)
	_box(neck, Vector3(0, 0.0, 0.35), Vector3(0.42, 0.5, 0.8), coat)
	_box(neck, Vector3(0, 0.27, 0.3), Vector3(0.12, 0.12, 0.8), mane)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.05, 0.75)
	neck.add_child(_head)
	_head.rotation.x = 1.1
	_box(_head, Vector3(0, 0.0, 0.25), Vector3(0.36, 0.36, 0.7), coat)
	_box(_head, Vector3(0, -0.02, 0.58), Vector3(0.3, 0.3, 0.12), white)
	for x in [-0.12, 0.12]:
		_box(_head, Vector3(x, 0.24, 0.0), Vector3(0.08, 0.2, 0.08), coat)
		_box(_head, Vector3(x * 1.6, 0.06, 0.3), Vector3(0.04, 0.06, 0.06), mane)
	_tail = Node3D.new()
	_tail.position = Vector3(0, 1.45, -0.95)
	add_child(_tail)
	_box(_tail, Vector3(0, -0.35, -0.12), Vector3(0.16, 0.8, 0.16), mane)
	_tail.rotation.x = 0.4
	for p in [Vector3(-0.25, 0.95, 0.7), Vector3(0.25, 0.95, 0.7), Vector3(-0.25, 0.95, -0.7), Vector3(0.25, 0.95, -0.7)]:
		var leg := Node3D.new()
		leg.position = p
		add_child(leg)
		_box(leg, Vector3(0, -0.45, 0), Vector3(0.18, 0.9, 0.18), coat)
		_box(leg, Vector3(0, -0.88, 0.02), Vector3(0.2, 0.12, 0.22), mane)
		_legs.append(leg)
	var label := Label3D.new()
	label.text = "Caballo"
	label.font_size = 36
	label.outline_size = 8
	label.pixel_size = 0.005
	label.modulate = Color(1.0, 0.92, 0.6)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 2.4
	label.name = "Label"
	add_child(label)
	_body = StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.8, 1.6, 2.0)
	col.shape = shape
	col.position.y = 0.8
	_body.add_child(col)
	add_child(_body)


func set_ridden(on: bool) -> void:
	ridden = on
	get_node("Label").visible = not on
	_body.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT


## Mueve las patas: paso, trote o galope según la velocidad.
func animate(speed: float, delta: float) -> void:
	_speed = speed


func _process(delta: float) -> void:
	if not ridden:
		_speed = move_toward(_speed, 0.0, delta * 10.0)
		_head.rotation.x = 1.1 + sin(Time.get_ticks_msec() * 0.0015) * 0.08
	var rate := clampf(_speed * 0.9, 0.0, 14.0)
	_phase += delta * rate
	var amp := clampf(_speed / 8.0, 0.0, 0.7)
	for i in _legs.size():
		var offset := 0.0 if i == 0 or i == 3 else PI
		_legs[i].rotation.x = sin(_phase + offset) * amp
	_tail.rotation.x = 0.4 + amp * 0.6 + sin(_phase * 0.5) * 0.1
	position.y += 0.0


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	return m


func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	parent.add_child(mi)
