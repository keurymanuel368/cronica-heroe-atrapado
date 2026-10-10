extends CharacterBody3D
## El héroe: se mueve en relación con la cámara, corre, salta, pelea con el
## arma elegida, esquiva, bloquea, lanza magia y sube de nivel.

const Toon := preload("res://scripts/toon.gd")
const ModelUtil := preload("res://scripts/model_util.gd")
const Weapons := preload("res://scripts/weapons.gd")
const Fx := preload("res://scripts/fx.gd")
const PROJECTILE := preload("res://scripts/projectile.gd")
const Rpg := preload("res://scripts/rpg.gd")

const WALK_SPEED := 3.4
const RUN_SPEED := 7.2
const BLOCK_SPEED := 1.6
const ACCELERATION := 14.0
const AIR_CONTROL := 0.35
const JUMP_VELOCITY := 7.0
const GRAVITY := 20.0
const TURN_SPEED := 12.0
const DODGE_SPEED := 11.0
const DODGE_TIME := 0.38
const LOCK_RANGE := 22.0

const MOUSE_SENSITIVITY := 0.0025
const STICK_SENSITIVITY := 2.6
const PITCH_MIN := deg_to_rad(-60.0)
const PITCH_MAX := deg_to_rad(25.0)
const ZOOM_MIN := 2.5
const ZOOM_MAX := 10.0

const HERO_MODEL := "res://assets/kaykit/characters/Knight.glb"
const ALL_GEAR := ["1H_Sword", "1H_Sword_Offhand", "2H_Sword", "Badge_Shield",
	"Rectangle_Shield", "Round_Shield", "Spike_Shield"]

const LOOPING := ["Idle", "Walking_A", "Running_A", "Jump_Idle", "Blocking",
	"2H_Melee_Idle", "Walking_Backwards", "Running_Strafe_Left", "Running_Strafe_Right"]

signal stats_changed
signal leveled_up(level: int)
signal died
signal weapon_changed(id: String)

var spawn_point := Vector3.ZERO

# --- Estado del personaje (la "ventana de estado") ---
var level := 1
var exp_points := 0
var max_hp := 100
var hp := 100
var max_mp := 50
var mp := 50.0
var atk := 10
var def := 4
var kills := 0
var weapon := "espada"
var gold := 20
var items: Dictionary = {"pocion": 2}
var skills: Dictionary = {"fuego": true}
var skill_points := 1
var element := "fuego"
var armor := 0
var forge := 0
var guild_member := false
var guild_points := 0
## Misiones activas: id -> progreso. Y las ya entregadas.
var quests: Dictionary = {}
var quests_done: Array = []
var target: Node3D = null

var _model: Node3D
var _skeleton: Skeleton3D
var _anim: AnimationPlayer
var _pivot: Node3D
var _arm: SpringArm3D
var _camera: Camera3D
var _yaw := 0.0
var _pitch := deg_to_rad(-14.0)
var _zoom := 5.0
var _was_on_floor := true
var _locked_anim_time := 0.0
var _jump_requested := false

var _attack: Dictionary = {}
var _attack_time := 0.0
var _attack_length := 0.0
var _attack_hit_done := false
var _combo := 0
var _queued_light := false
var _dodge_time := 0.0
var _dodge_dir := Vector3.ZERO
var _dodge_cooldown := 0.0
var _blocking := false
var _hurt_time := 0.0
var _dead_time := 0.0
var _since_combat := 99.0
var _weapon_nodes: Dictionary = {}
## Ataque pedido mientras no se podía (recibiendo un golpe, en el aire):
## se lanza en cuanto se pueda, si no pasó mucho tiempo.
var _buffered := ""
var _buffer_time := 0.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4
	_build_body()
	_build_camera()
	spawn_point = global_position
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cam-yaw="):
			_yaw = deg_to_rad(float(arg.trim_prefix("--cam-yaw=")))
		elif arg.begins_with("--cam-zoom="):
			_zoom = float(arg.trim_prefix("--cam-zoom="))
	set_weapon(weapon)


