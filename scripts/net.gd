extends Node
## Multijugador en salas de 4 asientos; cada asiento es una persona o una CPU.
##
## Quien hace de servidor lleva la partida entera (reparto, validación, CPU) y
## manda a cada jugador solo sus fichas. Hay dos formas de tener servidor:
##   - Misma wifi: el teléfono que crea la sala es servidor y jugador a la vez,
##     y se anuncia por la red local para que los demás lo encuentren.
##   - A distancia: un servidor dedicado (`--server`) con muchas salas, a las
##     que se entra con un código.
## El código de sala y de juego es el mismo en los dos casos.
##
## Este nodo debe estar en la misma ruta (/root/Main/Net) en todos los equipos.

## Cambió la sala en la que estoy (asientos, dificultad, anfitrión...).
signal room_changed(info: Dictionary)
## Hay eventos de partida nuevos en `events`.
signal game_event
## No se pudo conectar, o el servidor rechazó lo pedido.
signal failed(message: String)
## Se perdió la conexión con el servidor.
signal closed
## Cambió la lista de salas vistas en la wifi (`lan_rooms`).
signal lan_changed

const State = preload("res://scripts/domino_state.gd")
const AI = preload("res://scripts/domino_ai.gd")

const PORT := 8910
const BEACON_PORT := 8911
const TARGET_SCORE := 100
const LAN_CODE := "WIFI"
const NO_MOVE := -2
## Segundos que se insiste en conectar: poco en la wifi, mucho con un servidor
## en la nube que puede estar despertando.
const LAN_PATIENCE := 7.0
const REMOTE_PATIENCE := 80.0
## Cada cuánto manda el cliente una señal para que no le corten la conexión por inactiva.
const PING_EVERY := 20.0
## Orden en que se sientan los que llegan: primero de compañero del anfitrión.
const JOIN_ORDER := [2, 1, 3, 0]

# --- cliente
## Eventos de partida pendientes de procesar, en orden de llegada.
var events: Array = []
## Última información de mi sala; vacío si no estoy en ninguna.
var room_info := {}
## Salas anunciadas en la wifi: ip -> {name, players, seen}.
var lan_rooms := {}
var online := false

# --- servidor
var serving := false
## Servidor sin jugador local.
var dedicated := false
var rooms := {}
var peer_room := {}

var _local_call := false
var _rng := RandomNumberGenerator.new()
## Conexión en curso: {url, then}. Vacío si no se está conectando.
var _target := {}
var _deadline := 0
## Número de intento; invalida temporizadores y reintentos de intentos viejos.
var _attempt := 0
var _beacon: PacketPeerUDP
var _listener: PacketPeerUDP
var _beacon_timer := 0.0
var _ping_timer := 0.0


func _ready() -> void:
	_rng.randomize()
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_server_lost)
	multiplayer.peer_disconnected.connect(_peer_left)


# ---------------------------------------------------------------- API de cliente

## Crea una sala en este teléfono para jugar en la misma wifi.
func host_lan(player_name: String, look: Dictionary, difficulty: int) -> bool:
	leave()
	if _start_server(PORT) != OK:
		failed.emit("No se pudo abrir la sala en este teléfono.")
		return false
	_beacon = PacketPeerUDP.new()
	_beacon.set_broadcast_enabled(true)
	send("sv_create", [player_name, look, difficulty, LAN_CODE])
	return true


## Crea una sala en un servidor a distancia. `code_hint` pide un código concreto (pruebas).
func create_remote(address: String, player_name: String, look: Dictionary, difficulty: int,
		code_hint: String = "") -> void:
	_connect_to(address, func() -> void: sv_create.rpc_id(1, player_name, look, difficulty, code_hint), REMOTE_PATIENCE)


## Entra en una sala: por IP en la wifi (código vacío) o por código a distancia.
func join(address: String, code: String, player_name: String, look: Dictionary) -> void:
	_connect_to(address, func() -> void: sv_join.rpc_id(1, code, player_name, look),
			LAN_PATIENCE if code.strip_edges() == "" else REMOTE_PATIENCE)


## Manda una orden al servidor (que puede ser este mismo teléfono).
func send(method: String, args: Array = []) -> void:
	if serving:
		# Orden del propio anfitrión: se marca para no confundirla con la del
		# jugador remoto cuyo mensaje se esté atendiendo en este momento.
		_local_call = true
		callv(method, args)
		_local_call = false
	elif online:
		callv("rpc_id", [1, method] + args)


