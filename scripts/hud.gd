extends CanvasLayer
## Interfaz de combate: barras de vida, maná y EXP, arma actual, avisos del
## Sistema, ventana de estado, marcador del objetivo fijado y elección de arma.

const Weapons := preload("res://scripts/weapons.gd")

const GOLD := Color(0.91, 0.76, 0.42)
const RUNE := Color(0.44, 0.83, 1.0)
const TEXT := Color(0.91, 0.95, 1.0)

var player: Node

var _level_label: Label
var _hp_bar: ProgressBar
var _mp_bar: ProgressBar
var _exp_bar: ProgressBar
var _hp_text: Label
var _mp_text: Label
var _weapon_label: Label
var _toast: PanelContainer
var _toast_label: Label
var _toast_time := 0.0
var _status: PanelContainer
var _status_label: Label
var _picker: PanelContainer
var _marker: Label3D


func setup(p: Node) -> void:
	player = p
	_build_bars()
	_build_weapon_box()
	_build_toast()
	_build_status()
	_build_marker()
	player.stats_changed.connect(_refresh)
	player.leveled_up.connect(func(lv): show_system("¡Subiste al nivel %d!\nVida, maná, ataque y defensa aumentaron." % lv))
	player.died.connect(func(): show_system("Has caído en combate.\nEl Sistema te devuelve al cristal del despertar."))
	player.weapon_changed.connect(func(_id): _refresh())
	_refresh()
	var skip := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--weapon="):
			player.set_weapon(arg.trim_prefix("--weapon="))
			skip = true
		elif arg.begins_with("--capture"):
			skip = true
	if not skip:
		_build_picker()


func _style(alpha := 0.78) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.16, 0.31, alpha)
	sb.border_color = Color(0.44, 0.83, 1.0, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.shadow_color = Color(0.44, 0.83, 1.0, 0.25)
	sb.shadow_size = 6
	return sb


func _label(text: String, size: int, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.1))
	l.add_theme_constant_override("outline_size", 4)
	return l


func _bar(color: Color, width: float, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(width, height)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.05, 0.12, 0.85)
	bg.border_color = Color(0.44, 0.83, 1.0, 0.5)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	return bar


func _build_bars() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(24, 92)
	box.add_theme_constant_override("separation", 4)
	_level_label = _label("Nv 1", 20, GOLD)
	box.add_child(_level_label)
	for kind in ["hp", "mp"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var tag := _label("VIDA" if kind == "hp" else "MANÁ", 14, RUNE)
		tag.custom_minimum_size.x = 48
		row.add_child(tag)
		var bar := _bar(Color(0.86, 0.22, 0.25) if kind == "hp" else Color(0.25, 0.5, 1.0), 260, 16)
		row.add_child(bar)
		var txt := _label("", 14)
		row.add_child(txt)
		box.add_child(row)
		if kind == "hp":
			_hp_bar = bar
			_hp_text = txt
		else:
			_mp_bar = bar
			_mp_text = txt
	var exp_row := HBoxContainer.new()
	exp_row.add_theme_constant_override("separation", 8)
	var exp_tag := _label("EXP", 14, RUNE)
	exp_tag.custom_minimum_size.x = 48
	exp_row.add_child(exp_tag)
	_exp_bar = _bar(GOLD, 260, 8)
	_exp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	exp_row.add_child(_exp_bar)
	box.add_child(exp_row)
	add_child(box)


func _build_weapon_box() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(0.7))
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -330
	panel.offset_right = -24
	panel.offset_top = -92
	panel.offset_bottom = -24
	var v := VBoxContainer.new()
	v.add_child(_label("ARMA", 13, RUNE))
	_weapon_label = _label("", 18, GOLD)
	v.add_child(_weapon_label)
	panel.add_child(v)
	add_child(panel)


func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", _style())
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.offset_left = -300
	_toast.offset_right = 300
	_toast.offset_top = 210
	var v := VBoxContainer.new()
	var head := _label("【 SISTEMA 】", 16, RUNE)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	_toast_label = _label("", 18)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_toast_label)
	_toast.add_child(v)
	_toast.visible = false
	add_child(_toast)


func show_system(text: String, seconds := 4.0) -> void:
	_toast_label.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast_time = seconds


func _build_status() -> void:
	_status = PanelContainer.new()
	_status.add_theme_stylebox_override("panel", _style(0.88))
	_status.anchor_left = 0.5
	_status.anchor_right = 0.5
	_status.anchor_top = 0.5
	_status.anchor_bottom = 0.5
	_status.offset_left = -230
	_status.offset_right = 230
	_status.offset_top = -200
	_status.grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var head := _label("【 ESTADO 】", 22, RUNE)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	_status_label = _label("", 18)
	v.add_child(_status_label)
	var foot := _label("C para cerrar", 14, RUNE)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(foot)
	_status.add_child(v)
	_status.visible = false
	add_child(_status)


