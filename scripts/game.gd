extends Node2D
## Partida de dominó en parejas: tú (abajo) y tu compañero (arriba) contra las
## dos CPU de los lados. Controla turnos, animaciones, tablero y marcador.

signal exit_to_menu
## Partida en red terminada: volver a la sala para jugar otra.
signal back_to_room
signal _human_done(move: int)
signal _panel_done(action: String)

const State = preload("res://scripts/domino_state.gd")
const AI = preload("res://scripts/domino_ai.gd")
const Tile = preload("res://scripts/tile.gd")
const Table = preload("res://scripts/table.gd")
const Hand = preload("res://scripts/hand.gd")
const FancyButton = preload("res://scripts/fancy_button.gd")
const Settings = preload("res://scripts/settings.gd")
const Glass = preload("res://scripts/glass.gd")
const ChalkBoard = preload("res://scripts/chalk_board.gd")

const TARGET_SCORE := 100
const BOARD_SCALE := 1.25
## Radio (en unidades de pantalla) dentro del cual un toque cuenta como acierto.
const TOUCH_RADIUS := 80.0
## Lado corto de una ficha en unidades de tablero.
const S := 40.0

const NAMES := ["Tú", "Rival Este", "Compañero", "Rival Oeste"]
const DIFF_NAMES := ["Fácil", "Intermedio", "Difícil"]
const SEAT_ROT := [0.0, -PI / 2.0, PI, PI / 2.0]
## Tus fichas son grandes para poder tocarlas con el dedo.
const SEAT_SCALE := [2.0, 0.62, 0.62, 0.62]
const SLATE_SCALE := 1.1
const TEAM_COLORS := [Color(0.2, 0.45, 0.85), Color(0.8, 0.22, 0.2)]
## Aspecto de las CPU: [piel, estilo de mano, color de uñas/guantes, bebida].
## El del jugador 0 sale de los ajustes.
const CPU_LOOKS := [
	[],
	[Color(0.78, 0.56, 0.4), Hand.GLOVES, Color(0.12, 0.12, 0.14), Glass.BEER],
	[Color(0.6, 0.42, 0.3), Hand.NATURAL, Color.WHITE, Glass.LEMONADE],
	[Color(0.96, 0.82, 0.68), Hand.NAILS, Color(0.85, 0.1, 0.22), Glass.COFFEE],
]
## Posavasos de cada jugador (a su derecha): índice en Table.cup_centers().
const CUP_OF := [3, 1, 0, 2]
const GOLD := Color(1.0, 0.84, 0.3)
const CREAM := Color(0.97, 0.93, 0.82)
## Interruptores de sonido del panel de ajustes: clave en Settings.audio -> texto.
const SOUND_OPTIONS := {"pass_voice": "Audios al pasar", "sfx": "Efectos de sonido", "music": "Música"}

var difficulty: int = AI.MEDIUM
## Modo demostración: la CPU juega también tu mano.
var autoplay := false
var sfx: Node
## Partida en red (ver net.gd). Si es null, se juega en este teléfono contra CPU.
## En red el servidor reparte y decide; aquí los asientos se numeran siempre
## desde el mío: 0 = yo, 1 = derecha, 2 = compañero, 3 = izquierda.
var net: Node
## Mi asiento según el servidor.
var my_seat := 0
var names: Array = NAMES.duplicate()
## Aspecto de los otros jugadores humanos, por asiento; vacío si es CPU.
var seat_looks: Array = [{}, {}, {}, {}]
var _net_scores: Array = [0, 0]

## Disposición en pantalla; depende del ancho extra del teléfono (ver _layout).
## Zona de la mesa donde se arma la cadena de fichas.
var play_rect: Rect2
## Mitad del ancho de una fila de la cadena, en unidades de tablero.
var row_limit: float
var seat_pos: Array
var plate_rect: Array
var bubble_pos: Array
## Pizarras del marcador: junto a ti (Nosotros) y junto al Rival Este (Ellos).
var slate_pos: Array

var rng := RandomNumberGenerator.new()
var state: State
var scores: Array = [0, 0]
var hand_no := 0
var starter := -1

var tiles := {}
var hand_tiles: Array = [[], [], [], []]
var board_tiles: Array = []
## Extremos de la cadena: [izquierdo, derecho]. Cada uno {p, d, vs, next_h, vn}.
var arms: Array = []
var board_s := BOARD_SCALE
var board_off := Vector2.ZERO

var hands_gfx: Array = []
var tile_layer: Node2D
var fx_layer: Node2D
var ghosts: Array = []
var hud: Control
var plates: Array = []
var plate_labels: Array = []
var glasses: Array = []
var boards: Array = []
var info_lbl: Label
var banner: Label
var pass_btn: FancyButton
var overlay: ColorRect
var end_panel: Panel
var opt_panel: Panel
var _sound_btns := {}
var confetti: CPUParticles2D

var _awaiting := false
var _choices: Array = []
var _pending := -1
var _hover: Tile
var _last: Tile
var _ai_task := -1
var _banner_tw: Tween
var _plate_tw: Tween


## Marcador pulsante que indica dónde caería la ficha en un extremo.
class Ghost extends Node2D:
	var side := 0
	var t := 0.0
	var sb := StyleBoxFlat.new()

	func _init() -> void:
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(7)

	func _process(delta: float) -> void:
		if visible:
			t += delta
			queue_redraw()

	func _draw() -> void:
		var a := 0.6 + 0.4 * sin(t * 6.0)
		sb.bg_color = Color(1.0, 0.85, 0.2, 0.12 + 0.18 * a)
		sb.border_color = Color(1.0, 0.85, 0.2, a)
		sb.draw(get_canvas_item(), Rect2(-20, -40, 40, 80))

	func hit(p: Vector2) -> bool:
		var l := to_local(p)
		return absf(l.x) <= 30.0 and absf(l.y) <= 50.0

	## Distancia al punto tocado, para elegir el extremo más cercano al dedo.
	func distance(p: Vector2) -> float:
		return global_position.distance_to(p)


