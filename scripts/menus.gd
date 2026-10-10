extends CanvasLayer
## Ventanas del Sistema que pausan el juego: tablón del gremio, tienda,
## herrería, árbol de habilidades e inventario.

const Rpg := preload("res://scripts/rpg.gd")

const GOLD := Color(0.91, 0.76, 0.42)
const RUNE := Color(0.44, 0.83, 1.0)
const TEXT := Color(0.91, 0.95, 1.0)
const DIM := Color(0.6, 0.66, 0.75)

var player: Node
var main: Node
var _panel: PanelContainer
var _title: Label
var _info: Label
var _list: VBoxContainer
var _current := ""


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
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -420
	_panel.offset_right = 420
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
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.22, 0.42, 0.9) if state != "disabled" else Color(0.08, 0.1, 0.16, 0.8)
		if state == "hover" or state == "focus":
			sb.bg_color = Color(0.16, 0.32, 0.58, 0.95)
		sb.border_color = GOLD if state == "hover" else Color(0.44, 0.83, 1.0, 0.6)
		sb.set_border_width_all(1)
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
	refresh()
	_panel.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_menu() -> void:
	_panel.visible = false
	_current = ""
	get_tree().paused = false
	if main:
		main.save_game()


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
	_title.text = "【 TABLÓN DEL GREMIO 】"
	_info.text = "Rango %s  ·  %d puntos de gremio%s  ·  %d de oro" % [rank, player.guild_points,
		("  (siguiente rango: %d)" % next) if next > 0 else "", player.gold]
	var rank_i := Rpg.rank_index(rank)
	if not player.quests.is_empty():
		_section("Misiones aceptadas")
		for id in player.quests:
			var q := Rpg.quest(id)
			var ready: bool = player.quest_ready(id)
			_row("[%s] %s   %d/%d" % [q.rank, q.name, player.quest_progress(id), q.count], q.desc,
				"Entregar" if ready else "En curso", ready, _turn_in.bind(id), GOLD if ready else TEXT)
	_section("Misiones disponibles")
	var any := false
	for q in Rpg.QUESTS:
		if q.id in player.quests_done or player.quests.has(q.id):
			continue
		any = true
		var allowed := Rpg.rank_index(q.rank) <= rank_i
		var reward := "Recompensa: %d oro · %d EXP · %d puntos" % [q.gold, q.exp, q.gp]
		var can: bool = allowed and player.quests.size() < 3
		_row("[%s] %s" % [q.rank, q.name], "%s\n%s" % [q.desc, reward],
			"Aceptar" if allowed else "Rango %s" % q.rank, can, _accept.bind(q.id), TEXT if allowed else DIM)
	if not any:
		_row("¡Completaste todas las misiones del tablón!", "Pronto llegarán encargos de otras ciudades.")
	if player.quests_done.size() > 0:
		_section("Completadas: %d de %d" % [player.quests_done.size(), Rpg.QUESTS.size()])


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
