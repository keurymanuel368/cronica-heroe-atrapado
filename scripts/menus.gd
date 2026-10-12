extends CanvasLayer
## Ventanas del Sistema que pausan el juego: tablón del gremio, tienda,
## herrería, árbol de habilidades e inventario.

const Rpg := preload("res://scripts/rpg.gd")
const Settings := preload("res://scripts/settings.gd")

const GOLD := Color(0.91, 0.76, 0.42)
const RUNE := Color(1.0, 0.86, 0.55)
const TEXT := Color(0.91, 0.95, 1.0)
const DIM := Color(0.86, 0.78, 0.64)

var player: Node
var main: Node
var _panel: PanelContainer
var _title: Label
var _info: Label
var _list: VBoxContainer
var _current := ""
## Desde dónde se abrieron los ajustes ("pause" o "title").
var settings_back := "pause"
var _system_style: StyleBoxFlat
var _wood_style: StyleBoxFlat


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.12, 0.25, 0.94)
	sb.border_color = RUNE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	sb.shadow_color = Color(0.44, 0.83, 1.0, 0.3)
	sb.shadow_size = 10
	_panel.add_theme_stylebox_override("panel", sb)
	_system_style = sb
	_wood_style = StyleBoxFlat.new()
	_wood_style.bg_color = Color(0.45, 0.29, 0.16)
	_wood_style.border_color = Color(0.26, 0.15, 0.07)
	_wood_style.set_border_width_all(12)
	_wood_style.set_corner_radius_all(4)
	_wood_style.content_margin_left = 26
	_wood_style.content_margin_right = 26
	_wood_style.content_margin_top = 18
	_wood_style.content_margin_bottom = 18
	_wood_style.shadow_color = Color(0, 0, 0, 0.5)
	_wood_style.shadow_size = 14
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -440
	_panel.offset_right = 440
	_panel.offset_top = -330
	_panel.offset_bottom = 330
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_title = _label("", 24, RUNE)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_title)
	_info = _label("", 16, GOLD)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_info)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	v.add_child(scroll)
	var close := _button("Cerrar  (Esc)")
	close.pressed.connect(close_menu)
	v.add_child(close)
	_panel.add_child(v)
	_panel.visible = false
	add_child(_panel)


func _sfx(name_: String, volume_db := 0.0) -> void:
	var audio := get_tree().get_first_node_in_group("audio")
	if audio:
		audio.ui(name_, volume_db)


func is_open() -> bool:
	return _panel.visible


func _label(text: String, size: int, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.1))
	l.add_theme_constant_override("outline_size", 4)
	return l


func _button(text: String, enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(_sfx.bind("ui_click"))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.36, 0.22, 0.11, 0.95) if state != "disabled" else Color(0.24, 0.17, 0.12, 0.8)
		if state == "hover" or state == "focus":
			sb.bg_color = Color(0.52, 0.33, 0.15, 0.98)
		sb.border_color = GOLD if state == "hover" else Color(0.78, 0.58, 0.3, 0.8)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		b.add_theme_stylebox_override(state, sb)
	return b


## Fila: texto a la izquierda y un botón opcional a la derecha.
func _row(title: String, desc: String, button_text := "", enabled := true, on_press: Callable = Callable(), title_color := TEXT) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_label(title, 18, title_color))
	if desc != "":
		var d := _label(desc, 14, DIM)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = 520
		v.add_child(d)
	h.add_child(v)
	if button_text != "":
		var b := _button(button_text, enabled)
		b.custom_minimum_size.x = 150
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if on_press.is_valid():
			b.pressed.connect(on_press)
		h.add_child(b)
	_list.add_child(h)
	_list.add_child(HSeparator.new())


func _section(text: String) -> void:
	_list.add_child(_label(text, 17, RUNE))


func open(kind: String) -> void:
	_current = kind
	_panel.add_theme_stylebox_override("panel", _wood_style)
	_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.65))
	refresh()
	if not _panel.visible:
		_sfx("ui_open")
	_panel.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_menu() -> void:
	if _panel.visible:
		_sfx("ui_close")
	var was := _current
	_panel.visible = false
	_current = ""
	if was == "settings" and settings_back == "title":
		settings_back = "pause"
		return
	get_tree().paused = false
	if main and was != "pause" and was != "settings":
		main.save_game()
	if main and not main._touch and was == "pause":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	match _current:
		"board":
			_board()
		"shop":
			_shop()
		"smith":
			_smith()
		"skills":
			_skills()
		"inventory":
			_inventory()
		"pause":
			_pause()
		"settings":
			_settings()


func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("skills_menu") and _current == "skills" or event.is_action_pressed("inventory") and _current == "inventory":
		close_menu()
		get_viewport().set_input_as_handled()


