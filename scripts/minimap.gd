extends Control
## Minimapa redondo en la esquina y mapa grande del mundo (tecla M). El
## terreno se dibuja una sola vez a partir de las alturas del mundo, con
## sombreado de relieve; encima van el héroe, enemigos, gente y lugares.

const Interiors := preload("res://scripts/interiors.gd")

const SIZE := 220.0
## Metros que se ven de lado a lado del minimapa.
const VIEW := 130.0
## Zona del mundo que cubre la imagen.
const X0 := -180.0
const Z0 := -260.0
const SPAN := 360.0
const RES := 320
const FRAME := Color(0.78, 0.58, 0.3)
const INK := Color(0.12, 0.07, 0.03)

var world: Node
var player: Node3D
var main: Node
## true: mapa grande a pantalla completa.
var full := false
var _tex: ImageTexture
var _font: Font


func setup(w: Node, p: Node3D, m: Node, shared_tex: ImageTexture = null) -> void:
	world = w
	player = p
	main = m
	if not full:
		custom_minimum_size = Vector2(SIZE, SIZE)
		size = Vector2(SIZE, SIZE)
	_font = ThemeDB.fallback_font
	_tex = shared_tex if shared_tex else _bake()


func texture() -> ImageTexture:
	return _tex


func _bake() -> ImageTexture:
	var img := Image.create(RES, RES, false, Image.FORMAT_RGB8)
	var step := SPAN / RES
	for j in RES:
		for i in RES:
			var x := X0 + (i + 0.5) * step
			var z := Z0 + (j + 0.5) * step
			var h: float = world.height(x, z)
			var c: Color
			if h < world.WATER_LEVEL:
				c = Color(0.3, 0.58, 0.85).lerp(Color(0.2, 0.42, 0.75), clampf((world.WATER_LEVEL - h) / 3.0, 0.0, 1.0))
			elif world.road_distance(x, z) < 2.6:
				c = Color(0.82, 0.7, 0.48)
			elif h > 30.0:
				c = Color(0.93, 0.94, 0.97)
			elif h > 18.0:
				c = Color(0.6, 0.58, 0.54)
			else:
				c = Color(0.42, 0.66, 0.32).lerp(Color(0.62, 0.78, 0.42), clampf(h / 14.0, 0.0, 1.0))
				if Vector2(x, z).distance_to(world.FOREST) < world.FOREST_RADIUS:
					c = Color(0.2, 0.42, 0.22)
			if Vector2(x, z).distance_to(world.VILLAGE) < 24.0 and h >= world.WATER_LEVEL:
				c = c.lerp(Color(0.8, 0.66, 0.48), 0.35)
			# Relieve: luz desde el noroeste.
			var slope: float = world.height(x - 1.5, z - 1.5) - h
			c = c.lightened(clampf(slope * 0.08, 0.0, 0.3)) if slope > 0.0 else c.darkened(clampf(-slope * 0.08, 0.0, 0.3))
			img.set_pixel(i, j, c)
	# Casas del pueblo y castillo como bloques.
	var blocks: Array = []
	for hdef in Interiors.HOUSES:
		blocks.append([world.VILLAGE + hdef.at, 3.5])
	blocks.append([world.CASTLE, 9.0])
	for b in blocks:
		var p: Vector2 = b[0]
		var r: float = b[1]
		for dz in range(int(-r / step), int(r / step) + 1):
			for dx in range(int(-r / step), int(r / step) + 1):
				var px := int((p.x - X0) / step) + dx
				var pz := int((p.y - Z0) / step) + dz
				if px >= 0 and pz >= 0 and px < RES and pz < RES:
					var edge := absi(dx) == int(r / step) or absi(dz) == int(r / step)
					img.set_pixel(px, pz, Color(0.25, 0.3, 0.6) if edge else Color(0.4, 0.5, 0.85))
	return ImageTexture.create_from_image(img)


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	if player == null or _tex == null:
		return
	if full:
		_draw_full()
	else:
		_draw_mini()


# --- Minimapa redondo --------------------------------------------------------

