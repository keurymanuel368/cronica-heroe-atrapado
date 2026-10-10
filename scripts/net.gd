extends Node
## Cooperativo en grupo (hasta 4 jugadores). Uno crea la partida (anfitrión)
## y los demás se unen con su IP. El anfitrión manda en el mundo: enemigos,
## jefes, historia y hora del día. Cada jugador controla a su héroe y lleva
## su propio nivel y equipo; la EXP y el oro de cada enemigo se reparten
## a todo el grupo.

const PUPPET := preload("res://scripts/puppet.gd")
const ENEMY := preload("res://scripts/enemy.gd")
const PORT := 24565
const MAX_PLAYERS := 4
const SEND_RATE := 0.066
const ENEMY_RATE := 0.1

var main: Node
var player: Node
var player_name := "Héroe"
var _puppets: Dictionary = {}
var _send_timer := 0.0
var _enemy_timer := 0.0
var _clock_timer := 0.0
var _next_id := 0
var _enemies_by_id: Dictionary = {}
var _static_done := false

var _layer: CanvasLayer
var _panel: PanelContainer
var _status: Label
var _list: Label
var _name_edit: LineEdit
var _ip_edit: LineEdit
var _host_btn: Button
var _join_btn: Button
var _leave_btn: Button


func setup(m: Node, p: Node) -> void:
	main = m
	player = p
	name = "Net"
	add_to_group("net")
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)
	_build_panel()
	_static_done = true


func active() -> bool:
	return multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer) \
		and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func is_client() -> bool:
	return active() and not multiplayer.is_server()


func is_host() -> bool:
	return active() and multiplayer.is_server()


## Cada enemigo recibe un número para reconocerlo en todos los ordenadores.
func register_enemy(e: Node) -> void:
	if e.net_id < 0:
		if _static_done:
			# Enemigos que aparecen durante el juego (historia, invocaciones).
			_next_id = maxi(_next_id, 100000 if not is_client() else 500000)
		e.net_id = _next_id
		_next_id += 1
	_enemies_by_id[e.net_id] = e
	if _static_done and is_host():
		_spawn_enemy.rpc(e.net_id, e.kind, e.home, e.tint, e.title)


## Kaito vencido: todo el grupo ve el final.
func final_defeated() -> void:
	if is_host():
		_final.rpc()


@rpc("authority", "reliable")
func _final() -> void:
	main.story().client_ending()


# --- Crear, unirse y salir ---------------------------------------------------

func host() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
		_status.text = "No se pudo crear la partida (¿ya hay una abierta?)."
		return
	multiplayer.multiplayer_peer = peer
	_status.text = "Partida creada. Tus amigos deben unirse con una de estas IP:\n" + "\n".join(_my_ips())
	_refresh_buttons()


func join(ip: String) -> void:
	ip = ip.strip_edges()
	if ip == "":
		_status.text = "Escribe la IP del anfitrión."
		return
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		_status.text = "No se pudo conectar a %s." % ip
		return
	multiplayer.multiplayer_peer = peer
	_status.text = "Conectando con %s..." % ip
	_refresh_buttons()


func leave() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	for id in _puppets.keys():
		_remove_puppet(id)
	_status.text = "Jugando solo."
	_refresh_buttons()


func _on_connected() -> void:
	_status.text = "¡Conectado al grupo! El mundo y la historia son los del anfitrión."
	main.hud_message("Te uniste al grupo.")
	_refresh_buttons()


func _on_failed() -> void:
	_status.text = "No se pudo conectar. Revisa la IP y que el anfitrión haya creado la partida."
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_refresh_buttons()


func _on_server_gone() -> void:
	main.hud_message("El anfitrión cerró la partida. Sigues jugando solo.")
	leave()


func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		main.hud_message("Un amigo se unió al grupo.")
		_clock_sync.rpc_id(id, main._clock.time, main._clock.day)
		for eid in _enemies_by_id:
			var e = _enemies_by_id[eid]
			if eid >= 100000 and is_instance_valid(e) and e.is_alive():
				_spawn_enemy.rpc_id(id, eid, e.kind, e.home, e.tint, e.title)


func _on_peer_disconnected(id: int) -> void:
	_remove_puppet(id)
	main.hud_message("Un jugador salió del grupo.")


func _remove_puppet(id: int) -> void:
	if _puppets.has(id):
		_puppets[id].queue_free()
		_puppets.erase(id)


