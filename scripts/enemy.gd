extends CharacterBody3D
## Enemigo esqueleto: patrulla cerca de su punto de aparición, persigue al
## héroe cuando lo ve, ataca de cerca y deja EXP al morir. Reaparece después.

const Toon := preload("res://scripts/toon.gd")
const ModelUtil := preload("res://scripts/model_util.gd")
const Fx := preload("res://scripts/fx.gd")

const KINDS := {
	"minion": {
		"name": "Esqueleto",
		"model": "res://assets/kaykit/enemies/Skeleton_Minion.glb",
		"weapon": "res://assets/kaykit/enemies/Skeleton_Blade.gltf",
		"shield": "",
		"height": 1.7,
		"hp": 45, "atk": 8, "def": 0, "exp": 14,
		"speed": 4.6, "attack": "1H_Melee_Attack_Chop", "attack_speed": 1.2,
		"poise": false, "level": 1,
	},
	"warrior": {
		"name": "Guerrero esqueleto",
		"model": "res://assets/kaykit/enemies/Skeleton_Warrior.glb",
		"weapon": "res://assets/kaykit/enemies/Skeleton_Axe.gltf",
		"shield": "res://assets/kaykit/enemies/Skeleton_Shield_Small_A.gltf",
		"height": 2.05,
		"hp": 120, "atk": 16, "def": 4, "exp": 40,
		"speed": 3.4, "attack": "1H_Melee_Attack_Slice_Diagonal", "attack_speed": 0.9,
		"poise": true, "level": 3,
	},
}

enum State { IDLE, PATROL, CHASE, ATTACK, HIT, DEAD }

const GRAVITY := 20.0
const SIGHT := 16.0
const GIVE_UP := 30.0
const ATTACK_RANGE := 1.9
const RESPAWN_TIME := 18.0

var kind := "minion"
var home := Vector3.ZERO
var data: Dictionary

var hp := 1
var max_hp := 1
var _state := State.IDLE
var _timer := 0.0
var _patrol_target := Vector3.ZERO
var _attack_done := false
var _cooldown := 0.0
var _model: Node3D
var _anim: AnimationPlayer
var _bar_bg: Sprite3D
var _bar_fg: Sprite3D
var _label: Label3D
var _shape: CollisionShape3D
var _push := Vector3.ZERO
var _base_y := 0.0


func _ready() -> void:
	data = KINDS[kind]
	add_to_group("enemies")
	max_hp = data.hp
	hp = max_hp
	collision_layer = 4
	collision_mask = 1

	_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = data.height
	_shape.shape = capsule
	_shape.position.y = data.height * 0.5
	add_child(_shape)

	_model = (load(data.model) as PackedScene).instantiate()
	add_child(_model)
	ModelUtil.fit_height(_model, data.height)
	_base_y = _model.position.y
	var skeleton: Skeleton3D = _model.find_children("*", "Skeleton3D", true, false)[0]
	_attach(skeleton, "handslot.r", data.weapon)
	_attach(skeleton, "handslot.l", data.shield)
	Toon.apply(_model, 0.012)
	_anim = _model.find_child("AnimationPlayer", true, false)
	for n in ["Idle", "Walking_D_Skeletons", "Running_A", "Idle_Combat"]:
		if _anim.has_animation(n):
			_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	_anim.play("Idle")
	_anim.seek(randf() * 1.0)

	_build_bar()
	_timer = randf_range(1.0, 3.0)


func _attach(skeleton: Skeleton3D, bone: String, path: String) -> void:
	if path == "" or skeleton.find_bone(bone) < 0:
		return
	var slot := BoneAttachment3D.new()
	slot.bone_name = bone
	skeleton.add_child(slot)
	slot.add_child((load(path) as PackedScene).instantiate())


func _build_bar() -> void:
	var img := Image.create(100, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	_bar_bg = _bar_sprite(tex, Color(0.05, 0.05, 0.1, 0.8), 0)
	_bar_fg = _bar_sprite(tex, Color(0.9, 0.2, 0.2), 1)
	_label = Label3D.new()
	_label.text = "%s  Nv %d" % [data.name, data.level]
	_label.font_size = 40
	_label.outline_size = 10
	_label.pixel_size = 0.005
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.modulate = Color(1.0, 0.85, 0.8)
	_label.position.y = data.height + 0.62
	add_child(_label)
	_set_bar_visible(false)


func _bar_sprite(tex: Texture2D, color: Color, priority: int) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, 100, 10)
	s.centered = false
	s.offset = Vector2(-50, -5)
	s.pixel_size = 0.011
	s.modulate = color
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.no_depth_test = true
	s.render_priority = priority
	s.shaded = false
	s.position.y = data.height + 0.4
	add_child(s)
	return s


func _set_bar_visible(on: bool) -> void:
	_bar_bg.visible = on
	_bar_fg.visible = on
	_label.visible = on


func is_alive() -> bool:
	return _state != State.DEAD


