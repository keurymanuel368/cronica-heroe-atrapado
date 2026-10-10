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
	"rogue": {
		"name": "Pícaro esqueleto",
		"model": "res://assets/kaykit/enemies/Skeleton_Rogue.glb",
		"weapon": "res://assets/kaykit/enemies/Skeleton_Blade.gltf",
		"shield": "",
		"height": 1.75,
		"hp": 60, "atk": 11, "def": 1, "exp": 22,
		"speed": 5.6, "attack": "1H_Melee_Attack_Stab", "attack_speed": 1.5,
		"poise": false, "level": 2,
	},
	"mage": {
		"name": "Mago esqueleto",
		"model": "res://assets/kaykit/enemies/Skeleton_Mage.glb",
		"weapon": "res://assets/kaykit/enemies/Skeleton_Staff.gltf",
		"shield": "",
		"height": 1.8,
		"hp": 50, "atk": 14, "def": 0, "exp": 28,
		"speed": 3.0, "attack": "Spellcast_Shoot", "attack_speed": 1.0,
		"poise": false, "level": 3, "ranged": true, "range": 10.0,
	},
	"boss": {
		"name": "Rey Esqueleto",
		"model": "res://assets/kaykit/enemies/Skeleton_Warrior.glb",
		"weapon": "res://assets/kaykit/enemies/Skeleton_Axe.gltf",
		"shield": "res://assets/kaykit/enemies/Skeleton_Shield_Small_A.gltf",
		"height": 4.2,
		"hp": 900, "atk": 28, "def": 6, "exp": 400,
		"speed": 3.6, "attack": "2H_Melee_Attack_Chop", "attack_speed": 0.8,
		"poise": true, "level": 10, "boss": true, "respawn": false, "range": 3.6, "sight": 24.0,
	},
	"final": {
		"name": "Kaito, el Primer Héroe",
		"model": "res://assets/kaykit/characters/Knight.glb",
		"gear_keep": ["2H_Sword"],
		"weapon": "",
		"shield": "",
		"height": 3.6,
		"hp": 1900, "atk": 28, "def": 7, "exp": 1500,
		"speed": 4.6, "attack": "2H_Melee_Attack_Slice", "attack_speed": 0.9,
		"poise": true, "level": 15, "boss": true, "final": true, "respawn": false, "range": 3.4, "sight": 40.0,
		"tint": Color(0.5, 0.36, 0.7),
	},
}

enum State { IDLE, PATROL, CHASE, ATTACK, HIT, DEAD }

const GRAVITY := 20.0
const SIGHT := 16.0
const GIVE_UP := 30.0
const ATTACK_RANGE := 1.9
const RESPAWN_TIME := 18.0

var kind := "minion"
## Color y nombre especiales (guardianes del vacío de la historia).
var tint := Color.WHITE
var title := ""
var _special_timer := 6.0
## Número para el cooperativo (igual en todos los ordenadores).
var net_id := -1
var _net: Node
var _net_pos := Vector3.ZERO
var _net_rot := 0.0
var _summoned := 0
## Si es true no reaparece al morir (emboscadas).
var once := false
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
var _base_scale := Vector3.ONE
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
	if data.has("gear_keep"):
		for child in _model.find_children("*", "MeshInstance3D", true, false):
			var n := String(child.name)
			if not (n.begins_with("Knight") or n in data.gear_keep):
				child.visible = false
	ModelUtil.fit_height(_model, data.height)
	# Los modelos de KayKit ya tienen los pies en el origen.
	_model.position.y = 0.0
	_base_scale = _model.scale
	_base_y = _model.position.y
	var skeleton: Skeleton3D = _model.find_children("*", "Skeleton3D", true, false)[0]
	_attach(skeleton, "handslot.r", data.weapon)
	_attach(skeleton, "handslot.l", data.shield)
	var color: Color = data.get("tint", tint)
	Toon.apply(_model, 0.012, color)
	_anim = _model.find_child("AnimationPlayer", true, false)
	for n in ["Idle", "Walking_D_Skeletons", "Running_A", "Idle_Combat"]:
		if _anim.has_animation(n):
			_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	_anim.play("Idle")
	_anim.seek(randf() * 1.0)

	_build_bar()
	_timer = randf_range(1.0, 3.0)
	_net = get_tree().get_first_node_in_group("net")
	if _net:
		_net.register_enemy(self)
	_net_pos = global_position


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
	_label.text = "%s  Nv %d" % [title if title != "" else data.name, data.level + (3 if title != "" else 0)]
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
	if is_boss():
		on = false
	_bar_bg.visible = on
	_bar_fg.visible = on
	_label.visible = on


