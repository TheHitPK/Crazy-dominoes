extends RefCounted
## Inteligencia de las CPU.
##
## FÁCIL: juega casi al azar.
## INTERMEDIO: heurística (soltar fichas pesadas y dobles, conservar variedad).
## DIFÍCIL: deduce qué números le faltan a cada jugador por sus pases, reparte las
## fichas ocultas de forma coherente con eso muchas veces y simula cada mano hasta
## el final (Monte Carlo) para quedarse con la jugada que más puntos da a su pareja.
##
## La IA nunca mira las manos ajenas ni el pozo: solo usa el conjunto de fichas
## que no ha visto. Sin parejas (state.format), "mi pareja" es solo yo.

const State = preload("res://scripts/domino_state.gd")

enum { EASY, MEDIUM, HARD }

## Milisegundos que el nivel difícil dedica a simular cada jugada. En el
## navegador se baja, porque allí piensa en el hilo principal y congela la imagen.
static var think_ms := 450
const MAX_WORLDS := 400


static func choose(state: State, p: int, difficulty: int, seed_value: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var moves: Array = state.legal_moves(p)
	if moves.is_empty():
		return -1
	if moves.size() == 1:
		return moves[0]
	match difficulty:
		EASY:
			if rng.randf() < 0.65:
				return moves[rng.randi_range(0, moves.size() - 1)]
			return _best_heuristic(state, p, moves, rng, false, 6.0)
		MEDIUM:
			return _best_heuristic(state, p, moves, rng, false, 2.0)
	return _monte_carlo(state, p, moves, rng)


static func _best_heuristic(state: State, p: int, moves: Array, rng: RandomNumberGenerator,
		smart: bool, noise: float) -> int:
	var best: int = moves[0]
	var best_score := -1e9
	for m in moves:
		var v := _score(state, p, m, smart) + rng.randf() * noise
		if v > best_score:
			best_score = v
			best = m
	return best


static func _score(state: State, p: int, m: int, smart: bool) -> float:
	var t := m >> 1
	var a := State.hi(t)
	var b := State.lo(t)
	var nl := state.left
	var nr := state.right
	if nl < 0:
		nl = a
		nr = b
	elif (m & 1) == 0:
		nl = b if a == nl else a
	else:
		nr = b if a == nr else a
	var s := float(a + b)
	if a == b:
		s += 5.0
	# Fichas que me quedarían jugables: conservar salidas.
	var keep := 0
	for o in state.hands[p]:
		if o == t:
			continue
		var oa: int = State.hi(o)
		var ob: int = State.lo(o)
		if oa == nl or ob == nl or oa == nr or ob == nr:
			keep += 1
	s += 2.0 * keep
	if state.mode == State.FIVES:
		# Cincos: apuntarse ya los extremos múltiplo de 5 vale mucho.
		var sum := _ends_after(state, m, a, b, nl, nr)
		if sum > 0 and sum % 5 == 0:
			s += 1.5 * sum
	if smart and state.format != State.PAIRS:
		# Todos son rivales: conviene dejar números que alguno ya no tiene.
		for q in 4:
			if q != p and state.seated(q):
				for e in [nl, nr]:
					if state.voids[q][e]:
						s += 4.0
	elif smart:
		var nxt := (p + 1) % 4
		var mate := (p + 2) % 4
		var prev := (p + 3) % 4
		for e in [nl, nr]:
			if state.voids[nxt][e]:
				s += 5.0
			if state.voids[prev][e]:
				s += 3.0
			if state.voids[mate][e]:
				s -= 4.0
	return s


## Suma de los extremos tras la jugada `m` (como State.ends_sum), sin clonar.
static func _ends_after(state: State, m: int, a: int, b: int, nl: int, nr: int) -> int:
	if state.left < 0:
		return a + b
	var ld := state.left_dbl
	var rd := state.right_dbl
	if (m & 1) == 0:
		ld = a == b
	else:
		rd = a == b
	return nl * (2 if ld else 1) + nr * (2 if rd else 1)


static func _monte_carlo(state: State, p: int, moves: Array, rng: RandomNumberGenerator) -> int:
	var team := state.team_of(p)
	var totals: Array = []
	totals.resize(moves.size())
	totals.fill(0.0)
	var pool: Array = []
	for q in 4:
		if q != p:
			pool.append_array(state.hands[q])
	# Las fichas del pozo y las dormidas tampoco las ve: son parte de lo oculto.
	pool.append_array(state.pool)
	pool.append_array(state.sleeping)
	var worlds := 0
	var t0 := Time.get_ticks_msec()
	while worlds < MAX_WORLDS and Time.get_ticks_msec() - t0 < think_ms:
		var world: State = _sample_world(state, p, pool, rng)
		for i in moves.size():
			var s: State = world.clone()
			s.apply_move(moves[i])
			totals[i] += _rollout(s, team, rng)
		worlds += 1
	var best: int = moves[0]
	var best_score := -1e9
	for i in moves.size():
		var v: float = totals[i] / maxf(worlds, 1.0) + 0.1 * _score(state, p, moves[i], true)
		if v > best_score:
			best_score = v
			best = moves[i]
	return best


## Reparte las fichas ocultas entre los demás jugadores (y el pozo y las
## dormidas, que se tratan como dueños, POOL y SLEEP) respetando lo que se
## sabe de sus pases.
const POOL := 4
const SLEEP := 5

static func _sample_world(state: State, p: int, pool: Array, rng: RandomNumberGenerator) -> State:
	var w: State = state.clone()
	var others: Array = []
	for q in 4:
		if q != p and state.seated(q):
			others.append(q)
	if not state.pool.is_empty():
		others.append(POOL)
	if not state.sleeping.is_empty():
		others.append(SLEEP)
	for attempt in 25:
		var tiles: Array = pool.duplicate()
		State.shuffle(tiles, rng)
		# Primero las fichas con menos dueños posibles.
		var buckets: Array = [[], [], [], [], [], []]
		for t in tiles:
			buckets[_eligible(state, others, t).size()].append(t)
		var assign := {}
		for q in others:
			assign[q] = []
		var ok := true
		for n in buckets.size():
			for t in buckets[n]:
				var cands: Array = []
				for q in _eligible(state, others, t):
					var room: int = _room(state, q) - assign[q].size()
					# Peso proporcional al hueco libre de cada mano.
					for r in room:
						cands.append(q)
				if cands.is_empty():
					ok = false
					break
				assign[cands[rng.randi_range(0, cands.size() - 1)]].append(t)
			if not ok:
				break
		if ok:
			for q in others:
				_give(w, q, assign[q])
			return w
	# Sin reparto coherente tras varios intentos: reparto libre.
	var free: Array = pool.duplicate()
	State.shuffle(free, rng)
	var at := 0
	for q in others:
		var n: int = _room(state, q)
		_give(w, q, free.slice(at, at + n))
		at += n
	return w


static func _room(state: State, q: int) -> int:
	if q == POOL:
		return state.pool.size()
	if q == SLEEP:
		return state.sleeping.size()
	return state.hands[q].size()


static func _give(w: State, q: int, tiles: Array) -> void:
	if q == POOL:
		w.pool = tiles
	elif q == SLEEP:
		w.sleeping = tiles
	else:
		w.hands[q] = tiles


static func _eligible(state: State, others: Array, t: int) -> Array:
	var out: Array = []
	for q in others:
		if q == POOL or q == SLEEP or (not state.voids[q][State.hi(t)] and not state.voids[q][State.lo(t)]):
			out.append(q)
	return out


static func _rollout(s: State, team: int, rng: RandomNumberGenerator) -> float:
	var guard := 0
	while not s.is_over() and guard < 260:
		guard += 1
		var moves: Array = s.legal_moves(s.turn)
		if moves.is_empty():
			if s.can_draw():
				s.draw()
			else:
				s.apply_pass()
			continue
		s.apply_move(_best_heuristic(s, s.turn, moves, rng, false, 5.0))
	return s.score_for(team)
