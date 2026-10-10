extends Control
## Minimapa en la esquina: el terreno visto desde arriba (hecho una sola vez
## a partir de las alturas del mundo) con el héroe, enemigos, gente y lugares.

const SIZE := 220.0
## Metros que se ven de lado a lado del minimapa.
const VIEW := 130.0
## Zona del mundo que cubre la imagen.
const X0 := -180.0
const Z0 := -260.0
const SPAN := 360.0
const RES := 256

var world: Node
var player: Node3D
var main: Node
var _tex: ImageTexture
var _font: Font


func setup(w: Node, p: Node3D, m: Node) -> void:
	world = w
	player = p
	main = m
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	clip_contents = true
	_font = ThemeDB.fallback_font
	_bake()


func _bake() -> void:
	var img := Image.create(RES, RES, false, Image.FORMAT_RGB8)
	for j in RES:
		for i in RES:
			var x := X0 + (i + 0.5) * SPAN / RES
			var z := Z0 + (j + 0.5) * SPAN / RES
			var h: float = world.height(x, z)
			var c: Color
			if h < world.WATER_LEVEL:
				c = Color(0.25, 0.55, 0.85)
			elif world.road_distance(x, z) < 2.6:
				c = Color(0.78, 0.66, 0.45)
			elif h > 30.0:
				c = Color(0.9, 0.92, 0.96)
			elif h > 18.0:
				c = Color(0.55, 0.55, 0.52)
			else:
				c = Color(0.36, 0.62, 0.3).lerp(Color(0.55, 0.75, 0.38), clampf(h / 14.0, 0.0, 1.0))
				if Vector2(x, z).distance_to(world.FOREST) < world.FOREST_RADIUS:
					c = c.darkened(0.45)
			if Vector2(x, z).distance_to(world.VILLAGE) < 24.0 and h >= world.WATER_LEVEL:
				c = c.lerp(Color(0.75, 0.6, 0.45), 0.35)
			img.set_pixel(i, j, c)
	_tex = ImageTexture.create_from_image(img)


func _process(_delta: float) -> void:
	queue_redraw()


func _to_map(p: Vector3, center: Vector3) -> Vector2:
	var scale := SIZE / VIEW
	return Vector2(SIZE * 0.5, SIZE * 0.5) + Vector2(p.x - center.x, p.z - center.z) * scale


func _draw() -> void:
	if player == null or _tex == null:
		return
	draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)), Color(0.05, 0.08, 0.15, 0.9))
	if main and main.in_dungeon():
		_draw_label("Mazmorra", Vector2(SIZE * 0.5, SIZE * 0.5), Color(1, 0.8, 0.5))
		_border()
		return
	var c := player.global_position
	var scale := SIZE / VIEW
	var tex_px := SPAN / RES * scale
	var origin := _to_map(Vector3(X0, 0, Z0), c)
	draw_texture_rect(_tex, Rect2(origin, Vector2(RES, RES) * tex_px), false, Color(1, 1, 1, 0.95))

	# Lugares importantes.
	_place_mark(Vector3(world.VILLAGE.x, 0, world.VILLAGE.y), "Aldea", c)
	_place_mark(Vector3(world.ARENA.x, 0, world.ARENA.y), "Arena", c)
	_place_mark(Vector3(world.DUNGEON_GATE.x, 0, world.DUNGEON_GATE.y), "Mazmorra", c)
	_place_mark(Vector3(world.FOREST.x, 0, world.FOREST.y), "Bosque", c)
	_place_mark(Vector3(world.WINDMILL.x, 0, world.WINDMILL.y), "Molino", c)
	_place_mark(Vector3(world.CASTLE.x, 0, world.CASTLE.y), "Castillo", c)

	for npc in get_tree().get_nodes_in_group("npcs"):
		var p := _to_map(npc.global_position, c)
		draw_circle(p, 3.5, Color(1.0, 0.85, 0.3))
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_alive() and e.global_position.y > -50.0:
			var p := _to_map(e.global_position, c)
			draw_circle(p, 3.0 if not e.is_boss() else 6.0, Color(0.95, 0.25, 0.25))

	# El héroe: una flecha que apunta hacia donde mira.
	var yaw: float = player.facing_yaw()
	var dir := Vector2(sin(yaw), cos(yaw))
	var side := Vector2(dir.y, -dir.x)
	var center := Vector2(SIZE * 0.5, SIZE * 0.5)
	draw_colored_polygon(PackedVector2Array([center + dir * 9.0, center - dir * 6.0 + side * 6.0, center - dir * 3.0, center - dir * 6.0 - side * 6.0]), Color(0.45, 0.9, 1.0))
	_border()


func _place_mark(p: Vector3, text: String, c: Vector3) -> void:
	var m := _to_map(p, c)
	if Rect2(Vector2(-40, -10), Vector2(SIZE + 80, SIZE + 20)).has_point(m):
		_draw_label(text, m, Color(1, 0.95, 0.8))


func _draw_label(text: String, at: Vector2, color: Color) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 13).x
	draw_string_outline(_font, at - Vector2(w * 0.5, -4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0.05, 0.05, 0.1))
	draw_string(_font, at - Vector2(w * 0.5, -4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)


func _border() -> void:
	draw_rect(Rect2(Vector2(1, 1), Vector2(SIZE - 2, SIZE - 2)), Color(0.44, 0.83, 1.0, 0.9), false, 2.0)
	_draw_label("N", Vector2(SIZE * 0.5, 10), Color(1, 0.9, 0.5))
