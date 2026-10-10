extends Node3D
## Objeto que se recoge al pasar por encima (hierbas, hongos). Vuelve a
## crecer al cabo de un rato.

const Fx := preload("res://scripts/fx.gd")
const Rpg := preload("res://scripts/rpg.gd")

var item := "hierba"
var regrow := 75.0
var _timer := 0.0
var _visual: Node3D


func _ready() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var color := Color(0.4, 1.0, 0.45) if item == "hierba" else Color(0.55, 0.85, 1.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.2
	if item == "hierba":
		for i in 3:
			var leaf := MeshInstance3D.new()
			var m := PrismMesh.new()
			m.size = Vector3(0.18, 0.55, 0.05)
			m.material = mat
			leaf.mesh = m
			leaf.position = Vector3(0, 0.27, 0)
			leaf.rotation = Vector3(0.35, i * TAU / 3.0, 0)
			_visual.add_child(leaf)
	else:
		var stem := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.06
		sm.bottom_radius = 0.08
		sm.height = 0.35
		var white := StandardMaterial3D.new()
		white.albedo_color = Color(0.9, 0.92, 1.0)
		sm.material = white
		stem.mesh = sm
		stem.position.y = 0.17
		_visual.add_child(stem)
		var cap := MeshInstance3D.new()
		var cm := SphereMesh.new()
		cm.radius = 0.25
		cm.height = 0.25
		cm.material = mat
		cap.mesh = cm
		cap.position.y = 0.38
		_visual.add_child(cap)
	var sparkle := OmniLight3D.new()
	sparkle.light_color = color
	sparkle.light_energy = 0.6
	sparkle.omni_range = 2.0
	sparkle.position.y = 0.5
	_visual.add_child(sparkle)


func _process(delta: float) -> void:
	if not _visual.visible:
		_timer -= delta
		if _timer <= 0.0:
			_visual.visible = true
		return
	_visual.rotation.y += delta * 0.8
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player and player.is_alive() and player.global_position.distance_to(global_position) < 1.4:
		player.add_item(item, 1)
		Fx.number(get_parent(), global_position + Vector3(0, 1.2, 0), "+1 %s" % Rpg.ITEMS[item].name, Color(0.6, 1.0, 0.7), 40)
		_visual.visible = false
		_timer = regrow