func _to_map(p: Vector3, center: Vector3) -> Vector2:
	return Vector2(SIZE * 0.5, SIZE * 0.5) + Vector2(p.x - center.x, p.z - center.z) * (SIZE / VIEW)


func _draw_mini() -> void:
	var mid := Vector2(SIZE * 0.5, SIZE * 0.5)
	var radius := SIZE * 0.5 - 6.0
	draw_circle(mid, radius + 6.0, Color(0.2, 0.12, 0.06, 0.95))
	if main and (main.in_dungeon() or main.indoor_name() != ""):
		draw_circle(mid, radius, Color(0.12, 0.08, 0.05))
		_label("Mazmorra" if main.in_dungeon() else main.indoor_name(), mid, Color(1, 0.86, 0.55), 13, radius * 1.8)
		_frame(mid, radius)
		return
	var c := player.global_position
	# Círculo con la textura del terreno.
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	for i in 48:
		var a := TAU * i / 48.0
		var p := mid + Vector2(cos(a), sin(a)) * radius
		pts.append(p)
		var world_p := Vector2(c.x, c.z) + (p - mid) * (VIEW / SIZE)
		uvs.append(Vector2((world_p.x - X0) / SPAN, (world_p.y - Z0) / SPAN))
		cols.append(Color.WHITE)
	draw_polygon(pts, cols, uvs, _tex)

	for place in _places():
		var m := _to_map(place[0], c)
		if m.distance_to(mid) < radius - 10.0:
			_label(place[1], m, Color(1, 0.95, 0.8), 12)
	for h in get_tree().get_nodes_in_group("horses"):
		var p := _to_map(h.global_position, c)
		if p.distance_to(mid) < radius - 3.0 and not h.ridden:
			draw_circle(p, 3.5, Color(0.55, 0.35, 0.2))
	for npc in get_tree().get_nodes_in_group("npcs"):
		var p := _to_map(npc.global_position, c)
		if p.distance_to(mid) < radius - 3.0:
			draw_circle(p, 3.2, Color(1.0, 0.85, 0.3))
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_alive() and e.global_position.y > -50.0:
			var p := _to_map(e.global_position, c)
			if p.distance_to(mid) < radius - 3.0:
				draw_circle(p, 3.0 if not e.is_boss() else 6.0, Color(0.95, 0.25, 0.25))
	_arrow(mid, player.facing_yaw(), 1.0)
	_frame(mid, radius)


func _frame(mid: Vector2, radius: float) -> void:
	draw_arc(mid, radius + 2.0, 0.0, TAU, 64, FRAME, 5.0, true)
	draw_arc(mid, radius + 5.5, 0.0, TAU, 64, Color(0.3, 0.19, 0.09), 2.0, true)
	for d in [["N", Vector2(0, -1)], ["S", Vector2(0, 1)], ["E", Vector2(1, 0)], ["O", Vector2(-1, 0)]]:
		var p: Vector2 = mid + d[1] * (radius + 2.0)
		draw_circle(p, 9.0, Color(0.3, 0.19, 0.09))
		draw_arc(p, 9.0, 0.0, TAU, 20, FRAME, 1.5, true)
		_label(d[0], p, Color(1.0, 0.9, 0.6) if d[0] != "N" else Color(1.0, 0.5, 0.4), 12)


# --- Mapa grande -------------------------------------------------------------

