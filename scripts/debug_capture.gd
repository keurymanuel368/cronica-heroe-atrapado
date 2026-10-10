extends Node
## Solo para pruebas: si se lanza con `-- --capture=ruta.png`, guarda una
## captura de pantalla tras unos segundos y cierra el juego.

var _path := ""
var _time := 0.0
var _delay := 4.0
## Pulsaciones programadas: [segundo, acción].
var _taps: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			_path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--press="):
			for action in arg.trim_prefix("--press=").split(","):
				Input.action_press.call_deferred(action)
		elif arg.begins_with("--tap="):
			for item in arg.trim_prefix("--tap=").split(","):
				var parts := item.split("@")
				_taps.append([float(parts[1]), parts[0]])
		elif arg.begins_with("--hold="):
			for item in arg.trim_prefix("--hold=").split(","):
				var parts := item.split("@")
				_taps.append([float(parts[1]), parts[0], true])
		elif arg.begins_with("--capture-delay="):
			_delay = float(arg.trim_prefix("--capture-delay="))
	if _path == "":
		queue_free()


func _process(delta: float) -> void:
	_time += delta
	for tap in _taps.duplicate():
		if _time >= tap[0]:
			_taps.erase(tap)
			if tap.size() > 2:
				Input.action_press(tap[1])
				continue
			for pressed in [true, false]:
				var e := InputEventAction.new()
				e.action = tap[1]
				e.pressed = pressed
				Input.parse_input_event(e)
	if _time >= _delay:
		get_viewport().get_texture().get_image().save_png(_path)
		get_tree().quit()
