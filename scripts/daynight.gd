extends Node
## Ciclo de día y noche: mueve el sol, cambia el color del cielo, la luz y la
## niebla. Un día completo dura DAY_SECONDS segundos reales.

const DAY_SECONDS := 960.0

var sun: DirectionalLight3D
var env: Environment
var sky: ProceduralSkyMaterial
## Hora del día de 0 a 24 y número de día desde que despertó el héroe.
var time := 8.0
var day := 1
## Dentro de la mazmorra: sin sol ni cielo, solo antorchas.
var indoors := false

const SKY_DAY := Color(0.22, 0.48, 0.92)
const SKY_NIGHT := Color(0.03, 0.05, 0.16)
const HORIZON_DAY := Color(0.70, 0.85, 1.0)
const HORIZON_NIGHT := Color(0.10, 0.13, 0.28)
const HORIZON_DUSK := Color(1.0, 0.62, 0.38)


func _ready() -> void:
	add_to_group("world_clock")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--time="):
			time = float(arg.trim_prefix("--time="))


func _process(delta: float) -> void:
	time += delta * 24.0 / DAY_SECONDS
	if time >= 24.0:
		time -= 24.0
		day += 1
	apply()


func clock_text() -> String:
	var h := int(time)
	var m := int((time - h) * 60.0)
	return "Día %d · %02d:%02d" % [day, h, m]


func is_night() -> bool:
	return time < 5.5 or time > 19.5


func apply() -> void:
	if sun == null:
		return
	if indoors:
		sun.light_energy = 0.05
		sky.sky_top_color = Color(0.01, 0.01, 0.02)
		sky.sky_horizon_color = Color(0.02, 0.02, 0.03)
		sky.ground_horizon_color = sky.sky_horizon_color
		env.ambient_light_energy = 0.12
		env.fog_light_color = Color(0.02, 0.02, 0.04)
		env.tonemap_exposure = 1.1
		return
	# 0 al amanecer (6h), 1 al anochecer (18h).
	var phase := (time - 6.0) / 12.0
	var light := clampf(sin(phase * PI), -1.0, 1.0)
	var daylight := smoothstep(-0.12, 0.25, light)
	var dusk := clampf(1.0 - absf(light) / 0.3, 0.0, 1.0) * (1.0 if light > -0.15 else 0.0)

	if light > 0.0:
		sun.rotation_degrees = Vector3(-(8.0 + light * 62.0), -35.0 + (time - 12.0) * 12.0, 0)
		sun.light_color = Color(1.0, 0.96, 0.88).lerp(Color(1.0, 0.62, 0.38), dusk)
		sun.light_energy = lerpf(0.25, 0.85, daylight)
	else:
		# De noche la misma luz hace de luna: fría, tenue y alta.
		sun.rotation_degrees = Vector3(-50.0, 30.0, 0)
		sun.light_color = Color(0.55, 0.65, 1.0)
		sun.light_energy = 0.22

	sky.sky_top_color = SKY_NIGHT.lerp(SKY_DAY, daylight)
	var horizon := HORIZON_NIGHT.lerp(HORIZON_DAY, daylight)
	sky.sky_horizon_color = horizon.lerp(HORIZON_DUSK, dusk * 0.8)
	sky.ground_horizon_color = sky.sky_horizon_color
	env.ambient_light_energy = lerpf(0.22, 0.4, daylight)
	env.fog_light_color = Color(0.72, 0.84, 1.0).lerp(Color(0.12, 0.15, 0.3), 1.0 - daylight).lerp(HORIZON_DUSK, dusk * 0.4)
	env.tonemap_exposure = lerpf(1.05, 0.8, daylight)