func _build_body() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.9
	shape.shape = capsule
	shape.position.y = 0.95
	add_child(shape)

	_model = (load(HERO_MODEL) as PackedScene).instantiate()
	add_child(_model)
	for gear_name in ALL_GEAR:
		var gear := _model.find_child(gear_name, true, false)
		if gear:
			gear.visible = gear_name in ["1H_Sword", "Round_Shield"]
	var box := ModelUtil.local_aabb(_model)
	_model.scale = Vector3.ONE * (1.85 / box.size.y)
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0]
	_build_extra_weapons()
	Toon.apply(_model, 0.012)

	_anim = _model.find_child("AnimationPlayer", true, false)
	for anim_name in LOOPING:
		if _anim.has_animation(anim_name):
			_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_anim.play("Idle")


## La lanza (hecha aquí: asta de madera con punta de acero) y el arco.
func _build_extra_weapons() -> void:
	var slot := BoneAttachment3D.new()
	slot.bone_name = "handslot.r"
	_skeleton.add_child(slot)

	var spear := Node3D.new()
	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.045
	shaft_mesh.bottom_radius = 0.045
	shaft_mesh.height = 2.6
	shaft_mesh.radial_segments = 8
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.28, 0.15)
	shaft_mesh.material = wood
	shaft.mesh = shaft_mesh
	shaft.position.y = 0.55
	spear.add_child(shaft)
	var tip := MeshInstance3D.new()
	var tip_mesh := CylinderMesh.new()
	tip_mesh.top_radius = 0.0
	tip_mesh.bottom_radius = 0.12
	tip_mesh.height = 0.5
	tip_mesh.radial_segments = 4
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.82, 0.86, 0.92)
	tip_mesh.material = steel
	tip.mesh = tip_mesh
	tip.position.y = 2.1
	spear.add_child(tip)
	var band := MeshInstance3D.new()
	var band_mesh := CylinderMesh.new()
	band_mesh.top_radius = 0.07
	band_mesh.bottom_radius = 0.07
	band_mesh.height = 0.12
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.9, 0.7, 0.3)
	band_mesh.material = gold
	band.mesh = band_mesh
	band.position.y = 1.83
	spear.add_child(band)
	slot.add_child(spear)
	_weapon_nodes["lanza"] = spear

	var bow: Node3D = (load("res://assets/kaykit/weapons/crossbow_2handed.gltf") as PackedScene).instantiate()
	slot.add_child(bow)
	_weapon_nodes["arco"] = bow


func set_weapon(id: String) -> void:
	weapon = id
	var w: Dictionary = Weapons.DATA[id]
	for gear_name in ALL_GEAR:
		var gear := _model.find_child(gear_name, true, false)
		if gear:
			gear.visible = gear_name in w.gear
	for key in _weapon_nodes:
		_weapon_nodes[key].visible = key == id
	_combo = 0
	weapon_changed.emit(id)
	stats_changed.emit()


## Coloca la cámara y al héroe mirando hacia `yaw` (tras un teletransporte).
func face_yaw(yaw: float) -> void:
	_yaw = yaw
	_model.rotation.y = yaw + PI
	_pivot.global_position = global_position + Vector3(0, 1.6, 0)
	target = null


func total_def() -> int:
	return def + int(Weapons.DATA[weapon].defense) + int(Rpg.ARMOR_DEF[armor]) + (5 if skills.has("defensa1") else 0)


func is_alive() -> bool:
	return hp > 0


func exp_to_next() -> int:
	return 40 + level * 30


func _build_camera() -> void:
	_pivot = Node3D.new()
	_pivot.top_level = true
	add_child(_pivot)
	_arm = SpringArm3D.new()
	_arm.spring_length = _zoom
	_arm.margin = 0.3
	_arm.collision_mask = 1
	var probe := SphereShape3D.new()
	probe.radius = 0.25
	_arm.shape = probe
	_arm.add_excluded_object(get_rid())
	_pivot.add_child(_arm)
	_camera = Camera3D.new()
	_camera.fov = 62.0
	_camera.current = true
	_arm.add_child(_camera)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and event.button_index == MOUSE_BUTTON_LEFT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clamp(_zoom - 0.5, ZOOM_MIN, ZOOM_MAX)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clamp(_zoom + 0.5, ZOOM_MIN, ZOOM_MAX)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if target == null:
			_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_pitch = clamp(_pitch - event.relative.y * MOUSE_SENSITIVITY, PITCH_MIN, PITCH_MAX)
		return
	if not is_alive():
		return
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("jump"):
		_jump_requested = true
	elif event.is_action_pressed("cheer") and is_on_floor() and _attack.is_empty():
		_play_once("Cheer")
	elif event.is_action_pressed("attack_light"):
		if not _attack.is_empty():
			_queued_light = true
		elif not _start_attack(false):
			_buffered = "light"
			_buffer_time = 0.4
	elif event.is_action_pressed("attack_heavy"):
		if _attack.is_empty() and not _start_attack(true):
			_buffered = "heavy"
			_buffer_time = 0.4
	elif event.is_action_pressed("dodge"):
		_start_dodge()
	elif event.is_action_pressed("magic"):
		_cast_spell()
	elif event.is_action_pressed("cycle_element"):
		cycle_element()
	elif event.is_action_pressed("use_potion"):
		use_potion("pocion")
	elif event.is_action_pressed("use_ether"):
		use_potion("eter")
	elif event.is_action_pressed("lock_on"):
		_toggle_lock()
	else:
		for i in Weapons.ORDER.size():
			if event.is_action_pressed("weapon_%d" % (i + 1)):
				set_weapon(Weapons.ORDER[i])


