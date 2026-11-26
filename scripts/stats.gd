extends RefCounted
## Estadísticas del jugador (pantalla "Estadísticas"). Se guardan en
## user://stats.cfg. Son solo informativas: no dan monedas, así que no llevan
## firma como el monedero.

const PATH := "user://stats.cfg"

## "matches"/"wins": partidas completas contra la CPU (también torneo, ranked
## y desafío). "hands"/"dominoes": manos jugadas y manos que dominé yo.
## "streak"/"best_streak": victorias seguidas ahora y la mejor racha.
static var data := {"matches": 0, "wins": 0, "hands": 0, "dominoes": 0, "capicuas": 0, "blocked": 0,
		"streak": 0, "best_streak": 0, "coins_won": 0, "tournaments": 0, "cups": 0, "dailies": 0}

const LABELS := [
	["matches", "Partidas jugadas"],
	["wins", "Partidas ganadas"],
	["win_rate", "Porcentaje de victorias"],
	["best_streak", "Mejor racha"],
	["hands", "Manos jugadas"],
	["dominoes", "Manos dominadas por ti"],
	["capicuas", "Capicúas"],
	["blocked", "Trancas"],
	["coins_won", "Monedas ganadas"],
	["tournaments", "Torneos jugados"],
	["cups", "Copas ganadas"],
	["dailies", "Desafíos del día superados"],
]


static func load_stats() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key in data.keys():
		data[key] = int(cfg.get_value("stats", key, data[key]))


static func save() -> void:
	var cfg := ConfigFile.new()
	for key in data.keys():
		cfg.set_value("stats", key, data[key])
	cfg.save(PATH)


static func add(key: String, n: int = 1) -> void:
	data[key] = int(data.get(key, 0)) + n
	save()


## Fin de una mano: `mine` = la dominé yo; `capicua` y `blocked` según cómo acabó.
static func hand_done(mine: bool, capicua: bool, blocked: bool) -> void:
	data.hands += 1
	if mine:
		data.dominoes += 1
		if capicua:
			data.capicuas += 1
	if blocked:
		data.blocked += 1
	save()


static func match_done(won: bool, coins: int) -> void:
	data.matches += 1
	data.coins_won += coins
	if won:
		data.wins += 1
		data.streak += 1
		data.best_streak = maxi(data.best_streak, data.streak)
	else:
		data.streak = 0
	save()


## Texto de una fila de la pantalla de estadísticas.
static func value_text(key: String) -> String:
	if key == "win_rate":
		return "—" if data.matches == 0 else "%d %%" % roundi(100.0 * data.wins / data.matches)
	return str(int(data.get(key, 0)))
