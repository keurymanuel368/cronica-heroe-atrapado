extends RefCounted
## Textos de las escenas cinematográficas (con voz). Las voces se generan con
## tools/audio/voces.py: el archivo de cada línea es md5("Voz|texto")[:12].

const INTRO := [
	"Dicen que el Reino de Aurelia nació de un cristal caído del cielo.",
	"Durante siglos, ese cristal trajo héroes de otros mundos para proteger el reino.",
	"Hace cien años, el último de ellos, Kaito, venció al Rey Esqueleto... y desapareció sin dejar rastro.",
	"Hoy, el cristal ha vuelto a brillar.",
	"Y tú... acabas de despertar dentro de su historia.",
]

const KAITO_INTRO := [
	"Rompiste mis tres sellos... Lyra y Garrett por fin descansan. Te lo agradezco.",
	"Otro más... El Sistema nunca se cansa de traer héroes.",
	"Yo también quise volver a casa. Junté los fragmentos y abrí esta puerta.",
	"Pero solo hay una salida: vencer al guardián del Trono. Y ahora el guardián soy yo.",
	"¡Muéstrame si eres más fuerte que yo hace cien años!",
]

const KAITO_END := [
	"Así que... esto es perder. Qué ligero me siento.",
	"Cien años encerrado en este trono. Gracias por liberarme, héroe.",
	"Escucha: el Sistema no es tu enemigo. Solo busca a alguien digno de proteger este mundo.",
	"La puerta a tu mundo está abierta. Tú decides si cruzarla... o quedarte en Aurelia.",
	"Adiós, amigo. Cuida de ellos por mí.",
]

const ENDING := [
	"Y así, el héroe del cristal liberó al Primer Héroe de su prisión.",
	"El Sistema guardó silencio, y por primera vez en cien años, los esqueletos dejaron de despertar.",
	"En Aurelia todavía se cuenta su historia... la del héroe que quedó atrapado, y que eligió quedarse.",
]

const BOSS := [
	"¿Otro héroe del cristal? Hace cien años uno como tú me humilló.",
	"¡Esta vez tus huesos adornarán mi trono!",
]

## Presentación de cada jefe: tipo de enemigo -> [voz, líneas].
const BOSS_LINES := {
	"boss": ["Rey Esqueleto", BOSS],
	"musgoso": ["Gorran", ["Grrr... El bosque no olvida. Kaito me dejó aquí para guardar el sello.",
		"¡Ningún héroe del cristal lo romperá!"]],
	"lyra": ["Lyra", ["Cien años bajo el agua, esperando... ¿Vienes a liberarme, o a ocupar mi lugar?",
		"Si quieres el sello, tendrás que vencer a la marea."]],
	"garrett": ["Garrett", ["Juré proteger a Kaito y le fallé. No volveré a fallar.",
		"¡En guardia, héroe! Este sello solo cae si yo caigo."]],
}

const CHAPTERS := {
	1: "Capítulo uno. El despertar.",
	2: "Capítulo dos. El Rey de Aurelia.",
	3: "Capítulo tres. La mazmorra del Rey Esqueleto.",
	4: "Capítulo cuatro. Los tres sellos.",
	5: "Capítulo cinco. La Hechicera del Lago.",
	6: "Capítulo seis. La Torre del Norte.",
	7: "Capítulo siete. La verdad del Sistema.",
	8: "Capítulo ocho. El Trono del Vacío.",
}

## Nombre en pantalla -> voz.
const VOICE_OF := {
	"Abuelo Ered": "Abuelo Ered", "Rey Aurelio": "Rey Aurelio", "Hermana Elia": "Hermana Elia",
	"Sira": "Sira", "Kaito · El Primer Héroe": "Kaito", "Narrador": "Narrador", "Rey Esqueleto": "Rey Esqueleto",
}


static func voice_path(voice: String, text: String) -> String:
	return "res://assets/audio/voz/%s.ogg" % ("%s|%s" % [voice, text]).md5_text().substr(0, 12)