# --- Movimiento ------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_update_lock(delta)
	_update_camera(delta)
	_regen(delta)

	if not is_alive():
		_dead_time -= delta
		velocity.x = move_toward(velocity.x, 0, 20 * delta)
		velocity.z = move_toward(velocity.z, 0, 20 * delta)
		velocity.y -= GRAVITY * delta
		move_and_slide()
		if _dead_time <= 0.0:
			_revive()
		return

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (Basis(Vector3.UP, _yaw) * Vector3(input.x, 0, input.y))
	direction.y = 0
	if direction.length() > 1.0:
		direction = direction.normalized()

	_blocking = Input.is_action_pressed("block") and is_on_floor() and _attack.is_empty() and _dodge_time <= 0.0 and _hurt_time <= 0.0
	var running := Input.is_action_pressed("run") and not _blocking
	var target_speed := RUN_SPEED if running else WALK_SPEED
	if _blocking:
		target_speed = BLOCK_SPEED
	var wanted := direction * target_speed
	var control := 1.0 if is_on_floor() else AIR_CONTROL

	_dodge_cooldown = max(_dodge_cooldown - delta, 0.0)
	_hurt_time = max(_hurt_time - delta, 0.0)
	if _buffer_time > 0.0:
		_buffer_time -= delta
		if _attack.is_empty() and _start_attack(_buffered == "heavy"):
			_buffer_time = 0.0

	if _dodge_time > 0.0:
		_dodge_time -= delta
		velocity.x = _dodge_dir.x * DODGE_SPEED
		velocity.z = _dodge_dir.z * DODGE_SPEED
	elif not _attack.is_empty():
		_update_attack(delta)
		wanted = Vector3.ZERO
		velocity.x = move_toward(velocity.x, 0, 40 * delta)
		velocity.z = move_toward(velocity.z, 0, 40 * delta)
	elif _hurt_time > 0.0:
		velocity.x = move_toward(velocity.x, 0, 30 * delta)
		velocity.z = move_toward(velocity.z, 0, 30 * delta)
	else:
		if _locked_anim_time > 0.0:
			_locked_anim_time -= delta
			wanted = Vector3.ZERO
			if direction.length() > 0.1:
				_locked_anim_time = 0.0
		velocity.x = move_toward(velocity.x, wanted.x, ACCELERATION * control * delta * target_speed)
		velocity.z = move_toward(velocity.z, wanted.z, ACCELERATION * control * delta * target_speed)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if _jump_requested and is_on_floor() and _attack.is_empty() and _dodge_time <= 0.0:
		velocity.y = JUMP_VELOCITY
		_locked_anim_time = 0.0
		_play("Jump_Start", 0.05)
	_jump_requested = false

	move_and_slide()

	var flat := Vector3(velocity.x, 0, velocity.z)
	if (target and (_blocking or not _attack.is_empty() or flat.length() < 4.0)) and _dodge_time <= 0.0:
		var to_target := target.global_position - global_position
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(to_target.x, to_target.z), TURN_SPEED * delta)
	elif flat.length() > 0.2 and _attack.is_empty() and _dodge_time <= 0.0:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(flat.x, flat.z), TURN_SPEED * delta)

	_update_animation(flat.length())
	_was_on_floor = is_on_floor()

	if global_position.y < spawn_point.y - 30.0:
		global_position = spawn_point
		velocity = Vector3.ZERO