## Onda de impacto cuando una ficha golpea la mesa.
class Ring extends Node2D:
	var r := 8.0:
		set(v):
			r = v
			queue_redraw()

	func _draw() -> void:
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(1, 1, 1, 0.7), 3.0, true)


## Disposición en vertical. Tú y tu compañero se pegan a los bordes de abajo y
## arriba de la mesa, que en un teléfono es Table.pad más alta por cada lado
## que el diseño base de 720x1280. Los rivales quedan centrados a los lados.
func _layout() -> void:
	var p: float = Table.pad
	play_rect = Rect2(125, 270.0 - p, 470, 675.0 + p * 2.0)
	# La cadena corre en vertical, así que el límite de fila sale del alto.
	row_limit = play_rect.size.y * 0.5 / BOARD_SCALE - S - 6.0
	var mid := play_rect.get_center().y
	seat_pos = [Vector2(360, 1176.0 + p), Vector2(636, mid), Vector2(360, 92.0 - p), Vector2(84, mid)]
	plate_rect = [Rect2(396, 958.0 + p, 150, 30), Rect2(586, mid - 172.0, 124, 52),
			Rect2(285, 126.0 - p, 150, 30), Rect2(10, mid - 172.0, 124, 52)]
	bubble_pos = [Vector2(360, 900.0 + p), Vector2(500, mid), Vector2(360, 310.0 - p), Vector2(220, mid)]
	slate_pos = [Vector2(170, 958.0 + p), Vector2(444, 164.0 - p)]


## Gira un punto del tablero 90°: la cadena se calcula en horizontal y se
## muestra en vertical, que es como cabe en un teléfono de pie.
static func _turn(v: Vector2) -> Vector2:
	return Vector2(-v.y, v.x)


func _ready() -> void:
	_layout()
	rng.randomize()
	board_off = play_rect.get_center()
	if net != null and not net.events.is_empty():
		# El reparto que abre la partida ya dice quién se sienta dónde.
		_net_seats(net.events[0])
	add_child(Table.new())
	for p in 4:
		var h: Hand = Hand.new()
		h.position = seat_pos[p]
		h.rotation = SEAT_ROT[p]
		h.k = SEAT_SCALE[p]
		h.sleeve = TEAM_COLORS[p % 2]
		var look: Dictionary = seat_looks[p]
		if p == 0:
			h.skin = Settings.skin_color()
			h.style = Settings.data.hand_style
			h.accent = Settings.accent_color()
		elif not look.is_empty():
			# Otra persona: se ve con las manos que ella eligió.
			h.skin = Settings.SKINS[clampi(look.get("skin", 1), 0, Settings.SKINS.size() - 1)]
			h.style = clampi(look.get("hand_style", 0), 0, 2)
			h.accent = Settings.ACCENTS[clampi(look.get("accent", 0), 0, Settings.ACCENTS.size() - 1)]
		else:
			h.skin = CPU_LOOKS[p][0]
			h.style = CPU_LOOKS[p][1]
			h.accent = CPU_LOOKS[p][2]
		if p == 0:
			h.gap = 6.0
			h.fan = 0.00025
			h.arc = 0.00012
		else:
			h.gap = 4.0
			h.fan = 0.001
			h.arc = 0.0008
		h.z_index = 2
		add_child(h)
		hands_gfx.append(h)
	var cups := Table.cup_centers()
	for p in 4:
		var g: Glass = Glass.new()
		g.position = cups[CUP_OF[p]]
		g.drink = Settings.data.drink if p == 0 else CPU_LOOKS[p][3]
		if p != 0 and not seat_looks[p].is_empty():
			g.drink = clampi(seat_looks[p].get("drink", 0), 0, Glass.LIQUIDS.size() - 1)
		g.grip = hands_gfx[p].fill()
		g.toward = Vector2.DOWN.rotated(SEAT_ROT[p])
		g.z_index = 6
		add_child(g)
		glasses.append(g)
	tile_layer = Node2D.new()
	add_child(tile_layer)
	for side in 2:
		var g := Ghost.new()
		g.side = side
		g.z_index = 5
		g.visible = false
		add_child(g)
		ghosts.append(g)
	fx_layer = Node2D.new()
	fx_layer.z_index = 25
	add_child(fx_layer)
	_build_hud()
	if sfx != null:
		sfx.music(true)
	if net != null:
		_net_loop()
	else:
		_start_match()


func _exit_tree() -> void:
	if sfx != null:
		sfx.music(false)
	if _ai_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_ai_task)
		_ai_task = -1


# ---------------------------------------------------------------- flujo de juego

func _start_match() -> void:
	scores = [0, 0]
	hand_no = 0
	starter = -1
	_play_hand()


func _play_hand() -> void:
	hand_no += 1
	_reset_round()
	state = State.new()
	state.deal(rng)
	var opening := starter < 0
	if opening:
		# Primera mano: sale quien tenga el doble seis y debe abrir con él.
		starter = state.holder_of(State.DOUBLE_SIX)
		state.forced = State.DOUBLE_SIX
	state.turn = starter
	_refresh_score(false)
	await _announce_start(opening)
	while not state.is_over():
		var p := state.turn
		_set_active(p)
		var moves: Array = state.legal_moves(p)
		if moves.is_empty():
			await _do_pass(p)
			continue
		var mv: int
		if p == 0 and not autoplay:
			mv = await _human_turn(moves)
		else:
			mv = await _cpu_turn(p)
		await _do_move(p, mv)
	await _finish_hand()


## Reparte con animación y anuncia quién sale.
func _announce_start(opening: bool) -> void:
	await _animate_deal()
	if opening:
		_show_banner("Sale el doble seis: %s" % names[starter], GOLD)
	else:
		_show_banner("Sales tú" if starter == 0 else "Sale %s" % names[starter], GOLD)
	await _wait(1.0)