func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	var player := _player()
	var target_velocity := Vector3.ZERO
	_cooldown = max(_cooldown - delta, 0.0)
	_timer -= delta
	var to_player := Vector3.ZERO
	var dist := INF
	if player and player.is_alive():
		to_player = player.global_position - global_position
		to_player.y = 0
		dist = to_player.length()

	match _state:
		State.IDLE:
			_play("Idle")
			if dist < SIGHT:
				_state = State.CHASE
			elif _timer <= 0.0:
				var a := randf() * TAU
				_patrol_target = home + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, 7.0)
				_state = State.PATROL
				_timer = 6.0
		State.PATROL:
			var d := _patrol_target - global_position
			d.y = 0
			if dist < SIGHT:
				_state = State.CHASE
			elif d.length() < 0.6 or _timer <= 0.0:
				_state = State.IDLE
				_timer = randf_range(2.0, 4.0)
			else:
				target_velocity = d.normalized() * data.speed * 0.4
				_play("Walking_D_Skeletons" if _anim.has_animation("Walking_D_Skeletons") else "Walking_A")
		State.CHASE:
			if dist > GIVE_UP or global_position.distance_to(home) > 45.0 or not player.is_alive():
				_state = State.PATROL
				_patrol_target = home
				_timer = 10.0
			elif dist < ATTACK_RANGE:
				if _cooldown <= 0.0:
					_start_attack()
				else:
					_play("Idle_Combat" if _anim.has_animation("Idle_Combat") else "Idle")
					_face(to_player, delta)
			else:
				target_velocity = to_player.normalized() * data.speed
				_play("Running_A")
		State.ATTACK:
			_face(to_player, delta * 0.4)
			var length: float = _anim.get_animation(data.attack).length / data.attack_speed
			var elapsed := length - _timer
			if not _attack_done and elapsed > length * 0.45:
				_attack_done = true
				if player and player.is_alive() and dist < ATTACK_RANGE + 0.6:
					var fwd := Vector3(sin(_model.rotation.y), 0, cos(_model.rotation.y))
					if fwd.dot(to_player.normalized()) > 0.3:
						player.take_hit(data.atk, global_position, self)
			if _timer <= 0.0:
				_state = State.CHASE
				_cooldown = randf_range(0.8, 1.6)
		State.HIT:
			if _timer <= 0.0:
				_state = State.CHASE
		State.DEAD:
			if _timer <= 0.0:
				_respawn()
			return

	if target_velocity.length() > 0.1:
		_face(target_velocity, delta)
	velocity.x = move_toward(velocity.x, target_velocity.x + _push.x, 30.0 * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z + _push.z, 30.0 * delta)
	_push = _push.move_toward(Vector3.ZERO, 25.0 * delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if global_position.y < -20.0:
		global_position = home + Vector3(0, 2, 0)


func _face(dir: Vector3, delta: float) -> void:
	if dir.length() < 0.01:
		return
	_model.rotation.y = lerp_angle(_model.rotation.y, atan2(dir.x, dir.z), 10.0 * delta)


func _start_attack() -> void:
	_state = State.ATTACK
	_attack_done = false
	_anim.play(data.attack, 0.1, data.attack_speed)
	_timer = _anim.get_animation(data.attack).length / data.attack_speed


func _play(anim_name: String) -> void:
	if _anim.current_animation != anim_name:
		_anim.play(anim_name, 0.2)


## Recibe un golpe del héroe. Devuelve true si lo mató.
func take_hit(damage: int, from: Vector3, stagger: bool, push: float) -> bool:
	if _state == State.DEAD:
		return false
	var amount := maxi(1, int(damage * randf_range(0.9, 1.1)) - int(data.def))
	hp -= amount
	_update_bar()
	_set_bar_visible(true)
	Fx.number(get_parent(), global_position + Vector3(0, data.height + 0.2, 0), str(amount), Color(1.0, 0.95, 0.6) if not stagger else Color(1.0, 0.6, 0.25))
	var away := global_position - from
	away.y = 0
	if push > 0.0 and away.length() > 0.01:
		_push = away.normalized() * push
	if hp <= 0:
		_die()
		return true
	if _state != State.ATTACK or stagger:
		if not data.poise or stagger:
			_state = State.HIT
			_anim.play("Hit_A" if randf() < 0.5 else "Hit_B", 0.05)
			_timer = 0.45
		elif _state != State.ATTACK:
			_state = State.CHASE
	return false


func _update_bar() -> void:
	var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	_bar_fg.region_rect = Rect2(0, 0, 100.0 * ratio, 10)


func _die() -> void:
	_state = State.DEAD
	_timer = RESPAWN_TIME
	_anim.play("Death_A", 0.05)
	_set_bar_visible(false)
	_shape.disabled = true
	velocity = Vector3.ZERO
	var player := _player()
	if player:
		player.gain_exp(data.exp, global_position + Vector3(0, data.height, 0))
	var tween := create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(_model, "position:y", _base_y - 2.2, 1.5)
	tween.tween_callback(func(): _model.visible = false)


func _respawn() -> void:
	global_position = home + Vector3(0, 1.0, 0)
	hp = max_hp
	_update_bar()
	_shape.disabled = false
	_model.position.y = _base_y
	_model.visible = true
	_state = State.IDLE
	_timer = 2.0
	_anim.play("Spawn_Ground_Skeletons" if _anim.has_animation("Spawn_Ground_Skeletons") else "Idle", 0.0)