func _build_marker() -> void:
	_marker = Label3D.new()
	_marker.text = "▼"
	_marker.font_size = 72
	_marker.outline_size = 12
	_marker.modulate = Color(1.0, 0.85, 0.3)
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.no_depth_test = true
	_marker.pixel_size = 0.005
	_marker.visible = false
	player.get_parent().add_child.call_deferred(_marker)


## Al despertar, el Sistema pide elegir el arma del héroe.
func _build_picker() -> void:
	_picker = PanelContainer.new()
	_picker.add_theme_stylebox_override("panel", _style(0.9))
	_picker.anchor_left = 0.5
	_picker.anchor_right = 0.5
	_picker.anchor_top = 0.5
	_picker.anchor_bottom = 0.5
	_picker.offset_left = -340
	_picker.offset_right = 340
	_picker.offset_top = -170
	_picker.grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var head := _label("【 SISTEMA 】", 20, RUNE)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var msg := _label("Elige el arma con la que sobrevivirás en este mundo.", 18)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(msg)
	for i in Weapons.ORDER.size():
		var id: String = Weapons.ORDER[i]
		var w: Dictionary = Weapons.DATA[id]
		var b := Button.new()
		b.text = "%d.  %s  —  %s" % [i + 1, w.name, w.desc]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 17)
		b.add_theme_stylebox_override("normal", _style(0.6))
		var hover := _style(0.95)
		hover.border_color = GOLD
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", hover)
		b.add_theme_stylebox_override("focus", hover)
		b.pressed.connect(_pick.bind(id))
		v.add_child(b)
	var note := _label("Puedes cambiar con las teclas 1 a 4 mientras sea un prototipo.", 14, RUNE)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(note)
	_picker.add_child(v)
	add_child(_picker)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS


func _pick(id: String) -> void:
	player.set_weapon(id)
	_picker.queue_free()
	_picker = null
	get_tree().paused = false
	show_system("Arma elegida: %s.\nVe a la arena del este y derrota a los esqueletos." % Weapons.DATA[id].name, 5.0)


func _unhandled_input(event: InputEvent) -> void:
	if _picker:
		for i in Weapons.ORDER.size():
			if event is InputEventKey and event.pressed and event.physical_keycode == KEY_1 + i:
				_pick(Weapons.ORDER[i])
				get_viewport().set_input_as_handled()
				return
		return
	if event.is_action_pressed("status"):
		_status.visible = not _status.visible
		_refresh()


func _refresh() -> void:
	if player == null:
		return
	_level_label.text = "Nv %d   ·   Héroe atrapado" % player.level
	_hp_bar.max_value = player.max_hp
	_hp_bar.value = player.hp
	_hp_text.text = "%d / %d" % [player.hp, player.max_hp]
	_mp_bar.max_value = player.max_mp
	_mp_bar.value = player.mp
	_mp_text.text = "%d / %d" % [int(player.mp), player.max_mp]
	_exp_bar.max_value = player.exp_to_next()
	_exp_bar.value = player.exp_points
	var w: Dictionary = Weapons.DATA[player.weapon]
	_weapon_label.text = "%s   (1-4 cambiar)" % w.name
	if _status.visible:
		_status_label.text = "\n".join([
			"Nombre:  Héroe atrapado",
			"Nivel:  %d" % player.level,
			"EXP:  %d / %d" % [player.exp_points, player.exp_to_next()],
			"Vida:  %d / %d" % [player.hp, player.max_hp],
			"Maná:  %d / %d" % [int(player.mp), player.max_mp],
			"Ataque:  %d" % player.atk,
			"Defensa:  %d  (+%d del arma)" % [player.total_def(), int(w.defense)],
			"Arma:  %s" % w.name,
			"Bloqueo:  %d%% del daño" % int(float(w.block) * 100),
			"Magia:  Bola de fuego (%d de maná)" % player.FIREBALL_COST,
			"Enemigos derrotados:  %d" % player.kills,
		])


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		if _toast_time < 1.0:
			_toast.modulate.a = max(_toast_time, 0.0)
		if _toast_time <= 0.0:
			_toast.visible = false
	if player and _marker.is_inside_tree():
		var t = player.target
		_marker.visible = t != null
		if t:
			_marker.global_position = t.global_position + Vector3(0, t.data.height + 1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.08, 0)