func _update_camera(delta: float) -> void:
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if target == null:
		_yaw -= stick.x * STICK_SENSITIVITY * delta
	_pitch = clamp(_pitch - stick.y * STICK_SENSITIVITY * delta, PITCH_MIN, PITCH_MAX)
	_pivot.global_position = _pivot.global_position.lerp(global_position + Vector3(0, 1.6, 0), 1.0 - exp(-14.0 * delta))
	_pivot.rotation = Vector3(_pitch, _yaw, 0)
	_arm.spring_length = lerp(_arm.spring_length, _zoom, 1.0 - exp(-10.0 * delta))


func _update_animation(speed: float) -> void:
	if _dodge_time > 0.0 or not _attack.is_empty() or _hurt_time > 0.0:
		return
	if _blocking:
		_play("Blocking", 0.1)
		return
	if _locked_anim_time > 0.0:
		return
	if not is_on_floor():
		if _anim.current_animation != "Jump_Start" or not _anim.is_playing():
			_play("Jump_Idle", 0.15)
		return
	if not _was_on_floor:
		_play_once("Jump_Land", 0.05)
		_locked_anim_time = 0.0
		return
	if _anim.current_animation == "Jump_Land" and _anim.is_playing() and speed < 0.5:
		return
	if speed < 0.3:
		_play(Weapons.DATA[weapon].idle, 0.2)
	elif speed < WALK_SPEED + 0.6:
		_play("Walking_A", 0.2)
		_anim.speed_scale = clamp(speed / WALK_SPEED, 0.6, 1.3)
		return
	else:
		_play("Running_A", 0.2)
	_anim.speed_scale = 1.0


func _play(anim_name: String, blend := 0.2) -> void:
	if _anim.current_animation != anim_name:
		_anim.speed_scale = 1.0
		_anim.play(anim_name, blend)


func _play_once(anim_name: String, blend := 0.15) -> void:
	_anim.speed_scale = 1.0
	_anim.play(anim_name, blend)
	if anim_name == "Cheer":
		_locked_anim_time = _anim.get_animation(anim_name).length


# --- Combate ---------------------------------------------------------------

func _start_attack(heavy: bool) -> bool:
	if not is_on_floor() or _dodge_time > 0.0 or _hurt_time > 0.0:
		return false
	var w: Dictionary = Weapons.DATA[weapon]
	if heavy:
		_attack = w.heavy
		_combo = 0
	else:
		var list: Array = w.light
		_attack = list[_combo % list.size()]
		_combo += 1
	_attack_time = 0.0
	_attack_length = _anim.get_animation(_attack.anim).length / float(_attack.speed)
	_attack_hit_done = false
	_queued_light = false
	_locked_anim_time = 0.0
	_anim.play(_attack.anim, 0.08, float(_attack.speed))
	_anim.seek(0.0, true)
	_since_combat = 0.0
	# Gira hacia donde apunta la cámara o hacia el objetivo fijado.
	var aim := _aim_direction()
	_model.rotation.y = atan2(aim.x, aim.z)
	return true


func _aim_direction() -> Vector3:
	if target:
		var d := target.global_position - global_position
		d.y = 0
		return d.normalized()
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input.length() > 0.2:
		return (Basis(Vector3.UP, _yaw) * Vector3(input.x, 0, input.y)).normalized()
	return Basis(Vector3.UP, _yaw) * Vector3(0, 0, -1)


func _update_attack(delta: float) -> void:
	_attack_time += delta
	if not _attack_hit_done and _attack_time >= _attack_length * float(_attack.hit):
		_attack_hit_done = true
		if _attack.has("arrows"):
			_shoot_arrows(int(_attack.arrows), int(_attack.dmg))
		else:
			_melee_hit(_attack)
	# Encadena el siguiente golpe del combo si se pulsó a tiempo.
	if _queued_light and _attack_time > _attack_length * 0.6:
		_attack = {}
		_start_attack(false)
		return
	if _attack_time >= _attack_length:
		_attack = {}
		if _combo >= Weapons.DATA[weapon].light.size():
			_combo = 0
		_queued_light = false


