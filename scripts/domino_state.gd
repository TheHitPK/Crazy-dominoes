extends RefCounted
## Estado y reglas del dominó en parejas (doble seis, 28 fichas, 4 jugadores).
##
## Fichas: entero a*8+b con a<=b.
## Jugadas: ficha*2+lado, donde lado 0 = extremo izquierdo y 1 = extremo derecho.
## Parejas: jugadores 0 y 2 contra 1 y 3. El turno avanza 0 -> 1 -> 2 -> 3.

const PLAYERS := 4
const HAND_SIZE := 7
const DOUBLE_SIX := 6 * 8 + 6

var hands: Array = [[], [], [], []]
var left: int = -1
var right: int = -1
var turn: int = 0
## Ficha obligatoria para abrir (el doble seis en la primera mano), o -1.
var forced: int = -1
## Jugador que se quedó sin fichas, o -1.
var out_player: int = -1
## Tranca: nadie puede jugar.
var blocked: bool = false
## voids[p][n] == true: el jugador p pasó con el número n abierto, así que no lo tiene.
var voids: Array = []
var played: Array = []


func _init() -> void:
	for p in PLAYERS:
		var v: Array = []
		v.resize(7)
		v.fill(false)
		voids.append(v)


static func all_tiles() -> Array:
	var out: Array = []
	for a in 7:
		for b in range(a, 7):
			out.append(a * 8 + b)
	return out


static func shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func deal(rng: RandomNumberGenerator) -> void:
	var tiles := all_tiles()
	shuffle(tiles, rng)
	for p in PLAYERS:
		var h: Array = tiles.slice(p * HAND_SIZE, (p + 1) * HAND_SIZE)
		h.sort()
		hands[p] = h


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
		var a: int = t >> 3
		var b: int = t & 7
		if a == left or b == left:
			out.append(t * 2)
		if left != right and (a == right or b == right):
			out.append(t * 2 + 1)
	return out


func apply_move(m: int) -> void:
	var t := m >> 1
	var a := t >> 3
	var b := t & 7
	hands[turn].erase(t)
	played.append(t)
	if left < 0:
		left = a
		right = b
	elif (m & 1) == 0:
		left = b if a == left else a
	else:
		right = b if a == right else a
	forced = -1
	if hands[turn].is_empty():
		out_player = turn
		return
	turn = (turn + 1) % PLAYERS
	blocked = _nobody_can_play()


func apply_pass() -> void:
	voids[turn][left] = true
	voids[turn][right] = true
	turn = (turn + 1) % PLAYERS


func is_over() -> bool:
	return out_player >= 0 or blocked


func hand_points(p: int) -> int:
	var total := 0
	for t in hands[p]:
		total += (t >> 3) + (t & 7)
	return total


## Devuelve {team, winner, points, blocked, totals}. team = -1 si la tranca queda empatada.
func result() -> Dictionary:
	var totals: Array = []
	var sum := 0
	for p in PLAYERS:
		var pts := hand_points(p)
		totals.append(pts)
		sum += pts
	if out_player >= 0:
		return {"team": out_player % 2, "winner": out_player, "points": sum,
				"blocked": false, "totals": totals}
	# Tranca: gana la pareja del jugador con menos puntos en la mano.
	var best: int = totals.min()
	var winner := -1
	var tied := false
	for p in PLAYERS:
		if totals[p] != best:
			continue
		if winner < 0:
			winner = p
		elif p % 2 != winner % 2:
			tied = true
	if tied:
		return {"team": -1, "winner": -1, "points": 0, "blocked": true, "totals": totals}
	return {"team": winner % 2, "winner": winner, "points": sum, "blocked": true, "totals": totals}


## Valor de la mano terminada desde el punto de vista de una pareja (para la IA).
func score_for(team: int) -> float:
	var r := result()
	if r.team < 0:
		return 0.0
	var v: float = float(r.points) + 15.0
	return v if r.team == team else -v


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
	s.blocked = blocked
	s.played = played.duplicate()
	return s


func _nobody_can_play() -> bool:
	for p in PLAYERS:
		for t in hands[p]:
			var a: int = t >> 3
			var b: int = t & 7
			if a == left or b == left or a == right or b == right:
				return false
	return true
