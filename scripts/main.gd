extends Node
## Raíz del juego: alterna entre el menú, la sala de amigos y la partida con un fundido.
##
## Servidor dedicado para jugar a distancia (sin ventana):
##   godot --headless --path . -- --server [--port=8910]
## Sin --port usa la variable de entorno PORT (así lo pide Render) o el 8910.
##
## Argumentos de depuración (después de `--`):
##   --auto          empieza una partida en modo demostración (la CPU juega por ti)
##   --play          salta el menú y empieza una partida normal
##   --intro         muestra la entrada (rayo y logos) aunque haya otros argumentos;
##                   sin argumentos sale siempre
##   --diff=N        dificultad 0, 1 o 2 para --auto y --play
##   --mode=N        modo de juego 0, 1 o 2 (State.MODE_NAMES); no se guarda
##   --target=N      puntos para ganar (50, 100, 150 o 200); no se guarda
##   --format=N      0 parejas, 1 todos contra todos, 2 uno contra uno (solo contra la CPU)
##   --customize     abre el menú con el panel de personalización
##   --cpu-panel     abre el menú con la tarjeta "Prepara tu partida" (contra la CPU)
##   --panel=CLAVE   abre el menú con un panel de la barra de abajo (shop, tournament,
##                   ranked, daily, stats)
##   --event=TIPO    salta el menú y juega una partida de torneo, desafío, rápida
##                   o guiada (tournament, daily, quick, tutorial); el
##                   torneo tiene que estar empezado
##   --nine          con --play o --auto, juega con doble nueve
##   --coins=N       fija el saldo de monedas (se guarda)
##   --paid          con --play o --auto, la partida cobra y paga como una mesa del menú
##   --options       con --play o --auto, abre el panel de ajustes de la partida
##   --online        abre directamente la pantalla "Jugar con amigos"
##   --ranked        abre directamente la pantalla del ranked en línea
##   --server-addr=D usa la dirección D en lugar del servidor de Render (pruebas)
##   --square        fuerza la mesa cuadrada de la web de escritorio
##   --look=k:v,...  fuerza ajustes de aspecto, p. ej. --look=tile_style:1,hand_style:2
##   --speed=X       multiplica la velocidad del juego
##   --shot=RUTA     guarda una captura PNG y cierra
##   --shot-delay=S  segundos de espera antes de la captura (por defecto 3)
## Pruebas de red sin tocar la pantalla (la CPU juega por cada cliente):
##   --net-host            crea una sala de wifi en este equipo
##   --net-create=DIR      crea la sala TEST en un servidor dedicado
##   --net-join=DIR        entra en la sala de DIR (wifi) o en TEST (dedicado, con --net-code)
##   --net-code=TEST       código de sala para --net-join
##   --net-idle            en la partida de prueba no juega solo: deja que se acabe el tiempo del turno
##   --perf                escribe cada 2 s las imágenes por segundo, llamadas de dibujo y tiempo de CPU
##   --net-humans=N        el anfitrión empieza cuando haya N personas (por defecto 2)
##   --net-name=NOMBRE     nombre del jugador de prueba
##   --net-token=CLAVE     clave del jugador (la misma clave recupera su asiento al volver)
##   --net-public          el anfitrión de prueba hace pública su sala
##   --net-mode=N          el anfitrión de prueba elige el modo N (0..2)
##   --net-target=N        el anfitrión de prueba elige la meta de puntos
##   --net-browse=DIR      pide la lista de salas públicas y entra en la primera
##   --net-ranked=DIR      entra en la cola de ranked del servidor DIR y juega solo
##   --net-say=TEXTO       al empezar la partida manda TEXTO y el emoji 0 al chat (y muestra lo que llega)
##   --chat                abre el chat en la sala y, ya en la partida, a los 7 s

const Menu = preload("res://scripts/menu.gd")
const Game = preload("res://scripts/game.gd")
const Online = preload("res://scripts/online.gd")
const Net = preload("res://scripts/net.gd")
const AI = preload("res://scripts/domino_ai.gd")
const State = preload("res://scripts/domino_state.gd")
const Sfx = preload("res://scripts/sfx.gd")
const Settings = preload("res://scripts/settings.gd")
const Wallet = preload("res://scripts/wallet.gd")
const Table = preload("res://scripts/table.gd")
const Stats = preload("res://scripts/stats.gd")
const Tournament = preload("res://scripts/tournament.gd")
const Daily = preload("res://scripts/daily_challenge.gd")
const Ranked = preload("res://scripts/ranked.gd")
const Ads = preload("res://scripts/ads.gd")
const Intro = preload("res://scripts/intro.gd")