func _draw_full() -> void:
	var screen := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0, 0, 0, 0.6))
	var side := minf(screen.x, screen.y) - 120.0
	var origin := (screen - Vector2(side, side)) * 0.5
	var k := side / SPAN
	# Marco de madera y pergamino.
	draw_rect(Rect2(origin - Vector2(22, 22), Vector2(side + 44, side + 44)), Color(0.42, 0.27, 0.14))
	draw_rect(Rect2(origin - Vector2(22, 22), Vector2(side + 44, side + 44)), Color(0.25, 0.15, 0.07), false, 8.0)
	draw_texture_rect(_tex, Rect2(origin, Vector2(side, side)), false)
	draw_rect(Rect2(origin, Vector2(side, side)), FRAME, false, 3.0)
	var to_screen := func(p: Vector3) -> Vector2:
		return origin + Vector2(p.x - X0, p.z - Z0) * k
	for place in _places():
		_label(place[1], to_screen.call(place[0]), Color(1, 0.95, 0.8), 18)
	for hdef in Interiors.HOUSES:
		var at: Vector2 = world.VILLAGE + hdef.at
		var p: Vector2 = to_screen.call(Vector3(at.x, 0, at.y))
		_label(String(hdef.name).get_slice(" ", 0), p + Vector2(0, -12), Color(0.95, 0.95, 1.0), 11)
	for h in get_tree().get_nodes_in_group("horses"):
		if not h.ridden:
			draw_circle(to_screen.call(h.global_position), 5.0, Color(0.55, 0.35, 0.2))
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_alive() and e.global_position.y > -50.0 and e.global_position.x < 300.0:
			draw_circle(to_screen.call(e.global_position), 3.5 if not e.is_boss() else 7.0, Color(0.95, 0.25, 0.25))
	if main and main.indoor_name() == "" and not main.in_dungeon():
		_arrow(to_screen.call(player.global_position), player.facing_yaw(), 1.6)
	# Título y leyenda.
	_label("MAPA DEL REINO DE AURELIA", Vector2(screen.x * 0.5, origin.y - 40.0), Color(1.0, 0.88, 0.55), 26)
	var legend := [[Color(0.45, 0.9, 1.0), "Tú"], [Color(1.0, 0.85, 0.3), "Gente"], [Color(0.95, 0.25, 0.25), "Enemigos"],
		[Color(0.55, 0.35, 0.2), "Caballos"], [Color(0.4, 0.5, 0.85), "Edificios"]]
	var lx := origin.x + side + 40.0
	if lx + 140.0 > screen.x:
		lx = origin.x + 10.0
	for i in legend.size():
		var y := origin.y + 20.0 + i * 28.0
		draw_rect(Rect2(Vector2(lx - 6, y - 14), Vector2(140, 26)), Color(0.2, 0.12, 0.06, 0.85))
		draw_circle(Vector2(lx + 8, y - 1), 7.0, legend[i][0])
		draw_string(_font, Vector2(lx + 22, y + 5), legend[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.95, 0.85))
	_label("M  Cerrar el mapa", Vector2(screen.x * 0.5, origin.y + side + 44.0), Color(1, 0.95, 0.85), 16)


# --- Utilidades --------------------------------------------------------------

func _places() -> Array:
	return [
		[Vector3(world.VILLAGE.x, 0, world.VILLAGE.y - 28.0), "Aldea de Rivel"],
		[Vector3(world.ARENA.x, 0, world.ARENA.y), "Arena"],
		[Vector3(world.DUNGEON_GATE.x, 0, world.DUNGEON_GATE.y), "Mazmorra"],
		[Vector3(world.FOREST.x, 0, world.FOREST.y), "Bosque Susurrante"],
		[Vector3(world.WINDMILL.x, 0, world.WINDMILL.y), "Molino"],
		[Vector3(world.CASTLE.x, 0, world.CASTLE.y - 12.0), "Castillo de Aurelia"],
		[Vector3(world.AWAKENING.x, 0, world.AWAKENING.y + 8.0), "Cristal del despertar"],
	]


func _arrow(at: Vector2, yaw: float, scale: float) -> void:
	var dir := Vector2(sin(yaw), cos(yaw))
	var side := Vector2(dir.y, -dir.x)
	var pts := PackedVector2Array([at + dir * 10.0 * scale, at - dir * 7.0 * scale + side * 7.0 * scale,
		at - dir * 3.0 * scale, at - dir * 7.0 * scale - side * 7.0 * scale])
	draw_colored_polygon(pts, Color(0.45, 0.9, 1.0))
	pts.append(pts[0])
	draw_polyline(pts, INK, 1.5, true)


func _label(text: String, at: Vector2, color: Color, font_size := 13, max_width := -1.0) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, max_width, font_size).x
	var pos := at - Vector2(w * 0.5, -font_size * 0.35)
	draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, max_width, font_size, 4, INK)
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, max_width, font_size, color)