func _human_turn(moves: Array) -> int:
	_choices = moves
	_pending = -1
	_hover = null
	_awaiting = true
	for t: Tile in hand_tiles[0]:
		var ok := _playable(t.code)
		t.tween_marks(1.0 if ok else 0.0, 0.0 if ok else 1.0)
	_layout_hand(0, 0.2)
	var mv: int = await _human_done
	_awaiting = false
	_choices = []
	_hover = null
	_pending = -1
	_hide_ghosts()
	for t: Tile in hand_tiles[0]:
		t.tween_marks(0.0, 0.0)
	return mv


func _cpu_turn(p: int) -> int:
	var st: State = state.clone()
	var box := [-1]
	var seed_value := rng.randi()
	var diff := difficulty
	var t0 := Time.get_ticks_msec()
	if OS.has_feature("web"):
		# En el navegador no hay hilos: la IA piensa aquí mismo (main.gd le da menos tiempo).
		await get_tree().process_frame
		box[0] = AI.choose(st, p, diff, seed_value)
	else:
		# La IA piensa en otro hilo para no congelar las animaciones.
		_ai_task = WorkerThreadPool.add_task(func() -> void: box[0] = AI.choose(st, p, diff, seed_value))
		while not WorkerThreadPool.is_task_completed(_ai_task):
			await get_tree().process_frame
		WorkerThreadPool.wait_for_task_completion(_ai_task)
		_ai_task = -1
	var spent := (Time.get_ticks_msec() - t0) / 1000.0
	var think := rng.randf_range(0.55, 1.0)
	if spent < think:
		await _wait(think - spent)
	return box[0]


func _do_move(p: int, mv: int) -> void:
	var t := _commit_move(p, mv)
	_refit_board(t)

	if _last != null:
		_last.tween_marks(0.0, 0.0)
	_last = t
	t.z_index = 20
	if p != 0 or autoplay:
		t.flip_to(1.0, 0.28)
	var target := _b2s(t.board_pos)
	var tw := t.play_to(target, t.board_rot, board_s)
	_layout_hand(p, 0.3)
	hands_gfx[p].set_count(hand_tiles[p].size())
	_refresh_plates()
	await tw.finished
	t.z_index = 1
	t.tween_marks(0.6, 0.0)
	_play("clack", rng.randf_range(0.92, 1.1))
	_impact(target)
	if p != 0 and rng.randf() < 0.12:
		_drink(p)
	await _wait(0.18)


## Registra una jugada sin animarla: saca la ficha de la mano, calcula dónde
## cae en la cadena y actualiza el estado. Devuelve la ficha.
func _commit_move(p: int, mv: int) -> Tile:
	var code := mv >> 1
	var side := mv & 1
	var a := code >> 3
	var b := code & 7
	var dbl := a == b
	var t: Tile = tiles[code]
	hand_tiles[p].erase(t)
	if state.left < 0:
		# Primera ficha: al centro. El doble va atravesado a la cadena.
		t.board_pos = Vector2.ZERO
		t.board_rot = PI * 0.5 if dbl else 0.0
		var half := S * 0.5 if dbl else S
		arms = [
			{"p": Vector2(-half, 0), "d": Vector2.LEFT, "vs": -1.0, "next_h": Vector2.RIGHT, "vn": 0},
			{"p": Vector2(half, 0), "d": Vector2.RIGHT, "vs": 1.0, "next_h": Vector2.LEFT, "vn": 0},
		]
	else:
		var arm: Dictionary = arms[side]
		var endv: int = state.left if side == 0 else state.right
		if t.top != endv:
			# La mitad que casa va pegada a la cadena. Dar media vuelta no cambia el dibujo.
			t.set_values(endv, b if a == endv else a)
			t.rotation += PI
		var pl := _calc_place(arm, dbl)
		# En pantalla la cadena va girada 90° (ver _turn).
		t.board_pos = _turn(pl.center)
		t.board_rot = pl.rot + PI * 0.5
		arm.p = pl.p
		arm.d = pl.d
		arm.next_h = pl.next_h
		arm.vn = pl.vn
	board_tiles.append(t)
	state.apply_move(mv)
	return t


func _do_pass(p: int) -> void:
	if p == 0 and not autoplay:
		await _press_pass()
	else:
		await _wait(0.45)
	await _announce_pass(p)


