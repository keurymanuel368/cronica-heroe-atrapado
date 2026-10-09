extends CharacterBody3D
## El héroe: se mueve en relación con la cámara, corre, salta y celebra.

const Toon := preload("res://scripts/toon.gd")
const ModelUtil := preload("res://scripts/model_util.gd")

const WALK_SPEED := 3.4
const RUN_SPEED := 7.2
const ACCELERATION := 14.0
const AIR_CONTROL := 0.35
const JUMP_VELOCITY := 7.0
const GRAVITY := 20.0
const TURN_SPEED := 12.0

const MOUSE_SENSITIVITY := 0.0025
const STICK_SENSITIVITY := 2.6
const PITCH_MIN := deg_to_rad(-60.0)
const PITCH_MAX := deg_to_rad(25.0)
const ZOOM_MIN := 2.5
const ZOOM_MAX := 10.0

const HERO_MODEL := "res://assets/kaykit/characters/Knight.glb"
## Piezas del modelo que se dejan visibles: espada de una mano y escudo redondo.
const VISIBLE_GEAR := ["1H_Sword", "Round_Shield"]
const ALL_GEAR := ["1H_Sword", "1H_Sword_Offhand", "2H_Sword", "Badge_Shield",
	"Rectangle_Shield", "Round_Shield", "Spike_Shield"]

const LOOPING := ["Idle", "Walking_A", "Running_A", "Jump_Idle"]

var spawn_point := Vector3.ZERO

var _model: Node3D
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


func _ready() -> void:
	_build_body()
	_build_camera()
	spawn_point = global_position


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
			gear.visible = gear_name in VISIBLE_GEAR
	var box := ModelUtil.local_aabb(_model)
	_model.scale = Vector3.ONE * (1.85 / box.size.y)
	Toon.apply(_model, 0.012)

	_anim = _model.find_child("AnimationPlayer", true, false)
	for anim_name in LOOPING:
		if _anim.has_animation(anim_name):
			_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_anim.play("Idle")


func _build_camera() -> void:
	_pivot = Node3D.new()
	_pivot.top_level = true
	add_child(_pivot)
	_arm = SpringArm3D.new()
	_arm.spring_length = _zoom
	_arm.margin = 0.3
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
		if event.button_index == MOUSE_BUTTON_LEFT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clamp(_zoom - 0.5, ZOOM_MIN, ZOOM_MAX)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clamp(_zoom + 0.5, ZOOM_MIN, ZOOM_MAX)
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_pitch = clamp(_pitch - event.relative.y * MOUSE_SENSITIVITY, PITCH_MIN, PITCH_MAX)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("jump"):
		_jump_requested = true
	elif event.is_action_pressed("cheer") and is_on_floor():
		_play_once("Cheer")


func _physics_process(delta: float) -> void:
	_update_camera(delta)

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (Basis(Vector3.UP, _yaw) * Vector3(input.x, 0, input.y))
	direction.y = 0
	if direction.length() > 1.0:
		direction = direction.normalized()

	var running := Input.is_action_pressed("run")
	var target_speed := RUN_SPEED if running else WALK_SPEED
	var target := direction * target_speed
	var control := 1.0 if is_on_floor() else AIR_CONTROL

	if _locked_anim_time > 0.0:
		_locked_anim_time -= delta
		target = Vector3.ZERO
		if direction.length() > 0.1:
			_locked_anim_time = 0.0

	velocity.x = move_toward(velocity.x, target.x, ACCELERATION * control * delta * target_speed)
	velocity.z = move_toward(velocity.z, target.z, ACCELERATION * control * delta * target_speed)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if _jump_requested and is_on_floor():
		velocity.y = JUMP_VELOCITY
		_locked_anim_time = 0.0
		_play("Jump_Start", 0.05)
	_jump_requested = false

	move_and_slide()

	var flat := Vector3(velocity.x, 0, velocity.z)
	if flat.length() > 0.2:
		var facing := atan2(flat.x, flat.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, facing, TURN_SPEED * delta)

	_update_animation(flat.length())
	_was_on_floor = is_on_floor()

	if global_position.y < -25.0:
		global_position = spawn_point
		velocity = Vector3.ZERO


func _update_camera(delta: float) -> void:
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	_yaw -= stick.x * STICK_SENSITIVITY * delta
	_pitch = clamp(_pitch - stick.y * STICK_SENSITIVITY * delta, PITCH_MIN, PITCH_MAX)
	_pivot.global_position = _pivot.global_position.lerp(global_position + Vector3(0, 1.6, 0), 1.0 - exp(-14.0 * delta))
	_pivot.rotation = Vector3(_pitch, _yaw, 0)
	_arm.spring_length = lerp(_arm.spring_length, _zoom, 1.0 - exp(-10.0 * delta))


func _update_animation(speed: float) -> void:
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
		_play("Idle", 0.2)
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