func _my_ips() -> Array:
	var out: Array = []
	for ip in IP.get_local_addresses():
		if ip.contains(":") or ip.begins_with("127.") or ip.begins_with("169.254"):
			continue
		out.append(ip + ("   (Radmin VPN)" if ip.begins_with("26.") else ""))
	return out


# --- Envío periódico -----------------------------------------------------------

func _process(delta: float) -> void:
	if not active():
		return
	_send_timer -= delta
	if _send_timer <= 0.0:
		_send_timer = SEND_RATE
		var anim: AnimationPlayer = player._anim
		_player_state.rpc(player.global_position, player._model.rotation.y, anim.current_animation,
			anim.speed_scale, player.weapon, player.hp, player.max_hp, player.horse != null, player_name, multiplayer.get_unique_id() % 4)
	if multiplayer.is_server():
		_enemy_timer -= delta
		if _enemy_timer <= 0.0:
			_enemy_timer = ENEMY_RATE
			var states: Array = []
			for id in _enemies_by_id:
				var e = _enemies_by_id[id]
				if not is_instance_valid(e):
					continue
				states.append([id, e.global_position, e._model.rotation.y, e._anim.current_animation, e.hp, int(e._state)])
				if states.size() >= 12:
					_enemy_states.rpc(states)
					states = []
			if not states.is_empty():
				_enemy_states.rpc(states)
		_clock_timer -= delta
		if _clock_timer <= 0.0:
			_clock_timer = 5.0
			_clock_sync.rpc(main._clock.time, main._clock.day)
	_update_list()


@rpc("any_peer", "unreliable_ordered")
func _player_state(pos: Vector3, rot: float, anim: String, speed: float, w: String, hp: int, max_hp: int, riding: bool, name_: String, color: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not _puppets.has(id):
		var p := Node3D.new()
		p.set_script(PUPPET)
		p.peer_id = id
		p.color_index = color
		main.add_child(p)
		p.global_position = pos
		_puppets[id] = p
	_puppets[id].apply_state(pos, rot, anim, speed, w, hp, max_hp, riding, name_)


@rpc("authority", "unreliable_ordered")
func _enemy_states(states: Array) -> void:
	for s in states:
		var e = _enemies_by_id.get(s[0])
		if e and is_instance_valid(e):
			e.apply_net_state(s[1], s[2], s[3], s[4], s[5])


@rpc("authority", "reliable")
func _spawn_enemy(id: int, kind: String, home: Vector3, tint: Color, title: String) -> void:
	if _enemies_by_id.has(id):
		return
	var e := CharacterBody3D.new()
	e.set_script(ENEMY)
	e.kind = kind
	e.once = true
	e.tint = tint
	e.title = title
	e.net_id = id
	e.home = home
	e.position = home + Vector3(0, 0.5, 0)
	main.add_child(e)


@rpc("authority", "reliable")
func _clock_sync(time: float, day: int) -> void:
	main._clock.time = time
	main._clock.day = day


# --- Combate en grupo ----------------------------------------------------------

## Un jugador invitado golpea a un enemigo: el anfitrión aplica el daño.
func send_enemy_hit(e: Node, damage: int, from: Vector3, stagger: bool, push: float) -> void:
	_enemy_hit.rpc_id(1, e.net_id, damage, from, stagger, push)


@rpc("any_peer", "reliable")
func _enemy_hit(id: int, damage: int, from: Vector3, stagger: bool, push: float) -> void:
	var e = _enemies_by_id.get(id)
	if e and is_instance_valid(e):
		e.take_hit(damage, from, stagger, push)


## El anfitrión avisa al dueño del héroe golpeado.
func send_player_hit(peer: int, damage: int, from: Vector3) -> void:
	_player_hit.rpc_id(peer, damage, from)


@rpc("authority", "reliable")
func _player_hit(damage: int, from: Vector3) -> void:
	player.take_hit(damage, from)


## Recompensa compartida: todo el grupo gana EXP y oro por cada enemigo.
func enemy_died(e: Node, exp: int, gold: int) -> void:
	if is_host():
		_reward.rpc(e.net_id, exp, gold, e.kind, e.global_position)


@rpc("authority", "reliable")
func _reward(_id: int, exp: int, gold: int, kind: String, pos: Vector3) -> void:
	player.gain_exp(exp, pos + Vector3(0, 2.0, 0))
	player.on_enemy_killed(kind)
	player.add_gold(gold)


## Los orbes enemigos se ven en todas las pantallas; cada uno daña a su héroe.
func enemy_orb(start: Vector3, vel: Vector3, damage: int) -> void:
	if is_host():
		_orb.rpc(start, vel, damage)


@rpc("authority", "unreliable")
func _orb(start: Vector3, vel: Vector3, damage: int) -> void:
	var p := Node3D.new()
	p.set_script(preload("res://scripts/projectile.gd"))
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.3, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.2, 1.0)
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere.material = mat
	ball.mesh = sphere
	p.add_child(ball)
	main.add_child(p)
	p.global_position = start
	p.velocity = vel
	p.damage = damage
	p.hostile = true
	p.radius = 0.6
	p.life = 3.0


