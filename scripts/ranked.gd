extends RefCounted
## Ranked: ligas por puntos de clasificación (PR) que se ganan y se pierden por
## partida, con temporadas de un mes y premio al cerrar cada una.
##
##   Bronce III-I · Plata III-I · Oro III-I · Platino III-I · Diamante III-I · Maestro
##   100 PR por escalón; Maestro empieza en 1500 y no tiene techo.
##
## Se juega en línea (2 contra 2; si no hay 4 personas, se rellena con CPU).
## El servidor guarda la ficha de cada jugador en Supabase (ver cloud.gd) y
## aplica aquí las cuentas: estas funciones son puras, trabajan sobre un
## diccionario `rec` con las claves de new_record(), y el cliente las usa solo
## para mostrar (nombres de liga, barra de progreso).

const PER_TIER := 100
const MASTER := 1500
const DIVISIONS := ["Bronce", "Plata", "Oro", "Platino", "Diamante", "Maestro"]
const DIV_COLORS := [Color(0.8, 0.5, 0.25), Color(0.78, 0.8, 0.85), Color(1.0, 0.8, 0.3),
		Color(0.45, 0.85, 0.8), Color(0.55, 0.75, 1.0), Color(0.85, 0.45, 1.0)]
const TIER_NAMES := ["III", "II", "I"]
## Dificultad de las CPU que rellenan una partida, según la liga media.
const DIV_DIFFICULTY := [1, 1, 2, 2, 2, 2]
## Premio al cerrar la temporada, según la mejor liga alcanzada en ella.
const SEASON_REWARD := [200, 500, 1000, 2000, 4000, 8000]
const WIN := 25
const LOSS := 20
## Extra por cada victoria seguida, hasta STREAK_MAX.
const STREAK_BONUS := 5
const STREAK_MAX := 15
## Meta de las partidas de ranked.
const TARGET := 100
## Segundos en la cola antes de rellenar los asientos libres con CPU.
const FILL_AFTER := 30


## Ficha nueva de un jugador. "season": "AAAA-MM" de la temporada. "best":
## PR más alto de la temporada (decide el premio). "reward": premio pendiente
## de la temporada anterior. "streak": victorias seguidas.
static func new_record(player_name: String) -> Dictionary:
	return {"name": player_name, "season": season_id(), "pr": 0, "best": 0, "games": 0, "wins": 0, "streak": 0,
			"reward": 0}


static func season_id() -> String:
	return Time.get_date_string_from_system(true).substr(0, 7)


## Cambio de mes: se cierra la temporada (premio por la mejor liga) y los PR
## bajan a la mitad. Devuelve true si cambió algo.
static func roll_season(rec: Dictionary) -> bool:
	var now := season_id()
	if str(rec.season) == now:
		return false
	if int(rec.games) > 0:
		rec.reward = int(rec.reward) + SEASON_REWARD[division(int(rec.best))]
		rec.pr = int(rec.pr) / 2 / PER_TIER * PER_TIER
	rec.season = now
	rec.best = rec.pr
	rec.games = 0
	rec.wins = 0
	rec.streak = 0
	return true


static func division(points: int) -> int:
	if points >= MASTER:
		return DIVISIONS.size() - 1
	return points / (PER_TIER * 3)


## Nombre completo de la liga: "Oro II" o "Maestro".
static func rank_name(points: int) -> String:
	var d := division(points)
	if d == DIVISIONS.size() - 1:
		return "Maestro"
	return "%s %s" % [DIVISIONS[d], TIER_NAMES[(points / PER_TIER) % 3]]


## PR dentro del escalón actual (0-99); en Maestro, los PR por encima de 1500.
static func tier_progress(points: int) -> int:
	if points >= MASTER:
		return points - MASTER
	return points % PER_TIER


## PR que da o quita una partida. En Bronce y Plata perder quita la mitad, y
## nunca se baja de liga en Bronce ni de Plata a Bronce (suelo de liga).
static func points_for(rec: Dictionary, won: bool) -> int:
	var pr := int(rec.pr)
	if won:
		return WIN + mini(int(rec.streak) * STREAK_BONUS, STREAK_MAX)
	var d := division(pr)
	var loss := LOSS / 2 if d <= 1 else LOSS
	var floor_pr := PER_TIER * 3 if d == 1 else 0
	return -mini(loss, maxi(pr - floor_pr, 0))


## Apunta una partida en la ficha. Devuelve {delta, before, after, promoted, demoted}.
static func report(rec: Dictionary, won: bool) -> Dictionary:
	roll_season(rec)
	var before := int(rec.pr)
	var delta := points_for(rec, won)
	rec.pr = maxi(before + delta, 0)
	rec.games = int(rec.games) + 1
	if won:
		rec.wins = int(rec.wins) + 1
		rec.streak = int(rec.streak) + 1
	else:
		rec.streak = 0
	rec.best = maxi(int(rec.best), int(rec.pr))
	return {"delta": delta, "before": before, "after": int(rec.pr),
			"promoted": rank_name(int(rec.pr)) != rank_name(before) and delta > 0,
			"demoted": rank_name(int(rec.pr)) != rank_name(before) and delta < 0}


## Días que quedan para que acabe la temporada.
static func days_left() -> int:
	var d := Time.get_datetime_dict_from_system(true)
	var days_in := [31, 29 if int(d.year) % 4 == 0 else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	return days_in[int(d.month) - 1] - int(d.day) + 1


## Lo que ve el cliente de una ficha (sin claves internas).
static func public_view(rec: Dictionary) -> Dictionary:
	return {"name": str(rec.name), "season": str(rec.season), "pr": int(rec.pr), "best": int(rec.best),
			"games": int(rec.games), "wins": int(rec.wins), "streak": int(rec.streak), "reward": int(rec.reward)}