## Sale de la sala y cierra la conexión (o el servidor, si era el anfitrión).
func leave() -> void:
	if serving:
		for room: Dictionary in rooms.values():
			room.dead = true
		rooms.clear()
		peer_room.clear()
	elif online and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		sv_leave.rpc_id(1)
	if multiplayer.multiplayer_peer != null and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	serving = false
	online = false
	_beacon = null
	# Anula también cualquier intento de conexión o reintento en curso.
	_target = {}
	_attempt += 1
	events.clear()
	room_info = {}


## Empieza a escuchar las salas anunciadas en la wifi.
func listen_lan(on: bool) -> void:
	lan_rooms.clear()
	if not on:
		_listener = null
		return
	_listener = PacketPeerUDP.new()
	if _listener.bind(BEACON_PORT) != OK:
		_listener = null


## Direcciones IPv4 de este equipo en la red local, para dictárselas a los demás.
static func local_ips() -> Array:
	var out: Array = []
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10.") or (ip.begins_with("172.") and not ip.begins_with("172.0")):
			out.append(ip)
	return out


## Completa lo que el jugador escribió como dirección:
##   - con "://" se usa tal cual (https copiado del navegador pasa a wss);
##   - una IP (o "localhost") es un servidor directo: ws:// y el puerto del juego;
##   - un nombre de dominio es un servidor en la nube: wss:// cifrado.
static func full_url(address: String) -> String:
	var a := address.strip_edges().to_lower().trim_suffix("/")
	if "://" in a:
		return a.replace("https://", "wss://").replace("http://", "ws://")
	var host := a.get_slice(":", 0)
	if host.is_valid_ip_address() or host == "localhost":
		return "ws://%s" % a if ":" in a else "ws://%s:%d" % [a, PORT]
	return "wss://%s" % a


## Conecta con un servidor y, al lograrlo, ejecuta `then`. `patience` son los
## segundos durante los que se reintenta: un servidor gratuito en la nube se
## duerme si nadie lo usa y tarda cerca de un minuto en despertar.
func _connect_to(address: String, then: Callable, patience: float) -> void:
	leave()
	if address.strip_edges() == "":
		failed.emit("Falta la dirección.")
		return
	_target = {"url": full_url(address), "then": then}
	_deadline = Time.get_ticks_msec() + int(patience * 1000.0)
	_try_connect()


func _try_connect() -> void:
	_attempt += 1
	var peer := WebSocketMultiplayerPeer.new()
	if peer.create_client(_target.url) != OK:
		_target = {}
		failed.emit("Dirección no válida.")
		return
	multiplayer.multiplayer_peer = peer
	# Si el servidor no responde, el intento puede quedarse colgado mucho rato.
	get_tree().create_timer(8.0).timeout.connect(_attempt_expired.bind(_attempt))


func _attempt_expired(attempt: int) -> void:
	if attempt == _attempt and not online and not _target.is_empty():
		_connection_failed()


func _connected() -> void:
	online = true
	var then: Callable = _target.get("then", Callable())
	_target = {}
	if then.is_valid():
		then.call()


func _connection_failed() -> void:
	if _target.is_empty():
		return
	if Time.get_ticks_msec() < _deadline:
		# Todavía hay margen: se cierra este intento y se prueba otra vez en un momento.
		var attempt := _attempt
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		await get_tree().create_timer(3.0).timeout
		if attempt == _attempt and not _target.is_empty():
			_try_connect()
		return
	leave()
	failed.emit("No se pudo conectar. Revisa la dirección y tu conexión.")


func _server_lost() -> void:
	leave()
	closed.emit()


@rpc("authority", "call_remote", "reliable")
func cl_room(info: Dictionary) -> void:
	room_info = info
	room_changed.emit(info)


@rpc("authority", "call_remote", "reliable")
func cl_error(message: String) -> void:
	failed.emit(message)


@rpc("authority", "call_remote", "reliable")
func cl_event(ev: Dictionary) -> void:
	events.append(ev)
	game_event.emit()


# ------------------------------------------------------------- red local (wifi)

