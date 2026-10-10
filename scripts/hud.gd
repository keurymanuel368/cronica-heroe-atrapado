extends CanvasLayer
## Interfaz de combate: barras de vida, maná y EXP, arma actual, avisos del
## Sistema, ventana de estado, marcador del objetivo fijado y elección de arma.

const Weapons := preload("res://scripts/weapons.gd")
const Rpg := preload("res://scripts/rpg.gd")

const GOLD := Color(0.91, 0.76, 0.42)
const RUNE := Color(1.0, 0.86, 0.55)
const TEXT := Color(1.0, 0.96, 0.88)

var player: Node
var main: Node

var _prompt: Label
var _dialog: PanelContainer
var _dialog_name: Label
var _dialog_text: Label
var _talking: Node = null
## Líneas de la charla actual (las de la historia si toca).
var _lines: Array = []
var _story_talk := false
## Diálogo de escena (sin personaje cerca): líneas y qué hacer al acabar.
var _scene_name := ""
var _scene_lines: Array = []
var _scene_done: Callable
var _scene_index := 0
var _missions_text := ""
var _chapter: Control
var _ending: Control
var _line := 0
var _zone: Label
var _zone_time := 0.0
var _clock_label: Label
var _boss_box: VBoxContainer
var _boss_bar: ProgressBar
var _boss_name: Label
var _tracker: Label
var _gold_label: Label

var _level_label: Label
var _hp_bar: ProgressBar
var _mp_bar: ProgressBar
var _exp_bar: ProgressBar
var _hp_text: Label
var _mp_text: Label
var _weapon_label: Label
var _special_label: Label
var _special_bar: ProgressBar
var _power_label: Label
var _power_bar: ProgressBar
var _toast: PanelContainer
var _toast_label: Label
var _toast_time := 0.0
var _status: PanelContainer
var _status_label: Label
var _picker: PanelContainer
var _marker: Label3D


func setup(p: Node, loaded := false) -> void:
	player = p
	_build_bars()
	_build_talk()
	_build_zone_and_clock()
	_build_boss_bar()
	_build_weapon_box()
	_build_toast()
	_build_status()
	_build_marker()
	player.stats_changed.connect(_refresh)
	player.leveled_up.connect(func(lv): show_system("¡Subiste al nivel %d!\nVida, maná, ataque y defensa aumentaron." % lv))
	player.died.connect(func(): show_system("Has caído en combate.\nEl Sistema te devuelve al cristal del despertar."))
	player.weapon_changed.connect(func(_id): _refresh())
	_refresh()
	var skip := loaded
	for arg in OS.get_cmdline_user_args():
		if arg == "--full-power":
			player.power = 100.0
		if arg.begins_with("--weapon="):
			player.set_weapon(arg.trim_prefix("--weapon="))
			skip = true
		elif arg.begins_with("--capture"):
			skip = true
	if not skip:
		_build_picker()


func _style(alpha := 0.78) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.12, 0.06, alpha)
	sb.border_color = Color(0.78, 0.58, 0.3, 0.95)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.shadow_color = Color(0, 0, 0, 0.45)
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
	bg.bg_color = Color(0.08, 0.05, 0.03, 0.85)
	bg.border_color = Color(0.78, 0.58, 0.3, 0.6)
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
	panel.offset_left = -470
	panel.offset_right = -24
	panel.offset_top = -24
	panel.offset_bottom = -24
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	if preload("res://scripts/platform.gd").is_touch():
		# En pantalla táctil la esquina derecha es de los botones.
		panel.anchor_left = 0.0
		panel.anchor_right = 0.0
		panel.anchor_top = 0.0
		panel.anchor_bottom = 0.0
		panel.offset_left = 24
		panel.offset_right = 380
		panel.offset_top = 200
		panel.offset_bottom = 200
		panel.grow_vertical = Control.GROW_DIRECTION_END
	var v := VBoxContainer.new()
	v.add_child(_label("ARMA", 13, RUNE))
	_weapon_label = _label("", 16, GOLD)
	v.add_child(_weapon_label)
	_special_label = _label("", 15, Color(1.0, 0.95, 0.85))
	v.add_child(_special_label)
	_special_bar = _bar(Color(0.45, 0.8, 1.0), 420, 7)
	v.add_child(_special_bar)
	_power_label = _label("", 15, Color(1.0, 0.85, 0.4))
	v.add_child(_power_label)
	_power_bar = _bar(Color(1.0, 0.75, 0.25), 420, 9)
	v.add_child(_power_bar)
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


