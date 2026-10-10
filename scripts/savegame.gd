## Guarda y carga la partida en un archivo del usuario.

const PATH := "user://partida.cfg"
const SAVED := ["level", "exp_points", "max_hp", "hp", "max_mp", "atk", "def", "kills",
	"gold", "items", "skills", "skill_points", "element", "armor", "forge",
	"guild_member", "guild_points", "quests", "quests_done", "story", "story_count"]


static func exists() -> bool:
	return FileAccess.file_exists(PATH)


static func save(player: Node, clock: Node, position: Vector3, flags: Dictionary) -> void:
	var cfg := ConfigFile.new()
	for key in SAVED:
		cfg.set_value("heroe", key, player.get(key))
	cfg.set_value("heroe", "weapon", player.weapon)
	cfg.set_value("heroe", "mp", int(player.mp))
	cfg.set_value("heroe", "position", position)
	for key in flags:
		cfg.set_value("mundo", key, flags[key])
	cfg.set_value("mundo", "time", clock.time)
	cfg.set_value("mundo", "day", clock.day)
	cfg.save(PATH)


static func flag(key: String) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return false
	return cfg.get_value("mundo", key, false)


static func load_into(player: Node, clock: Node) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return false
	for key in SAVED:
		player.set(key, cfg.get_value("heroe", key, player.get(key)))
	player.mp = float(cfg.get_value("heroe", "mp", player.max_mp))
	player.hp = maxi(1, player.hp)
	player.set_weapon(cfg.get_value("heroe", "weapon", "espada"))
	player.global_position = cfg.get_value("heroe", "position", player.global_position) + Vector3(0, 0.5, 0)
	clock.time = cfg.get_value("mundo", "time", 8.0)
	clock.day = cfg.get_value("mundo", "day", 1)
	player.stats_changed.emit()
	return true