func _process(delta: float) -> void:
	if online and not serving:
		_ping_timer -= delta
		if _ping_timer <= 0.0:
			_ping_timer = PING_EVERY
			sv_ping.rpc_id(1)
	if _beacon != null and serving:
		_beacon_timer -= delta
		if _beacon_timer <= 0.0:
			_beacon_timer = 1.0
			_announce()
	if _listener != null:
		var changed := false
		while _listener.get_available_packet_count() > 0:
			var data: Variant = JSON.parse_string(_listener.get_packet().get_string_from_utf8())
			var ip := _listener.get_packet_ip()
			if data is Dictionary and data.get("game", "") == "crazy-dominoes":
				lan_rooms[ip] = {"name": str(data.get("name", "?")), "players": int(data.get("players", 1)),
						"seen": Time.get_ticks_msec()}
				changed = true
		for ip: String in lan_rooms.keys():
			if Time.get_ticks_msec() - int(lan_rooms[ip].seen) > 3500:
				lan_rooms.erase(ip)
				changed = true
		if changed:
			lan_changed.emit()


## Anuncia la sala por la red local mientras no haya empezado la partida.
func _announce() -> void:
	var room: Dictionary = rooms.get(LAN_CODE, {})
	if room.is_empty() or room.started:
		return
	var host_name := ""
	var players := 0
	for seat: Dictionary in room.seats:
		if seat.peer != 0:
			players += 1
			if seat.peer == room.host:
				host_name = seat.name
	var packet := JSON.stringify({"game": "crazy-dominoes", "name": host_name, "players": players}).to_utf8_buffer()
	var targets := ["255.255.255.255"]
	for ip: String in local_ips():
		targets.append(ip.get_slice(".", 0) + "." + ip.get_slice(".", 1) + "." + ip.get_slice(".", 2) + ".255")
	for target: String in targets:
		_beacon.set_dest_address(target, BEACON_PORT)
		_beacon.put_packet(packet)


# ---------------------------------------------------------------------- servidor

## Arranca un servidor dedicado (sin jugador local) para jugar a distancia.
func serve_dedicated(port: int) -> bool:
	dedicated = true
	var err := _start_server(port)
	print("[servidor] ", "escuchando en el puerto %d" % port if err == OK else "no se pudo abrir el puerto %d" % port)
	return err == OK