const BASE_SIZE := Vector2(720, 1280)
## Pruebas: --event con --auto (la CPU juega por ti la partida del evento).
var _event_auto := false
## Cuánto crece la mesa por cada lado en la web de escritorio: 720 + 2·280 = 1280, cuadrada.
const SQUARE_SIDE := 280.0

var sfx: Node
var net: Net
var current: Node
var fade: ColorRect
var _busy := false
## Cambio de pantalla pedido mientras otro estaba en curso.
var _queued := Callable()


func _ready() -> void:
	# Mismo nombre y ruta en todos los equipos: las llamadas de red lo necesitan.
	net = Net.new()
	net.name = "Net"
	add_child(net)

	var args := {}
	for arg in OS.get_cmdline_user_args():
		args[arg.get_slice("=", 0)] = arg.get_slice("=", 1) if "=" in arg else ""
	if args.has("--perf"):
		_perf_every = 2.0
	if args.has("--speed"):
		Engine.time_scale = float(args["--speed"])
	if args.has("--server"):
		# Los servicios en la nube (Render, etc.) dicen el puerto en la variable PORT.
		var env_port := OS.get_environment("PORT")
		net.serve_dedicated(int(args.get("--port", env_port if env_port != "" else str(Net.PORT))))
		return

	sfx = Sfx.new()
	add_child(sfx)
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)

	RenderingServer.set_default_clear_color(Table.FLOOR)
	if args.has("--square") or _is_desktop_web():
		# Mesa cuadrada: se ensancha el lienzo base y la mesa crece hacia los lados.
		Table.side = SQUARE_SIDE
		get_tree().root.content_scale_size = Vector2i(BASE_SIZE + Vector2(SQUARE_SIDE * 2.0, 0))
	_fit_screen()
	get_viewport().size_changed.connect(_center_content)
	net.closed.connect(_on_net_closed)

	Settings.load_settings()
	Settings.apply_performance()
	Wallet.load_wallet()
	Wallet.sanitize_look()
	Stats.load_stats()
	Tournament.load_tournament()
	Daily.load_daily()
	# Anuncios (modo prueba hasta instalar el plugin de AdMob). Solo con pantalla.
	var ads := Ads.new()
	ads.name = "Ads"
	add_child(ads)
	if args.has("--coins"):
		# Pruebas: fija el saldo (sí se guarda).
		Wallet.data.coins = int(args["--coins"])
		Wallet.save()
	if args.has("--look"):
		# --look=clave:valor,clave:valor  (no se guarda en disco)
		for pair in str(args["--look"]).split(","):
			Settings.data[pair.get_slice(":", 0)] = int(pair.get_slice(":", 1))
	if args.has("--mode"):
		Settings.rules.mode = clampi(int(args["--mode"]), 0, State.MODE_NAMES.size() - 1)
	if args.has("--target"):
		Settings.rules.target = int(args["--target"])
	if args.has("--server-addr"):
		Online.server_override = str(args["--server-addr"])
	if args.has("--nine"):
		Settings.rules.nine = 1
	if args.has("--format"):
		Settings.rules.format = clampi(int(args["--format"]), 0, State.FORMAT_NAMES.size() - 1)
	var diff := clampi(int(args.get("--diff", "2")), 0, 2)

	if args.has("--net-host") or args.has("--net-create") or args.has("--net-join") or args.has("--net-browse") \
			or args.has("--net-ranked"):
		# Con --online se ve la sala (para capturas); no combinar con una partida de prueba.
		_switch(_make_online.bind("") if args.has("--online") else _make_menu)
		_net_test(args)
	elif args.has("--auto") or args.has("--play"):
		if args.has("--paid"):
			Wallet.pay_entry(diff, Settings.rules.bet)
		_switch(_make_game.bind(diff, args.has("--auto"), args.has("--paid")))
		if args.has("--options"):
			current.call_deferred("_show_options")
	elif args.has("--online") or args.has("--ranked"):
		_switch(_make_online.bind("", args.has("--ranked")))
	elif args.has("--event"):
		_event_auto = args.has("--auto")
		_switch(_make_event_game.bind(str(args["--event"])))
	elif args.is_empty() or args.has("--intro"):
		# Arranque normal: logo del estudio con el rayo y logo del juego; el menú
		# entra cuando termina (ver intro.gd).
		_play_intro()
	else:
		_switch(_make_menu.bind(str(args.get("--panel", ""))))
		if args.has("--customize"):
			current.open_customize()
		if args.has("--cpu-panel"):
			current._open_setup(false)
	if args.has("--shot"):
		await get_tree().create_timer(float(args.get("--shot-delay", "3"))).timeout
		get_viewport().get_texture().get_image().save_png(args["--shot"])
		get_tree().quit()


