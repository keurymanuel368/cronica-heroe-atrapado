extends Node3D
## Habitante del pueblo: está en su sitio, mira al héroe cuando se acerca y
## habla con él (tecla F). Algunos además hacen algo al terminar de hablar,
## como el posadero, que deja descansar y guarda la partida.

const Toon := preload("res://scripts/toon.gd")
const ModelUtil := preload("res://scripts/model_util.gd")

const TALK_RANGE := 2.8

var npc_name := "Aldeano"
var role := ""
var model_path := "res://assets/kaykit/characters/Rogue.glb"
var gear: Array = []
var lines: Array = []
## Qué pasa al terminar la charla: "" (nada) o "rest" (descansar y guardar).
var action := ""
var height := 1.75
## Tras la primera charla, los que tienen tienda o gremio solo saludan.
var talked := false

var _model: Node3D
var _anim: AnimationPlayer
var _label: Label3D
var _gesture_timer := 0.0


func _ready() -> void:
	add_to_group("npcs")
	_model = (load(model_path) as PackedScene).instantiate()
	add_child(_model)
	for child in _model.find_children("*", "MeshInstance3D", true, false):
		var n := String(child.name)
		var is_gear := not (n.begins_with("Knight") or n.begins_with("Barbarian") or n.begins_with("Mage") or n.begins_with("Rogue"))
		if is_gear:
			child.visible = n in gear
	ModelUtil.fit_height(_model, height)
	# Los personajes de KayKit ya tienen los pies en el origen.
	_model.position.y = 0.0
	Toon.apply(_model, 0.012)
	_anim = _model.find_child("AnimationPlayer", true, false)
	_anim.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
	_anim.play("Idle")
	_anim.seek(randf())
	_gesture_timer = randf_range(4.0, 9.0)

	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = height
	shape.shape = capsule
	shape.position.y = height * 0.5
	body.add_child(shape)
	add_child(body)

	_label = Label3D.new()
	_label.text = npc_name if role == "" else "%s\n%s" % [npc_name, role]
	_label.font_size = 40
	_label.outline_size = 10
	_label.pixel_size = 0.005
	_label.modulate = Color(1.0, 0.92, 0.6)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = height + 0.45
	add_child(_label)


func _process(delta: float) -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var d := player.global_position - global_position
	d.y = 0
	if d.length() < 7.0:
		_model.global_rotation.y = lerp_angle(_model.global_rotation.y, atan2(d.x, d.z), 4.0 * delta)
	else:
		_model.rotation.y = lerp_angle(_model.rotation.y, 0.0, 2.0 * delta)
	_gesture_timer -= delta
	if _gesture_timer <= 0.0:
		_gesture_timer = randf_range(6.0, 12.0)
		if _anim.has_animation("Interact") and d.length() > 4.0:
			_anim.play("Interact", 0.3)
			_anim.queue("Idle")


func can_talk(from: Vector3) -> bool:
	var d := from - global_position
	d.y = 0
	return d.length() < TALK_RANGE


func on_talk_start() -> void:
	_anim.play("Cheer" if lines.size() > 0 and randf() < 0.3 else "Interact", 0.2)
	_anim.queue("Idle")