func _build_talk() -> void:
	_prompt = _label("", 18, GOLD)
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_left = -300
	_prompt.offset_right = 300
	_prompt.offset_top = -250
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_prompt)

	_dialog = PanelContainer.new()
	_dialog.add_theme_stylebox_override("panel", _style(0.9))
	_dialog.anchor_left = 0.5
	_dialog.anchor_right = 0.5
	_dialog.anchor_top = 1.0
	_dialog.anchor_bottom = 1.0
	_dialog.offset_left = -420
	_dialog.offset_right = 420
	_dialog.offset_top = -210
	_dialog.offset_bottom = -40
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_dialog_name = _label("", 20, GOLD)
	v.add_child(_dialog_name)
	_dialog_text = _label("", 19)
	_dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_text.custom_minimum_size = Vector2(780, 70)
	v.add_child(_dialog_text)
	var hint := _label("F  continuar", 14, RUNE)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(hint)
	_dialog.add_child(v)
	_dialog.visible = false
	add_child(_dialog)


func _build_zone_and_clock() -> void:
	_zone = _label("", 34, GOLD)
	_zone.anchor_left = 0.5
	_zone.anchor_right = 0.5
	_zone.offset_left = -400
	_zone.offset_right = 400
	_zone.offset_top = 300
	_zone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone.add_theme_constant_override("outline_size", 8)
	_zone.visible = false
	add_child(_zone)
	_clock_label = _label("", 16, RUNE)
	_clock_label.anchor_left = 1.0
	_clock_label.anchor_right = 1.0
	_clock_label.offset_left = -260
	_clock_label.offset_right = -24
	_clock_label.offset_top = 250
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_clock_label)
	_gold_label = _label("", 18, GOLD)
	_gold_label.anchor_left = 1.0
	_gold_label.anchor_right = 1.0
	_gold_label.offset_left = -360
	_gold_label.offset_right = -24
	_gold_label.offset_top = 274
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_gold_label)
	_tracker = _label("", 16)
	_tracker.anchor_left = 1.0
	_tracker.anchor_right = 1.0
	_tracker.offset_left = -420
	_tracker.offset_right = -24
	_tracker.offset_top = 304
	_tracker.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_tracker)


func _build_boss_bar() -> void:
	_boss_box = VBoxContainer.new()
	_boss_box.anchor_left = 0.5
	_boss_box.anchor_right = 0.5
	_boss_box.anchor_top = 1.0
	_boss_box.anchor_bottom = 1.0
	_boss_box.offset_left = -360
	_boss_box.offset_right = 360
	_boss_box.offset_top = -120
	_boss_name = _label("", 20, Color(1.0, 0.6, 0.5))
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(_boss_name)
	_boss_bar = _bar(Color(0.8, 0.15, 0.2), 720, 18)
	_boss_box.add_child(_boss_bar)
	_boss_box.visible = false
	add_child(_boss_box)


func show_zone(text: String) -> void:
	_zone.text = "— %s —" % text
	_zone.visible = true
	_zone.modulate.a = 1.0
	_zone_time = 3.5


func _nearest_npc() -> Node:
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.can_talk(player.global_position):
			return npc
	return null


func _talk_next() -> void:
	if _talking == null:
		return
	var short: bool = not _story_talk and (_talking.talked or (_talking.action == "guild" and player.guild_member))
	var total: int = 1 if short else _lines.size()
	if _line >= total:
		var finished := _talking
		_talking = null
		_dialog.visible = false
		finished.talked = true
		if _story_talk and main:
			_story_talk = false
			main.story().on_talk_finished(finished.npc_name)
			if finished.action == "" or finished.action == "guild" and player.guild_member:
				return
		match finished.action:
			"rest":
				if main:
					main.rest()
				show_system("Dormiste hasta el amanecer.\nVida y maná al máximo. Partida guardada.", 4.0)
			"guild":
				if not player.guild_member:
					player.guild_member = true
					show_system("Registrado en el Gremio de Aventureros.\nRango F. Cumple misiones para subir de rango.", 5.0)
				main.open_menu("board")
			"shop":
				main.open_menu("shop")
			"smith":
				main.open_menu("smith")
		return
	_dialog_name.text = finished_name(_talking)
	_dialog_text.text = _lines[_line]
	_line += 1