## Si está peleando con el héroe (para la barra del jefe en pantalla).
func is_engaged() -> bool:
	return _state == State.CHASE or _state == State.ATTACK or _state == State.HIT


func is_alive() -> bool:
	return _state != State.DEAD


## El héroe más cercano (en grupo también los amigos) al que perseguir.
func _player() -> Node3D:
	var best: Node3D = get_tree().get_first_node_in_group("player")
	if _net == null or not _net.active():
		return best
	var best_d := INF if best == null or not best.is_alive() else best.global_position.distance_to(global_position)
	for p in get_tree().get_nodes_in_group("remote_players"):
		if p.is_alive():
			var d: float = p.global_position.distance_to(global_position)
			if d < best_d:
				best_d = d
				best = p
	return best


## En un invitado, el enemigo solo copia lo que manda el anfitrión.
func apply_net_state(pos: Vector3, rot: float, anim: String, new_hp: int, state: int) -> void:
	_net_pos = pos
	_net_rot = rot
	if new_hp != hp:
		hp = new_hp
		_update_bar()
		_set_bar_visible(hp < max_hp and state != State.DEAD)
	if anim != "" and _anim.has_animation(anim) and _anim.current_animation != anim and state != State.DEAD:
		_anim.play(anim, 0.15)
	if state == State.DEAD and _state != State.DEAD:
		_state = State.DEAD
		_anim.play("Death_A", 0.05)
		_set_bar_visible(false)
		_shape.disabled = true
	elif state != State.DEAD and _state == State.DEAD:
		_state = state as State
		_shape.disabled = false
		_model.position.y = _base_y
		_model.visible = true
		global_position = pos
	elif state != State.DEAD:
		_state = state as State


func _net_puppet(delta: float) -> void:
	if global_position.distance_to(_net_pos) > 8.0:
		global_position = _net_pos
	else:
		global_position = global_position.lerp(_net_pos, 1.0 - exp(-10.0 * delta))
	_model.rotation.y = lerp_angle(_model.rotation.y, _net_rot, 1.0 - exp(-12.0 * delta))


func _physics_process(delta: float) -> void:
	if _net and _net.is_client():
		_net_puppet(delta)
		return
	var player := _player()
	var target_velocity := Vector3.ZERO
	_cooldown = max(_cooldown - delta, 0.0)
	_timer -= delta
	var to_player := Vector3.ZERO
	var dist := INF
	if player and player.is_alive():
		to_player = player.global_position - global_position
		var dy := absf(to_player.y)
		to_player.y = 0
		dist = to_player.length() if dy < 25.0 else INF

	match _state:
		State.IDLE:
			_play("Idle")
			if dist < float(data.get("sight", SIGHT)):
				_state = State.CHASE
			elif _timer <= 0.0:
				var a := randf() * TAU
				_patrol_target = home + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, 7.0)
				_state = State.PATROL
				_timer = 6.0
		State.PATROL:
			var d := _patrol_target - global_position
			d.y = 0
			if dist < float(data.get("sight", SIGHT)):
				_state = State.CHASE
			elif d.length() < 0.6 or _timer <= 0.0:
				_state = State.IDLE
				_timer = randf_range(2.0, 4.0)
			else:
				target_velocity = d.normalized() * data.speed * 0.4
				_play("Walking_D_Skeletons" if _anim.has_animation("Walking_D_Skeletons") else "Walking_A")
		State.CHASE:
			if data.get("final", false):
				_final_specials(player, delta)
			if dist > GIVE_UP or global_position.distance_to(home) > 45.0 or not player.is_alive():
				_state = State.PATROL
				_patrol_target = home
				_timer = 10.0
			elif dist < _range():
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
				if data.get("ranged", false):
					_cast_orb(player)
				elif player and player.is_alive() and dist < _range() + 0.6:
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
	if global_position.y < home.y - 20.0:
		global_position = home + Vector3(0, 2, 0)


func _range() -> float:
	return float(data.get("range", ATTACK_RANGE))


func is_boss() -> bool:
	return data.get("boss", false)


## El mago esqueleto lanza un orbe morado lento hacia el héroe.
func _cast_orb(player: Node3D) -> void:
	if player == null or not player.is_alive():
		return
	var p := Node3D.new()
	p.set_script(preload("res://scripts/projectile.gd"))
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.3, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.2, 1.0)
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere.material = mat
	ball.mesh = sphere
	p.add_child(ball)
	get_parent().add_child(p)
	var start := global_position + Vector3(0, 1.5, 0)
	p.global_position = start
	var aim := (player.global_position + Vector3(0, 1.0, 0)) - start
	p.velocity = aim.normalized() * 11.0
	p.damage = int(data.atk)
	p.hostile = true
	p.radius = 0.6
	p.life = 2.5
	p.source = self
	if _net:
		_net.enemy_orb(start, p.velocity, int(data.atk))