## Entrada de la app. Va en su propia capa por encima del fundido: el menú se
## crea debajo al terminar y la entrada se desvanece encima de él.
func _play_intro() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var intro: Intro = Intro.new()
	intro.sfx = sfx
	layer.add_child(intro)
	await intro.finished
	_switch(_make_menu)
	var tw := intro.create_tween()
	tw.tween_property(intro, "modulate:a", 0.0, 0.4)
	tw.tween_callback(layer.queue_free)


## El diseño base es 720x1280 (vertical). En pantallas más altas (casi todos los
## teléfonos) el contenido se centra y la mesa se alarga hasta donde lo permitan
## el notch y la barra de gestos.
func _fit_screen() -> void:
	var extra := _center_content()
	var inset := 0.0
	if OS.has_feature("mobile"):
		var screen := DisplayServer.screen_get_size()
		var safe := DisplayServer.get_display_safe_area()
		if screen.y > 0:
			var units_per_px := get_viewport().get_visible_rect().size.y / float(screen.y)
			inset = maxf(safe.position.y, screen.y - safe.end.y) * units_per_px
	Table.pad = maxf(extra - inset, 0.0)


## La versión web abierta en un ordenador: navegador que no es de móvil y con
## ventana apaisada. Ahí la mesa se muestra cuadrada; en el teléfono (web o
## app) sigue en vertical.
func _is_desktop_web() -> bool:
	if not OS.has_feature("web") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return false
	var window := DisplayServer.window_get_size()
	return window.x >= window.y


func _center_content() -> float:
	var free := (get_viewport().get_visible_rect().size - BASE_SIZE) * 0.5
	free = free.max(Vector2.ZERO)
	get_viewport().canvas_transform = Transform2D(0.0, free)
	return free.y


## Alto del teclado del teléfono en el fotograma anterior (ver _process).
var _keyboard_h := 0
## Pruebas de rendimiento (--perf): cada cuántos segundos se escriben las medidas.
var _perf_every := 0.0
var _perf_t := 0.0


