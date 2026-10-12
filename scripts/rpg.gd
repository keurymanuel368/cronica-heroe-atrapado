## Datos del juego de rol: rangos del gremio, misiones, objetos, tienda,
## elementos de magia y árbol de habilidades.

const RANKS := [["F", 0], ["E", 30], ["D", 80], ["C", 160], ["B", 300], ["A", 500], ["S", 800]]

## Tipos de misión: "kill" (derrotar enemigos de un tipo, "any" vale
## cualquiera), "gather" (reunir objetos) y "escort" (acompañar a alguien).
const QUESTS := [
	{"id": "q1", "rank": "F", "name": "Primeros pasos", "type": "kill", "target": "any", "count": 3,
		"desc": "Derrota a 3 esqueletos cualesquiera.", "gold": 30, "exp": 20, "gp": 12},
	{"id": "q2", "rank": "F", "name": "Hierbas para la posada", "type": "gather", "target": "hierba", "count": 5,
		"desc": "Tomás necesita 5 hierbas curativas. Crecen en la pradera.", "gold": 35, "exp": 15, "gp": 12},
	{"id": "q3", "rank": "E", "name": "Limpieza de la arena", "type": "kill", "target": "warrior", "count": 1,
		"desc": "Derrota a un guerrero esqueleto.", "gold": 50, "exp": 30, "gp": 20},
	{"id": "q4", "rank": "E", "name": "Huesos para Borin", "type": "gather", "target": "hueso", "count": 6,
		"desc": "El herrero quiere 6 huesos de esqueleto para sus forjas.", "gold": 55, "exp": 30, "gp": 20},
	{"id": "q5", "rank": "E", "name": "Escolta al molino", "type": "escort", "target": "bram", "count": 1,
		"desc": "Acompaña al comerciante Bram desde la aldea hasta el molino del oeste. Dicen que hay emboscadas.", "gold": 80, "exp": 45, "gp": 28},
	{"id": "q6", "rank": "D", "name": "Sombras del bosque", "type": "kill", "target": "rogue", "count": 4,
		"desc": "Derrota a 4 pícaros esqueleto en el Bosque Susurrante.", "gold": 90, "exp": 60, "gp": 35},
	{"id": "q7", "rank": "D", "name": "Hongos lunares", "type": "gather", "target": "hongo", "count": 4,
		"desc": "Reúne 4 hongos lunares. Solo brillan en el bosque.", "gold": 85, "exp": 55, "gp": 35},
	{"id": "q8", "rank": "D", "name": "Cazamagos", "type": "kill", "target": "mage", "count": 3,
		"desc": "Derrota a 3 magos esqueleto.", "gold": 110, "exp": 70, "gp": 40},
	{"id": "q9", "rank": "C", "name": "Patrulla del este", "type": "kill", "target": "any", "count": 10,
		"desc": "Derrota a 10 esqueletos para mantener seguros los caminos.", "gold": 150, "exp": 120, "gp": 60},
	{"id": "q10", "rank": "C", "name": "El Rey Esqueleto", "type": "kill", "target": "boss", "count": 1,
		"desc": "Baja a la mazmorra del este y derrota al Rey Esqueleto.", "gold": 500, "exp": 400, "gp": 200},
	{"id": "q11", "rank": "C", "name": "Limpieza de las ruinas", "type": "kill", "target": "any", "count": 20,
		"desc": "Derrota a 20 enemigos cualesquiera.", "gold": 300, "exp": 300, "gp": 120},
	{"id": "q12", "rank": "B", "name": "El guardián del bosque", "type": "kill", "target": "musgoso", "count": 1,
		"desc": "Derrota a Gorran, guardián del primer sello.", "gold": 600, "exp": 500, "gp": 220},
	{"id": "q13", "rank": "B", "name": "La Hechicera del Lago", "type": "kill", "target": "lyra", "count": 1,
		"desc": "Derrota a Lyra en las Ruinas del Lago.", "gold": 700, "exp": 600, "gp": 250},
	{"id": "q14", "rank": "A", "name": "El caballero de la torre", "type": "kill", "target": "garrett", "count": 1,
		"desc": "Derrota a Garrett en la Torre del Norte.", "gold": 900, "exp": 800, "gp": 300},
	{"id": "q15", "rank": "A", "name": "Cazador legendario", "type": "kill", "target": "any", "count": 50,
		"desc": "Derrota a 50 enemigos cualesquiera.", "gold": 1200, "exp": 1000, "gp": 400},
]

