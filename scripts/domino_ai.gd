extends RefCounted
## Inteligencia de las CPU.
##
## FÁCIL: juega casi al azar.
## INTERMEDIO: heurística (soltar fichas pesadas y dobles, conservar variedad).
## DIFÍCIL: deduce qué números le faltan a cada jugador por sus pases, reparte las
## fichas ocultas de forma coherente con eso muchas veces y simula cada mano hasta
## el final (Monte Carlo) para quedarse con la jugada que más puntos da a su pareja.
##
## La IA nunca mira las manos ajenas: solo usa el conjunto de fichas que no ha visto.

const State = preload("res://scripts/domino_state.gd")

enum { EASY, MEDIUM, HARD }

const THINK_MS := 450
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
	var a := t >> 3
	var b := t & 7
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
		var oa: int = o >> 3
		var ob: int = o & 7
		if oa == nl or ob == nl or oa == nr or ob == nr:
			keep += 1
	s += 2.0 * keep
	if smart:
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


static func _monte_carlo(state: State, p: int, moves: Array, rng: RandomNumberGenerator) -> int:
	var team := p % 2
	var totals: Array = []
	totals.resize(moves.size())
	totals.fill(0.0)
	var pool: Array = []
	for q in 4:
		if q != p:
			pool.append_array(state.hands[q])
	var worlds := 0
	var t0 := Time.get_ticks_msec()
	while worlds < MAX_WORLDS and Time.get_ticks_msec() - t0 < THINK_MS:
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


## Reparte las fichas ocultas entre los otros tres jugadores respetando lo que
## se sabe de sus pases.
static func _sample_world(state: State, p: int, pool: Array, rng: RandomNumberGenerator) -> State:
	var w: State = state.clone()
	var others: Array = []
	for q in 4:
		if q != p:
			others.append(q)
	for attempt in 25:
		var tiles: Array = pool.duplicate()
		State.shuffle(tiles, rng)
		# Primero las fichas con menos dueños posibles.
		var buckets: Array = [[], [], [], []]
		for t in tiles:
			buckets[_eligible(state, others, t).size()].append(t)
		var assign := {}
		for q in others:
			assign[q] = []
		var ok := true
		for n in [0, 1, 2, 3]:
			for t in buckets[n]:
				var cands: Array = []
				for q in _eligible(state, others, t):
					if assign[q].size() < state.hands[q].size():
						# Peso proporcional al hueco libre de cada mano.
						for r in state.hands[q].size() - assign[q].size():
							cands.append(q)
				if cands.is_empty():
					ok = false
					break
				assign[cands[rng.randi_range(0, cands.size() - 1)]].append(t)
			if not ok:
				break
		if ok:
			for q in others:
				w.hands[q] = assign[q]
			return w
	# Sin reparto coherente tras varios intentos: reparto libre.
	var free: Array = pool.duplicate()
	State.shuffle(free, rng)
	var at := 0
	for q in others:
		var n: int = state.hands[q].size()
		w.hands[q] = free.slice(at, at + n)
		at += n
	return w


static func _eligible(state: State, others: Array, t: int) -> Array:
	var out: Array = []
	for q in others:
		if not state.voids[q][t >> 3] and not state.voids[q][t & 7]:
			out.append(q)
	return out


static func _rollout(s: State, team: int, rng: RandomNumberGenerator) -> float:
	var guard := 0
	while not s.is_over() and guard < 160:
		guard += 1
		var moves: Array = s.legal_moves(s.turn)
		if moves.is_empty():
			s.apply_pass()
			continue
		s.apply_move(_best_heuristic(s, s.turn, moves, rng, false, 5.0))
	return s.score_for(team)
