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
##   --diff=N        dificultad 0, 1 o 2 para --auto y --play
##   --customize     abre el menú con el panel de personalización
##   --online        abre directamente la pantalla "Jugar con amigos"
##   --look=k:v,...  fuerza ajustes de aspecto, p. ej. --look=tile_style:1,hand_style:2
##   --speed=X       multiplica la velocidad del juego
##   --shot=RUTA     guarda una captura PNG y cierra
##   --shot-delay=S  segundos de espera antes de la captura (por defecto 3)
## Pruebas de red sin tocar la pantalla (la CPU juega por cada cliente):
##   --net-host            crea una sala de wifi en este equipo
##   --net-create=DIR      crea la sala TEST en un servidor dedicado
##   --net-join=DIR        entra en la sala de DIR (wifi) o en TEST (dedicado, con --net-code)
##   --net-code=TEST       código de sala para --net-join
##   --net-humans=N        el anfitrión empieza cuando haya N personas (por defecto 2)
##   --net-name=NOMBRE     nombre del jugador de prueba

const Menu = preload("res://scripts/menu.gd")
const Game = preload("res://scripts/game.gd")
const Online = preload("res://scripts/online.gd")
const Net = preload("res://scripts/net.gd")
const Sfx = preload("res://scripts/sfx.gd")
const Settings = preload("res://scripts/settings.gd")
const Table = preload("res://scripts/table.gd")

const BASE_SIZE := Vector2(720, 1280)

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
	_fit_screen()
	get_viewport().size_changed.connect(_center_content)
	net.closed.connect(_on_net_closed)

	Settings.load_settings()
	if args.has("--look"):
		# --look=clave:valor,clave:valor  (no se guarda en disco)
		for pair in str(args["--look"]).split(","):
			Settings.data[pair.get_slice(":", 0)] = int(pair.get_slice(":", 1))
	var diff := clampi(int(args.get("--diff", "2")), 0, 2)

	if args.has("--net-host") or args.has("--net-create") or args.has("--net-join"):
		# Con --online se ve la sala (para capturas); no combinar con una partida de prueba.
		_switch(_make_online.bind("") if args.has("--online") else _make_menu)
		_net_test(args)
	elif args.has("--auto") or args.has("--play"):
		_switch(_make_game.bind(diff, args.has("--auto")))
	elif args.has("--online"):
		_switch(_make_online.bind(""))
	else:
		_switch(_make_menu)
		if args.has("--customize"):
			current.open_customize()
	if args.has("--shot"):
		await get_tree().create_timer(float(args.get("--shot-delay", "3"))).timeout
		get_viewport().get_texture().get_image().save_png(args["--shot"])
		get_tree().quit()


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


func _center_content() -> float:
	var free := (get_viewport().get_visible_rect().size - BASE_SIZE) * 0.5
	free = free.max(Vector2.ZERO)
	get_viewport().canvas_transform = Transform2D(0.0, free)
	return free.y


func _notification(what: int) -> void:
	# Botón "atrás" de Android: de la partida o la sala al menú, y del menú fuera.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if current is Game or current is Online:
			_to_menu()
		else:
			get_tree().quit()


func _to_menu() -> void:
	net.leave()
	_switch(_make_menu)


func _on_net_closed() -> void:
	# El anfitrión cerró la sala o se cayó la red en mitad de la partida.
	if current is Game:
		_switch(_make_online.bind("Se perdió la conexión con la sala."))


func _make_menu() -> Node:
	var m: Menu = Menu.new()
	m.sfx = sfx
	m.start_game.connect(func(d: int) -> void: _switch(_make_game.bind(d, false)))
	m.open_online.connect(func() -> void: _switch(_make_online.bind("")))
	return m


func _make_online(notice: String) -> Node:
	var o: Online = Online.new()
	o.sfx = sfx
	o.net = net
	o.notice = notice
	o.back.connect(_to_menu)
	o.start_game.connect(func() -> void: _switch(_make_net_game.bind(false)))
	return o


func _make_game(difficulty: int, autoplay: bool) -> Node:
	var g: Game = Game.new()
	g.sfx = sfx
	g.difficulty = difficulty
	g.autoplay = autoplay
	g.exit_to_menu.connect(func() -> void: _switch(_make_menu))
	return g


## Partida en red: el servidor reparte y valida; esta pantalla solo muestra y pide jugadas.
func _make_net_game(autoplay: bool) -> Node:
	var g: Game = Game.new()
	g.sfx = sfx
	g.net = net
	g.autoplay = autoplay
	g.exit_to_menu.connect(_to_menu)
	g.back_to_room.connect(func() -> void: _switch(_make_online.bind("")))
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
	var state := {"in_game": false, "tries": 0}
	net.room_changed.connect(func(info: Dictionary) -> void:
		var count := 0
		for seat: Dictionary in info.seats:
			if seat.human:
				count += 1
		print("[%s] sala %s: %d personas, anfitrión=%s" % [player, info.code, count, info.host])
		if info.host and not info.started and not state.in_game and count >= humans:
			net.send("sv_start"))
	net.game_event.connect(func() -> void:
		if not state.in_game and not net.events.is_empty() and net.events[0].type == "hand_start":
			state.in_game = true
			_switch(_make_net_game.bind(true)))
	var connect_now := func() -> void:
		if args.has("--net-host"):
			net.host_lan(player, Settings.my_look(), 0)
		elif args.has("--net-create"):
			net.create_remote(args["--net-create"], player, Settings.my_look(), 0, "TEST")
		else:
			net.join(args["--net-join"], args.get("--net-code", ""), player, Settings.my_look())
	net.failed.connect(func(message: String) -> void:
		print("[%s] fallo: %s" % [player, message])
		# La sala puede no existir todavía: se reintenta unas cuantas veces.
		state.tries += 1
		if state.tries < 8:
			await get_tree().create_timer(1.0).timeout
			connect_now.call())
	connect_now.call()