# --- Tablón del gremio ------------------------------------------------------

func _board() -> void:
	var rank := Rpg.rank_for(player.guild_points)
	var next := Rpg.next_rank_points(player.guild_points)
	_title.text = "TABLÓN DEL GREMIO DE RIVEL"
	_info.text = "Rango %s  ·  %d puntos de gremio%s  ·  %d de oro  ·  Máximo 3 encargos a la vez" % [rank, player.guild_points,
		("  (siguiente rango: %d)" % next) if next > 0 else "", player.gold]
	var rank_i := Rpg.rank_index(rank)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 18)
	_list.add_child(grid)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	# Primero los encargos aceptados, luego los disponibles.
	for id in player.quests:
		var q := Rpg.quest(id)
		var ready: bool = player.quest_ready(id)
		grid.add_child(_paper(q, "ACEPTADA  %d/%d" % [player.quest_progress(id), q.count],
			"Entregar" if ready else "En curso", ready, _turn_in.bind(id), rng.randf_range(-2.5, 2.5), Color(1.0, 0.95, 0.75)))
	for q in Rpg.QUESTS:
		if q.id in player.quests_done or player.quests.has(q.id):
			continue
		var allowed: bool = Rpg.rank_index(q.rank) <= rank_i
		var can: bool = allowed and player.quests.size() < 3
		grid.add_child(_paper(q, "Recompensa: %d oro · %d EXP" % [q.gold, q.exp],
			"Aceptar" if allowed else "Requiere rango %s" % q.rank, can, _accept.bind(q.id), rng.randf_range(-3.0, 3.0),
			Color(0.96, 0.9, 0.74) if allowed else Color(0.78, 0.74, 0.66)))
	var done := _label("Encargos completados: %d de %d" % [player.quests_done.size(), Rpg.QUESTS.size()], 15, Color(1.0, 0.9, 0.65))
	_list.add_child(done)


## Un papel clavado en el tablón: rango, título, texto y botón.
func _paper(q: Dictionary, status: String, button_text: String, enabled: bool, on_press: Callable, tilt: float, paper_color: Color) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(250, 210)
	var paper := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = paper_color
	sb.border_color = Color(0.7, 0.6, 0.42)
	sb.set_border_width_all(1)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 16
	sb.content_margin_bottom = 10
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(3, 4)
	paper.add_theme_stylebox_override("panel", sb)
	paper.size = Vector2(240, 200)
	paper.position = Vector2(5, 5)
	paper.pivot_offset = Vector2(120, 100)
	paper.rotation_degrees = tilt
	var ink := Color(0.22, 0.14, 0.08)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var head := HBoxContainer.new()
	var title := Label.new()
	title.text = q.name
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", ink)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(title)
	var stamp := Label.new()
	stamp.text = q.rank
	stamp.add_theme_font_size_override("font_size", 22)
	stamp.add_theme_color_override("font_color", Color(0.72, 0.12, 0.1))
	head.add_child(stamp)
	v.add_child(head)
	var desc := Label.new()
	desc.text = q.desc
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.32, 0.22, 0.14))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(214, 0)
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(desc)
	var st := Label.new()
	st.text = status
	st.add_theme_font_size_override("font_size", 12)
	st.add_theme_color_override("font_color", Color(0.45, 0.3, 0.12))
	v.add_child(st)
	var b := _button(button_text, enabled)
	v.add_child(b)
	if on_press.is_valid():
		b.pressed.connect(on_press)
	paper.add_child(v)
	holder.add_child(paper)
	# Chincheta roja arriba del papel.
	var pin := Panel.new()
	var pin_sb := StyleBoxFlat.new()
	pin_sb.bg_color = Color(0.85, 0.15, 0.12)
	pin_sb.set_corner_radius_all(8)
	pin_sb.shadow_color = Color(0, 0, 0, 0.4)
	pin_sb.shadow_size = 2
	pin.add_theme_stylebox_override("panel", pin_sb)
	pin.size = Vector2(14, 14)
	pin.position = Vector2(118, 0)
	holder.add_child(pin)
	return holder


func _accept(id: String) -> void:
	player.quests[id] = 0
	if id == "q10" and main and main.boss_is_defeated():
		player.quests[id] = 1
	if main:
		main.on_quest_accepted(id)
	refresh()


