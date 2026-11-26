extends RefCounted
## Estado y reglas del dominó (doble seis o doble nueve, hasta 4 asientos).
##
## Fichas: entero (a << shift) | b con a<=b. En doble seis shift = 3 (a*8+b),
## que es lo que viaja por la red y no puede cambiar. En doble nueve shift = 4
## (a*16+b). Lee los valores siempre con hi() y lo() y crea fichas con code().
## El juego de fichas es estático (use_set): la partida lo pone al empezar y lo
## devuelve a doble seis al terminar; el servidor nunca lo cambia.
## Jugadas: ficha*2+lado, donde lado 0 = extremo izquierdo y 1 = extremo derecho.
## Asientos 0..3; el turno avanza 0 -> 1 -> 2 -> 3 saltando los vacíos.
## Formatos (ver PAIRS...): en parejas, 0 y 2 contra 1 y 3; en los demás cada
## jugador va por su cuenta y su "equipo" es su propio asiento (team_of).

const PLAYERS := 4
## Fichas por jugador en doble seis; en doble nueve, NINE_HAND (ver hand_size).
const HAND_SIZE := 7
const NINE_HAND := 10
## El doble seis en la codificación de doble seis (la de la red).
const DOUBLE_SIX := 6 * 8 + 6

## Número más alto del juego de fichas (6 o 9) y bits del número de abajo.
static var top := 6
static var shift := 3

## Modos de juego: cambian solo cómo se cuentan los puntos de cada mano.
##   CLASSIC: la pareja ganadora suma las fichas de las cuatro manos.
##   RIVALS: solo suma las fichas que les quedaron a los rivales.
##   CAPICUA: como el clásico, más CAPICUA_BONUS si se domina con una ficha que
##            casaba en los dos extremos.
##   FIVES: "Cincos". Cada vez que los extremos suman múltiplo de 5, quien juega
##          se lo apunta al momento; al dominar se suman las fichas de los
##          rivales redondeadas a 5. Solo contra la CPU.
enum { CLASSIC, RIVALS, CAPICUA, FIVES }
const MODE_NAMES := ["Clásico", "Por rivales", "Capicúa", "Cincos"]
## Modos que entienden las salas en red (las APK viejas solo conocen estos).
const NET_MODES := 3
const CAPICUA_BONUS := 25
## Metas de puntos que se pueden elegir para ganar la partida.
const TARGETS := [50, 100, 150, 200]
const DEFAULT_TARGET := 100

## Formatos: cuántos juegan y si hay parejas. La red solo usa PAIRS.
##   PAIRS: 2 contra 2, se reparten las 28 fichas.
##   SOLO: 4 jugadores, todos contra todos; también se reparten las 28.
##   DUEL: 1 contra 1 en los asientos 0 y 2. Sobran 14 fichas, que quedan en
##         el pozo: quien no puede jugar roba hasta que le salga una que case.
const PAIRS := 0
const SOLO := 1
const DUEL := 2
const FORMAT_NAMES := ["Parejas", "Todos contra todos", "1 contra 1"]

var mode: int = CLASSIC
var format: int = PAIRS
## Fichas boca abajo que se pueden robar (solo en DUEL).
var pool: Array = []
## Doble nueve en parejas o todos contra todos: fichas que no se reparten y no
## se pueden robar ("dormidas"). Nadie las ve.
var sleeping: Array = []
## Cincos: puntos apuntados en la mano por equipo (team_of) y los de la última jugada.
var fives: Array = [0, 0, 0, 0]
var last_fives := 0
## El extremo izquierdo o derecho lo cierra un doble (cuenta dos veces en Cincos).
var left_dbl := false
var right_dbl := false
var hands: Array = [[], [], [], []]
var left: int = -1
var right: int = -1
var turn: int = 0
## Ficha obligatoria para abrir (el doble seis en la primera mano), o -1.
var forced: int = -1
## Jugador que se quedó sin fichas, o -1.
var out_player: int = -1
## Quien dominó lo hizo con una ficha que casaba en los dos extremos (distintos).
var capicua := false
## Tranca: nadie puede jugar.
var blocked: bool = false
## voids[p][n] == true: el jugador p pasó con el número n abierto, así que no lo tiene.
var voids: Array = []
var played: Array = []


