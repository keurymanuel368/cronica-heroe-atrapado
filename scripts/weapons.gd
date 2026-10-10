## Las cuatro armas que el héroe puede elegir al despertar.
## Cada ataque: animación, daño, alcance, ángulo del golpe (grados), momento
## del golpe (fracción de la animación) y velocidad de la animación.

const ORDER := ["espada", "escudo", "lanza", "arco"]

const DATA := {
	"espada": {
		"name": "Espada y escudo",
		"desc": "Equilibrada: combos rápidos y buen bloqueo.",
		"gear": ["1H_Sword", "Round_Shield"],
		"light": [
			{"anim": "1H_Melee_Attack_Slice_Diagonal", "dmg": 11, "range": 2.4, "arc": 110, "hit": 0.38, "speed": 1.5},
			{"anim": "1H_Melee_Attack_Slice_Horizontal", "dmg": 12, "range": 2.4, "arc": 140, "hit": 0.40, "speed": 1.5},
			{"anim": "1H_Melee_Attack_Chop", "dmg": 16, "range": 2.4, "arc": 90, "hit": 0.42, "speed": 1.4},
		],
		"heavy": {"anim": "1H_Melee_Attack_Stab", "dmg": 30, "range": 2.8, "arc": 60, "hit": 0.45, "speed": 1.35, "stagger": true},
		"block": 0.75,
		"defense": 2,
		"idle": "Idle",
	},
	"escudo": {
		"name": "Gran escudo",
		"desc": "Casi no recibe daño. Golpea poco, pero empuja.",
		"gear": ["Rectangle_Shield"],
		"light": [
			{"anim": "Unarmed_Melee_Attack_Punch_A", "dmg": 6, "range": 2.0, "arc": 100, "hit": 0.32, "speed": 1.6},
			{"anim": "Unarmed_Melee_Attack_Punch_B", "dmg": 7, "range": 2.0, "arc": 100, "hit": 0.32, "speed": 1.6},
			{"anim": "Unarmed_Melee_Attack_Kick", "dmg": 9, "range": 2.2, "arc": 100, "hit": 0.40, "speed": 1.4},
		],
		"heavy": {"anim": "Block_Attack", "dmg": 14, "range": 2.6, "arc": 120, "hit": 0.40, "speed": 1.2, "stagger": true, "push": 9.0},
		"block": 0.95,
		"defense": 8,
		"idle": "Idle",
	},
	"lanza": {
		"name": "Lanza",
		"desc": "Mucho alcance. El ataque fuerte gira y golpea alrededor.",
		"gear": [],
		"light": [
			{"anim": "2H_Melee_Attack_Stab", "dmg": 13, "range": 3.4, "arc": 50, "hit": 0.42, "speed": 1.7},
			{"anim": "2H_Melee_Attack_Slice", "dmg": 12, "range": 3.2, "arc": 120, "hit": 0.40, "speed": 1.5},
		],
		"heavy": {"anim": "2H_Melee_Attack_Spin", "dmg": 24, "range": 3.4, "arc": 360, "hit": 0.35, "speed": 1.5, "stagger": true},
		"block": 0.5,
		"defense": 0,
		"idle": "2H_Melee_Idle",
	},
	"arco": {
		"name": "Arco",
		"desc": "Dispara flechas desde lejos. Débil de cerca.",
		"gear": [],
		"light": [
			{"anim": "2H_Ranged_Shoot", "dmg": 12, "hit": 0.35, "speed": 1.6, "arrows": 1},
		],
		"heavy": {"anim": "2H_Ranged_Shooting", "dmg": 10, "hit": 0.5, "speed": 1.1, "arrows": 3},
		"block": 0.3,
		"defense": 0,
		"idle": "Idle",
	},
}


## Poder especial de cada arma (tecla 1): nombre, descripción y recarga.
const SPECIALS := {
	"espada": {"name": "Cien Espadas", "desc": "Torbellino de cortes alrededor del héroe", "cd": 8.0},
	"escudo": {"name": "Muro Divino", "desc": "Onda que derriba y escudo invencible 3 s", "cd": 10.0},
	"lanza": {"name": "Lanza Relámpago", "desc": "Embestida veloz que atraviesa enemigos", "cd": 7.0},
	"arco": {"name": "Lluvia de Flechas", "desc": "Cae una lluvia de flechas sobre la zona", "cd": 9.0},
}