func _turn_in(id: String) -> void:
	var q := Rpg.quest(id)
	if not player.quest_ready(id):
		return
	if q.type == "gather":
		player.add_item(q.target, -int(q.count))
	player.quests.erase(id)
	player.quests_done.append(id)
	var old_rank := Rpg.rank_for(player.guild_points)
	player.guild_points += int(q.gp)
	player.add_gold(int(q.gold))
	player.gain_exp(int(q.exp), player.global_position + Vector3(0, 2.4, 0), false)
	var new_rank := Rpg.rank_for(player.guild_points)
	if main:
		var msg := "Misión cumplida: %s\n+%d oro · +%d EXP" % [q.name, q.gold, q.exp]
		if new_rank != old_rank:
			msg += "\n¡Ascendiste al rango %s del gremio!" % new_rank
		main.hud_message(msg)
		_sfx("quest")
	refresh()


# --- Tienda -----------------------------------------------------------------

func _shop() -> void:
	_title.text = "【 TIENDA DE PIP 】"
	_info.text = "Tienes %d de oro" % player.gold
	_section("Comprar")
	for entry in Rpg.SHOP:
		if entry.has("id"):
			var item: Dictionary = Rpg.ITEMS[entry.id]
			_row("%s   (tienes %d)" % [item.name, player.item_count(entry.id)], item.desc,
				"Comprar · %d" % entry.price, player.gold >= entry.price, _buy_item.bind(entry.id, entry.price))
		else:
			var owned: bool = player.armor >= entry.armor
			_row(entry.name, "Defensa +%d" % entry.def,
				"Equipada" if player.armor == entry.armor else ("Ya tienes una mejor" if owned else "Comprar · %d" % entry.price),
				not owned and player.gold >= entry.price, _buy_armor.bind(entry.armor, entry.price))
	_section("Vender materiales")
	for id in Rpg.SELL_PRICES:
		var n: int = player.item_count(id)
		_row("%s   (tienes %d)" % [Rpg.ITEMS[id].name, n], "Pip paga %d de oro por cada uno." % Rpg.SELL_PRICES[id],
			"Vender 1", n > 0, _sell.bind(id))


func _buy_item(id: String, price: int) -> void:
	if player.gold < price:
		return
	player.add_gold(-price)
	player.add_item(id, 1)
	refresh()


func _buy_armor(tier: int, price: int) -> void:
	if player.gold < price or player.armor >= tier:
		return
	player.add_gold(-price)
	player.armor = tier
	player.stats_changed.emit()
	refresh()


func _sell(id: String) -> void:
	if player.item_count(id) <= 0:
		return
	player.add_item(id, -1)
	player.add_gold(int(Rpg.SELL_PRICES[id]))
	refresh()


# --- Herrería ---------------------------------------------------------------

func _smith() -> void:
	_title.text = "【 HERRERÍA DE BORIN 】"
	_info.text = "Tienes %d de oro y %d huesos" % [player.gold, player.item_count("hueso")]
	_row("Arma actual: %s +%d" % [player.Weapons.DATA[player.weapon].name, player.forge],
		"Cada mejora da +4 de ataque a todas tus armas. Ataque total: %d" % player.total_atk())
	if player.forge >= Rpg.MAX_FORGE:
		_row("Tu arma ya está al máximo.", "Borin no puede hacer más con los materiales de esta zona.")
		return
	var cost := Rpg.forge_cost(player.forge)
	var can: bool = player.gold >= cost[0] and player.item_count("hueso") >= cost[1]
	_row("Forjar mejora +%d" % (player.forge + 1), "Cuesta %d de oro y %d huesos." % [cost[0], cost[1]],
		"Forjar", can, _forge)


func _forge() -> void:
	var cost := Rpg.forge_cost(player.forge)
	if player.gold < cost[0] or player.item_count("hueso") < cost[1]:
		return
	player.add_gold(-cost[0])
	player.add_item("hueso", -cost[1])
	player.forge += 1
	player.stats_changed.emit()
	refresh()


# --- Árbol de habilidades ---------------------------------------------------

func _skills() -> void:
	_title.text = "【 ÁRBOL DE HABILIDADES 】"
	_info.text = "Puntos de habilidad: %d   ·   Ganas 1 al subir de nivel" % player.skill_points
	var branch := ""
	for sk in Rpg.SKILLS:
		if sk[4] != branch:
			branch = sk[4]
			_section("Rama de %s" % branch)
		var learned: bool = player.skills.has(sk[0])
		var req_ok: bool = sk[3] == "" or player.skills.has(sk[3])
		var req_name := ""
		for other in Rpg.SKILLS:
			if other[0] == sk[3]:
				req_name = other[1]
		var desc: String = sk[2]
		if not req_ok:
			desc += "  (Requiere: %s)" % req_name
		var button := "Aprendida" if learned else ("Aprender" if req_ok else "Bloqueada")
		_row(sk[1], desc, button, not learned and req_ok and player.skill_points > 0, _learn.bind(sk[0]),
			GOLD if learned else (TEXT if req_ok else DIM))