func _melee_hit(a: Dictionary) -> void:
	var fwd := Vector3(sin(_model.rotation.y), 0, cos(_model.rotation.y))
	var half_arc := deg_to_rad(float(a.arc) * 0.5)
	var hit_any := false
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.is_alive():
			continue
		var d: Vector3 = enemy.global_position - global_position
		d.y = 0
		if d.length() > float(a.range) + 0.4:
			continue
		if a.arc < 360 and d.length() > 0.5 and fwd.angle_to(d.normalized()) > half_arc:
			continue
		var damage := int(a.dmg) + total_atk() / 2
		if skills.has("maestria"):
			damage = int(damage * 1.2)
		enemy.take_hit(damage, global_position, a.get("stagger", false), float(a.get("push", 2.0)))
		hit_any = true
	if hit_any:
		_hitstop()


## Pausa de un instante al acertar, para que los golpes se sientan.
func _hitstop() -> void:
	Engine.time_scale = 0.15
	await get_tree().create_timer(0.05, true, false, true).timeout
	Engine.time_scale = 1.0


func _shoot_arrows(count: int, damage: int) -> void:
	var aim := _aim_direction()
	var arrow_scene := load("res://assets/kaykit/weapons/arrow.gltf") as PackedScene
	for i in count:
		var spread := (i - (count - 1) * 0.5) * 0.12
		var dir := (Basis(Vector3.UP, spread) * aim).normalized()
		var p := Node3D.new()
		p.set_script(PROJECTILE)
		var model: Node3D = arrow_scene.instantiate()
		model.scale = Vector3.ONE * 1.6
		model.rotation.x = -PI * 0.5
		p.add_child(model)
		get_parent().add_child(p)
		p.global_position = global_position + Vector3(0, 1.3, 0) + aim * 0.6
		p.velocity = dir * 34.0
		p.damage = damage + total_atk() / 2
		p.gravity = 2.0
		p.life = 1.6
		p.source = self


func spell_cost(element: String) -> int:
	var c: int = Rpg.MAGIC[element].cost
	if skills.has("mana2"):
		c = int(round(c * 0.75))
	return c


func cycle_element() -> void:
	var known: Array = []
	for e in Rpg.ELEMENTS:
		if skills.has(e):
			known.append(e)
	if known.is_empty():
		return
	element = known[(known.find(element) + 1) % known.size()]
	stats_changed.emit()


func _cast_spell() -> void:
	if not skills.has(element):
		return
	var cost := spell_cost(element)
	if mp < cost or not _attack.is_empty() or _dodge_time > 0.0 or not is_on_floor():
		return
	mp -= cost
	stats_changed.emit()
	_attack = {"anim": "Spellcast_Shoot", "dmg": 0, "hit": 0.45, "speed": 1.3, "range": 0, "arc": 0}
	_attack_time = 0.0
	_attack_length = _anim.get_animation("Spellcast_Shoot").length / 1.3
	_attack_hit_done = true
	_anim.play("Spellcast_Shoot", 0.08, 1.3)
	var aim := _aim_direction()
	_model.rotation.y = atan2(aim.x, aim.z)
	_since_combat = 0.0
	await get_tree().create_timer(_attack_length * 0.45).timeout
	if not is_alive():
		return
	var color: Color = Rpg.MAGIC[element].color
	var power := total_atk()
	match element:
		"fuego":
			_spell_orb(aim, color, 26 + power, 20.0, 1.3, true, 0.28)
		"agua":
			var heal := 30 + level * 6
			hp = mini(max_hp, hp + heal)
			Fx.number(get_parent(), global_position + Vector3(0, 2.2, 0), "+%d" % heal, Color(0.4, 1.0, 0.6), 56)
			_burst(color, 2.5)
			stats_changed.emit()
		"viento":
			for i in 3:
				_spell_orb((Basis(Vector3.UP, (i - 1) * 0.22) * aim).normalized(), color, 12 + power / 2, 30.0, 0.9, false, 0.16)
		"tierra":
			_burst(color, 5.5)
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if enemy.is_alive() and enemy.global_position.distance_to(global_position) < 6.0:
					enemy.take_hit(22 + power, global_position, true, 10.0)
		"luz":
			_spell_orb(aim, color, int((40 + power) * 1.5), 34.0, 1.2, true, 0.35)
		"oscuridad":
			var orb := _spell_orb(aim, color, 22 + power, 18.0, 1.1, false, 0.3)
			orb.drain = 0.5