## Diálogo de escena: un personaje habla aunque no haya nadie cerca (F avanza).
func show_dialog(speaker: String, lines: Array, on_done: Callable = Callable()) -> void:
	_talking = null
	_scene_name = speaker
	_scene_lines = lines.duplicate()
	_scene_index = 0
	_scene_done = on_done
	_dialog.visible = true
	_scene_next()


func _scene_next() -> void:
	if _scene_index >= _scene_lines.size():
		_scene_lines.clear()
		_dialog.visible = false
		if _scene_done.is_valid():
			_scene_done.call()
		return
	_dialog_name.text = _scene_name
	_dialog_text.text = _scene_lines[_scene_index] + "\n\n(F para continuar)"
	_scene_index += 1


## Tarjeta grande de capítulo nuevo en el centro de la pantalla.
func show_chapter(top: String, title: String) -> void:
	if _chapter:
		_chapter.queue_free()
	_chapter = VBoxContainer.new()
	_chapter.set_anchors_preset(Control.PRESET_CENTER)
	_chapter.offset_left = -400
	_chapter.offset_right = 400
	_chapter.offset_top = -140
	_chapter.offset_bottom = -20
	_chapter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var a := _label(top, 26, RUNE)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var b := _label(title, 52, GOLD)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("outline_size", 12)
	b.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.03))
	_chapter.add_child(a)
	_chapter.add_child(b)
	add_child(_chapter)
	var tw := _chapter.create_tween()
	_chapter.modulate.a = 0.0
	tw.tween_property(_chapter, "modulate:a", 1.0, 0.8)
	tw.tween_interval(3.5)
	tw.tween_property(_chapter, "modulate:a", 0.0, 1.2)
	tw.tween_callback(_chapter.queue_free)