## Muestra el botón "Pasar" y espera a que el jugador lo pulse.
func _press_pass() -> void:
	pass_btn.visible = true
	pass_btn.scale = Vector2(0.3, 0.3)
	create_tween().tween_property(pass_btn, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pass_btn.pulse(true)
	await pass_btn.pressed
	pass_btn.pulse(false)
	pass_btn.visible = false


func _announce_pass(p: int) -> void:
	state.apply_pass()
	_play("pass")
	_bubble(p, "¡Paso!")
	# Quien pasa aprovecha para echar un trago.
	if p != 0 and rng.randf() < 0.4:
		_drink(p)
	await _wait(0.85)


## El jugador p coge su vaso, bebe un trago y lo devuelve al posavasos.
func _drink(p: int) -> void:
	var g: Glass = glasses[p]
	var seat: Vector2 = seat_pos[p]
	var target := g.position.lerp(seat, 0.08) + g.toward * 50.0
	g.sip(target, _play.bind("gulp", rng.randf_range(0.9, 1.15)))


func _finish_hand() -> void:
	_set_active(-1)
	var res: Dictionary = state.result()
	if res.blocked:
		_show_banner("¡TRANCA!", Color(1.0, 0.45, 0.35))
	elif res.winner == 0:
		_show_banner("¡Dominaste!", GOLD)
	else:
		_show_banner("¡Dominó de %s!" % names[res.winner], GOLD)
	# Se destapan las fichas que quedaron en las manos.
	for p in range(1, 4):
		var i := 0
		for t: Tile in hand_tiles[p]:
			t.flip_to(1.0, 0.3, i * 0.06)
			i += 1
	await _wait(2.0)

	var team: int = res.team
	if net != null:
		# En red manda el marcador del servidor.
		scores = _net_scores.duplicate()
	elif team >= 0:
		scores[team] += res.points
		starter = res.winner
	_refresh_score(true)
	var match_over: bool = scores[0] >= TARGET_SCORE or scores[1] >= TARGET_SCORE

	var title := "Tranca empatada"
	var color := CREAM
	if match_over:
		title = "¡VICTORIA!" if scores[0] > scores[1] else "DERROTA"
		color = GOLD if scores[0] > scores[1] else Color(1.0, 0.45, 0.4)
	elif team == 0:
		title = "¡Mano para nosotros!"
		color = Color(0.55, 0.85, 1.0)
	elif team == 1:
		title = "Mano para ellos"
		color = Color(1.0, 0.55, 0.5)
	var lines: Array = []
	if res.blocked:
		lines.append("Juego trancado: gana quien tenga menos puntos en la mano.")
	else:
		lines.append("Te quedaste sin fichas." if res.winner == 0 else "%s se quedó sin fichas." % names[res.winner])
	lines.append("Puntos de la mano: +%d" % res.points if team >= 0 else "Nadie suma puntos.")
	lines.append("")
	lines.append("%s: %d   ·   %s: %d" % [names[0], res.totals[0], names[2], res.totals[2]])
	lines.append("%s: %d   ·   %s: %d" % [names[1], res.totals[1], names[3], res.totals[3]])
	lines.append("")
	lines.append("Marcador:  Nosotros %d  —  %d Ellos" % [scores[0], scores[1]])
	var buttons: Array = [["Siguiente mano", "next", Color(0.25, 0.6, 0.3)]]
	if match_over:
		var again: Array = ["Volver a la sala", "room"] if net != null else ["Jugar de nuevo", "again"]
		buttons = [[again[0], again[1], Color(0.25, 0.6, 0.3)], ["Menú", "menu", Color(0.45, 0.35, 0.25)]]
		_play("win" if scores[0] > scores[1] else "lose")
		if scores[0] > scores[1]:
			confetti.restart()
	if autoplay and net != null:
		# Cliente de prueba: sigue solo.
		print("[%s] mano %d -> %s" % [names[0], hand_no, str(scores)])
		await _wait(1.0)
		if match_over:
			get_tree().quit()
		net.send("sv_ready")
		return
	_show_end(title, color, lines, buttons)
	var action: String = await _panel_done
	_hide_end()
	match action:
		"next":
			if net != null:
				# La siguiente mano empieza cuando todos estén listos.
				net.send("sv_ready")
				_show_banner("Esperando a los demás…", CREAM)
			else:
				_play_hand()
		"again": _start_match()
		"room": back_to_room.emit()
		"menu": exit_to_menu.emit()


# ------------------------------------------------------------------ partida en red

## Asiento del servidor -> asiento visto desde el mío.
func _vis(seat: int) -> int:
	return (seat - my_seat + 4) % 4


## Nombres y aspecto de cada asiento según el servidor.
func _net_seats(ev: Dictionary) -> void:
	my_seat = ev.you
	for v in 4:
		var seat: Dictionary = ev.seats[(v + my_seat) % 4]
		var human: bool = seat.human
		# "away": su dueño se salió y puede volver; mientras, juega una CPU.
		var away: bool = seat.get("away", false)
		if v == 0:
			names[v] = NAMES[0]
		elif human:
			names[v] = str(seat.name)
		else:
			names[v] = "%s (CPU)" % seat.name if away else NAMES[v]
		seat_looks[v] = seat.look if (human or away) and v != 0 else {}


## Procesa en orden lo que va mandando el servidor; cada evento espera a que
## termine la animación del anterior.
func _net_loop() -> void:
	while true:
		while net.events.is_empty():
			await net.game_event
		var ev: Dictionary = net.events.pop_front()
		match ev.type:
			"hand_start":
				await _net_hand_start(ev)
			"turn":
				await _net_turn(_vis(ev.seat))
			"move":
				await _net_move(_vis(ev.seat), ev.move)
			"pass":
				state.turn = _vis(ev.seat)
				await _announce_pass(_vis(ev.seat))
			"hand_end":
				await _net_hand_end(ev)
			"resume":
				await _net_resume(ev)
			"left":
				var v := _vis(ev.seat)
				_bubble(v, "%s se fue: sigue la CPU" % ev.name)
				names[v] = "%s (CPU)" % ev.name
				_refresh_plates()
			"back":
				var v := _vis(ev.seat)
				_bubble(v, "%s volvió" % ev.name)
				names[v] = str(ev.name)
				_refresh_plates()


func _net_hand_start(ev: Dictionary) -> void:
	_net_seats(ev)
	hand_no = ev.hand_no
	difficulty = ev.difficulty
	scores = _team_scores(ev.scores)
	_reset_round()
	state = State.new()
	for v in 4:
		var hand: Array = []
		if v == 0:
			hand = Array(ev.hand)
			hand.sort()
		else:
			# No sé qué fichas tienen los demás: marcadores negativos únicos
			# que se sustituyen por la ficha real cuando la juegan.
			for i in State.HAND_SIZE:
				hand.append(-(v * 10 + i + 1))
		state.hands[v] = hand
	starter = _vis(ev.starter)
	if ev.opening:
		state.forced = State.DOUBLE_SIX
	state.turn = starter
	_refresh_score(false)
	await _announce_start(ev.opening)


## Vuelvo a una partida en marcha: el servidor manda mis fichas y todo lo
## jugado en esta mano, y la mesa se reconstruye de golpe, sin repartir.
func _net_resume(ev: Dictionary) -> void:
	_net_seats(ev)
	hand_no = ev.hand_no
	difficulty = ev.difficulty
	scores = _team_scores(ev.scores)
	_net_scores = scores.duplicate()
	_reset_round()
	state = State.new()
	_refresh_score(false)
	var history: Array = ev.history
	if int(ev.turn) < 0:
		# Entre partidas: no hay mano en curso que mostrar.
		_show_banner("Esperando la siguiente mano…", CREAM)
		return
	# Las manos se rehacen como estaban al repartir (las mías: las que me quedan
	# más las que ya jugué) y luego se repiten las jugadas una a una.
	var mine: Array = Array(ev.hand)
	for entry: Array in history:
		if _vis(entry[0]) == 0:
			mine.append(int(entry[1]) >> 1)
	mine.sort()
	for v in 4:
		var hand: Array = mine
		if v != 0:
			hand = []
			for i in State.HAND_SIZE:
				hand.append(-(v * 10 + i + 1))
		state.hands[v] = hand
	starter = _vis(ev.starter)
	_spawn_tiles()
	for entry: Array in history:
		var v := _vis(entry[0])
		var mv: int = entry[1]
		if v != 0:
			_reveal(hand_tiles[v][0], v, mv >> 1)
		state.turn = v
		var t := _commit_move(v, mv)
		t.flip = 1.0
		t.z_index = 1
		_last = t
	state.turn = _vis(ev.turn)
	_refit_board(null)
	for t: Tile in board_tiles:
		t.fly_to(_b2s(t.board_pos), t.board_rot, board_s, 0.45)
	if _last != null:
		_last.tween_marks(0.6, 0.0)
	for v in 4:
		for t: Tile in hand_tiles[v]:
			t.z_index = 3
			if v == 0 and not autoplay:
				t.flip = 1.0
		_layout_hand(v, 0.45)
		hands_gfx[v].set_count(hand_tiles[v].size())
	_refresh_plates()
	_show_banner("Volviste a la partida", GOLD)
	if autoplay:
		print("[%s] reanudado: %d fichas en la mesa, me quedan %d" % [names[0], board_tiles.size(), hand_tiles[0].size()])
	await _wait(0.8)
	if ev.over:
		_show_banner("Esperando la siguiente mano…", CREAM)
	else:
		_set_active(_vis(ev.turn))


func _team_scores(server_scores: Array) -> Array:
	var mine := my_seat % 2
	return [int(server_scores[mine]), int(server_scores[1 - mine])]


func _net_turn(v: int) -> void:
	_set_active(v)
	if v != 0:
		return
	var moves: Array = state.legal_moves(0)
	if moves.is_empty():
		if not autoplay:
			await _press_pass()
		net.send("sv_move", [-1])
	elif autoplay:
		net.send("sv_move", [AI.choose(state, 0, AI.EASY, rng.randi())])
	else:
		var mv: int = await _human_turn(moves)
		net.send("sv_move", [mv])


func _net_move(v: int, mv: int) -> void:
	if v != 0:
		_reveal(hand_tiles[v][rng.randi_range(0, hand_tiles[v].size() - 1)], v, mv >> 1)
	state.turn = v
	await _do_move(v, mv)


## Da su valor real a una ficha que hasta ahora estaba oculta en la mano de otro.
func _reveal(t: Tile, v: int, code: int) -> void:
	var hand: Array = state.hands[v]
	hand[hand.find(t.code)] = code
	tiles.erase(t.code)
	t.code = code
	t.set_values(code >> 3, code & 7)
	tiles[code] = t


func _net_hand_end(ev: Dictionary) -> void:
	for v in range(1, 4):
		var real: Array = ev.hands[(v + my_seat) % 4]
		var hidden: Array = hand_tiles[v]
		for i in mini(real.size(), hidden.size()):
			_reveal(hidden[i], v, real[i])
	state.out_player = -1 if ev.out < 0 else _vis(ev.out)
	state.blocked = ev.blocked
	_net_scores = _team_scores(ev.scores)
	await _finish_hand()


# ------------------------------------------------------------------ animaciones

func _reset_round() -> void:
	for c in tile_layer.get_children():
		c.queue_free()
	tiles.clear()
	board_tiles.clear()
	hand_tiles = [[], [], [], []]
	arms = []
	board_s = BOARD_SCALE
	board_off = play_rect.get_center()
	_last = null
	_hide_ghosts()
	pass_btn.visible = false
	confetti.emitting = false
	for g: Glass in glasses:
		if g.level < 0.3:
			g.refill()


## Crea las fichas de todas las manos, boca abajo y amontonadas en el centro.
func _spawn_tiles() -> void:
	var c := play_rect.get_center()
	for p in 4:
		for code in state.hands[p]:
			var t: Tile = Tile.new()
			t.code = code
			t.set_values(code >> 3, code & 7)
			t.flip = 0.0
			t.position = c + Vector2(rng.randf_range(-150, 150), rng.randf_range(-150, 150))
			t.rotation = rng.randf_range(-PI, PI)
			t.scale = Vector2(0.75, 0.75)
			t.modulate.a = 0.0
			t.z_index = 1
			tile_layer.add_child(t)
			t.create_tween().tween_property(t, "modulate:a", 1.0, 0.25)
			tiles[code] = t
			hand_tiles[p].append(t)
		hands_gfx[p].set_count(State.HAND_SIZE)
	_refresh_plates()


## "Sopa": las fichas boca abajo se revuelven en el centro y luego se reparten.
func _animate_deal() -> void:
	var c := play_rect.get_center()
	_spawn_tiles()
	for r in 3:
		_play("shuffle")
		for t: Tile in tiles.values():
			var pos := c + Vector2(rng.randf_range(-150, 150), rng.randf_range(-150, 150))
			t.fly_to(pos, t.rotation + rng.randf_range(-2.0, 2.0), 0.75, 0.3)
		await _wait(0.33)
	var idx := 0
	for i in State.HAND_SIZE:
		for q in 4:
			var p := (starter + q) % 4
			var t: Tile = hand_tiles[p][i]
			var sl: Array = hands_gfx[p].slot(i, State.HAND_SIZE)
			var delay := idx * 0.05
			t.z_index = 3
			t.fly_to(sl[0], sl[1], SEAT_SCALE[p], 0.38, delay)
			if p == 0 and not autoplay:
				t.flip_to(1.0, 0.28, delay + 0.22)
			if idx % 2 == 0:
				get_tree().create_timer(delay + 0.3).timeout.connect(_play.bind("tick", 1.0))
			idx += 1
	await _wait(idx * 0.05 + 0.55)


func _layout_hand(p: int, dur: float) -> void:
	var arr: Array = hand_tiles[p]
	var n := arr.size()
	for i in n:
		var t: Tile = arr[i]
		var sl: Array = hands_gfx[p].slot(i, n)
		var pos: Vector2 = sl[0]
		var scl: float = SEAT_SCALE[p]
		if p == 0 and _awaiting:
			if t == _hover or t.code == _pending:
				pos.y -= 30.0
				scl *= 1.06
			elif _playable(t.code):
				pos.y -= 14.0
		t.fly_to(pos, sl[1], scl, dur)


func _impact(pos: Vector2) -> void:
	var ring := Ring.new()
	ring.position = pos
	fx_layer.add_child(ring)
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "r", 58.0 * board_s / BOARD_SCALE, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(ring.queue_free)


# ---------------------------------------------------------------------- tablero

func _b2s(v: Vector2) -> Vector2:
	return board_off + v * board_s


## Calcula dónde cae la siguiente ficha de un extremo. La cadena avanza en filas:
## al llegar al borde gira con una ficha vertical y vuelve en sentido contrario
## (el extremo derecho baja; el izquierdo sube). Los dobles van atravesados.
func _calc_place(arm: Dictionary, dbl: bool) -> Dictionary:
	var p: Vector2 = arm.p
	var d: Vector2 = arm.d
	var vertical: bool = absf(d.y) > 0.5
	# Los tramos verticales miden dos fichas para que las filas no se toquen.
	var turn_now: bool = arm.vn >= 2
	if not vertical:
		var length := S if dbl else 2.0 * S
		turn_now = absf(p.x + d.x * length) > row_limit
	if turn_now:
		var n: Vector2 = arm.next_h if vertical else Vector2(0, arm.vs)
		var base := p + d * (S * 0.5)
		return {"center": base + n * (S * 0.5), "rot": n.angle() - PI * 0.5, "p": base + n * (S * 1.5),
				"d": n, "next_h": arm.next_h if vertical else -d, "vn": 0 if vertical else 1}
	var vn: int = arm.vn + 1 if vertical else 0
	if dbl:
		return {"center": p + d * (S * 0.5), "rot": d.angle(), "p": p + d * S, "d": d, "next_h": arm.next_h, "vn": vn}
	return {"center": p + d * S, "rot": d.angle() - PI * 0.5, "p": p + d * (2.0 * S), "d": d, "next_h": arm.next_h, "vn": vn}


## Centra la cadena en la zona de juego y la encoge si ya no cabe.
func _refit_board(skip: Tile) -> void:
	var bb := Rect2()
	var first := true
	for t: Tile in board_tiles:
		var half := Vector2(S * 0.5, S) if absf(sin(t.board_rot)) < 0.5 else Vector2(S, S * 0.5)
		var r := Rect2(t.board_pos - half, half * 2.0)
		bb = r if first else bb.merge(r)
		first = false
	bb = bb.grow(14.0)
	var s := minf(BOARD_SCALE, minf(play_rect.size.x / bb.size.x, play_rect.size.y / bb.size.y))
	var off := play_rect.get_center() - bb.get_center() * s
	if is_equal_approx(s, board_s) and off.is_equal_approx(board_off):
		return
	board_s = s
	board_off = off
	for t: Tile in board_tiles:
		if t != skip:
			t.fly_to(_b2s(t.board_pos), t.board_rot, s, 0.45)


func _show_ghosts(code: int) -> void:
	var dbl := (code >> 3) == (code & 7)
	for g: Ghost in ghosts:
		var pl := _calc_place(arms[g.side], dbl)
		g.position = _b2s(_turn(pl.center))
		g.rotation = pl.rot + PI * 0.5
		g.scale = Vector2(board_s, board_s)
		g.visible = true


func _hide_ghosts() -> void:
	for g: Ghost in ghosts:
		g.visible = false


# ---------------------------------------------------------------------- entrada

func _unhandled_input(event: InputEvent) -> void:
	# Tu vaso se puede coger en cualquier momento.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and glasses[0].hit(get_global_mouse_position()):
		if glasses[0].level <= 0.02:
			glasses[0].refill()
		else:
			_drink(0)
		return
	if not _awaiting:
		return
	if event is InputEventMouseMotion:
		var h := _tile_at(get_global_mouse_position())
		if h != null and not _playable(h.code):
			h = null
		if h != _hover:
			_hover = h
			_layout_hand(0, 0.15)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click(get_global_mouse_position())


func _click(pos: Vector2) -> void:
	if _pending >= 0:
		# Con el dedo no hace falta acertar justo en el marcador: vale tocar cerca.
		var best: Ghost = null
		for g: Ghost in ghosts:
			if g.visible and g.distance(pos) < TOUCH_RADIUS and (best == null or g.distance(pos) < best.distance(pos)):
				best = g
		if best != null:
			_human_done.emit(_pending * 2 + best.side)
			return
	var t := _tile_at(pos)
	if t == null:
		if _pending >= 0:
			_pending = -1
			_hide_ghosts()
			_layout_hand(0, 0.15)
		return
	var sides: Array = []
	for m in _choices:
		if (m >> 1) == t.code:
			sides.append(m & 1)
	if sides.is_empty():
		t.wiggle()
		_play("bad")
	elif sides.size() == 1:
		_human_done.emit(t.code * 2 + sides[0])
	else:
		# La ficha cabe en los dos extremos: hay que elegir uno.
		_pending = t.code
		_show_ghosts(t.code)
		_layout_hand(0, 0.15)
		_play("click")
		_bubble(0, "Elige un extremo")


func _tile_at(pos: Vector2) -> Tile:
	for t: Tile in hand_tiles[0]:
		if t.hit(pos):
			return t
	return null


func _playable(code: int) -> bool:
	for m in _choices:
		if (m >> 1) == code:
			return true
	return false


# -------------------------------------------------------------------------- HUD

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	# Sigue el centrado del contenido en pantallas anchas.
	layer.follow_viewport_enabled = true
	add_child(layer)
	hud = Control.new()
	hud.size = Vector2(720, 1280)
	var pad: float = Table.pad
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)

	var sp := _panel(hud, Rect2(172, 177.0 - pad, 262, 42), Color(0.08, 0.05, 0.03, 0.85), Color(0.85, 0.65, 0.3, 0.9))
	info_lbl = _label(sp, "", 16, Color(0.9, 0.83, 0.67), Rect2(0, 0, 262, 42))

	for team in 2:
		var board: ChalkBoard = ChalkBoard.new()
		board.title = "NOSOTROS" if team == 0 else "ELLOS"
		board.tint = TEAM_COLORS[team].lightened(0.5)
		board.position = slate_pos[team]
		board.scale = Vector2(SLATE_SCALE, SLATE_SCALE)
		hud.add_child(board)
		boards.append(board)

	for p in 4:
		var plate := _panel(hud, plate_rect[p], Color(0.08, 0.05, 0.03, 0.8), TEAM_COLORS[p % 2])
		plate.pivot_offset = plate.size * 0.5
		plates.append(plate)
		plate_labels.append(_label(plate, names[p], 16, CREAM, Rect2(Vector2.ZERO, plate.size)))

	var menu_btn := _button(hud, "Menú", Color(0.45, 0.33, 0.22), Rect2(58, 172.0 - pad, 104, 52), 20)
	menu_btn.pressed.connect(_show_options)

	pass_btn = _button(hud, "Pasar", Color(0.8, 0.45, 0.1), Rect2(396, 994.0 + pad, 150, 62), 28)
	pass_btn.visible = false

	banner = _label(hud, "", 46, GOLD, Rect2(20, 520, 680, 170))
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.02))
	banner.add_theme_constant_override("outline_size", 14)
	banner.pivot_offset = banner.size * 0.5
	banner.modulate.a = 0.0

	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	# Más grande que la pantalla para cubrir también los márgenes de un teléfono.
	overlay.position = Vector2(-1500, -1500)
	overlay.size = Vector2(4280, 3720)
	overlay.visible = false
	hud.add_child(overlay)

	confetti = CPUParticles2D.new()
	confetti.position = Vector2(360, -20.0 - pad)
	confetti.emitting = false
	confetti.one_shot = true
	confetti.amount = 220
	confetti.lifetime = 4.0
	confetti.explosiveness = 0.55
	confetti.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	confetti.emission_rect_extents = Vector2(360, 8)
	confetti.direction = Vector2(0, 1)
	confetti.spread = 35.0
	confetti.gravity = Vector2(0, 240)
	confetti.initial_velocity_min = 60.0
	confetti.initial_velocity_max = 320.0
	confetti.angular_velocity_min = -360.0
	confetti.angular_velocity_max = 360.0
	confetti.scale_amount_min = 5.0
	confetti.scale_amount_max = 11.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	ramp.colors = PackedColorArray([Color(1, 0.3, 0.3), GOLD, Color(0.3, 0.85, 0.45), Color(0.3, 0.6, 1.0), Color(0.9, 0.4, 0.95)])
	confetti.color_initial_ramp = ramp
	hud.add_child(confetti)

	end_panel = _panel(hud, Rect2(50, 400, 620, 420), Color(0.13, 0.08, 0.05, 0.97), GOLD)
	end_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	end_panel.pivot_offset = end_panel.size * 0.5
	_build_options()
	end_panel.visible = false