func _spell_orb(dir: Vector3, color: Color, damage: int, speed: float, radius: float, stagger: bool, size: float) -> Node3D:
	var p := Node3D.new()
	p.set_script(PROJECTILE)
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = size
	sphere.height = size * 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere.material = mat
	ball.mesh = sphere
	p.add_child(ball)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.0
	light.omni_range = 5.0
	p.add_child(light)
	get_parent().add_child(p)
	p.global_position = global_position + Vector3(0, 1.4, 0) + dir * 0.8
	p.velocity = dir * speed
	p.damage = damage
	p.radius = radius
	p.stagger = stagger
	p.life = 2.0
	p.source = self
	return p


## Anillo de luz que se expande alrededor del héroe (sanación, temblor).
func _burst(color: Color, radius: float) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	torus.material = mat
	ring.mesh = torus
	get_parent().add_child(ring)
	ring.global_position = global_position + Vector3(0, 0.3, 0)
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * radius, 0.45)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tween.chain().tween_callback(ring.queue_free)


# --- Inventario, oro, equipo y misiones ------------------------------------

func total_atk() -> int:
	return atk + forge * 4 + (4 if skills.has("fuerza1") else 0)


func add_item(id: String, count := 1) -> void:
	items[id] = int(items.get(id, 0)) + count
	if items[id] <= 0:
		items.erase(id)
	stats_changed.emit()


func item_count(id: String) -> int:
	return int(items.get(id, 0))


func add_gold(amount: int) -> void:
	gold += amount
	stats_changed.emit()


func use_potion(kind: String) -> void:
	if item_count(kind) <= 0 or not is_alive():
		return
	if kind == "pocion":
		if hp >= max_hp:
			return
		hp = mini(max_hp, hp + 60)
		Fx.number(get_parent(), global_position + Vector3(0, 2.2, 0), "+60", Color(0.4, 1.0, 0.6), 52)
	else:
		if mp >= max_mp:
			return
		mp = minf(max_mp, mp + 40)
		Fx.number(get_parent(), global_position + Vector3(0, 2.2, 0), "+40 MP", Color(0.5, 0.7, 1.0), 48)
	add_item(kind, -1)


## Aprende una habilidad del árbol si hay puntos y se cumple el requisito.
func learn_skill(id: String) -> bool:
	if skills.has(id) or skill_points <= 0:
		return false
	for sk in Rpg.SKILLS:
		if sk[0] == id:
			if sk[3] != "" and not skills.has(sk[3]):
				return false
			skills[id] = true
			skill_points -= 1
			_apply_skill(id)
			stats_changed.emit()
			return true
	return false


func _apply_skill(id: String) -> void:
	match id:
		"vida1":
			max_hp += 25
			hp += 25
		"vida2":
			max_hp += 40
			hp += 40
		"mana1":
			max_mp += 20
			mp += 20


## Avisa a las misiones activas de un enemigo derrotado.
func on_enemy_killed(kind: String) -> void:
	for id in quests:
		var q := Rpg.quest(id)
		if q.type == "kill" and (q.target == kind or (q.target == "any" and kind != "boss")):
			quests[id] = mini(int(q.count), int(quests[id]) + 1)
	stats_changed.emit()


func quest_progress(id: String) -> int:
	var q := Rpg.quest(id)
	if q.type == "gather":
		return mini(item_count(q.target), int(q.count))
	return int(quests.get(id, 0))


func quest_ready(id: String) -> bool:
	return quest_progress(id) >= int(Rpg.quest(id).count)


func _start_dodge() -> void:
	if _dodge_cooldown > 0.0 or not is_on_floor() or _hurt_time > 0.0:
		return
	if not _attack.is_empty() and _attack_time < _attack_length * 0.5:
		return
	_attack = {}
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input.length() > 0.2:
		_dodge_dir = (Basis(Vector3.UP, _yaw) * Vector3(input.x, 0, input.y)).normalized()
	else:
		_dodge_dir = -Vector3(sin(_model.rotation.y), 0, cos(_model.rotation.y))
	_dodge_time = DODGE_TIME
	_dodge_cooldown = DODGE_TIME + (0.1 if skills.has("esquiva") else 0.25)
	# Elige la animación según hacia dónde rueda respecto a donde mira.
	var fwd := Vector3(sin(_model.rotation.y), 0, cos(_model.rotation.y))
	var right := fwd.cross(Vector3.UP)
	var f := fwd.dot(_dodge_dir)
	var r := right.dot(_dodge_dir)
	var anim_name := "Dodge_Forward"
	if absf(f) >= absf(r):
		anim_name = "Dodge_Forward" if f > 0 else "Dodge_Backward"
	else:
		anim_name = "Dodge_Right" if r > 0 else "Dodge_Left"
	_anim.play(anim_name, 0.05, _anim.get_animation(anim_name).length / DODGE_TIME)