func _init() -> void:
	for p in PLAYERS:
		var v: Array = []
		v.resize(top + 1)
		v.fill(false)
		voids.append(v)


## Elige el juego de fichas: doble nueve (true) o doble seis (false).
static func use_set(nine: bool) -> void:
	top = 9 if nine else 6
	shift = 4 if nine else 3


static func hi(t: int) -> int:
	return t >> shift


static func lo(t: int) -> int:
	return t & ((1 << shift) - 1)


static func code(a: int, b: int) -> int:
	return (mini(a, b) << shift) | maxi(a, b)


static func hand_size() -> int:
	return NINE_HAND if top == 9 else HAND_SIZE


static func all_tiles() -> Array:
	var out: Array = []
	for a in top + 1:
		for b in range(a, top + 1):
			out.append(code(a, b))
	return out


static func shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func seated(p: int) -> bool:
	return format != DUEL or p % 2 == 0


## Pareja (en PAIRS) o asiento del jugador: lo que suma puntos junto.
func team_of(p: int) -> int:
	return p % 2 if format == PAIRS else p


func next_seat(p: int) -> int:
	var q := (p + 1) % PLAYERS
	while not seated(q):
		q = (q + 1) % PLAYERS
	return q


func deal(rng: RandomNumberGenerator) -> void:
	var tiles := all_tiles()
	shuffle(tiles, rng)
	var at := 0
	for p in PLAYERS:
		if not seated(p):
			hands[p] = []
			continue
		var h: Array = tiles.slice(at, at + hand_size())
		at += hand_size()
		h.sort()
		hands[p] = h
	# Lo que sobra se roba en 1 contra 1; en los demás formatos, en doble
	# nueve, se queda dormido (en doble seis no sobra nada).
	if format == DUEL:
		pool = tiles.slice(at)
		sleeping = []
	else:
		pool = []
		sleeping = tiles.slice(at)


## Ficha con la que se abre la primera mano: el doble seis o, si quedó en el
## pozo (1 contra 1), el doble más alto repartido; sin dobles, la más pesada.
func opening_tile() -> int:
	var best := -1
	var best_value := -1
	for p in PLAYERS:
		for t in hands[p]:
			var a: int = hi(t)
			var b: int = lo(t)
			var value := (100 + a) if a == b else a + b
			if value > best_value:
				best_value = value
				best = t
	return best


func can_draw() -> bool:
	return not pool.is_empty()


## El jugador del turno roba una ficha del pozo. Devuelve la ficha.
func draw() -> int:
	var t: int = pool.pop_back()
	hands[turn].append(t)
	return t


func holder_of(code: int) -> int:
	for p in PLAYERS:
		if hands[p].has(code):
			return p
	return 0


func legal_moves(p: int) -> Array:
	var out: Array = []
	var h: Array = hands[p]
	if left < 0:
		for t in h:
			if forced < 0 or t == forced:
				out.append(t * 2 + 1)
		return out
	for t in h:
		var a: int = hi(t)
		var b: int = lo(t)
		if a == left or b == left:
			out.append(t * 2)
		if left != right and (a == right or b == right):
			out.append(t * 2 + 1)
	return out


func apply_move(m: int) -> void:
	var t := m >> 1
	var a := hi(t)
	var b := lo(t)
	hands[turn].erase(t)
	played.append(t)
	if hands[turn].is_empty() and left >= 0 and left != right:
		capicua = (a == left or b == left) and (a == right or b == right)
	if left < 0:
		left = a
		right = b
		left_dbl = a == b
		right_dbl = a == b
	elif (m & 1) == 0:
		left = b if a == left else a
		left_dbl = a == b
	else:
		right = b if a == right else a
		right_dbl = a == b
	forced = -1
	last_fives = 0
	if mode == FIVES:
		var sum := ends_sum()
		if sum > 0 and sum % 5 == 0:
			last_fives = sum
			fives[team_of(turn)] += sum
	if hands[turn].is_empty():
		out_player = turn
		return
	turn = next_seat(turn)
	blocked = _nobody_can_play()