func _panel(parent: Node, rect: Rect2, bg: Color, border: Color) -> Panel:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	var pn := Panel.new()
	pn.add_theme_stylebox_override("panel", sb)
	pn.position = rect.position
	pn.size = rect.size
	pn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(pn)
	return pn


func _label(parent: Node, text: String, font_size: int, color: Color, rect: Rect2,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var lb := Label.new()
	lb.text = text
	lb.add_theme_font_size_override("font_size", font_size)
	lb.add_theme_color_override("font_color", color)
	lb.horizontal_alignment = align
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.position = rect.position
	lb.size = rect.size
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lb)
	return lb


func _button(parent: Node, text: String, color: Color, rect: Rect2, font_size: int) -> FancyButton:
	var b: FancyButton = FancyButton.new()
	b.setup(text, color, font_size)
	b.position = rect.position
	b.size = rect.size
	parent.add_child(b)
	b.pressed.connect(_play.bind("click", 1.0))
	return b


func _refresh_score(animate: bool) -> void:
	info_lbl.text = "Mano %d  ·  Meta %d  ·  %s" % [hand_no, TARGET_SCORE, DIFF_NAMES[difficulty]]
	for team in 2:
		var board: ChalkBoard = boards[team]
		if animate and scores[team] != board.shown:
			_play("chalk")
		board.set_score(scores[team], animate)