func _learn(id: String) -> void:
	if player.learn_skill(id) and id in Rpg.ELEMENTS:
		player.element = id
		player.stats_changed.emit()
	refresh()


# --- Inventario -------------------------------------------------------------

func _inventory() -> void:
	_title.text = "【 INVENTARIO 】"
	_info.text = "%d de oro   ·   Armadura: %s   ·   Arma +%d" % [player.gold, Rpg.ARMOR_NAMES[player.armor], player.forge]
	if player.items.is_empty():
		_row("La mochila está vacía.", "")
	for id in player.items:
		var item: Dictionary = Rpg.ITEMS[id]
		var usable: bool = id == "pocion" or id == "eter"
		_row("%s  x%d" % [item.name, player.items[id]], item.desc, "Usar" if usable else "", true, _use.bind(id))
	_section("Magia conocida")
	for e in Rpg.ELEMENTS:
		if player.skills.has(e):
			var m: Dictionary = Rpg.MAGIC[e]
			_row("%s · %s%s" % [m.name, m.spell, "   (equipada)" if player.element == e else ""],
				"%s  Cuesta %d de maná." % [m.desc, player.spell_cost(e)], "Equipar", player.element != e, _equip_element.bind(e))


func _use(id: String) -> void:
	player.use_potion(id)
	refresh()


func _equip_element(e: String) -> void:
	player.element = e
	player.stats_changed.emit()
	refresh()


# --- Pausa y ajustes ---------------------------------------------------------

func _big_button(text: String, on_press: Callable) -> void:
	var b := _button(text)
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_font_size_override("font_size", 21)
	b.pressed.connect(on_press)
	_list.add_child(b)


func _pause() -> void:
	_title.text = "PAUSA"
	_info.text = main.story().chapter_title() if main and main.story() else ""
	_big_button("Continuar", close_menu)
	_big_button("Ajustes", func(): open("settings"))
	_big_button("Ver controles", func():
		main._help_panel.visible = true
		close_menu())
	_big_button("Guardar partida", func():
		main.save_game()
		_info.text = "Partida guardada.")
	_big_button("Volver al título", func():
		main.save_game()
		close_menu()
		main.back_to_title())
	if not OS.has_feature("mobile"):
		_big_button("Salir del juego", func():
			main.save_game()
			get_tree().quit())


func _slider(text: String, key: String, lo: float, hi: float, suffix := "%") -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	var l := _label(text, 18)
	l.custom_minimum_size.x = 250
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 5
	s.value = float(Settings.get_value(key))
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size.y = 32
	var v := _label("%d%s" % [int(s.value), suffix], 18, GOLD)
	v.custom_minimum_size.x = 70
	s.value_changed.connect(func(x: float):
		v.text = "%d%s" % [int(x), suffix]
		Settings.set_value(key, int(x), main))
	s.drag_ended.connect(func(_c: bool): _sfx("ui_click"))
	h.add_child(s)
	h.add_child(v)
	_list.add_child(h)


func _toggle(text: String, key: String) -> void:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = bool(Settings.get_value(key))
	c.add_theme_font_size_override("font_size", 18)
	c.toggled.connect(func(on: bool):
		_sfx("ui_click")
		Settings.set_value(key, on, main)
		if key == "ayuda" and main:
			main._help_panel.visible = on)
	_list.add_child(c)


func _settings() -> void:
	_title.text = "AJUSTES"
	_info.text = "Los cambios se guardan solos."
	_section("Sonido")
	_slider("Volumen general", "general", 0, 100)
	_slider("Música", "musica", 0, 100)
	_slider("Efectos", "efectos", 0, 100)
	_slider("Voces", "voces", 0, 100)
	_section("Juego")
	_slider("Sensibilidad de la cámara", "sensibilidad", 30, 200)
	_toggle("Mostrar la ayuda de controles al jugar", "ayuda")
	_section("Gráficos")
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var l := _label("Calidad", 18)
	l.custom_minimum_size.x = 250
	h.add_child(l)
	for i in Settings.QUALITY.size():
		var b := _button(Settings.QUALITY[i] + ("  ✓" if int(Settings.get_value("calidad")) == i else ""))
		b.custom_minimum_size = Vector2(130, 40)
		b.pressed.connect(func():
			Settings.set_value("calidad", i, main)
			refresh())
		h.add_child(b)
	_list.add_child(h)
	var hint := _label("Baja: más fluido en celulares y PCs sencillos.  Alta: sombras finas y bordes suaves.", 14, DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(hint)
	if not OS.has_feature("mobile"):
		_toggle("Pantalla completa (F11)", "pantalla_completa")
	_list.add_child(HSeparator.new())
	_big_button("Volver", func():
		if settings_back == "title":
			close_menu()
		else:
			open("pause"))
