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
const UI = preload("res://scripts/ui_theme.gd")
const Avatar = preload("res://scripts/avatar.gd")
const Chat = preload("res://scripts/chat.gd")
const SignalMeter = preload("res://scripts/signal_meter.gd")
const Wallet = preload("res://scripts/wallet.gd")
const UISkin = preload("res://scripts/ui_skin.gd")
const Stats = preload("res://scripts/stats.gd")
const Tournament = preload("res://scripts/tournament.gd")
const Daily = preload("res://scripts/daily_challenge.gd")
const Ads = preload("res://scripts/ads.gd")

const BOARD_SCALE := 1.25
## Radio (en unidades de pantalla) dentro del cual un toque cuenta como acierto.
const TOUCH_RADIUS := 80.0
## Formas de revolver las fichas antes de repartir (ver _shuffle_target).
const SHUFFLES := ["sopa", "remolino", "montones", "ola", "explosion"]
## Segundos que se muestra que no tengo jugada antes de pasar solo.
const PASS_PAUSE := 0.9
## Cuánto hay que mover el dedo sobre una ficha para que cuente como arrastre y no como toque.
const DRAG_START := 18.0
## La ficha arrastrada va por encima del dedo, para que se vea.
const DRAG_LIFT := Vector2(0, -70)
## Lado corto de una ficha en unidades de tablero.
const S := 40.0

const NAMES := ["Tú", "Rival Este", "Compañero", "Rival Oeste"]
const DIFF_NAMES := ["Fácil", "Intermedio", "Difícil"]
const SEAT_ROT := [0.0, -PI / 2.0, PI, PI / 2.0]
## Tus fichas son grandes para poder tocarlas con el dedo.
const SEAT_SCALE := [2.0, 0.62, 0.62, 0.62]
const SLATE_SCALE := 1.1
const TEAM_COLORS := [Color(0.2, 0.45, 0.85), Color(0.8, 0.22, 0.2)]
## Sin parejas cada asiento lleva su color (ver _seat_color).
const SOLO_COLORS := [Color(0.2, 0.45, 0.85), Color(0.8, 0.22, 0.2), Color(0.85, 0.6, 0.15), Color(0.45, 0.7, 0.3)]
const SOLO_NAMES := ["Tú", "Este", "Norte", "Oeste"]
const DUEL_NAMES := ["Tú", "", "Rival", ""]
## Nombre corto del formato para el cartel de la mano (el de parejas no se escribe).
const FORMAT_SHORT := ["", "Todos", "1 vs 1"]
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
## Avatar de las CPU (índice en Avatar.ICON_NAMES); el del jugador 0 sale de los ajustes.
const CPU_AVATARS := [0, Avatar.BOLT, Avatar.CROWN, Avatar.MOON]
const GOLD := Color(1.0, 0.84, 0.3)
const CREAM := Color(0.97, 0.93, 0.82)
## Interruptores de sonido del panel de ajustes: clave en Settings.audio -> texto.
const SOUND_OPTIONS := {"pass_voice": "Audios de voz", "sfx": "Efectos de sonido", "music": "Música",
		"vibrate": "Vibración"}
## Premio de la primera partida guiada.
const TUTORIAL_REWARD := 200
## Reacciones rápidas al tocar la placa de un jugador (índices en Chat.EMOJIS).
const REACTIONS := [8, 0, 9, 3, 2, 6]
## Lo que la CPU contesta o suelta cuando pasa algo en la mesa.
const CPU_HAPPY := [0, 1, 8, 9, 10]
const CPU_SAD := [3, 4, 5, 2]

var difficulty: int = AI.MEDIUM
## Modo de juego (State.CLASSIC...) y puntos para ganar. En red los manda el servidor.
var mode: int = State.CLASSIC
## Parejas, todos contra todos o 1 contra 1 (State.PAIRS...). En red, siempre parejas.
var format: int = State.PAIRS
var target: int = State.DEFAULT_TARGET
## Partida con apuesta, elegida en el menú: la apuesta `bet` ya se cobró y al
## terminar se pagan el premio (si se gana) y la experiencia (ver Wallet).
var paid := false
var bet := 0
## Modo demostración: la CPU juega también tu mano.
var autoplay := false
## Doble nueve (55 fichas, 10 por jugador). Solo contra la CPU.
var double_nine := false
## Partida de torneo, ranked o desafío del día ("" = normal). Ver main.gd.
var event := ""
## Música de esta partida ("game", o "event" en torneo y ranked).
var _music_kind := "game"
## Desafío del día: semilla del reparto (0 = al azar).
var deal_seed := 0
## El resultado del evento ya se apuntó (para no contarlo dos veces al salir).
var _event_reported := false
var _hint_btn: FancyButton
var _reactions: Panel
## Partida guiada: consejos ya mostrados y el panel donde salen.
var _coached := {}
var _coach_panel: Panel
var _coach_text: Label
var _coach_ok: FancyButton
## Velocidad del juego antes de la partida rápida, para devolverla al salir.
var _speed_before := 1.0
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
var _board_vertical := true
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
## Fichas del pozo (1 contra 1), boca abajo en el lado izquierdo de la mesa.
var pool_tiles: Array = []
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
var avatars: Array = []
var glasses: Array = []
var boards: Array = []
var info_lbl: Label
var banner: Label
var overlay: ColorRect
var end_panel: Panel
var opt_panel: Panel
var _sound_btns := {}
var _hands_btn: FancyButton
## Chat de la sala (solo en partidas en red) y mensajes sin leer.
var _chat: Chat
var _chat_btn: FancyButton
var _unread := 0
var confetti: CPUParticles2D

var _awaiting := false
var _choices: Array = []
var _pending := -1
var _hover: Tile
## Ficha sobre la que se apoyó el dedo, y dónde; decide entre toque y arrastre.
var _press_tile: Tile
var _press_pos := Vector2.ZERO
## Ficha que se está arrastrando y extremos en los que puede caer.
var _drag: Tile
var _drag_sides: Array = []
var _last_shuffle := -1
## Pruebas: fuerza una forma de revolver (índice en SHUFFLES); -1 = al azar.
var force_shuffle := -1
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
	# `s` solo es distinto de 0 en la web de escritorio (mesa cuadrada): los
	# rivales y lo que va en las esquinas se separan hacia los lados.
	var s: float = Table.side
	play_rect = Rect2(125.0 - s, 270.0 - p, 470.0 + s * 2.0, 639.0 + p * 2.0)
	# La cadena corre a lo largo del lado mayor de la zona de juego: en vertical
	# en el teléfono, en horizontal en la mesa cuadrada.
	_board_vertical = play_rect.size.y > play_rect.size.x
	var run := play_rect.size.y if _board_vertical else play_rect.size.x
	row_limit = run * 0.5 / BOARD_SCALE - S - 6.0
	var mid := play_rect.get_center().y
	# Tus fichas no van pegadas al borde de abajo: queda sitio para que se vean
	# la palma y los pulgares que las sujetan.
	seat_pos = [Vector2(360, 1140.0 + p), Vector2(636.0 + s, mid), Vector2(360, 92.0 - p), Vector2(84.0 - s, mid)]
	# Cada placa lleva el avatar del jugador: a la izquierda en la tuya y la de tu
	# compañero; arriba, centrado, en las estrechas de los rivales.
	plate_rect = [Rect2(392, 900.0 + p, 166, 72), Rect2(572.0 + s, mid - 236.0, 142, 124),
			Rect2(240, 120.0 - p, 240, 48), Rect2(6.0 - s, mid - 236.0, 142, 124)]
	bubble_pos = [Vector2(360, 864.0 + p), Vector2(500.0 + s, mid), Vector2(360, 310.0 - p), Vector2(220.0 - s, mid)]
	slate_pos = [Vector2(170, 922.0 + p), Vector2(444.0 + s, 164.0 - p)]