## Kaito: anillos de orbes cada pocos segundos y esqueletos de apoyo al
## bajar de vida.
func _final_specials(player: Node3D, delta: float) -> void:
	_special_timer -= delta
	if _special_timer <= 0.0:
		_special_timer = randf_range(5.0, 7.5) if hp > max_hp / 2 else randf_range(3.5, 5.0)
		_anim.play("Spellcast_Shoot", 0.1)
		var count := 10 if hp > max_hp / 2 else 16
		for i in count:
			var a := TAU * i / count
			_orb(global_position + Vector3(0, 1.5, 0), Vector3(cos(a), 0, sin(a)) * 9.0, int(data.atk * 0.6))
		if player:
			_orb(global_position + Vector3(0, 2.0, 0), (player.global_position + Vector3(0, 1.0, 0) - global_position - Vector3(0, 2.0, 0)).normalized() * 14.0, int(data.atk * 0.8))
	var thresholds := [0.7, 0.4, 0.15]
	if _summoned < thresholds.size() and hp < max_hp * thresholds[_summoned]:
		_summoned += 1
		Fx.number(get_parent(), global_position + Vector3(0, data.height + 1.0, 0), "¡Levantaos, guardianes!", Color(0.8, 0.5, 1.0), 56)
		for i in 3:
			var e := CharacterBody3D.new()
			e.set_script(load("res://scripts/enemy.gd"))
			e.kind = ["minion", "rogue", "mage"][i]
			e.once = true
			e.tint = Color(0.6, 0.4, 0.9)
			e.title = "Guardián del vacío"
			var a := TAU * i / 3.0
			e.home = global_position + Vector3(cos(a) * 5.0, 0, sin(a) * 5.0)
			e.position = e.home + Vector3(0, 0.5, 0)
			get_parent().add_child(e)


func _orb(start: Vector3, vel: Vector3, damage: int) -> void:
	var p := Node3D.new()
	p.set_script(preload("res://scripts/projectile.gd"))
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.3, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.2, 1.0)
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere.material = mat
	ball.mesh = sphere
	p.add_child(ball)
	get_parent().add_child(p)
	p.global_position = start
	p.velocity = vel
	p.damage = damage
	p.hostile = true
	p.radius = 0.6
	p.life = 3.0
	p.source = self
	if _net:
		_net.enemy_orb(start, vel, damage)


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
	if _net and _net.is_client():
		# El anfitrión aplica el daño; aquí solo se ve el golpe.
		_net.send_enemy_hit(self, damage, from, stagger, push)
		Fx.number(get_parent(), global_position + Vector3(0, data.height + 0.2, 0), str(maxi(1, damage - int(data.def))), Color(1.0, 0.95, 0.6))
		_model.scale = Vector3(1.15, 0.85, 1.15) * _base_scale
		_model.create_tween().tween_property(_model, "scale", _base_scale, 0.15)
		return false
	var amount := maxi(1, int(damage * randf_range(0.9, 1.1)) - int(data.def))
	hp -= amount
	# Se encoge un instante al recibir el golpe.
	_model.scale = Vector3(1.15, 0.85, 1.15) * _base_scale
	var tw := _model.create_tween()
	tw.tween_property(_model, "scale", _base_scale, 0.15)
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
	_timer = RESPAWN_TIME if data.get("respawn", true) and not once else INF
	_anim.play("Death_A", 0.05)
	_set_bar_visible(false)
	_shape.disabled = true
	velocity = Vector3.ZERO
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if _net:
		_net.enemy_died(self, data.exp, int(data.exp * 0.6) + 3)
	if player:
		player.gain_exp(data.exp, global_position + Vector3(0, data.height, 0))
		player.on_enemy_killed(kind)
		var coins := int(data.exp * 0.6) + randi_range(1, 6)
		player.add_gold(coins)
		Fx.number(get_parent(), global_position + Vector3(0, data.height + 0.6, 0), "+%d oro" % coins, Color(1.0, 0.85, 0.3), 40)
		if randf() < 0.55:
			player.add_item("hueso", 1)
	get_tree().call_group("story_listeners", "on_story_kill", self)
	if is_boss():
		get_tree().call_group("boss_listeners", "on_boss_defeated", self)
		if kind == "final" and _net:
			_net.final_defeated()
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