## Pantalla final con créditos y botón para seguir explorando.
func show_ending() -> void:
	_ending = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.02, 0.05, 0.92)
	_ending.add_theme_stylebox_override("panel", sb)
	_ending.set_anchors_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	for item in [["FIN", 84, GOLD], ["Crónica del Héroe Atrapado", 34, RUNE],
			["Liberaste a Kaito, el Primer Héroe, y el Sistema te reconoce como el guardián de Aurelia.", 20, TEXT],
			["La puerta a tu mundo sigue abierta en el cristal. Pero Aurelia aún te necesita.", 20, TEXT],
			["Héroe: nivel %d  ·  %d enemigos derrotados  ·  %d misiones del gremio" % [player.level, player.kills, player.quests_done.size()], 18, GOLD],
			["Creado por Manuel y Claude", 18, TEXT], ["¡Gracias por jugar!", 26, GOLD]]:
		var l := _label(item[0], item[1], item[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	var b := Button.new()
	b.text = "Seguir explorando Aurelia"
	b.add_theme_font_size_override("font_size", 20)
	b.custom_minimum_size = Vector2(360, 54)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func():
		_ending.queue_free()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	v.add_child(b)
	_ending.add_child(v)
	add_child(_ending)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_ending.modulate.a = 0.0
	_ending.create_tween().tween_property(_ending, "modulate:a", 1.0, 2.0)


func finished_name(npc: Node) -> String:
	return npc.npc_name if npc.role == "" else "%s  ·  %s" % [npc.npc_name, npc.role]


func _unhandled_input(event: InputEvent) -> void:
	if _picker == null and event.is_action_pressed("interact") and player.is_alive():
		if not _scene_lines.is_empty():
			_scene_next()
		elif _talking:
			_talk_next()
		else:
			var npc := _nearest_npc()
			if npc:
				_talking = npc
				_line = 0
				_lines = npc.lines
				_story_talk = false
				if main and main.story():
					var story_lines: Array = main.story().lines_for(npc.npc_name)
					if not story_lines.is_empty():
						_lines = story_lines
						_story_talk = true
				_dialog.visible = true
				if main:
					main._help_panel.visible = false
				npc.on_talk_start()
				_talk_next()
			elif main and main.portal_prompt() != "":
				main.use_portal()
		get_viewport().set_input_as_handled()
		return
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


func _update_powers() -> void:
	if player == null or _special_bar == null:
		return
	var sp: Dictionary = Weapons.SPECIALS[player.weapon]
	var cd: float = player.special_cd
	_special_label.text = "[1] %s%s" % [sp.name, ("   %.0f s" % ceilf(cd)) if cd > 0.0 else "   ¡Listo!"]
	_special_bar.max_value = float(sp.cd)
	_special_bar.value = float(sp.cd) - cd
	var pw: float = player.power
	if player.awakened > 0.0:
		_power_label.text = "[2] ¡DESPERTAR ACTIVO!  %.0f s" % ceilf(player.awakened)
	elif pw >= 100.0:
		_power_label.text = "[2] Despertar del Héroe   ¡LISTO!"
	else:
		_power_label.text = "[2] Despertar del Héroe   %d%%" % int(pw)
	_power_bar.value = pw


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
	_weapon_label.text = "%s +%d   (3 cambiar)\nMagia: %s · %s  (R lanzar · T cambiar)\nPociones %d (Z)  ·  Éter %d (X)" % [w.name, player.forge,
		Rpg.MAGIC[player.element].name, Rpg.MAGIC[player.element].spell, player.item_count("pocion"), player.item_count("eter")]
	_gold_label.text = "%d de oro%s" % [player.gold, ("   ·   %d punto(s) de habilidad (V)" % player.skill_points) if player.skill_points > 0 else ""]
	var lines: Array = []
	for id in player.quests:
		var q := Rpg.quest(id)
		var ready: bool = player.quest_ready(id)
		lines.append("%s  %d/%d%s" % [q.name, player.quest_progress(id), q.count, "  ✔ entrégala en el gremio" if ready else ""])
	_missions_text = ("MISIONES\n" + "\n".join(lines)) if not lines.is_empty() else ""
	if _status.visible:
		_status_label.text = "\n".join([
			"Nombre:  Héroe atrapado",
			"Nivel:  %d" % player.level,
			"EXP:  %d / %d" % [player.exp_points, player.exp_to_next()],
			"Vida:  %d / %d" % [player.hp, player.max_hp],
			"Maná:  %d / %d" % [int(player.mp), player.max_mp],
			"Ataque:  %d" % player.total_atk(),
			"Defensa:  %d  (+%d del arma)" % [player.total_def(), int(w.defense)],
			"Arma:  %s" % w.name,
			"Bloqueo:  %d%% del daño" % int(float(w.block) * 100),
			"Magia:  %s (%d de maná)" % [Rpg.MAGIC[player.element].spell, player.spell_cost(player.element)],
			"Armadura:  %s" % Rpg.ARMOR_NAMES[player.armor],
			"Gremio:  %s" % (("rango %s  (%d puntos)" % [Rpg.rank_for(player.guild_points), player.guild_points]) if player.guild_member else "sin registrar"),
			"Oro:  %d" % player.gold,
			"Enemigos derrotados:  %d" % player.kills,
		])


func _process(delta: float) -> void:
	_update_powers()
	if main and main.story():
		_tracker.text = main.story().tracker_text() + ("\n\n" + _missions_text if _missions_text != "" else "")
	else:
		_tracker.text = _missions_text
	if _toast_time > 0.0:
		_toast_time -= delta
		if _toast_time < 1.0:
			_toast.modulate.a = max(_toast_time, 0.0)
		if _toast_time <= 0.0:
			_toast.visible = false
	if _zone_time > 0.0:
		_zone_time -= delta
		if _zone_time < 1.0:
			_zone.modulate.a = max(_zone_time, 0.0)
		if _zone_time <= 0.0:
			_zone.visible = false
	var clock := get_tree().get_first_node_in_group("world_clock")
	if clock:
		_clock_label.text = clock.clock_text() + ("  ·  Noche" if clock.is_night() else "")
	if player:
		var prompt := ""
		if not _scene_lines.is_empty():
			prompt = ""
		elif _talking:
			if not _talking.can_talk(player.global_position):
				_talking = null
				_dialog.visible = false
		else:
			var npc := _nearest_npc()
			if npc:
				prompt = "F  Hablar con %s" % npc.npc_name
			elif main and main.portal_prompt() != "":
				prompt = "F  " + main.portal_prompt()
		_prompt.text = prompt
		var boss: Node = null
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.is_boss() and e.is_alive() and e.is_engaged():
				boss = e
		_boss_box.visible = boss != null
		if boss:
			_boss_name.text = "%s  ·  Nv %d" % [boss.data.name, boss.data.level]
			_boss_bar.max_value = boss.max_hp
			_boss_bar.value = boss.hp
	if player and _marker.is_inside_tree():
		var t = player.target
		_marker.visible = t != null
		if t:
			_marker.global_position = t.global_position + Vector3(0, t.data.height + 1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.08, 0)