## La cadena se calcula siempre en horizontal. En un teléfono de pie se muestra
## girada 90° (en vertical), que es como cabe; en la mesa cuadrada, tal cual.
func _turn(v: Vector2) -> Vector2:
	return Vector2(-v.y, v.x) if _board_vertical else v


## Giro que se suma a cada ficha de la mesa para acompañar a _turn.
func _turn_rot() -> float:
	return PI * 0.5 if _board_vertical else 0.0


func _ready() -> void:
	# El juego de fichas es global en State: en red, siempre doble seis.
	State.use_set(double_nine and net == null)
	if event == "quick":
		# Rápida: todo va un 30 % más deprisa (CPU, animaciones y pausas).
		_speed_before = Engine.time_scale
		Engine.time_scale = _speed_before * 1.3
	_layout()
	rng.randomize()
	board_off = play_rect.get_center()
	if net != null and not net.events.is_empty():
		# El reparto que abre la partida ya dice quién se sienta dónde.
		_net_seats(net.events[0])
	if net != null:
		format = State.PAIRS
	elif format == State.SOLO and names == NAMES:
		names = SOLO_NAMES.duplicate()
	elif format == State.DUEL and names == NAMES:
		# En el torneo, main.gd ya puso el nombre del rival.
		names = DUEL_NAMES.duplicate()
	add_child(Table.new())
	for p in 4:
		var h: Hand = Hand.new()
		h.position = seat_pos[p]
		h.rotation = SEAT_ROT[p]
		h.k = SEAT_SCALE[p]
		h.sleeve = _seat_color(p)
		# Con muchas fichas (robadas del pozo) se juntan para no salirse de la pantalla.
		h.max_span = 660.0 if p == 0 else (420.0 if p == 2 else 520.0)
		h.visible = _seated(p)
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
		g.visible = _seated(p)
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
	_apply_show_hands()
	if sfx != null:
		# Torneo y ranked llevan un jazz más movido que las partidas normales.
		var lively: bool = event == "tournament" or (net != null and net.room_info.get("ranked", false))
		_music_kind = "event" if lively else "game"
		sfx.music(true, _music_kind)
	if net != null:
		_net_loop()
	else:
		_start_match()


func _exit_tree() -> void:
	State.use_set(false)
	if event == "quick":
		Engine.time_scale = _speed_before
	if sfx != null:
		sfx.music(false, _music_kind)
	if _ai_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_ai_task)
		_ai_task = -1


# ---------------------------------------------------------------- flujo de juego

## En 1 contra 1 solo se sientan 0 (tú) y 2 (enfrente).
func _seated(p: int) -> bool:
	return format != State.DUEL or p % 2 == 0


func _seat_color(p: int) -> Color:
	return TEAM_COLORS[p % 2] if format == State.PAIRS else SOLO_COLORS[p]


func _start_match() -> void:
	if deal_seed != 0:
		# Desafío del día: el mismo reparto para todos.
		rng.seed = deal_seed
	_event_reported = false
	# Un marcador por pareja o, sin parejas, uno por asiento.
	scores = [0, 0] if format == State.PAIRS else [0, 0, 0, 0]
	hand_no = 0
	starter = -1
	_play_hand()


func _play_hand() -> void:
	hand_no += 1
	_reset_round()
	state = State.new()
	state.mode = mode
	state.format = format
	state.deal(rng)
	var opening := starter < 0
	if opening:
		# Primera mano: sale quien tenga el doble seis y debe abrir con él (en
		# 1 contra 1 puede estar en el pozo: entonces, el doble más alto).
		state.forced = state.opening_tile()
		starter = state.holder_of(state.forced)
	state.turn = starter
	_refresh_score(false)
	await _announce_start(opening)
	await _coach("start", "Juegas en pareja con quien tienes enfrente, arriba. Gana la pareja que llegue antes a %d puntos." % target)
	while not state.is_over():
		var p := state.turn
		_set_active(p)
		var moves: Array = state.legal_moves(p)
		if moves.is_empty():
			if state.can_draw():
				await _do_draw(p)
			else:
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
	var top_double := State.code(State.top, State.top)
	if opening and state.forced != top_double:
		_show_banner("Sale el %d/%d: %s" % [State.hi(state.forced), State.lo(state.forced), names[starter]], GOLD)
	elif opening:
		_show_banner("Sale el doble %s: %s" % ["nueve" if State.top == 9 else "seis", names[starter]], GOLD)
	else:
		_show_banner("Sales tú" if starter == 0 else "Sale %s" % names[starter], GOLD)
	await _wait(1.0)


func _human_turn(moves: Array) -> int:
	_choices = moves
	_pending = -1
	_hover = null
	_press_tile = null
	_drag = null
	_awaiting = true
	for t: Tile in hand_tiles[0]:
		var ok := _playable(t.code)
		t.tween_marks(1.0 if ok else 0.0, 0.0 if ok else 1.0)
	_layout_hand(0, 0.2)
	await _coach("turn", "Te toca. Las fichas que brillan casan con la mesa: arrastra una hasta la mesa o tócala para jugarla.")
	if _two_sided(moves):
		await _coach("sides", "Esa ficha casa por los dos lados: suéltala en el extremo que quieras, se marcan en dorado.")
	elif _coached.has("turn"):
		await _coach("hint", "Si dudas, el botón Pista de la derecha te dice la mejor jugada (cuesta unas monedas).")
	_show_hint_button(true)
	var mv: int = await _human_done
	_show_hint_button(false)
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
	if mode == State.FIVES and net == null and state.last_fives > 0:
		var team := state.team_of(p)
		scores[team] += state.last_fives
		_refresh_score(true)
		_bubble(p, "¡%d!  Cincos" % state.last_fives, 0.9)
		_play("point")
	if p == 0 and not autoplay:
		_vibrate(25)
	if p != 0 and rng.randf() < 0.12:
		_drink(p)
	await _wait(0.18)


## Registra una jugada sin animarla: saca la ficha de la mano, calcula dónde
## cae en la cadena y actualiza el estado. Devuelve la ficha.
func _commit_move(p: int, mv: int) -> Tile:
	var code := mv >> 1
	var side := mv & 1
	var a := State.hi(code)
	var b := State.lo(code)
	var dbl := a == b
	var t: Tile = tiles[code]
	hand_tiles[p].erase(t)
	if state.left < 0:
		# Primera ficha: al centro. El doble va atravesado a la cadena.
		t.board_pos = Vector2.ZERO
		t.board_rot = (0.0 if dbl else -PI * 0.5) + _turn_rot()
		var half := S * 0.5 if dbl else S
		# "cross": la última ficha de ese extremo es un doble atravesado (ver _calc_place).
		arms = [
			{"p": Vector2(-half, 0), "d": Vector2.LEFT, "vs": -1.0, "next_h": Vector2.RIGHT, "vn": 0, "cross": dbl},
			{"p": Vector2(half, 0), "d": Vector2.RIGHT, "vs": 1.0, "next_h": Vector2.LEFT, "vn": 0, "cross": dbl},
		]
	else:
		var arm: Dictionary = arms[side]
		var endv: int = state.left if side == 0 else state.right
		if t.top != endv:
			# La mitad que casa va pegada a la cadena. Dar media vuelta no cambia el dibujo.
			t.set_values(endv, b if a == endv else a)
			t.rotation += PI
		var pl := _calc_place(arm, dbl)
		# En el teléfono la cadena va girada 90° (ver _turn).
		t.board_pos = _turn(pl.center)
		t.board_rot = pl.rot + _turn_rot()
		arm.p = pl.p
		arm.d = pl.d
		arm.next_h = pl.next_h
		arm.vn = pl.vn
		arm.cross = pl.cross
	board_tiles.append(t)
	state.apply_move(mv)
	return t