# --- Ventana del grupo (tecla P) -------------------------------------------

func toggle_panel() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_refresh_buttons()
	else:
		player_name = _name_edit.text.strip_edges() if _name_edit.text.strip_edges() != "" else "Héroe"
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func panel_open() -> bool:
	return _panel.visible


func _build_panel() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 6
	add_child(_layer)
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.45, 0.29, 0.16)
	sb.border_color = Color(0.26, 0.15, 0.07)
	sb.set_border_width_all(12)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 14
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -330
	_panel.offset_right = 330
	_panel.offset_top = -270
	_panel.offset_bottom = 270
	_panel.visible = false
	_layer.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	v.add_child(_text("JUGAR CON AMIGOS", 26, Color(1.0, 0.9, 0.65)))
	v.add_child(_text("Hasta 4 jugadores. Uno crea la partida y los demás se unen con su IP.\nSi no estáis en la misma casa, instalad todos Radmin VPN (gratis) y uníos a la misma red.", 14, Color(0.95, 0.88, 0.75)))
	var row := HBoxContainer.new()
	row.add_child(_text("Tu nombre:", 16, Color(1, 0.95, 0.85)))
	_name_edit = LineEdit.new()
	_name_edit.text = player_name
	_name_edit.custom_minimum_size.x = 260
	row.add_child(_name_edit)
	v.add_child(row)
	_host_btn = _button("Crear partida (anfitrión)")
	_host_btn.pressed.connect(func():
		player_name = _name_edit.text.strip_edges() if _name_edit.text.strip_edges() != "" else "Héroe"
		host())
	v.add_child(_host_btn)
	var row2 := HBoxContainer.new()
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "IP del anfitrión, por ejemplo 26.12.34.56"
	_ip_edit.custom_minimum_size.x = 380
	row2.add_child(_ip_edit)
	_join_btn = _button("Unirse")
	_join_btn.pressed.connect(func():
		player_name = _name_edit.text.strip_edges() if _name_edit.text.strip_edges() != "" else "Héroe"
		join(_ip_edit.text))
	row2.add_child(_join_btn)
	v.add_child(row2)
	_leave_btn = _button("Salir del grupo")
	_leave_btn.pressed.connect(leave)
	v.add_child(_leave_btn)
	_status = _text("Jugando solo.", 15, Color(1.0, 0.9, 0.6))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)
	_list = _text("", 15, Color(1, 0.95, 0.85))
	v.add_child(_list)
	var close := _button("Cerrar (P)")
	close.pressed.connect(toggle_panel)
	v.add_child(close)
	_refresh_buttons()


func _refresh_buttons() -> void:
	if _host_btn == null:
		return
	var on := active() or (multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer))
	_host_btn.disabled = on
	_join_btn.disabled = on
	_leave_btn.disabled = not on


func _update_list() -> void:
	if not _panel.visible:
		return
	var names: Array = ["%s (tú)" % player_name]
	for id in _puppets:
		names.append(_puppets[id].player_name)
	_list.text = "Grupo (%d/%d):  %s" % [names.size(), MAX_PLAYERS, ",  ".join(names)]


func _text(t: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", 17)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.36, 0.22, 0.11, 0.95) if state != "disabled" else Color(0.24, 0.17, 0.12, 0.8)
		if state == "hover":
			s.bg_color = Color(0.52, 0.33, 0.15, 0.98)
		s.border_color = Color(0.78, 0.58, 0.3, 0.8)
		s.set_border_width_all(2)
		s.set_corner_radius_all(4)
		s.content_margin_left = 12
		s.content_margin_right = 12
		s.content_margin_top = 6
		s.content_margin_bottom = 6
		b.add_theme_stylebox_override(state, s)
	return b