func _process(_delta: float) -> void:
	# Si el teclado se cierra (botón atrás) con un campo de texto aún en uso,
	# se suelta el campo: si no, Android deja a la vista la caja de texto del
	# teclado, una franja blanca encima del juego.
	if _perf_every > 0.0:
		_perf_t += _delta
		if _perf_t >= _perf_every:
			_perf_t = 0.0
			print("[perf] fps=%d  dibujos=%d  objetos=%d  cpu=%.1f ms  nodos=%d" % [
					Engine.get_frames_per_second(),
					Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
					Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
					Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
					Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return
	var h := DisplayServer.virtual_keyboard_get_height()
	if h == 0 and _keyboard_h > 0 and get_viewport().gui_get_focus_owner() is LineEdit:
		get_viewport().gui_release_focus()
	_keyboard_h = h


func _notification(what: int) -> void:
	# Al minimizar, se suelta el campo de texto en uso y se esconde el teclado:
	# si no, al volver Android deja a la vista la caja de texto del teclado (una
	# franja blanca encima del juego).
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if is_inside_tree():
			get_viewport().gui_release_focus()
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
			DisplayServer.virtual_keyboard_hide()
	# Botón "atrás" de Android: de la partida o la sala al menú, y del menú fuera.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if current is Game and current.net == null:
			# Contra la CPU: como "Salir al menú" (en el torneo cuenta como derrota).
			current.leave_match()
		elif current is Game or current is Online:
			_to_menu()
		else:
			get_tree().quit()


func _to_menu() -> void:
	Online.rejoin_code = ""
	net.ranked_mode = false
	net.leave()
	_switch(_make_menu)


func _on_net_closed() -> void:
	# Se cayó la red en mitad de la partida (o se minimizó el juego en Android):
	# la pantalla en línea vuelve sola a la sala si sabe su código.
	if current is Game:
		_switch(_make_online.bind("Se perdió la conexión con la sala.", false, true))


func _make_menu(panel: String = "") -> Node:
	var m: Menu = Menu.new()
	m.sfx = sfx
	m.open_panel = panel
	m.start_event.connect(func(kind: String) -> void: _switch(_make_event_game.bind(kind)))
	m.open_ranked.connect(func() -> void: _switch(_make_online.bind("", true)))
	# El menú ya cobró la entrada de la mesa: la partida paga el premio al ganar.
	m.start_game.connect(func(d: int) -> void: _switch(_make_game.bind(d, false, true)))
	m.open_online.connect(func() -> void: _switch(_make_online.bind("")))
	return m


func _make_online(notice: String, ranked: bool = false, rejoin: bool = false) -> Node:
	var o: Online = Online.new()
	o.rejoin = rejoin
	o.sfx = sfx
	o.net = net
	o.notice = notice
	o.start_ranked = ranked
	o.back.connect(_to_menu)
	o.start_game.connect(func() -> void: _switch(_make_net_game.bind(false)))
	return o


func _make_game(difficulty: int, autoplay: bool, paid: bool = false) -> Node:
	var g: Game = Game.new()
	g.sfx = sfx
	g.difficulty = difficulty
	g.paid = paid
	g.bet = Settings.rules.bet
	g.mode = clampi(Settings.rules.mode, 0, State.MODE_NAMES.size() - 1)
	g.format = clampi(Settings.rules.format, 0, State.FORMAT_NAMES.size() - 1)
	g.double_nine = Settings.rules.nine == 1
	g.target = Settings.rules.target if State.TARGETS.has(Settings.rules.target) else State.DEFAULT_TARGET
	g.autoplay = autoplay
	g.exit_to_menu.connect(func() -> void: _switch(_make_menu))
	return g


## Partida de torneo, desafío del día, rápida o guiada: reglas fijas según el
## evento (ver tournament.gd y daily_challenge.gd). Al terminar vuelve al
## menú con el panel del evento abierto.
func _make_event_game(kind: String) -> Node:
	var g: Game = Game.new()
	g.sfx = sfx
	g.event = kind
	g.autoplay = _event_auto
	match kind:
		"tournament":
			g.format = State.DUEL
			g.mode = State.CLASSIC
			g.difficulty = Tournament.difficulty()
			g.target = Tournament.target()
			g.names = Game.DUEL_NAMES.duplicate()
			g.names[2] = Tournament.opponent_name()
		"daily":
			g.format = State.PAIRS
			g.mode = Daily.mode()
			g.difficulty = Daily.DIFFICULTY
			g.target = Daily.TARGET
			g.deal_seed = Daily.seed_value()
		"quick":
			# Partida rápida: lo último elegido, sin apuesta y a 50, más deprisa.
			g.format = clampi(Settings.rules.format, 0, State.FORMAT_NAMES.size() - 1)
			g.mode = clampi(Settings.rules.mode, 0, State.MODE_NAMES.size() - 1)
			g.difficulty = mini(Settings.rules.difficulty, Wallet.DIFF_LEVEL.size() - 1)
			if Wallet.level() < Wallet.DIFF_LEVEL[g.difficulty]:
				g.difficulty = 0
			g.target = 50
			g.double_nine = Settings.rules.nine == 1
		"tutorial":
			# Partida guiada: en parejas, clásico, CPU fácil y a 50.
			g.format = State.PAIRS
			g.mode = State.CLASSIC
			g.difficulty = 0
			g.target = 50
	var back := func() -> void: _switch(_make_menu.bind(kind))
	g.exit_to_menu.connect(back)
	return g


## Partida en red: el servidor reparte y valida; esta pantalla solo muestra y pide jugadas.
func _make_net_game(autoplay: bool) -> Node:
	var g: Game = Game.new()
	g.sfx = sfx
	g.net = net
	g.autoplay = autoplay
	g.exit_to_menu.connect(_to_menu)
	# Tras una partida de ranked se vuelve a la pantalla del ranked.
	g.back_to_room.connect(func() -> void: _switch(_make_online.bind("", net.ranked_mode)))
	return g


func _switch(maker: Callable) -> void:
	if _busy:
		_queued = maker
		return
	_busy = true
	if current != null:
		await create_tween().tween_property(fade, "color:a", 1.0, 0.25).finished
		current.queue_free()
	current = maker.call()
	add_child(current)
	move_child(current, 0)
	await create_tween().tween_property(fade, "color:a", 0.0, 0.35).finished
	_busy = false
	if _queued.is_valid():
		var next := _queued
		_queued = Callable()
		_switch(next)


## Cliente de prueba: crea o entra en una sala y juega solo.
func _net_test(args: Dictionary) -> void:
	var player: String = args.get("--net-name", "Prueba")
	var humans := int(args.get("--net-humans", "2"))
	# Cada cliente de prueba lleva su propia clave; repetirla simula al mismo jugador que vuelve.
	var token: String = args.get("--net-token", "prueba-" + player)
	var state := {"in_game": false, "tries": 0}
	net.room_changed.connect(func(info: Dictionary) -> void:
		var count := 0
		for seat: Dictionary in info.seats:
			if seat.human:
				count += 1
		print("[%s] sala %s: %d personas, anfitrión=%s, pública=%s" % [player, info.code, count, info.host, info.get("public", false)])
		if args.has("--net-public") and info.host and not info.get("public", false):
			net.set_public(true)
		if args.has("--chat") and current is Online and not state.has("chat"):
			state.chat = true
			current.call_deferred("_open_chat")
		if info.host and not info.started and info.has("mode") and not state.has("rules"):
			state.rules = true
			net.set_rules(int(args.get("--net-mode", "0")), int(args.get("--net-target", "100")))
		if info.host and not info.started and not state.in_game and count >= humans:
			net.send("sv_start"))
	net.public_rooms.connect(func(list: Array) -> void:
		print("[%s] salas públicas: %s" % [player, str(list)])
		if args.has("--net-browse") and not list.is_empty() and net.room_info.is_empty():
			net.join("", str(list[0].code), player, Settings.my_look(), token))
	net.chat_message.connect(func(msg: Dictionary) -> void:
		print("[%s] chat de %s: %s %s" % [player, msg.name, "emoji" if int(msg.kind) == 1 else "texto", msg.text]))
	net.game_event.connect(func() -> void:
		if not state.in_game and not net.events.is_empty() and net.events[0].type in ["hand_start", "resume"]:
			state.in_game = true
			if args.has("--net-say"):
				get_tree().create_timer(2.0).timeout.connect(func() -> void:
					net.chat(0, args["--net-say"])
					net.chat(0, "demasiado pronto")
					get_tree().create_timer(4.0, true, false, true).timeout.connect(func() -> void: net.chat(1, "0")))
			if args.has("--chat"):
				get_tree().create_timer(7.0, true, false, true).timeout.connect(func() -> void: current._open_chat())
			_switch(_make_net_game.bind(not args.has("--net-idle"))))
	if args.has("--net-ranked"):
		# El token del ranked tiene que ser largo (el servidor rechaza los cortos).
		token = token.sha256_text().left(32)
		net.ranked_profile.connect(func(rec: Dictionary) -> void:
			print("[%s] ranked: %s (%d PR, %d partidas)" % [player, Ranked.rank_name(int(rec.pr)), int(rec.pr), int(rec.games)])
			if not state.has("queued"):
				state.queued = true
				net.ranked_queue(true, Settings.my_look()))
		net.ranked_queue_changed.connect(func(info: Dictionary) -> void:
			if int(info.get("secs", 0)) % 5 == 0:
				print("[%s] cola: %s" % [player, str(info)]))
		net.ranked_result.connect(func(res: Dictionary) -> void:
			print("[%s] resultado ranked: %s %+d PR -> %s" % [player, "gana" if res.won else "pierde", int(res.delta), res.rank]))
	var connect_now := func() -> void:
		if args.has("--net-ranked"):
			net.ranked_connect(args["--net-ranked"], player, token)
		elif args.has("--net-host"):
			net.host_lan(player, Settings.my_look(), 0, token)
		elif args.has("--net-create"):
			net.create_remote(args["--net-create"], player, Settings.my_look(), 0, token, args.get("--net-code", "TEST"))
		elif args.has("--net-browse"):
			net.browse(args["--net-browse"])
		else:
			net.join(args["--net-join"], args.get("--net-code", ""), player, Settings.my_look(), token)
	net.failed.connect(func(message: String) -> void:
		print("[%s] fallo: %s" % [player, message])
		# La sala puede no existir todavía: se reintenta unas cuantas veces.
		state.tries += 1
		if state.tries < 8:
			await get_tree().create_timer(1.0).timeout
			connect_now.call())
	connect_now.call()