## Sin ficha que case y con fichas en el pozo: roba una (sola, sin tocar nada).
func _do_draw(p: int) -> void:
	var code := state.draw()
	var t: Tile = tiles[code]
	pool_tiles.erase(t)
	hand_tiles[p].append(t)
	t.z_index = 3
	if p == 0 and not autoplay:
		t.flip_to(1.0, 0.25, 0.1)
	_layout_hand(p, 0.3)
	hands_gfx[p].set_count(hand_tiles[p].size())
	_refresh_plates()
	_play("tick", rng.randf_range(0.9, 1.1))
	await _wait(0.35 if p == 0 else 0.3)


func _do_pass(p: int) -> void:
	if p == 0 and not autoplay:
		await _auto_pass()
	else:
		await _wait(0.45)
	await _announce_pass(p)


## No tengo ficha que case: el pase es automático. Mis fichas se atenúan un
## momento para que se vea que no hay jugada y el turno sigue solo.
func _auto_pass() -> void:
	for t: Tile in hand_tiles[0]:
		t.tween_marks(0.0, 1.0)
	await _coach("pass", "No tienes ninguna ficha que case con los extremos: pasas solo y le toca al siguiente.")
	await _wait(PASS_PAUSE)
	for t: Tile in hand_tiles[0]:
		t.tween_marks(0.0, 0.0)


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
	g.sip(target, _drink_sound)


## Al beber suena una de las voces de audio/drinks/ o, si no hay (o están
## apagadas en los ajustes), el trago sintetizado.
func _drink_sound() -> void:
	if sfx != null and sfx.has_voice("drink"):
		_play("drink")
	else:
		_play("gulp", rng.randf_range(0.9, 1.15))


func _finish_hand() -> void:
	_set_active(-1)
	var res: Dictionary = state.result()
	if res.blocked:
		_show_banner("¡TRANCA!", Color(1.0, 0.45, 0.35))
	elif res.winner == 0:
		_show_banner("¡Dominaste!", GOLD)
		_vibrate(80)
	else:
		_show_banner("¡Dominó de %s!" % names[res.winner], GOLD)
	if net == null and not autoplay:
		Stats.hand_done(res.winner == 0 and not res.blocked, res.capicua, res.blocked)
		_cpu_react(res)
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
	# Mi marcador es siempre el 0 (mi pareja o yo). Solo suma uno por mano, así
	# que nunca llegan dos a la meta a la vez.
	var match_over: bool = scores.max() >= target
	var won: bool = scores[0] >= target

	var title := "Tranca empatada"
	var color := CREAM
	if match_over:
		title = "¡VICTORIA!" if won else "DERROTA"
		color = GOLD if won else Color(1.0, 0.45, 0.4)
	elif team == 0:
		title = "¡Mano para nosotros!" if format == State.PAIRS else "¡Mano para ti!"
		color = Color(0.55, 0.85, 1.0)
	elif team > 0:
		title = "Mano para ellos" if format == State.PAIRS else "Mano para %s" % names[team]
		color = Color(1.0, 0.55, 0.5)
	var lines: Array = []
	if res.blocked:
		lines.append("Juego trancado: gana quien tenga menos puntos en la mano.")
	else:
		lines.append("Te quedaste sin fichas." if res.winner == 0 else "%s se quedó sin fichas." % names[res.winner])
	if team < 0:
		lines.append("Nadie suma puntos.")
	elif res.capicua:
		lines.append("Puntos de la mano: +%d  (¡capicúa! +%d)" % [res.points, State.CAPICUA_BONUS])
	else:
		lines.append("Puntos de la mano: +%d" % res.points)
	if mode == State.FIVES:
		var mine: int = state.fives[state.team_of(0)]
		var theirs := 0
		for q in state.fives.size():
			if q != state.team_of(0):
				theirs += state.fives[q]
		lines.append("Cincos en la mano: tú %d  ·  rivales %d" % [mine, theirs])
	lines.append("")
	lines.append("%s: %d   ·   %s: %d" % [names[0], res.totals[0], names[2], res.totals[2]])
	if format != State.DUEL:
		lines.append("%s: %d   ·   %s: %d" % [names[1], res.totals[1], names[3], res.totals[3]])
	lines.append("")
	if format == State.PAIRS:
		lines.append("Marcador:  Nosotros %d  —  %d Ellos" % [scores[0], scores[1]])
	else:
		var parts: Array = []
		for q in 4:
			if _seated(q):
				parts.append("%s %d" % [names[q], scores[q]])
		lines.append("Marcador:  " + "  ·  ".join(parts))
	var buttons: Array = [["Siguiente mano", "next", UI.PRIMARY]]
	var reward := {}
	if match_over and net == null and (paid or event != ""):
		# Con apuesta, premio y experiencia; en torneo, ranked o desafío, solo
		# experiencia (sus premios van aparte, en _event_result).
		reward = Wallet.finish_match(won, difficulty, target, bet if paid else 0, format)
		# En lugar de la línea en blanco antes del marcador.
		lines[lines.size() - 2] = ("+%d monedas  ·  +%d XP" % [reward.coins, reward.xp]) if reward.coins > 0 \
				else "+%d XP" % reward.xp
		if reward.level_up:
			_level_up(reward)
	if match_over and net == null:
		if not autoplay:
			Stats.match_done(won, int(reward.get("coins", 0)))
		var ev_line := _event_result(won) if event != "" else ""
		if ev_line != "":
			lines.insert(0, ev_line)
	if match_over:
		var again_text := "Jugar de nuevo"
		if paid and net == null:
			again_text = "Otra (%d)" % bet
		var again: Array = ["Volver a la sala", "room"] if net != null else [again_text, "again"]
		if net != null and net.room_info.get("ranked", false):
			# Ranked: el resultado lo manda el servidor justo al acabar.
			again = ["Continuar", "room"]
			var rr: Dictionary = net.ranked_last
			if not rr.is_empty():
				lines.insert(0, "%+d PR  ·  %s" % [int(rr.delta), str(rr.rank)])
		buttons = [[again[0], again[1], UI.PRIMARY], ["Menú", "menu", UI.NEUTRAL]]
		if event == "quick":
			buttons = [["Otra rápida", "again", UI.PRIMARY], ["Menú", "menu", UI.NEUTRAL]]
		elif event != "":
			buttons = [["Continuar", "menu", UI.PRIMARY]]
		elif int(reward.get("coins", 0)) > 0:
			# Doblar el premio viendo un anuncio (con premio: lo pide el jugador).
			buttons.push_front(["x2  %d" % reward.coins, "double", UI.BUY])
		_play("win" if won else "lose")
		if won:
			confetti.restart()
	if autoplay and net != null:
		# Cliente de prueba: sigue solo.
		print("[%s] mano %d -> %s" % [names[0], hand_no, str(scores)])
		await _wait(1.0)
		if match_over:
			get_tree().quit()
		net.send("sv_ready")
		return
	var action := ""
	while true:
		await _coach("end", "Fin de la mano. Quien se queda sin fichas domina y su pareja suma los puntos de todas las fichas que quedan. Si nadie puede jugar es tranca: gana quien tenga menos puntos.")
		_show_end(title, color, lines, buttons)
		action = await _panel_done
		if action != "double":
			break
		_hide_end()
		var got := [false]
		var ads := Ads.get_ads()
		if ads != null:
			await ads.show_rewarded(func() -> void: got[0] = true)
		if got[0]:
			Wallet.add_coins(int(reward.coins))
			Stats.add("coins_won", int(reward.coins))
			lines[lines.size() - 2] = "+%d monedas (x2)  ·  +%d XP" % [int(reward.coins) * 2, reward.xp]
			_play("win")
			buttons.pop_front()
	_hide_end()
	if match_over and net == null and not autoplay:
		# Entre partidas, y solo si toca por frecuencia (ver ads.gd).
		var ads := Ads.get_ads()
		if ads != null:
			await ads.after_match()
	match action:
		"next":
			if net != null:
				# La siguiente mano empieza cuando todos estén listos.
				net.send("sv_ready")
				_show_banner("Esperando a los demás…", CREAM)
			else:
				_play_hand()
		"again":
			if paid and not Wallet.pay_entry(difficulty, bet):
				# Sin monedas para otra: al menú, donde están el regalo y la ayuda.
				exit_to_menu.emit()
			else:
				_start_match()
		"room": back_to_room.emit()
		"menu": exit_to_menu.emit()