func _start_server(port: int) -> Error:
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_server(port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	serving = true
	return OK


func _sender() -> int:
	if _local_call:
		return 1
	var id := multiplayer.get_remote_sender_id()
	return id if id != 0 else 1


## Entrega un mensaje a un jugador; el anfitrión de wifi se lo entrega a sí mismo.
func _to(peer: int, method: String, args: Array) -> void:
	if peer == 1 and not dedicated:
		callv(method, args)
	elif multiplayer.get_peers().has(peer):
		callv("rpc_id", [peer, method] + args)


func _broadcast(room: Dictionary, ev: Dictionary) -> void:
	for seat: Dictionary in room.seats:
		if seat.peer != 0:
			_to(seat.peer, "cl_event", [ev])


func _room_of(peer: int) -> Dictionary:
	return rooms.get(peer_room.get(peer, ""), {})


func _seat_of(room: Dictionary, peer: int) -> int:
	for i in 4:
		if room.seats[i].peer == peer:
			return i
	return -1


func _seats_public(room: Dictionary) -> Array:
	var out: Array = []
	for seat: Dictionary in room.seats:
		out.append({"name": seat.name, "human": seat.peer != 0, "look": seat.look})
	return out


func _push_room(room: Dictionary) -> void:
	var seats := _seats_public(room)
	for i in 4:
		var peer: int = room.seats[i].peer
		if peer != 0:
			_to(peer, "cl_room", [{"code": room.code, "difficulty": room.difficulty, "started": room.started,
					"host": peer == room.host, "you": i, "seats": seats}])


func _new_code() -> String:
	# Sin letras que se confundan al dictarlas.
	var letters := "ABCDEFGHJKMNPQRSTUVWXYZ"
	while true:
		var code := ""
		for i in 4:
			code += letters[_rng.randi_range(0, letters.length() - 1)]
		if not rooms.has(code):
			return code
	return ""


func _clean_name(player_name: String) -> String:
	var n := player_name.strip_edges().left(12)
	return n if n != "" else "Jugador"


@rpc("any_peer", "call_remote", "reliable")
func sv_create(player_name: String, look: Dictionary, difficulty: int, code_hint: String) -> void:
	var id := _sender()
	_leave_room(id)
	var code := code_hint if code_hint != "" and not rooms.has(code_hint) else _new_code()
	var seats: Array = []
	for i in 4:
		seats.append({"peer": 0, "name": "", "look": {}})
	var room := {"code": code, "seats": seats, "difficulty": clampi(difficulty, 0, 2), "host": id,
			"started": false, "dead": false, "state": null, "scores": [0, 0], "starter": -1,
			"hand_no": 0, "pending": NO_MOVE, "ready": {}}
	rooms[code] = room
	seats[0] = {"peer": id, "name": _clean_name(player_name), "look": look}
	peer_room[id] = code
	if dedicated:
		print("[sala %s] creada por %s" % [code, seats[0].name])
	_push_room(room)


@rpc("any_peer", "call_remote", "reliable")
func sv_join(code: String, player_name: String, look: Dictionary) -> void:
	var id := _sender()
	_leave_room(id)
	var key := code.strip_edges().to_upper()
	# En wifi solo hay una sala por anfitrión: no hace falta código.
	if key == "" and rooms.size() == 1:
		key = rooms.keys()[0]
	var room: Dictionary = rooms.get(key, {})
	if room.is_empty():
		_to(id, "cl_error", ["No existe esa sala."])
		return
	if room.started:
		_to(id, "cl_error", ["Esa partida ya empezó."])
		return
	for i: int in JOIN_ORDER:
		if room.seats[i].peer == 0:
			room.seats[i] = {"peer": id, "name": _clean_name(player_name), "look": look}
			peer_room[id] = key
			_push_room(room)
			return
	_to(id, "cl_error", ["La sala está llena."])


## Cambiarse a un asiento libre (ocupado por una CPU).
@rpc("any_peer", "call_remote", "reliable")
func sv_sit(seat: int) -> void:
	var id := _sender()
	var room := _room_of(id)
	var from := -1 if room.is_empty() else _seat_of(room, id)
	if from < 0 or room.started or seat < 0 or seat > 3 or room.seats[seat].peer != 0:
		return
	room.seats[seat] = room.seats[from]
	room.seats[from] = {"peer": 0, "name": "", "look": {}}
	_push_room(room)


@rpc("any_peer", "call_remote", "reliable")
func sv_difficulty(difficulty: int) -> void:
	var room := _room_of(_sender())
	if room.is_empty() or room.host != _sender() or room.started:
		return
	room.difficulty = clampi(difficulty, 0, 2)
	_push_room(room)


@rpc("any_peer", "call_remote", "reliable")
func sv_start() -> void:
	var room := _room_of(_sender())
	if room.is_empty() or room.host != _sender() or room.started:
		return
	room.started = true
	_push_room(room)
	_run_match(room)


## Jugada del jugador en turno; -1 significa pasar.
@rpc("any_peer", "call_remote", "reliable")
func sv_move(move: int) -> void:
	var id := _sender()
	var room := _room_of(id)
	if room.is_empty() or room.state == null:
		return
	var st: State = room.state
	if st.is_over() or st.turn != _seat_of(room, id):
		return
	var moves: Array = st.legal_moves(st.turn)
	if (move == -1 and moves.is_empty()) or moves.has(move):
		room.pending = move


## "Siguiente mano".
@rpc("any_peer", "call_remote", "reliable")
func sv_ready() -> void:
	var room := _room_of(_sender())
	if not room.is_empty():
		room.ready[_sender()] = true


## Señal de vida: los proxys de la nube cierran las conexiones que no mandan nada.
@rpc("any_peer", "call_remote", "reliable")
func sv_ping() -> void:
	pass


@rpc("any_peer", "call_remote", "reliable")
func sv_leave() -> void:
	_leave_room(_sender())


func _peer_left(id: int) -> void:
	if serving:
		_leave_room(id)


## Saca a un jugador de su sala: su asiento lo toma una CPU y la partida sigue.
func _leave_room(id: int) -> void:
	var room := _room_of(id)
	peer_room.erase(id)
	if room.is_empty():
		return
	var seat := _seat_of(room, id)
	var gone: String = room.seats[seat].name
	room.seats[seat] = {"peer": 0, "name": "", "look": {}}
	var next_host := 0
	for s: Dictionary in room.seats:
		if s.peer != 0:
			next_host = s.peer
			break
	if next_host == 0:
		room.dead = true
		rooms.erase(room.code)
		if dedicated:
			print("[sala %s] cerrada" % room.code)
		return
	if room.host == id:
		room.host = next_host
	if room.started:
		_broadcast(room, {"type": "left", "seat": seat, "name": gone})
	_push_room(room)


# ------------------------------------------------------------ partida (servidor)

func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _run_match(room: Dictionary) -> void:
	room.scores = [0, 0]
	room.starter = -1
	room.hand_no = 0
	while not room.dead:
		await _run_hand(room)
		if room.dead:
			return
		if room.scores[0] >= TARGET_SCORE or room.scores[1] >= TARGET_SCORE:
			break
	# Fin de la partida: la sala vuelve a la espera para poder jugar otra.
	room.started = false
	room.state = null
	_push_room(room)


func _run_hand(room: Dictionary) -> void:
	room.hand_no += 1
	var st := State.new()
	st.deal(_rng)
	var opening: bool = room.starter < 0
	if opening:
		room.starter = st.holder_of(State.DOUBLE_SIX)
		st.forced = State.DOUBLE_SIX
	st.turn = room.starter
	room.state = st
	room.ready = {}
	room.pending = NO_MOVE
	var seats := _seats_public(room)
	for i in 4:
		var peer: int = room.seats[i].peer
		if peer != 0:
			# Cada jugador recibe solo sus propias fichas.
			_to(peer, "cl_event", [{"type": "hand_start", "you": i, "hand": st.hands[i].duplicate(),
					"starter": room.starter, "opening": opening, "scores": room.scores.duplicate(),
					"hand_no": room.hand_no, "seats": seats, "difficulty": room.difficulty}])
	# Tiempo para la animación de revolver y repartir.
	await _pause(5.2)
	while not st.is_over() and not room.dead:
		var seat := st.turn
		# Se limpia antes de avisar del turno: el anfitrión recibe el aviso al
		# instante y su respuesta puede llegar antes de la línea siguiente.
		room.pending = NO_MOVE
		_broadcast(room, {"type": "turn", "seat": seat})
		var moves: Array = st.legal_moves(seat)
		var move := -1
		if room.seats[seat].peer != 0:
			while room.pending == NO_MOVE and room.seats[seat].peer != 0 and not room.dead:
				await get_tree().process_frame
			if room.dead:
				return
			move = room.pending
			room.pending = NO_MOVE
		if move == NO_MOVE or room.seats[seat].peer == 0:
			# Asiento de CPU, o el jugador se fue en mitad de su turno.
			if moves.is_empty():
				move = -1
				await _pause(0.5)
			else:
				move = await _cpu_move(st, seat, room.difficulty)
		if room.dead:
			return
		if move < 0:
			st.apply_pass()
			_broadcast(room, {"type": "pass", "seat": seat})
			await _pause(1.0)
		else:
			st.apply_move(move)
			_broadcast(room, {"type": "move", "seat": seat, "move": move})
			await _pause(0.85)
	if room.dead:
		return
	var res := st.result()
	if res.team >= 0:
		room.scores[res.team] += res.points
		room.starter = res.winner
	var hands: Array = []
	for i in 4:
		hands.append(st.hands[i].duplicate())
	_broadcast(room, {"type": "hand_end", "hands": hands, "out": st.out_player, "blocked": st.blocked,
			"scores": room.scores.duplicate()})
	if dedicated:
		print("[sala %s] mano %d: equipo %d +%d -> %s" % [room.code, room.hand_no, res.team, res.points, str(room.scores)])
	if room.scores[0] >= TARGET_SCORE or room.scores[1] >= TARGET_SCORE:
		return
	# Espera a que todos pulsen "Siguiente mano" (con un límite por si alguien no lo hace).
	var t0 := Time.get_ticks_msec()
	while not room.dead and not _all_ready(room) and Time.get_ticks_msec() - t0 < 45000:
		await get_tree().process_frame


func _all_ready(room: Dictionary) -> bool:
	for seat: Dictionary in room.seats:
		if seat.peer != 0 and not room.ready.has(seat.peer):
			return false
	return true


func _cpu_move(st: State, seat: int, difficulty: int) -> int:
	var copy: State = st.clone()
	var box := [-1]
	var seed_value := _rng.randi()
	var t0 := Time.get_ticks_msec()
	var task := WorkerThreadPool.add_task(func() -> void: box[0] = AI.choose(copy, seat, difficulty, seed_value))
	while not WorkerThreadPool.is_task_completed(task):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	var spent := (Time.get_ticks_msec() - t0) / 1000.0
	if spent < 0.8:
		await _pause(0.8 - spent)
	return box[0]
