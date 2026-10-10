extends Node3D
## Otro jugador del grupo, visto en esta pantalla: se mueve suavemente hacia
## la posición que manda su ordenador y repite su animación.

const Toon := preload("res://scripts/toon.gd")
const Weapons := preload("res://scripts/weapons.gd")
const ModelUtil := preload("res://scripts/model_util.gd")
const ALL_GEAR := ["1H_Sword", "1H_Sword_Offhand", "2H_Sword", "Badge_Shield",
	"Rectangle_Shield", "Round_Shield", "Spike_Shield"]
const COLORS := [Color(0.55, 0.85, 1.0), Color(1.0, 0.7, 0.5), Color(0.7, 1.0, 0.6), Color(1.0, 0.6, 0.9)]

var peer_id := 0
var player_name := "Héroe"
var hp := 100
var max_hp := 100
var weapon := ""
var color_index := 0
var data := {"height": 1.85}

var _model: Node3D
var _anim: AnimationPlayer
var _label: Label3D
var _target_pos := Vector3.ZERO
var _target_rot := 0.0
var _riding := false
var _horse: Node3D


func _ready() -> void:
	add_to_group("remote_players")
	_model = (load("res://assets/kaykit/characters/Knight.glb") as PackedScene).instantiate()
	add_child(_model)
	var box := ModelUtil.local_aabb(_model)
	_model.scale = Vector3.ONE * (1.85 / box.size.y)
	Toon.apply(_model, 0.012, COLORS[color_index % COLORS.size()].lerp(Color.WHITE, 0.55))
	_anim = _model.find_child("AnimationPlayer", true, false)
	for n in ["Idle", "Walking_A", "Running_A", "Jump_Idle", "Blocking", "Sit_Chair_Idle", "Running_Strafe_Left",
			"Running_Strafe_Right", "Walking_Backwards", "2H_Melee_Idle", "Unarmed_Idle"]:
		if _anim.has_animation(n):
			_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	_anim.play("Idle")
	_label = Label3D.new()
	_label.font_size = 40
	_label.outline_size = 10
	_label.pixel_size = 0.005
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = COLORS[color_index % COLORS.size()]
	_label.position.y = 2.2
	add_child(_label)
	_target_pos = global_position
	_set_weapon("espada")


func _fit_scale() -> void:
	pass


func apply_state(pos: Vector3, rot: float, anim: String, speed: float, w: String, new_hp: int, new_max: int, riding: bool, name_: String) -> void:
	_target_pos = pos
	_target_rot = rot
	hp = new_hp
	max_hp = new_max
	player_name = name_
	_label.text = "%s\n%d / %d" % [player_name, hp, max_hp]
	if w != weapon:
		_set_weapon(w)
	if anim != "" and _anim.has_animation(anim) and _anim.current_animation != anim:
		_anim.play(anim, 0.15)
	_anim.speed_scale = speed
	if riding != _riding:
		_riding = riding
		_model.position.y = 1.62 if riding else 0.0
		if riding and _horse == null:
			_horse = Node3D.new()
			_horse.set_script(preload("res://scripts/horse.gd"))
			add_child(_horse)
			_horse.set_ridden(true)
			_horse.remove_from_group("horses")
		elif not riding and _horse:
			_horse.queue_free()
			_horse = null


func _set_weapon(w: String) -> void:
	weapon = w
	var gear: Array = Weapons.DATA[w].gear if Weapons.DATA.has(w) else []
	for gear_name in ALL_GEAR:
		var node := _model.find_child(gear_name, true, false)
		if node:
			node.visible = gear_name in gear
	if w == "lanza":
		var node := _model.find_child("2H_Sword", true, false)
		if node:
			node.visible = true


func _process(delta: float) -> void:
	var dist := global_position.distance_to(_target_pos)
	if dist > 12.0:
		global_position = _target_pos
	else:
		global_position = global_position.lerp(_target_pos, 1.0 - exp(-12.0 * delta))
	_model.rotation.y = lerp_angle(_model.rotation.y, _target_rot, 1.0 - exp(-14.0 * delta))
	if _horse:
		_horse.rotation.y = _model.rotation.y
		_horse.animate(dist / maxf(delta, 0.001) * 0.1, delta)


func is_alive() -> bool:
	return hp > 0


## Un enemigo del anfitrión golpea a este jugador: se lo dice a su ordenador.
func take_hit(damage: int, from: Vector3, _attacker: Node3D = null) -> void:
	var net := get_tree().get_first_node_in_group("net")
	if net:
		net.send_player_hit(peer_id, damage, from)