## Subida de nivel al terminar una partida: aviso grande con las monedas de regalo.
func _level_up(reward: Dictionary) -> void:
	await _wait(0.6)
	_show_banner("¡Nivel %d!  +%d monedas  +%d gemas" % [reward.level, reward.bonus, reward.gems], GOLD)
	confetti.restart()


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
	if not avatars.is_empty():
		_refresh_avatars()


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
	_net_rules(ev)
	scores = _team_scores(ev.scores)
	_reset_round()
	state = State.new()
	state.mode = mode
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
	_net_rules(ev)
	scores = _team_scores(ev.scores)
	_net_scores = scores.duplicate()
	_reset_round()
	state = State.new()
	state.mode = mode
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


## Modo y meta de la sala. Un servidor anterior a los modos no los manda: clásico a 100.
func _net_rules(ev: Dictionary) -> void:
	mode = clampi(int(ev.get("mode", State.CLASSIC)), 0, State.MODE_NAMES.size() - 1)
	target = int(ev.get("target", State.DEFAULT_TARGET))


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
			await _auto_pass()
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
	t.set_values(State.hi(code), State.lo(code))
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
	pool_tiles = []
	arms = []
	board_s = BOARD_SCALE
	board_off = play_rect.get_center()
	_last = null
	_hide_ghosts()
	confetti.emitting = false
	for g: Glass in glasses:
		if g.level < 0.3:
			g.refill()


## Crea las fichas de todas las manos, boca abajo y amontonadas en el centro.
func _spawn_tiles() -> void:
	for p in 4:
		for code in state.hands[p]:
			hand_tiles[p].append(_new_tile(code))
		hands_gfx[p].set_count(state.hands[p].size())
	for code in state.pool:
		pool_tiles.append(_new_tile(code))
	_refresh_plates()


func _new_tile(code: int) -> Tile:
	var c := play_rect.get_center()
	var t: Tile = Tile.new()
	t.code = code
	t.set_values(State.hi(code), State.lo(code))
	t.flip = 0.0
	t.position = c + Vector2(rng.randf_range(-150, 150), rng.randf_range(-150, 150))
	t.rotation = rng.randf_range(-PI, PI)
	t.scale = Vector2(0.75, 0.75)
	t.modulate.a = 0.0
	t.z_index = 1
	tile_layer.add_child(t)
	t.create_tween().tween_property(t, "modulate:a", 1.0, 0.25)
	tiles[code] = t
	return t


## Hueco i del pozo (1 contra 1): columnas a la izquierda de la mesa, donde en
## parejas se sentaría el rival del oeste. En doble seis son 2 columnas de 7;
## en doble nueve (35 fichas) se llenan también 2 columnas a la derecha.
func _bone_slot(i: int) -> Vector2:
	var mid := play_rect.get_center().y
	if State.top != 9:
		return Vector2(52.0 - Table.side + (i % 2) * 46.0, mid + (i / 2 - 3) * 64.0)
	var rows := 9
	var col := i / rows
	var row := i % rows
	var x := 52.0 - Table.side + col * 46.0 if col < 2 else 668.0 + Table.side - (col - 2) * 46.0
	return Vector2(x, mid + (row - (rows - 1) * 0.5) * 58.0)


## "Sopa": las fichas boca abajo se revuelven en el centro y luego se reparten.
func _animate_deal() -> void:
	_spawn_tiles()
	await _shuffle_animation()
	var idx := 0
	for i in State.hand_size():
		for q in 4:
			var p := (starter + q) % 4
			if not _seated(p):
				continue
			var t: Tile = hand_tiles[p][i]
			var sl: Array = hands_gfx[p].slot(i, State.hand_size())
			var delay := idx * 0.05
			t.z_index = 3
			t.fly_to(sl[0], sl[1], SEAT_SCALE[p], 0.38, delay)
			if p == 0 and not autoplay:
				t.flip_to(1.0, 0.28, delay + 0.22)
			if idx % 2 == 0:
				get_tree().create_timer(delay + 0.3).timeout.connect(_play.bind("tick", 1.0))
			idx += 1
	# Lo que sobra (1 contra 1) queda boca abajo en el pozo.
	for i in pool_tiles.size():
		var t: Tile = pool_tiles[i]
		t.fly_to(_bone_slot(i), 0.0, 0.7, 0.38, idx * 0.05 + i * 0.03)
	await _wait(idx * 0.05 + pool_tiles.size() * 0.03 + 0.55)


## Revuelve las fichas boca abajo antes de repartir. Cada mano usa una forma
## distinta de revolver, al azar y sin repetir la de la mano anterior.
func _shuffle_animation() -> void:
	await get_tree().process_frame
	var pick := rng.randi_range(0, SHUFFLES.size() - 1)
	if pick == _last_shuffle:
		pick = (pick + 1) % SHUFFLES.size()
	if force_shuffle >= 0:
		pick = force_shuffle % SHUFFLES.size()
	_last_shuffle = pick
	var order: Array = tiles.values()
	State.shuffle(order, rng)
	var c := play_rect.get_center()
	var n := order.size()
	# Remolino y ola van ficha a ficha; el resto, todas a la vez.
	var stagger := 0.008 if SHUFFLES[pick] in ["remolino", "ola"] else 0.0
	for step in 3:
		_play("shuffle", rng.randf_range(0.9, 1.1))
		for i in n:
			var t: Tile = order[i]
			var target := _shuffle_target(SHUFFLES[pick], step, i, n, c, t)
			t.fly_to(target[0], target[1], 0.75, 0.3, i * stagger)
		await _wait(0.33 + stagger * n)


