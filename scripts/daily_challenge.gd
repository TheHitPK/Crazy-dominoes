extends RefCounted
## Desafío del día: la misma partida para todos ese día (el reparto sale de la
## fecha) en parejas contra la CPU difícil, a 50 puntos. Un intento gratis al
## día; los siguientes, viendo un anuncio. Ganarlo da monedas y alarga la racha.
## Se guarda en user://daily.cfg.

const Wallet = preload("res://scripts/wallet.gd")
const Stats = preload("res://scripts/stats.gd")

const PATH := "user://daily.cfg"
const REWARD := 300
## Extra por día seguido superado, hasta 7 días.
const STREAK_BONUS := 50
## Gemas por superar el desafío del día.
const GEMS := 3
const TARGET := 50
const DIFFICULTY := 2
## Cada día tiene un modo distinto (índice en State.MODE_NAMES), en rueda.
const MODES := 3

## "day": último día jugado. "tries": intentos usados ese día. "done": superado
## ese día. "streak": días seguidos superados. "last_win": último día superado.
static var data := {"day": "", "tries": 0, "done": false, "streak": 0, "last_win": ""}


static func load_daily() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key in data.keys():
		data[key] = cfg.get_value("d", key, data[key])


static func save() -> void:
	var cfg := ConfigFile.new()
	for key in data.keys():
		cfg.set_value("d", key, data[key])
	cfg.save(PATH)


static func today() -> String:
	return Time.get_date_string_from_system()


static func _roll() -> void:
	if str(data.day) != today():
		data.day = today()
		data.tries = 0
		data.done = false
		save()


static func done() -> bool:
	_roll()
	return bool(data.done)


## El primer intento del día es gratis; los demás piden un anuncio.
static func free_try() -> bool:
	_roll()
	return int(data.tries) == 0


static func use_try() -> void:
	_roll()
	data.tries = int(data.tries) + 1
	save()


## Semilla del reparto de hoy: igual en todos los teléfonos.
static func seed_value() -> int:
	return hash("crazy-dominoes-desafio-" + today())


static func mode() -> int:
	return abs(seed_value()) % MODES


static func reward() -> int:
	return REWARD + STREAK_BONUS * mini(_next_streak() - 1, 6)


static func _next_streak() -> int:
	var yesterday := Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) - 86400)
	return int(data.streak) + 1 if str(data.last_win) == yesterday else 1


## Desafío superado: cobra y alarga la racha. Devuelve las monedas.
static func complete() -> int:
	if done():
		return 0
	var coins := reward()
	data.streak = _next_streak()
	data.last_win = today()
	data.done = true
	save()
	Wallet.add_coins(coins)
	Wallet.add_gems(GEMS)
	Stats.add("dailies")
	return coins
