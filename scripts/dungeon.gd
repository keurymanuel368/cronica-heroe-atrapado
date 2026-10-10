extends Node3D
## La mazmorra del Rey Esqueleto: se construye bajo el mapa a partir de un
## plano de texto. Cada carácter es una casilla de 4 x 4 metros.
##   #  roca      .  suelo     S  entrada (y salida)
##   e  esqueleto   r  pícaro   m  mago   w  guerrero   B  jefe
##   P  pilar       C  cofre    T  suelo con antorcha cercana

const Toon := preload("res://scripts/toon.gd")
const ENEMY := preload("res://scripts/enemy.gd")
const PIECES := "res://assets/kaykit/dungeon/"
const CELL := 4.0
const ORIGIN := Vector3(0, -220, 0)

const MAP := [
	"#############",
	"#####C.C#####",
	"###.......###",
	"##....B....##",
	"##..P...P..##",
	"##.........##",
	"##..P...P..##",
	"###.......###",
	"######.######",
	"######.######",
	"###..w.m..###",
	"##.e.....e.##",
	"##..P...P..##",
	"##.r.....r.##",
	"###.......###",
	"######.######",
	"######.######",
	"######S######",
	"#############",
]

var start := Vector3.ZERO
var boss: Node3D
var _chest_spots: Array[Vector3] = []
var _wall_count := 0


func build() -> void:
	var rows := MAP.size()
	var cols: int = MAP[0].length()
	var floor_slab := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(cols * CELL, 1.0, rows * CELL)
	shape.shape = box
	floor_slab.add_child(shape)
	floor_slab.position = ORIGIN + Vector3(cols * CELL * 0.5 - CELL * 0.5, -0.5, rows * CELL * 0.5 - CELL * 0.5)
	add_child(floor_slab)

	for z in rows:
		for x in cols:
			var ch: String = MAP[z][x]
			if ch == "#":
				continue
			var center := _cell(x, z)
			_piece("floor_tile_large", center, 0.0, false)
			for dir in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				if _is_rock(x + dir.x, z + dir.y):
					_wall(center, dir)
			match ch:
				"S":
					start = center
				"P":
					_piece("pillar_decorated", center, 0.0, true)
					_box(center + Vector3(0, 2, 0), Vector3(2.2, 4, 1.7))
				"C":
					_chest_spots.append(center)
				"e", "r", "m", "w":
					_enemy({"e": "minion", "r": "rogue", "m": "mage", "w": "warrior"}[ch], center)
				"B":
					boss = _enemy("boss", center)
	for spot in _chest_spots:
		var chest := _piece("chest_gold", spot, PI, true)
		chest.name = "Cofre"


func _cell(x: int, z: int) -> Vector3:
	return ORIGIN + Vector3(x * CELL, 0, z * CELL)


func _is_rock(x: int, z: int) -> bool:
	if z < 0 or z >= MAP.size() or x < 0 or x >= MAP[0].length():
		return true
	return MAP[z][x] == "#"


func _wall(center: Vector3, dir: Vector2i) -> void:
	var pos := center + Vector3(dir.x, 0, dir.y) * (CELL * 0.5)
	var yaw := 0.0 if dir.x == 0 else PI / 2.0
	_wall_count += 1
	_piece("wall_cracked" if _wall_count % 7 == 0 else "wall", pos, yaw, true)
	_box(pos + Vector3(0, 2, 0), Vector3(CELL, 4, 1) if dir.x == 0 else Vector3(1, 4, CELL))
	# Una antorcha cada tres paredes, mirando hacia dentro.
	if _wall_count % 3 == 0:
		var inward := -Vector3(dir.x, 0, dir.y)
		var torch := _piece("torch_mounted", pos + inward * 0.5 + Vector3(0, 2.4, 0), atan2(inward.x, inward.z), false)
		torch.scale = Vector3.ONE * 1.2
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.58, 0.25)
		light.light_energy = 1.3
		light.omni_range = 8.0
		light.position = pos + inward * 1.2 + Vector3(0, 2.9, 0)
		add_child(light)


func _piece(name_: String, pos: Vector3, yaw: float, outline: bool) -> Node3D:
	var model: Node3D = (load(PIECES + name_ + ".glb") as PackedScene).instantiate()
	model.position = pos
	model.rotation.y = yaw
	add_child(model)
	Toon.apply(model, 0.015 if outline else 0.0)
	return model


func _box(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var col := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	col.shape = b
	body.add_child(col)
	add_child(body)


func _enemy(kind: String, at: Vector3) -> Node3D:
	var e := CharacterBody3D.new()
	e.set_script(ENEMY)
	e.kind = kind
	e.home = at
	e.position = at + Vector3(0, 0.5, 0)
	get_parent().add_child.call_deferred(e)
	return e