## Posición y giro de la ficha i (de n) en el paso `step` (0..2) de un revuelto.
func _shuffle_target(kind: String, step: int, i: int, n: int, c: Vector2, t: Tile) -> Array:
	var jitter := Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6))
	match kind:
		"remolino":
			# Giran en anillos alrededor del centro, cada vez más cerrados.
			var radius := (70.0 + (i % 3) * 45.0) * (1.0 - step * 0.2)
			var angle := float(i) / n * TAU + step * 1.1
			return [c + Vector2.from_angle(angle) * radius + jitter, angle + PI * 0.5]
		"montones":
			# Dos montones a los lados que se intercalan en uno solo y se abren.
			if step == 0:
				var side := -1.0 if i % 2 == 0 else 1.0
				return [c + Vector2(side * 130.0, 60.0 - i * 2.5) + jitter, rng.randf_range(-0.08, 0.08)]
			if step == 1:
				return [c + Vector2(rng.randf_range(-14, 14), 60.0 - i * 4.5), rng.randf_range(-0.12, 0.12)]
			return [c + Vector2(rng.randf_range(-110, 110), rng.randf_range(-110, 110)), rng.randf_range(-PI, PI)]
		"ola":
			# En filas y columnas, con una ola que las recorre.
			var col := i % 7
			var row := i / 7
			var base := c + Vector2((col - 3) * 50.0, (row - 1.5) * 92.0)
			var wave := sin(col * 0.9 + step * 1.7)
			if step == 2:
				return [c + Vector2(rng.randf_range(-140, 140), rng.randf_range(-140, 140)), rng.randf_range(-PI, PI)]
			return [base + Vector2(0, wave * 30.0), wave * 0.35]
		"explosion":
			# Se juntan en el centro, salen disparadas en círculo y caen revueltas.
			if step == 0:
				return [c + jitter * 1.5, rng.randf_range(-PI, PI)]
			if step == 1:
				var angle := float(i) / n * TAU
				return [c + Vector2.from_angle(angle) * 185.0, angle]
			return [c + Vector2(rng.randf_range(-150, 150), rng.randf_range(-150, 150)), rng.randf_range(-PI, PI)]
	# "sopa": las manos las mueven sin orden por el centro de la mesa.
	return [c + Vector2(rng.randf_range(-150, 150), rng.randf_range(-150, 150)), t.rotation + rng.randf_range(-2.0, 2.0)]


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
		if t == _drag:
			# La que llevo en el dedo no vuelve a su hueco.
			continue
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
		var next_h: Vector2 = arm.next_h if vertical else -d
		var vn0 := 0 if vertical else 1
		if arm.get("cross", false):
			# Tras un doble atravesado, la ficha del giro sale por la punta del doble.
			# Si saliera del borde, como tras una ficha normal, quedaría medio montada
			# a su lado.
			var tip := p - d * (S * 0.5) + n * S
			return {"center": tip + n * S, "rot": n.angle() - PI * 0.5, "p": tip + n * (2.0 * S),
					"d": n, "next_h": next_h, "vn": vn0, "cross": false}
		var base := p + d * (S * 0.5)
		return {"center": base + n * (S * 0.5), "rot": n.angle() - PI * 0.5, "p": base + n * (S * 1.5),
				"d": n, "next_h": next_h, "vn": vn0, "cross": false}
	var vn: int = arm.vn + 1 if vertical else 0
	# En el tramo corto que une dos filas el doble va a lo largo, como las demás:
	# atravesado sobresaldría por los lados y no quedaría alineado con la ficha que sigue.
	if dbl and not vertical:
		return {"center": p + d * (S * 0.5), "rot": d.angle(), "p": p + d * S, "d": d, "next_h": arm.next_h, "vn": vn,
				"cross": true}
	return {"center": p + d * S, "rot": d.angle() - PI * 0.5, "p": p + d * (2.0 * S), "d": d, "next_h": arm.next_h, "vn": vn,
			"cross": false}


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


## Marca en la mesa dónde caería la ficha en cada extremo de `sides`.
func _show_ghosts(code: int, sides: Array = [0, 1]) -> void:
	var dbl := State.hi(code) == State.lo(code)
	for g: Ghost in ghosts:
		g.visible = sides.has(g.side)
		g.scale = Vector2(board_s, board_s)
		if not g.visible:
			continue
		if arms.is_empty():
			# Mesa vacía: la primera ficha va al centro.
			g.position = _b2s(Vector2.ZERO)
			g.rotation = (0.0 if dbl else -PI * 0.5) + _turn_rot()
		else:
			var pl := _calc_place(arms[g.side], dbl)
			g.position = _b2s(_turn(pl.center))
			g.rotation = pl.rot + _turn_rot()


func _hide_ghosts() -> void:
	for g: Ghost in ghosts:
		g.visible = false


# ---------------------------------------------------------------------- entrada

func _unhandled_input(event: InputEvent) -> void:
	# El dedo llega como ratón (Godot convierte los toques). La posición se
	# saca del propio evento, ya en coordenadas de la mesa.
	if not event is InputEventMouse:
		return
	var pos: Vector2 = (make_input_local(event) as InputEventMouse).position
	var button := event as InputEventMouseButton
	# Tu vaso se puede coger en cualquier momento.
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT and glasses[0].hit(pos):
		if glasses[0].level <= 0.02:
			glasses[0].refill()
		else:
			_drink(0)
		return
	if not _awaiting:
		return
	# Hay dos formas de jugar una ficha: tocarla (se suelta el dedo sin moverlo)
	# o arrastrarla hasta la mesa.
	if button != null and button.button_index != MOUSE_BUTTON_LEFT:
		return
	if button != null and button.pressed:
		_press_tile = _tile_at(pos)
		_press_pos = pos
		if _press_tile == null:
			# Toque fuera de mis fichas: elegir un extremo marcado o cancelar.
			_click(pos)
	elif button != null:
		if _drag != null:
			_end_drag()
		elif _press_tile != null and _press_tile == _tile_at(pos):
			_click(pos)
		_press_tile = null
	elif event is InputEventMouseMotion:
		if _drag != null:
			_drag_to(pos)
		elif _press_tile != null:
			if _playable(_press_tile.code) and pos.distance_to(_press_pos) > DRAG_START:
				_begin_drag(_press_tile)
				_drag_to(pos)
		else:
			var h := _tile_at(pos)
			if h != null and not _playable(h.code):
				h = null
			if h != _hover:
				_hover = h
				_layout_hand(0, 0.15)


func _begin_drag(t: Tile) -> void:
	_drag = t
	_pending = -1
	_hover = null
	_drag_sides = []
	for m in _choices:
		if (m >> 1) == t.code:
			_drag_sides.append(m & 1)
	t.z_index = 20
	_show_ghosts(t.code, _drag_sides)
	_layout_hand(0, 0.15)
	_play("click")


func _drag_to(pos: Vector2) -> void:
	_drag.fly_to(pos + DRAG_LIFT, 0.0, SEAT_SCALE[0] * 0.85, 0.06)


## Suelta la ficha arrastrada: se juega si cayó en la mesa, o vuelve a la mano.
func _end_drag() -> void:
	var t := _drag
	var side := _drop_side(t.position)
	_drag = null
	_hide_ghosts()
	if side >= 0:
		_human_done.emit(t.code * 2 + side)
	else:
		t.z_index = 3
		_layout_hand(0, 0.2)


## Extremo en el que cae una ficha soltada en `point`, o -1 si no cayó en la mesa.
## Con un solo extremo posible vale cualquier punto de la mesa; con dos, el más cercano.
func _drop_side(point: Vector2) -> int:
	if _drag_sides.is_empty() or not play_rect.grow(40.0).has_point(point):
		return -1
	var best: int = _drag_sides[0]
	var best_distance := INF
	for g: Ghost in ghosts:
		if g.visible and g.distance(point) < best_distance:
			best_distance = g.distance(point)
			best = g.side
	return best


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


