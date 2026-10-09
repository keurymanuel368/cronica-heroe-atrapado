extends Node
## Solo para pruebas: si se lanza con `-- --capture=ruta.png`, guarda una
## captura de pantalla tras unos segundos y cierra el juego.

var _path := ""
var _time := 0.0
var _delay := 4.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			_path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--capture-delay="):
			_delay = float(arg.trim_prefix("--capture-delay="))
	if _path == "":
		queue_free()


func _process(delta: float) -> void:
	_time += delta
	if _time >= _delay:
		get_viewport().get_texture().get_image().save_png(_path)
		get_tree().quit()