const ITEMS := {
	"pocion": {"name": "Poción de vida", "desc": "Recupera 60 de vida. Tecla Z."},
	"eter": {"name": "Éter", "desc": "Recupera 40 de maná. Tecla X."},
	"hierba": {"name": "Hierba curativa", "desc": "Material. Crece en la pradera."},
	"hongo": {"name": "Hongo lunar", "desc": "Material. Brilla en el bosque."},
	"hueso": {"name": "Hueso", "desc": "Material. Lo sueltan los esqueletos."},
	"fragmento": {"name": "Fragmento del Sistema", "desc": "Objeto de la historia. Late como un corazón."},
	"sello_bosque": {"name": "Sello del Bosque", "desc": "Objeto de la historia. Huele a musgo y a lluvia."},
	"sello_lago": {"name": "Sello del Lago", "desc": "Objeto de la historia. Siempre está frío y húmedo."},
	"sello_torre": {"name": "Sello de la Torre", "desc": "Objeto de la historia. Lleva grabado el escudo de Garrett."},
}

## Tienda de Pip: objetos y armaduras.
const SHOP := [
	{"id": "pocion", "price": 20},
	{"id": "eter", "price": 25},
	{"armor": 1, "name": "Armadura de cuero", "def": 4, "price": 80},
	{"armor": 2, "name": "Cota de malla", "def": 9, "price": 220},
	{"armor": 3, "name": "Armadura de placas", "def": 16, "price": 500},
]
const ARMOR_NAMES := ["Ropa de viajero", "Armadura de cuero", "Cota de malla", "Armadura de placas"]
const ARMOR_DEF := [0, 4, 9, 16]
const SELL_PRICES := {"hierba": 3, "hongo": 5, "hueso": 2}

## Herrería de Borin: cada mejora del arma da +4 de ataque.
const MAX_FORGE := 5


static func forge_cost(level: int) -> Array:
	return [60 * (level + 1), 3 * (level + 1)]


## Los 6 elementos. Cada uno se desbloquea en el árbol de habilidades.
const ELEMENTS := ["fuego", "agua", "viento", "tierra", "luz", "oscuridad"]
const MAGIC := {
	"fuego": {"name": "Fuego", "spell": "Bola de fuego", "cost": 15, "color": Color(1.0, 0.45, 0.1),
		"desc": "Una bola de fuego que aturde."},
	"agua": {"name": "Agua", "spell": "Sanación", "cost": 20, "color": Color(0.3, 0.7, 1.0),
		"desc": "Cura tu vida."},
	"viento": {"name": "Viento", "spell": "Cuchillas de viento", "cost": 14, "color": Color(0.6, 1.0, 0.7),
		"desc": "Tres cuchillas rápidas en abanico."},
	"tierra": {"name": "Tierra", "spell": "Temblor", "cost": 25, "color": Color(0.75, 0.55, 0.3),
		"desc": "Golpea el suelo: daña y empuja a todos alrededor."},
	"luz": {"name": "Luz", "spell": "Lanza de luz", "cost": 30, "color": Color(1.0, 0.97, 0.7),
		"desc": "Un rayo sagrado. Muy fuerte contra los no muertos."},
	"oscuridad": {"name": "Oscuridad", "spell": "Drenaje", "cost": 20, "color": Color(0.55, 0.2, 0.85),
		"desc": "Roba vida al enemigo que toca."},
}

## Árbol de habilidades: [id, nombre, descripción, requisito, rama].
const SKILLS := [
	["fuego", "Magia de fuego", "Bola de fuego (la conoces desde el despertar).", "", "Magia"],
	["agua", "Magia de agua", "Aprende Sanación.", "fuego", "Magia"],
	["viento", "Magia de viento", "Aprende Cuchillas de viento.", "fuego", "Magia"],
	["tierra", "Magia de tierra", "Aprende Temblor.", "agua", "Magia"],
	["luz", "Magia de luz", "Aprende Lanza de luz.", "viento", "Magia"],
	["oscuridad", "Magia de oscuridad", "Aprende Drenaje.", "luz", "Magia"],
	["mana1", "Mente clara", "+20 de maná máximo.", "", "Magia"],
	["mana2", "Concentración", "Los hechizos cuestan un 25% menos.", "mana1", "Magia"],
	["vida1", "Aguante", "+25 de vida máxima.", "", "Cuerpo"],
	["vida2", "Corazón de héroe", "+40 de vida máxima.", "vida1", "Cuerpo"],
	["fuerza1", "Fuerza", "+4 de ataque.", "", "Cuerpo"],
	["maestria", "Maestría de armas", "Tus ataques con arma hacen un 20% más.", "fuerza1", "Cuerpo"],
	["defensa1", "Piel de hierro", "+5 de defensa.", "", "Cuerpo"],
	["esquiva", "Paso ligero", "La esquiva se recarga el doble de rápido.", "defensa1", "Cuerpo"],
]


static func rank_for(points: int) -> String:
	var r := "F"
	for pair in RANKS:
		if points >= pair[1]:
			r = pair[0]
	return r


static func rank_index(r: String) -> int:
	for i in RANKS.size():
		if RANKS[i][0] == r:
			return i
	return 0


static func next_rank_points(points: int) -> int:
	for pair in RANKS:
		if points < pair[1]:
			return pair[1]
	return -1


static func quest(id: String) -> Dictionary:
	for q in QUESTS:
		if q.id == id:
			return q
	return {}