func _refresh_plates() -> void:
	for p in 4:
		# Las placas de los rivales son estrechas: nombre arriba, fichas debajo.
		var fmt := "%s\n%d fichas" if p % 2 == 1 else "%s  ·  %d"
		plate_labels[p].text = fmt % [names[p], hand_tiles[p].size()]


func _set_active(p: int) -> void:
	if _plate_tw != null and _plate_tw.is_valid():
		_plate_tw.kill()
	for i in 4:
		var plate: Panel = plates[i]
		plate.scale = Vector2.ONE
		plate.modulate = Color(1.5, 1.4, 1.0) if i == p else Color(1, 1, 1, 0.7)
	if p < 0:
		return
	_plate_tw = create_tween().set_loops()
	_plate_tw.tween_property(plates[p], "scale", Vector2(1.08, 1.08), 0.4).set_trans(Tween.TRANS_SINE)
	_plate_tw.tween_property(plates[p], "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_SINE)


func _show_banner(text: String, color: Color) -> void:
	if _banner_tw != null and _banner_tw.is_valid():
		_banner_tw.kill()
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.scale = Vector2(0.4, 0.4)
	banner.modulate.a = 0.0
	_banner_tw = create_tween()
	_banner_tw.tween_property(banner, "modulate:a", 1.0, 0.15)
	_banner_tw.parallel().tween_property(banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tw.tween_interval(1.0)
	_banner_tw.tween_property(banner, "modulate:a", 0.0, 0.3)


func _bubble(p: int, text: String) -> void:
	var size := Vector2(maxf(120.0, text.length() * 13.0 + 30.0), 44)
	var center: Vector2 = bubble_pos[p]
	var pn := _panel(hud, Rect2(center - size * 0.5, size), Color(0.98, 0.96, 0.9), TEAM_COLORS[p % 2])
	_label(pn, text, 20, Color(0.15, 0.1, 0.06), Rect2(Vector2.ZERO, size))
	pn.pivot_offset = size * 0.5
	pn.scale = Vector2(0.2, 0.2)
	var tw := pn.create_tween()
	tw.tween_property(pn, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.7)
	tw.tween_property(pn, "modulate:a", 0.0, 0.25)
	tw.tween_callback(pn.queue_free)


func _show_end(title: String, color: Color, lines: Array, buttons: Array) -> void:
	for c in end_panel.get_children():
		c.queue_free()
	var w := end_panel.size.x
	var tl := _label(end_panel, title, 44, color, Rect2(0, 16, w, 62))
	tl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	tl.add_theme_constant_override("outline_size", 8)
	var y := 90.0
	for ln in lines:
		_label(end_panel, ln, 20, CREAM, Rect2(20, y, w - 40, 28))
		y += 30.0
	var bw := 230.0
	var total := buttons.size() * bw + (buttons.size() - 1) * 24.0
	var x := (w - total) * 0.5
	for spec in buttons:
		var action: String = spec[1]
		var b := _button(end_panel, spec[0], spec[2], Rect2(x, 340, bw, 56), 24)
		b.pressed.connect(func() -> void: _panel_done.emit(action))
		x += bw + 24.0
	overlay.visible = true
	overlay.modulate.a = 0.0
	end_panel.visible = true
	end_panel.scale = Vector2(0.6, 0.6)
	end_panel.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(overlay, "modulate:a", 1.0, 0.25)
	tw.tween_property(end_panel, "modulate:a", 1.0, 0.2)
	tw.tween_property(end_panel, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_end() -> void:
	overlay.visible = false
	end_panel.visible = false


## Panel del botón "Menú": interruptores de sonido, seguir jugando o salir.
## La partida no se detiene mientras está abierto (en red no se puede).
func _build_options() -> void:
	opt_panel = _panel(hud, Rect2(60, 330, 600, 620), Color(0.13, 0.08, 0.05, 0.97), GOLD)
	opt_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	opt_panel.pivot_offset = opt_panel.size * 0.5
	opt_panel.visible = false
	_label(opt_panel, "Ajustes", 40, GOLD, Rect2(0, 18, 600, 56))
	var y := 96.0
	for key: String in SOUND_OPTIONS.keys():
		var b := _button(opt_panel, "", Color.GRAY, Rect2(50, y, 500, 76), 26)
		b.pressed.connect(_toggle_sound.bind(key))
		_sound_btns[key] = b
		y += 92.0
	var resume := _button(opt_panel, "Seguir jugando", Color(0.25, 0.6, 0.3), Rect2(50, 396, 500, 84), 30)
	resume.pressed.connect(_hide_options)
	var leave := _button(opt_panel, "Salir al menú", Color(0.7, 0.2, 0.18), Rect2(125, 506, 350, 70), 26)
	leave.pressed.connect(func() -> void: exit_to_menu.emit())
	_refresh_options()


func _refresh_options() -> void:
	for key: String in _sound_btns.keys():
		var on: bool = Settings.audio[key] != 0
		var b: FancyButton = _sound_btns[key]
		b.text = "%s:  %s" % [SOUND_OPTIONS[key], "Sí" if on else "No"]
		b.set_color(Color(0.2, 0.5, 0.6) if on else Color(0.4, 0.32, 0.26))


func _toggle_sound(key: String) -> void:
	Settings.audio[key] = 0 if Settings.audio[key] != 0 else 1
	Settings.save()
	_refresh_options()
	if sfx != null:
		sfx.refresh_audio()


func _show_options() -> void:
	_refresh_options()
	overlay.visible = true
	overlay.modulate.a = 1.0
	opt_panel.visible = true
	opt_panel.scale = Vector2(0.7, 0.7)
	create_tween().tween_property(opt_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_options() -> void:
	opt_panel.visible = false
	# Si entre tanto terminó la mano, su panel sigue necesitando el fondo oscuro.
	overlay.visible = end_panel.visible


func _play(id: String, pitch: float = 1.0) -> void:
	if sfx != null:
		sfx.play(id, pitch)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