## Con muchas fichas (1 contra 1) se solapan: gana la de centro más cercano al dedo.
func _tile_at(pos: Vector2) -> Tile:
	var best: Tile = null
	var best_d := INF
	for t: Tile in hand_tiles[0]:
		var d := t.global_position.distance_squared_to(pos)
		if t.hit(pos) and d < best_d:
			best = t
			best_d = d
	return best


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

	var sp := _panel(hud, Rect2(172.0 - Table.side, 170.0 - pad, 262, 76), UI.SURFACE_SOFT, UI.BORDER)
	info_lbl = _label(sp, "", 22, Color(0.9, 0.83, 0.67), Rect2(0, 0, 262, 76))

	for team in 2:
		var board: ChalkBoard = ChalkBoard.new()
		board.title = "NOSOTROS" if team == 0 else "ELLOS"
		if format == State.DUEL:
			board.title = "TÚ" if team == 0 else "RIVAL"
		elif format == State.SOLO:
			# Sin parejas: el mío y el del rival que va primero.
			board.title = "TÚ" if team == 0 else "LÍDER"
		board.tint = TEAM_COLORS[team].lightened(0.5)
		board.position = slate_pos[team]
		board.scale = Vector2(SLATE_SCALE, SLATE_SCALE)
		hud.add_child(board)
		boards.append(board)

	for p in 4:
		var plate := _panel(hud, plate_rect[p], Color(0.08, 0.05, 0.03, 0.8), _seat_color(p))
		plate.pivot_offset = plate.size * 0.5
		plate.visible = _seated(p)
		plates.append(plate)
		if not autoplay:
			plate.mouse_filter = Control.MOUSE_FILTER_STOP
			plate.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			plate.gui_input.connect(func(ev: InputEvent) -> void:
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					_open_reactions(p))
		var av: Avatar = Avatar.new()
		var text_rect := Rect2(Vector2.ZERO, plate.size)
		match p:
			0:
				av.position = Vector2(6, 6)
				av.size = Vector2(60, 60)
				text_rect = Rect2(66, 0, plate.size.x - 66, plate.size.y)
			2:
				av.position = Vector2(4, 4)
				av.size = Vector2(40, 40)
				av.ring_width = 3.0
				text_rect = Rect2(44, 0, plate.size.x - 44, plate.size.y)
			_:
				av.position = Vector2((plate.size.x - 56) * 0.5, 6)
				av.size = Vector2(56, 56)
				text_rect = Rect2(0, 62, plate.size.x, plate.size.y - 64)
		plate.add_child(av)
		avatars.append(av)
		plate_labels.append(_label(plate, names[p], 22, CREAM, text_rect))
	_refresh_avatars()

	var menu_btn := _button(hud, "Menú", UI.NEUTRAL, Rect2(40.0 - Table.side, 164.0 - pad, 120, UI.TOUCH), 28)
	menu_btn.pressed.connect(_show_options)
	if net == null and not autoplay and event != "daily":
		# Pista: la jugada que haría la CPU difícil. En ranked y en el desafío no,
		# para que no se gane pagando.
		_hint_btn = _button(hud, "Pista", UI.BUY, Rect2(548.0 + Table.side, 846.0 + pad, 164, 70), 26)
		_hint_btn.set_icon("bulb", 30)
		_hint_btn.pressed.connect(_hint)
		_hint_btn.visible = false
	_build_reactions()
	if net != null:
		# Encima de la placa del rival de la derecha, donde no tapa la mesa.
		var mid := play_rect.get_center().y
		_chat_btn = _button(hud, "Chat", UI.ACCENT, Rect2(604.0 + Table.side, mid - 344.0, 108, 76), 28)
		_chat_btn.pressed.connect(_open_chat)
		# Debajo, la señal de la conexión.
		var meter: SignalMeter = SignalMeter.new()
		meter.net = net
		meter.position = Vector2(608.0 + Table.side, mid - 264.0)
		meter.size = Vector2(104, 24)
		hud.add_child(meter)


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

	end_panel = _panel(hud, Rect2(40, 360, 640, 500), UI.SURFACE, GOLD)
	UISkin.dress(end_panel)
	end_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	end_panel.pivot_offset = end_panel.size * 0.5
	_build_options()
	end_panel.visible = false
	if net != null:
		_chat = Chat.new()
		_chat.net = net
		_chat.sfx = sfx
		_chat.top = Table.pad
		hud.add_child(_chat)
		net.chat_message.connect(_on_chat)
		net.mute_changed.connect(_refresh_avatars)


func _open_chat() -> void:
	_unread = 0
	_chat_btn.text = "Chat"
	_chat.open()


## Mensaje del chat: un bocadillo (o un emoji grande) junto a quien lo mandó,
## y la cuenta de no leídos en el botón si el chat está cerrado.
func _on_chat(msg: Dictionary) -> void:
	var v := posmod(int(msg.seat) - my_seat, 4)
	if int(msg.kind) == Chat.EMOJI:
		var tex := Chat.emoji(str(msg.text))
		if tex != null:
			_emoji_pop(v, tex)
	else:
		_bubble(v, str(msg.text), 2.6)
	if not _chat.visible and v != 0:
		_unread += 1
		_chat_btn.text = "Chat %d" % mini(_unread, 9)
		_play("click", 1.5)


