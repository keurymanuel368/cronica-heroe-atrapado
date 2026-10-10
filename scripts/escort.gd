extends Node3D
## Bram, el comerciante de la misión de escolta: sigue al héroe hasta el
## molino. A mitad de camino salen esqueletos a emboscarlos.

const Toon := preload("res://scripts/toon.gd")
const ModelUtil := preload("res://scripts/model_util.gd")

var world: Node
var goal := Vector3.ZERO
var on_arrive: Callable
var on_ambush: Callable
var _model: Node3D
var _anim: AnimationPlayer
var _ambushed := false
var _done := false
var _start := Vector3.ZERO


func _ready() -> void:
	_start = global_position
	_model = (load("res://assets/kaykit/characters/Rogue_Hooded.glb") as PackedScene).instantiate()
	add_child(_model)
	for child in _model.find_children("*", "MeshInstance3D", true, false):
		if not String(child.name).begins_with("Rogue"):
			child.visible = false
	ModelUtil.fit_height(_model, 1.75)
	_model.position.y = 0.0
	Toon.apply(_model, 0.012, Color(1.0, 0.85, 0.7))
	_anim = _model.find_child("AnimationPlayer", true, false)
	for n in ["Idle", "Walking_A", "Running_A"]:
		_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	_anim.play("Idle")
	var label := Label3D.new()
	label.text = "Bram\nComerciante (escolta)"
	label.font_size = 40
	label.outline_size = 10
	label.pixel_size = 0.005
	label.modulate = Color(0.6, 1.0, 0.7)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 2.2
	add_child(label)


func _process(delta: float) -> void:
	if _done:
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var to_player := player.global_position - global_position
	to_player.y = 0
	var speed := 0.0
	if to_player.length() > 3.0:
		speed = 6.5 if to_player.length() > 8.0 else 3.6
		var step := to_player.normalized() * speed * delta
		global_position += step
		global_position.y = world.height(global_position.x, global_position.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(step.x, step.z), 8.0 * delta)
	if speed > 5.0:
		_play("Running_A")
	elif speed > 0.0:
		_play("Walking_A")
	else:
		_play("Idle")
	var total := _start.distance_to(goal)
	if not _ambushed and global_position.distance_to(goal) < total * 0.55:
		_ambushed = true
		on_ambush.call(global_position)
	if global_position.distance_to(goal) < 14.0:
		_done = true
		_play("Cheer")
		on_arrive.call()


func _play(n: String) -> void:
	if _anim.current_animation != n:
		_anim.play(n, 0.2)
