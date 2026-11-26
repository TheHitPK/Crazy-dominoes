extends RefCounted
## Torneo de eliminación contra la CPU: 8 jugadores (tú y 7 CPU) en un cuadro.
##
##   Cuartos (8 -> 4)  ->  Semifinal (4 -> 2)  ->  Final (2 -> 1)
##
## Tus partidas son 1 contra 1 (State.DUEL) a 50 puntos, y la final a 100. Las
## partidas entre CPU se resuelven solas al terminar la tuya. Si pierdes, quedas
## fuera y cobras según hasta dónde llegaste. La entrada se paga al empezar.
## Se guarda en user://tournament.cfg, así que se puede seguir otro día.

const Wallet = preload("res://scripts/wallet.gd")
const Stats = preload("res://scripts/stats.gd")

const PATH := "user://tournament.cfg"
## Copas: entrada, nivel para entrar y dificultad de la CPU en cada ronda.
const CUPS := [
	{"name": "Copa Bronce", "entry": 100, "level": 1, "diff": [0, 1, 1], "color": Color(0.8, 0.5, 0.25)},
	{"name": "Copa Plata", "entry": 500, "level": 3, "diff": [1, 1, 2], "color": Color(0.78, 0.8, 0.85)},
	{"name": "Copa Oro", "entry": 2000, "level": 5, "diff": [1, 2, 2], "color": Color(1.0, 0.8, 0.3)},
]
const ROUND_NAMES := ["Cuartos de final", "Semifinal", "Final"]
const TARGETS := [50, 50, 100]
## Premio por ronda alcanzada, en veces la entrada: [cae en cuartos, en
## semifinal, en la final, campeón]. Con un 50 % de victorias se recupera más
## o menos la entrada; quien juega bien gana.
const PRIZE := [0.0, 0.5, 2.0, 5.0]
## Gemas para el campeón de cada copa (Bronce, Plata, Oro).
const CHAMPION_GEMS := [3, 8, 20]
const CPU_NAMES := ["Don Ramón", "Tía Carmen", "El Profe", "Chucho", "Mari", "El Flaco", "Doña Rosa", "Beto",
		"Lupe", "Toño", "La Nena", "Don Pepe", "Chela", "El Güero"]

## "cup": copa (-1 = no hay torneo). "players": 8 nombres, el 0 eres tú.
## "rounds": ganadores de cada ronda ya jugada (índices en players).
## "out": quedaste fuera (el torneo acabó para ti). "seed": para el reparto de nombres.
static var data := {"cup": -1, "players": [], "rounds": [], "out": false}


static func load_tournament() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key in data.keys():
		data[key] = cfg.get_value("t", key, data[key])


static func save() -> void:
	var cfg := ConfigFile.new()
	for key in data.keys():
		cfg.set_value("t", key, data[key])
	cfg.save(PATH)


static func active() -> bool:
	return int(data.cup) >= 0


static func cup() -> Dictionary:
	return CUPS[clampi(int(data.cup), 0, CUPS.size() - 1)]


## Ronda que toca jugar (0 cuartos, 1 semifinal, 2 final; 3 = terminado).
static func round_no() -> int:
	return data.rounds.size()


## Por qué no se puede entrar en esa copa, o "" si se puede.
static func cant_enter(index: int) -> String:
	var c: Dictionary = CUPS[index]
	if Wallet.level() < int(c.level):
		return "Se desbloquea en el nivel %d." % c.level
	if Wallet.coins() < int(c.entry):
		return "Te faltan %d monedas para la entrada." % (int(c.entry) - Wallet.coins())
	return ""


## Paga la entrada y sortea el cuadro. Devuelve false si no se puede.
static func start(index: int) -> bool:
	if cant_enter(index) != "":
		return false
	Wallet.add_coins(-int(CUPS[index].entry))
	var names: Array = CPU_NAMES.duplicate()
	names.shuffle()
	var players: Array = ["Tú"]
	players.append_array(names.slice(0, 7))
	data = {"cup": index, "players": players, "rounds": [], "out": false}
	Stats.add("tournaments")
	save()
	return true


## Quién sigue vivo en la ronda `r` (antes de jugarla), en orden de cuadro.
static func alive(r: int) -> Array:
	if r == 0:
		return range(8)
	return data.rounds[r - 1]


## Índice de mi rival en la ronda que toca.
static func opponent() -> int:
	var left := alive(round_no())
	var i := left.find(0)
	if i < 0:
		return -1
	return left[i ^ 1]


static func opponent_name() -> String:
	var o := opponent()
	return data.players[o] if o >= 0 else ""


static func difficulty() -> int:
	return cup().diff[clampi(round_no(), 0, 2)]


static func target() -> int:
	return TARGETS[clampi(round_no(), 0, 2)]


## Resultado de mi partida: resuelve la ronda entera y, si acabó el torneo para
## mí, paga el premio. Devuelve {prize, champion, out, round}.
static func report(won: bool) -> Dictionary:
	var r := round_no()
	var left := alive(r)
	var winners: Array = []
	for k in range(0, left.size(), 2):
		var a: int = left[k]
		var b: int = left[k + 1]
		if a == 0 or b == 0:
			winners.append(0 if won else (b if a == 0 else a))
		else:
			winners.append(a if randf() < 0.5 else b)
	data.rounds.append(winners)
	var result := {"prize": 0, "champion": false, "out": not won, "round": r, "gems": 0}
	if not won or r == 2:
		# Fuera, o ganaste la final: se cobra según la ronda alcanzada.
		var reached := r + (1 if won else 0)
		result.prize = roundi(int(cup().entry) * PRIZE[reached] / 5.0) * 5
		result.champion = won
		data.out = true
		if result.prize > 0:
			Wallet.add_coins(result.prize)
		if won:
			Stats.add("cups")
			result.gems = CHAMPION_GEMS[clampi(int(data.cup), 0, CHAMPION_GEMS.size() - 1)]
			Wallet.add_gems(result.gems)
		# Si perdí, el resto del cuadro se resuelve solo para ver quién ganó.
		while data.rounds.size() < 3:
			var rest: Array = data.rounds[data.rounds.size() - 1]
			var next: Array = []
			for k in range(0, rest.size(), 2):
				next.append(rest[k] if randf() < 0.5 else rest[k + 1])
			data.rounds.append(next)
	save()
	return result


## Cierra el torneo terminado (para poder entrar en otro).
static func close() -> void:
	data = {"cup": -1, "players": [], "rounds": [], "out": false}
	save()


## Abandonar a medias cuenta como perder la partida que toca.
static func forfeit() -> Dictionary:
	return report(false)