## Recibe un golpe enemigo. La esquiva lo evita; el bloqueo lo reduce.
func take_hit(damage: int, from: Vector3, _attacker: Node3D = null) -> void:
	if not is_alive() or _dodge_time > 0.0:
		return
	_since_combat = 0.0
	var amount := maxi(1, damage - total_def() / 2)
	var away := global_position - from
	away.y = 0
	var fwd := Vector3(sin(_model.rotation.y), 0, cos(_model.rotation.y))
	if _blocking and away.length() > 0.01 and fwd.dot(-away.normalized()) > 0.2:
		amount = maxi(0, int(round(amount * (1.0 - float(Weapons.DATA[weapon].block)))))
		_anim.play("Block_Hit", 0.05)
		velocity += away.normalized() * 3.0
		Fx.number(get_parent(), global_position + Vector3(0, 2.1, 0), "Bloqueo" if amount == 0 else str(amount), Color(0.6, 0.85, 1.0), 48)
	else:
		_attack = {}
		_hurt_time = 0.3
		_anim.play("Hit_A", 0.05)
		if away.length() > 0.01:
			velocity += away.normalized() * 5.0
		Fx.number(get_parent(), global_position + Vector3(0, 2.1, 0), str(amount), Color(1.0, 0.35, 0.3))
	hp = maxi(0, hp - amount)
	stats_changed.emit()
	if hp <= 0:
		_die()


func _die() -> void:
	_attack = {}
	target = null
	_anim.play("Death_A", 0.05)
	_dead_time = 3.5
	died.emit()


func _revive() -> void:
	global_position = spawn_point
	velocity = Vector3.ZERO
	hp = max_hp
	mp = max_mp
	_anim.play("Idle")
	stats_changed.emit()


func _regen(delta: float) -> void:
	if not is_alive():
		return
	_since_combat += delta
	var changed := false
	if mp < max_mp:
		mp = minf(max_mp, mp + 2.5 * delta)
		changed = true
	if _since_combat > 6.0 and hp < max_hp:
		hp = mini(max_hp, hp + maxi(1, int(max_hp * 0.04 * delta + randf())))
		changed = true
	if changed:
		stats_changed.emit()


func gain_exp(amount: int, where: Vector3, from_kill := true) -> void:
	exp_points += amount
	if from_kill:
		kills += 1
	Fx.number(get_parent(), where, "+%d EXP" % amount, Color(0.55, 0.9, 1.0), 44)
	while exp_points >= exp_to_next():
		exp_points -= exp_to_next()
		level += 1
		max_hp += 15
		max_mp += 8
		atk += 3
		def += 2
		hp = max_hp
		mp = max_mp
		skill_points += 1
		leveled_up.emit(level)
	stats_changed.emit()


# --- Fijar objetivo --------------------------------------------------------

func _toggle_lock() -> void:
	if target:
		target = null
		return
	var best: Node3D = null
	var best_score := INF
	var cam_fwd := Basis(Vector3.UP, _yaw) * Vector3(0, 0, -1)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.is_alive():
			continue
		var d: Vector3 = enemy.global_position - global_position
		d.y = 0
		if d.length() > LOCK_RANGE:
			continue
		var score := d.length() * (1.0 + cam_fwd.angle_to(d.normalized()) * 1.5)
		if score < best_score:
			best_score = score
			best = enemy
	target = best


func _update_lock(delta: float) -> void:
	if target == null:
		return
	if not is_instance_valid(target) or not target.is_alive() or target.global_position.distance_to(global_position) > LOCK_RANGE + 6.0:
		target = null
		return
	var d := target.global_position - global_position
	var wanted_yaw := atan2(-d.x, -d.z)
	_yaw = lerp_angle(_yaw, wanted_yaw, 1.0 - exp(-6.0 * delta))
