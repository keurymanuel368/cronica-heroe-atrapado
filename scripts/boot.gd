extends Control
## Pantalla de inicio. Busca en GitHub la versión más nueva del juego, la
## descarga si hace falta y la carga antes de entrar al mundo. Así cada
## actualización llega sola al abrir el juego, sin descargar otro .exe.

const BASE_URL := "https://raw.githubusercontent.com/keurymanuel368/cronica-heroe-atrapado/descargas/"
const LOCAL_PACK := "user://juego.pck"
const LOCAL_VERSION := "user://version.txt"
const GAME_SCENE := "res://scenes/main.tscn"
const CHECK_TIMEOUT := 6.0
const DOWNLOAD_TIMEOUT := 180.0

var _status: Label
var _bar: ProgressBar
var _http: HTTPRequest
var _built_in := 0
var _remote := 0
var _downloading := false
var _base_url := BASE_URL


func _ready() -> void:
	_build_ui()
	_built_in = _read_int("res://version.txt")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--update-url="):
			_base_url = arg.trim_prefix("--update-url=")
	_http = HTTPRequest.new()
	_http.timeout = CHECK_TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_on_version)
	_say("Buscando actualizaciones…")
	var err := _http.request(_base_url + "version.txt?t=%d" % Time.get_unix_time_from_system())
	if err != OK:
		_start_game()


func _process(_delta: float) -> void:
	if _downloading and _http.get_body_size() > 0:
		_bar.value = 100.0 * _http.get_downloaded_bytes() / _http.get_body_size()


func _on_version(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_http.request_completed.disconnect(_on_version)
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_say("Sin conexión. Jugando con la versión guardada.")
		_start_game()
		return
	_remote = body.get_string_from_utf8().strip_edges().to_int()
	var cached := _read_int(LOCAL_VERSION) if FileAccess.file_exists(LOCAL_PACK) else 0
	if _remote <= max(_built_in, cached):
		_start_game()
		return
	_say("Descargando la versión %d…" % _remote)
	_bar.visible = true
	_downloading = true
	_http.timeout = DOWNLOAD_TIMEOUT
	_http.download_file = LOCAL_PACK + ".tmp"
	_http.request_completed.connect(_on_pack)
	if _http.request(_base_url + "juego.pck?v=%d" % _remote) != OK:
		_start_game()


func _on_pack(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_downloading = false
	var tmp := LOCAL_PACK + ".tmp"
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LOCAL_PACK))
		DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(LOCAL_PACK))
		var f := FileAccess.open(LOCAL_VERSION, FileAccess.WRITE)
		f.store_string(str(_remote))
		f.close()
		_say("Actualización instalada.")
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		_say("No se pudo descargar. Jugando con la versión guardada.")
	_start_game()


func _start_game() -> void:
	var cached := _read_int(LOCAL_VERSION)
	if FileAccess.file_exists(LOCAL_PACK) and cached > _built_in:
		if not ProjectSettings.load_resource_pack(LOCAL_PACK, true):
			_say("La actualización guardada está dañada. Usando la versión base.")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(LOCAL_PACK))
	await get_tree().create_timer(0.4).timeout
	get_tree().change_scene_to_file(GAME_SCENE)


func _read_int(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	return FileAccess.get_file_as_string(path).strip_edges().to_int()


func _say(text: String) -> void:
	_status.text = text


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.06, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(560, 0)
	box.position = Vector2(-280, -70)
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	var title := Label.new()
	title.text = "CRÓNICA DEL HÉROE ATRAPADO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.91, 0.76, 0.42))
	box.add_child(title)
	var tag := Label.new()
	tag.text = "【 SISTEMA 】"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_color_override("font_color", Color(0.44, 0.83, 1.0))
	box.add_child(tag)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 18)
	box.add_child(_status)
	_bar = ProgressBar.new()
	_bar.visible = false
	_bar.custom_minimum_size = Vector2(0, 14)
	box.add_child(_bar)