## Cincos: lo que suman los extremos abiertos. Un doble en un extremo cuenta
## sus dos mitades; con una sola ficha en la mesa, cuenta la ficha entera.
func ends_sum() -> int:
	if left < 0:
		return 0
	if played.size() == 1:
		return left + right
	return left * (2 if left_dbl else 1) + right * (2 if right_dbl else 1)


## Solo se pasa sin fichas que casen y con el pozo vacío, así que la deducción
## "no tiene ese número" no la estropea un robo posterior.
func apply_pass() -> void:
	voids[turn][left] = true
	voids[turn][right] = true
	turn = next_seat(turn)
	# En 1 contra 1 la tranca puede llegar al vaciarse el pozo, no con una jugada.
	blocked = _nobody_can_play()


func is_over() -> bool:
	return out_player >= 0 or blocked


func hand_points(p: int) -> int:
	var total := 0
	for t in hands[p]:
		total += hi(t) + lo(t)
	return total


## Devuelve {team, winner, points, blocked, totals, capicua}. team = -1 si la
## tranca queda empatada. Los puntos dependen del modo (ver CLASSIC...). Las
## fichas del pozo no cuentan.
func result() -> Dictionary:
	var totals: Array = []
	for p in PLAYERS:
		totals.append(hand_points(p))
	if out_player >= 0:
		var team := team_of(out_player)
		var bonus := mode == CAPICUA and capicua
		return {"team": team, "winner": out_player,
				"points": _points_for(team, totals) + (CAPICUA_BONUS if bonus else 0),
				"blocked": false, "totals": totals, "capicua": bonus}
	# Tranca: gana (la pareja de) quien tenga menos puntos en la mano.
	var best := 1 << 30
	for p in PLAYERS:
		if seated(p):
			best = mini(best, totals[p])
	var winner := -1
	var tied := false
	for p in PLAYERS:
		if not seated(p) or totals[p] != best:
			continue
		if winner < 0:
			winner = p
		elif team_of(p) != team_of(winner):
			tied = true
	if tied:
		return {"team": -1, "winner": -1, "points": 0, "blocked": true, "totals": totals, "capicua": false}
	return {"team": team_of(winner), "winner": winner, "points": _points_for(team_of(winner), totals),
			"blocked": true, "totals": totals, "capicua": false}


## Puntos que se lleva `team` según el modo: todas las manos o solo las de los
## rivales (en Cincos, las de los rivales redondeadas al 5 más cercano).
func _points_for(team: int, totals: Array) -> int:
	var sum := 0
	for p in PLAYERS:
		if (mode != RIVALS and mode != FIVES) or team_of(p) != team:
			sum += totals[p]
	if mode == FIVES:
		return roundi(sum / 5.0) * 5
	return sum


## Valor de la mano terminada desde el punto de vista de una pareja (para la IA).
func score_for(team: int) -> float:
	var r := result()
	var v := 0.0
	if r.team >= 0:
		v = float(r.points) + 15.0
		v = v if r.team == team else -v
	if mode == FIVES:
		# Lo apuntado durante la mano también cuenta.
		var best_other := 0
		for q in fives.size():
			if q != team:
				best_other = maxi(best_other, fives[q])
		v += fives[team] - best_other
	return v


func clone():
	var s = get_script().new()
	for p in PLAYERS:
		s.hands[p] = hands[p].duplicate()
		s.voids[p] = voids[p].duplicate()
	s.left = left
	s.right = right
	s.turn = turn
	s.forced = forced
	s.out_player = out_player
	s.capicua = capicua
	s.mode = mode
	s.format = format
	s.pool = pool.duplicate()
	s.sleeping = sleeping.duplicate()
	s.fives = fives.duplicate()
	s.last_fives = last_fives
	s.left_dbl = left_dbl
	s.right_dbl = right_dbl
	s.blocked = blocked
	s.played = played.duplicate()
	return s


func _nobody_can_play() -> bool:
	if not pool.is_empty():
		# Aún se puede robar.
		return false
	for p in PLAYERS:
		for t in hands[p]:
			var a: int = hi(t)
			var b: int = lo(t)
			if a == left or b == left or a == right or b == right:
				return false
	return true