func _emoji_pop(p: int, tex: Texture2D) -> void:
	var img := TextureRect.new()
	img.texture = tex
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.size = Vector2(110, 110)
	img.position = bubble_pos[p] - img.size * 0.5
	img.pivot_offset = img.size * 0.5
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.scale = Vector2(0.2, 0.2)
	hud.add_child(img)
	var tw := img.create_tween()
	tw.tween_property(img, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.0)
	tw.set_parallel(true)
	tw.tween_property(img, "position:y", img.position.y - 60.0, 0.5)
	tw.tween_property(img, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(img.queue_free)


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
	var head := "Mano %d  ·  a %d puntos" % [hand_no, target]
	if format != State.PAIRS:
		head = "Mano %d  ·  a %d  ·  %s" % [hand_no, target, FORMAT_SHORT[format]]
	info_lbl.text = "%s\n%s  ·  CPU %s" % [head, State.MODE_NAMES[mode], DIFF_NAMES[difficulty]]
	match event:
		"tournament":
			info_lbl.text = "%s  ·  a %d\n%s" % [Tournament.cup().name, target,
					Tournament.ROUND_NAMES[clampi(Tournament.round_no(), 0, 2)]]
		"daily":
			info_lbl.text = "Desafío del día\nMano %d  ·  a %d" % [hand_no, target]
	for team in 2:
		var board: ChalkBoard = boards[team]
		var value: int = scores[team]
		if team == 1 and format != State.PAIRS:
			value = 0
			for q in range(1, 4):
				value = maxi(value, scores[q])
		if animate and value != board.shown:
			_play("chalk")
		board.set_score(value, animate)


func _refresh_plates() -> void:
	for p in 4:
		# Solo la de tu compañero es de una línea; en las demás, nombre arriba
		# y fichas debajo.
		var count: int = hand_tiles[p].size()
		var fmt := "%s  ·  %d"
		if p != 2:
			fmt = "%s\n%d ficha" if count == 1 else "%s\n%d fichas"
		plate_labels[p].text = fmt % [names[p], count]


## Foto o icono de cada jugador: el mío de los ajustes, el de otra persona
## según lo que eligió, y uno fijo para cada CPU.
func _refresh_avatars() -> void:
	for p in 4:
		var av: Avatar = avatars[p]
		av.ring = _seat_color(p).lightened(0.25)
		if p == 0:
			Settings.apply_avatar(av)
		elif not seat_looks[p].is_empty():
			var look: Dictionary = seat_looks[p]
			if net != null and net.muted.has(names[p]):
				# Silenciado: tampoco se ve su foto, solo su icono.
				look = look.duplicate()
				look.erase("photo")
			av.show_look(look, names[p])
		else:
			av.photo = null
			av.icon = CPU_AVATARS[p]


func _set_active(p: int) -> void:
	if _plate_tw != null and _plate_tw.is_valid():
		_plate_tw.kill()
	for i in 4:
		var plate: Panel = plates[i]
		plate.scale = Vector2.ONE
		plate.modulate = Color(1.5, 1.4, 1.0) if i == p else Color(1, 1, 1, 0.7)
		# El aro dorado marca a quién le toca.
		avatars[i].ring = GOLD if i == p else _seat_color(i).lightened(0.25)
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


func _bubble(p: int, text: String, hold: float = 0.7) -> void:
	# Un mensaje largo del chat ocupa dos líneas en vez de salirse.
	var wide := text.length() * 15.0 + 44.0
	var size := Vector2(minf(maxf(150.0, wide), 520.0), 58.0 if wide <= 520.0 else 96.0)
	var center: Vector2 = bubble_pos[p]
	center.x = clampf(center.x, size.x * 0.5 + 10.0 - Table.side, 710.0 + Table.side - size.x * 0.5)
	var pn := _panel(hud, Rect2(center - size * 0.5, size), Color(0.98, 0.96, 0.9), _seat_color(p))
	var lb := _label(pn, text, UI.CAPTION, Color(0.15, 0.1, 0.06), Rect2(10, 0, size.x - 20, size.y))
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pn.pivot_offset = size * 0.5
	pn.scale = Vector2(0.2, 0.2)
	var tw := pn.create_tween()
	tw.tween_property(pn, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(pn, "modulate:a", 0.0, 0.25)
	tw.tween_callback(pn.queue_free)


func _show_end(title: String, color: Color, lines: Array, buttons: Array) -> void:
	for c in end_panel.get_children():
		c.queue_free()
	var w := end_panel.size.x
	var tl := _label(end_panel, title, 44, color, Rect2(0, 18, w, 62))
	tl.add_theme_font_override("font", UISkin.serif())
	tl.add_theme_color_override("font_outline_color", UISkin.TITLE_OUTLINE)
	tl.add_theme_constant_override("outline_size", 10)
	var y := 90.0
	for ln in lines:
		var lb := _label(end_panel, "", UI.CAPTION, CREAM, Rect2(20, y, w - 40, 34))
		# Una frase larga (como la de la tranca) pasa a otra línea en vez de salirse
		# del panel. El ajuste va antes que el texto: si no, la etiqueta crece a lo ancho.
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lb.text = ln
		lb.size = Vector2(w - 40, 34)
		var rows := maxi(lb.get_line_count(), 1)
		lb.size.y = 34.0 * rows
		y += 34.0 * rows + 2.0
	# Si el texto ocupa más de lo previsto, el panel crece y sigue centrado.
	var by := maxf(384.0, y + 12.0)
	end_panel.size.y = by + UI.TOUCH + 28.0
	end_panel.position.y = 610.0 - end_panel.size.y * 0.5
	end_panel.pivot_offset = end_panel.size * 0.5
	var bw := 270.0
	var total := buttons.size() * bw + (buttons.size() - 1) * 24.0
	var x := (w - total) * 0.5
	for spec in buttons:
		var action: String = spec[1]
		var b := _button(end_panel, spec[0], spec[2], Rect2(x, by, bw, UI.TOUCH), 28)
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


## Panel del botón "Menú": interruptores de sonido y de manos, seguir jugando o salir.
## La partida no se detiene mientras está abierto (en red no se puede).
func _build_options() -> void:
	opt_panel = _panel(hud, Rect2(60, 240, 600, 810), Color(0.13, 0.08, 0.05, 0.97), GOLD)
	opt_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	opt_panel.pivot_offset = opt_panel.size * 0.5
	opt_panel.visible = false
	UISkin.dress(opt_panel)
	UISkin.title(_label(opt_panel, "Ajustes", 40, GOLD, Rect2(0, 20, 600, 56)))
	var y := 96.0
	for key: String in SOUND_OPTIONS.keys():
		var b := _button(opt_panel, "", Color.GRAY, Rect2(50, y, 500, UI.TOUCH_SMALL), 30)
		b.pressed.connect(_toggle_sound.bind(key))
		_sound_btns[key] = b
		y += 96.0
	_hands_btn = _button(opt_panel, "", Color.GRAY, Rect2(50, y, 500, UI.TOUCH_SMALL), 30)
	_hands_btn.pressed.connect(_toggle_hands)
	var resume := _button(opt_panel, "Seguir jugando", UI.PRIMARY, Rect2(50, 588, 500, UI.TOUCH), UI.BUTTON)
	resume.pressed.connect(_hide_options)
	var leave := _button(opt_panel, "Salir al menú", UI.DANGER, Rect2(125, 696, 350, UI.TOUCH_SMALL), 30)
	leave.pressed.connect(leave_match)
	_refresh_options()


## Salir a mitad de partida. En el torneo cuenta como perderla (si no,
## bastaría con salir al ir perdiendo); el desafío ya gastó su intento. El
## ranked es en línea: allí lo cuenta el servidor (ver net.gd, _ranked_finish).
func leave_match() -> void:
	if net == null and not _event_reported and event == "tournament" and state != null:
		_event_reported = true
		Tournament.forfeit()
		Stats.match_done(false, 0)
	exit_to_menu.emit()


func _refresh_options() -> void:
	for key: String in _sound_btns.keys():
		_paint_switch(_sound_btns[key], SOUND_OPTIONS[key], Settings.audio[key] != 0)
	_paint_switch(_hands_btn, "Manos visibles", Settings.data.show_hands != 0)


func _paint_switch(b: FancyButton, label: String, on: bool) -> void:
	b.text = "%s:  %s" % [label, "Sí" if on else "No"]
	b.set_color(Color(0.2, 0.5, 0.6) if on else Color(0.4, 0.32, 0.26))


func _toggle_hands() -> void:
	Settings.data.show_hands = 0 if Settings.data.show_hands != 0 else 1
	Settings.save()
	_refresh_options()
	_apply_show_hands()


## Manos que sujetan las fichas o, si el jugador las ocultó, un atril de madera
## (las mías y las de los demás). Las fichas no se mueven.
func _apply_show_hands() -> void:
	var on: bool = Settings.data.show_hands != 0
	for h: Hand in hands_gfx:
		h.rack = not on
	for g: Glass in glasses:
		g.show_grip = on


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


# ------------------------------------------------------- eventos (torneo, ranked, desafío)

## Apunta el resultado del evento y devuelve la línea que lo resume.
func _event_result(won: bool) -> String:
	if _event_reported:
		return ""
	_event_reported = true
	match event:
		"tournament":
			var r := Tournament.report(won)
			if r.champion:
				_show_banner("¡Campeón!  +%d monedas  +%d gemas" % [r.prize, r.gems], GOLD)
				return "¡Campeón de la %s!  +%d monedas  +%d gemas" % [Tournament.cup().name, r.prize, r.gems]
			if r.out:
				return "Eliminado en %s.%s" % [Tournament.ROUND_NAMES[r.round].to_lower(),
						"  +%d monedas" % r.prize if r.prize > 0 else ""]
			return "¡Pasas a %s!" % Tournament.ROUND_NAMES[r.round + 1].to_lower()
		"daily":
			if won:
				var coins := Daily.complete()
				if coins > 0:
					return "¡Desafío superado!  +%d monedas  +%d gemas" % [coins, Daily.GEMS]
				return "¡Desafío superado!"
			return "Desafío no superado: otro intento viendo un anuncio."
		"tutorial":
			var first: bool = Settings.rules.tutorial != 1
			Settings.rules.tutorial = 1
			Settings.save()
			if first:
				Wallet.add_coins(TUTORIAL_REWARD)
				return "¡Partida guiada completada!  +%d monedas" % TUTORIAL_REWARD
			return "¡Partida guiada completada!"
	return ""


# ------------------------------------------------------------------ pista

func _show_hint_button(on: bool) -> void:
	if _hint_btn == null:
		return
	_hint_btn.visible = on
	_hint_btn.text = "Pista" if Wallet.coins() < Wallet.HINT_COST else "Pista %d" % Wallet.HINT_COST
	if on:
		_hint_btn.set_icon("video" if Wallet.coins() < Wallet.HINT_COST else "bulb", 30)


## Cuesta HINT_COST monedas o, si no alcanzan, un anuncio.
func _hint() -> void:
	if not _awaiting:
		return
	if Wallet.coins() >= Wallet.HINT_COST:
		Wallet.add_coins(-Wallet.HINT_COST)
		_give_hint()
		return
	var ads := Ads.get_ads()
	if ads != null:
		ads.show_rewarded(_give_hint)


## Calcula la jugada de la CPU difícil para mí y la marca: la ficha brilla y
## aparece la sombra en el extremo donde va.
func _give_hint() -> void:
	if not _awaiting:
		return
	_hint_btn.disabled = true
	var st: State = state.clone()
	var box := [-1]
	var seed_value := rng.randi()
	if OS.has_feature("web"):
		box[0] = AI.choose(st, 0, AI.HARD, seed_value)
	else:
		var task := WorkerThreadPool.add_task(func() -> void: box[0] = AI.choose(st, 0, AI.HARD, seed_value))
		while not WorkerThreadPool.is_task_completed(task):
			await get_tree().process_frame
		WorkerThreadPool.wait_for_task_completion(task)
	_hint_btn.disabled = false
	if not _awaiting or box[0] < 0:
		return
	var code: int = box[0] >> 1
	for t: Tile in hand_tiles[0]:
		t.tween_marks(1.0 if t.code == code else 0.0, 0.0 if t.code == code else 1.0)
	_show_ghosts(code, [box[0] & 1])
	_bubble(0, "Juega el %d/%d" % [State.hi(code), State.lo(code)], 1.6)
	_play("point")


# ------------------------------------------------------------- reacciones

func _vibrate(ms: int) -> void:
	if Settings.audio.get("vibrate", 1) != 0 and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


## Fila de emojis que sale al tocar la placa de un jugador.
func _build_reactions() -> void:
	_reactions = _panel(hud, Rect2(110, 560, 500, 104), UI.SURFACE, GOLD)
	UISkin.dress(_reactions)
	_reactions.mouse_filter = Control.MOUSE_FILTER_STOP
	_reactions.visible = false
	for i in REACTIONS.size():
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.icon = Chat.EMOJIS[REACTIONS[i]]
		b.expand_icon = true
		b.position = Vector2(18 + i * 78, 16)
		b.size = Vector2(72, 72)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_reactions.add_child(b)
		b.pressed.connect(_react.bind(i))


func _open_reactions(p: int) -> void:
	if _reactions.visible and _reactions.get_meta("to", -1) == p:
		_reactions.visible = false
		return
	_reactions.set_meta("to", p)
	_reactions.position.y = clampf(bubble_pos[p].y - 52.0, 300.0, 860.0)
	_reactions.visible = true
	_reactions.scale = Vector2(0.7, 0.7)
	_reactions.pivot_offset = _reactions.size * 0.5
	create_tween().tween_property(_reactions, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_play("click")


func _react(i: int) -> void:
	var to: int = _reactions.get_meta("to", 0)
	_reactions.visible = false
	var e: int = REACTIONS[i]
	if net != null:
		# En red va por el chat: todos ven el emoji junto a mi avatar.
		net.chat(Chat.EMOJI, str(e))
		return
	_throw_emoji(0, to, e)
	if to != 0 and rng.randf() < 0.6:
		# La CPU contesta a veces.
		get_tree().create_timer(rng.randf_range(1.2, 2.0)).timeout.connect(func() -> void:
			if is_inside_tree():
				var back: Array = CPU_HAPPY if e in CPU_HAPPY else CPU_SAD
				_throw_emoji(to, 0, back[rng.randi() % back.size()]))


## Emoji que vuela de la placa de `from` a la de `to` y explota allí.
func _throw_emoji(from: int, to: int, e: int) -> void:
	var tex: Texture2D = Chat.EMOJIS[e]
	if from == to:
		_emoji_pop(to, tex)
		return
	var img := TextureRect.new()
	img.texture = tex
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.size = Vector2(80, 80)
	img.pivot_offset = img.size * 0.5
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.position = plate_rect[from].get_center() - img.size * 0.5
	hud.add_child(img)
	var tw := img.create_tween().set_parallel(true)
	tw.tween_property(img, "position", bubble_pos[to] - img.size * 0.5, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(img, "rotation", TAU, 0.5)
	tw.chain().tween_callback(func() -> void:
		img.queue_free()
		_emoji_pop(to, tex)
		_play("tick", 1.4))


## La CPU reacciona a veces cuando alguien domina, hace capicúa o tranca.
func _cpu_react(res: Dictionary) -> void:
	for p in range(1, 4):
		if not _seated(p) or rng.randf() > 0.3:
			continue
		var happy: bool = (res.team == p % 2) if format == State.PAIRS else (res.winner == p)
		var pool: Array = CPU_HAPPY if happy else CPU_SAD
		var e: int = pool[rng.randi() % pool.size()]
		get_tree().create_timer(rng.randf_range(0.4, 1.4)).timeout.connect(func() -> void:
			if is_inside_tree():
				_emoji_pop(p, Chat.EMOJIS[e]))


# ------------------------------------------------------------ partida guiada

## Muestra un consejo de la partida guiada (una sola vez cada uno) y espera a
## que se pulse "Entendido". Fuera de la partida guiada no hace nada.
func _coach(key: String, text: String) -> void:
	if event != "tutorial" or autoplay or _coached.has(key):
		return
	_coached[key] = true
	if _coach_panel == null:
		_coach_panel = _panel(hud, Rect2(50, 360, 620, 330), UI.SURFACE, GOLD)
		UISkin.dress(_coach_panel)
		_coach_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		_coach_panel.pivot_offset = _coach_panel.size * 0.5
		var head := _label(_coach_panel, "Partida guiada", 34, GOLD, Rect2(0, 16, 620, 50))
		UISkin.title(head)
		_coach_text = _label(_coach_panel, "", UI.BODY - 2, CREAM, Rect2(36, 74, 548, 150))
		_coach_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_coach_ok = _button(_coach_panel, "Entendido", UI.PRIMARY, Rect2(180, 232, 260, 76), UI.BUTTON - 2)
	_coach_text.text = text
	_coach_text.size = Vector2(548, 150)
	_coach_panel.visible = true
	_coach_panel.scale = Vector2(0.7, 0.7)
	create_tween().tween_property(_coach_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _coach_ok.pressed
	_coach_panel.visible = false


## Alguna jugada posible casa por los dos extremos (con extremos distintos).
func _two_sided(moves: Array) -> bool:
	var seen := {}
	for mv: int in moves:
		var code := mv >> 1
		if seen.has(code):
			return true
		seen[code] = true
	return false
