extends Control
## Pantalla "Jugar con amigos": crear o unirse a una sala (en la misma wifi o a
## distancia) y, ya dentro, elegir asiento y empezar.

signal back
signal start_game

const Settings = preload("res://scripts/settings.gd")
const Table = preload("res://scripts/table.gd")
const FancyButton = preload("res://scripts/fancy_button.gd")
const Net = preload("res://scripts/net.gd")
const OnlineConfig = preload("res://scripts/online_config.gd")

const GOLD := Color(1.0, 0.84, 0.3)
const CREAM := Color(0.97, 0.93, 0.82)
const BLUE := Color(0.2, 0.45, 0.85)
const RED := Color(0.8, 0.22, 0.2)
const GREEN := Color(0.25, 0.62, 0.3)
const BROWN := Color(0.45, 0.33, 0.22)
const DIFF_NAMES := ["Fácil", "Intermedio", "Difícil"]
const REMOTE_WAIT := "Conectando… Si el servidor estaba dormido puede tardar un minuto."
## Posición de los asientos en la sala, vistos desde el mío: abajo, derecha, arriba, izquierda.
const SEAT_RECTS := [Rect2(210, 690, 300, 120), Rect2(380, 510, 310, 120), Rect2(210, 330, 300, 120), Rect2(30, 510, 310, 120)]

var sfx: Node
var net: Net
## Mensaje a mostrar al abrir (por ejemplo, "se perdió la conexión").
var notice := ""

var _entry: Control
var _lobby: Control
var _name: LineEdit
var _ip: LineEdit
var _server: LineEdit
var _code: LineEdit
var _status: Label
var _lan_list: Control
var _lobby_title: Label
var _lobby_hint: Label
var _seat_btns: Array = []
var _diff_btn: FancyButton
var _start_btn: FancyButton
var _wait_lbl: Label
var _started := false


func _ready() -> void:
	size = Vector2(720, 1280)
	add_child(Table.new())
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.02, 0.0, 0.62)
	shade.position = Vector2(-1500, -1500)
	shade.size = Vector2(4280, 3720)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_build_entry()
	_build_lobby()
	_status = _label(self, "", 22, Color(1.0, 0.7, 0.4), Rect2(30, 1060, 660, 64))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var exit_btn := _button(self, "Volver", BROWN, Rect2(215, 1140, 290, 70), 26)
	exit_btn.pressed.connect(_leave)

	net.room_changed.connect(_on_room)
	net.failed.connect(_on_failed)
	net.closed.connect(_on_failed.bind("Se perdió la conexión con la sala."))
	net.lan_changed.connect(_refresh_lan)
	net.game_event.connect(_on_game_event)
	_status.text = notice
	if net.room_info.is_empty():
		_show_entry()
	else:
		_on_room(net.room_info)


func _exit_tree() -> void:
	net.listen_lan(false)


func _process(_delta: float) -> void:
	# Sube la pantalla para que el teclado del teléfono no tape el campo en uso.
	var shift := 0.0
	var focus := get_viewport().gui_get_focus_owner()
	var keyboard := 0
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		keyboard = DisplayServer.virtual_keyboard_get_height()
	if focus is LineEdit and keyboard > 0:
		var view := get_viewport().get_visible_rect().size
		var keyboard_units := keyboard * view.y / maxf(DisplayServer.window_get_size().y, 1.0)
		var visible_bottom := view.y - keyboard_units - get_viewport().canvas_transform.origin.y
		var field: LineEdit = focus
		var field_bottom := field.global_position.y - position.y + field.size.y + 20.0
		shift = minf(0.0, visible_bottom - field_bottom)
	position.y = lerpf(position.y, shift, 0.3)


# ------------------------------------------------------------------- vista: entrar

func _build_entry() -> void:
	_entry = Control.new()
	add_child(_entry)
	_label(_entry, "Jugar con amigos", 46, GOLD, Rect2(0, 90, 720, 64))
	_label(_entry, "Tu nombre", 22, CREAM, Rect2(60, 176, 600, 30), HORIZONTAL_ALIGNMENT_LEFT)
	_name = _field(_entry, Rect2(60, 208, 600, 66), "Escribe tu nombre", Settings.profile.name, 12)

	# La wifi y la sala en línea van en bloques aparte: en el navegador no se
	# puede abrir una sala en la red local, así que ese bloque se oculta.
	var wifi := Control.new()
	_entry.add_child(wifi)
	var remote := Control.new()
	_entry.add_child(remote)
	if OS.has_feature("web"):
		wifi.visible = false
		remote.position.y = -470.0
	_label(wifi, "En la misma wifi", 26, GOLD, Rect2(60, 300, 600, 36), HORIZONTAL_ALIGNMENT_LEFT)
	var host_btn := _button(wifi, "Crear sala", GREEN, Rect2(60, 344, 600, 80), 30)
	host_btn.pressed.connect(_host_lan)
	_lan_list = Control.new()
	_lan_list.position = Vector2(60, 440)
	wifi.add_child(_lan_list)
	_ip = _field(wifi, Rect2(60, 700, 390, 66), "IP del anfitrión", "", 40)
	var ip_btn := _button(wifi, "Unirse", BLUE, Rect2(466, 700, 194, 66), 26)
	ip_btn.pressed.connect(func() -> void: _join(_ip.text, ""))

	_label(remote, "En línea (a distancia)", 26, GOLD, Rect2(60, 800, 600, 36), HORIZONTAL_ALIGNMENT_LEFT)
	_server = _field(remote, Rect2(60, 842, 600, 66), "Dirección del servidor", Settings.profile.server, 120)
	# Con la dirección del servidor incorporada en el juego no se pide: uno
	# crea la sala y los demás solo escriben el código.
	var built_in := OnlineConfig.SERVER_URL != ""
	_server.visible = not built_in
	var y := 846.0 if built_in else 924.0
	var create_btn := _button(remote, "Crear sala en línea", GREEN, Rect2(60, y, 600, 80), 30)
	create_btn.pressed.connect(_create_remote)
	_code = _field(remote, Rect2(60, y + 96.0, 290, 76), "Código de la sala", Settings.profile.last_code, 4)
	_code.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var join_btn := _button(remote, "Unirse", BLUE, Rect2(366, y + 96.0, 294, 76), 28)
	join_btn.pressed.connect(_join_remote)
	if not built_in:
		# Sin dirección incorporada hace falta una línea más: la pantalla se compacta.
		create_btn.size.y = 60
		_code.position.y = y + 68.0
		_code.size.y = 60
		join_btn.position.y = y + 68.0
		join_btn.size.y = 60


func _show_entry() -> void:
	_entry.visible = true
	_lobby.visible = false
	_started = false
	net.listen_lan(true)
	_refresh_lan()


func _refresh_lan() -> void:
	for c in _lan_list.get_children():
		c.queue_free()
	if net.lan_rooms.is_empty():
		_label(_lan_list, "Buscando salas en tu wifi…\nSi no aparece, escribe la IP que ve el anfitrión.", 20,
				Color(CREAM, 0.75), Rect2(0, 0, 600, 70))
		return
	var i := 0
	for ip: String in net.lan_rooms.keys():
		if i >= 3:
			break
		var info: Dictionary = net.lan_rooms[ip]
		var b := _button(_lan_list, "Sala de %s  ·  %d/4  ·  Unirse" % [info.name, info.players], BLUE,
				Rect2(0, i * 80.0, 600, 68), 24)
		b.pressed.connect(_join.bind(ip, ""))
		i += 1


func _player_name() -> String:
	var n := _name.text.strip_edges()
	if n == "":
		n = "Jugador"
	Settings.profile.name = n
	Settings.profile.server = _server.text.strip_edges()
	Settings.save()
	return n


## Servidor a distancia: el incorporado en el juego o, si no hay, el escrito a mano.
func _server_address() -> String:
	return OnlineConfig.SERVER_URL if OnlineConfig.SERVER_URL != "" else _server.text


func _host_lan() -> void:
	_status.text = ""
	net.listen_lan(false)
	if not net.host_lan(_player_name(), Settings.my_look(), 1, Settings.player_token()):
		net.listen_lan(true)


func _create_remote() -> void:
	_status.text = REMOTE_WAIT
	net.listen_lan(false)
	net.create_remote(_server_address(), _player_name(), Settings.my_look(), 1, Settings.player_token())


func _join_remote() -> void:
	if _code.text.strip_edges() == "":
		_status.text = "Escribe el código de la sala."
		return
	_join(_server_address(), _code.text)


func _join(address: String, code: String) -> void:
	_status.text = "Conectando…" if code.strip_edges() == "" else REMOTE_WAIT
	net.listen_lan(false)
	net.join(address, code, _player_name(), Settings.my_look(), Settings.player_token())


# -------------------------------------------------------------------- vista: sala

func _build_lobby() -> void:
	_lobby = Control.new()
	_lobby.visible = false
	add_child(_lobby)
	_lobby_title = _label(_lobby, "", 44, GOLD, Rect2(0, 100, 720, 60))
	_lobby_hint = _label(_lobby, "", 22, CREAM, Rect2(40, 168, 640, 120))
	_lobby_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for v in 4:
		var b := _button(_lobby, "", BLUE if v % 2 == 0 else RED, SEAT_RECTS[v], 24)
		b.pressed.connect(_sit.bind(v))
		_seat_btns.append(b)
	_label(_lobby, "Azul: tu pareja  ·  Rojo: los rivales", 20, Color(CREAM, 0.8), Rect2(0, 826, 720, 30))
	_diff_btn = _button(_lobby, "", BROWN, Rect2(160, 872, 400, 70), 24)
	_diff_btn.pressed.connect(_cycle_difficulty)
	_start_btn = _button(_lobby, "Empezar partida", GREEN, Rect2(110, 958, 500, 88), 32)
	_start_btn.pressed.connect(func() -> void: net.send("sv_start"))
	_wait_lbl = _label(_lobby, "Esperando a que el anfitrión empiece…", 24, CREAM, Rect2(0, 972, 720, 60))


func _on_room(info: Dictionary) -> void:
	_entry.visible = false
	_lobby.visible = true
	_status.text = ""
	net.listen_lan(false)
	var lan: bool = info.code == Net.LAN_CODE
	if not lan and Settings.profile.last_code != info.code:
		# Se recuerda la sala: si me salgo sin querer, el código ya está escrito para volver.
		Settings.profile.last_code = info.code
		Settings.save()
	_lobby_title.text = "Sala en tu wifi" if lan else "Código:  %s" % info.code
	if not lan:
		_lobby_hint.text = "Pasa este código a tus amigos.\nSolo tienen que escribirlo y pulsar Unirse."
	elif info.host:
		_lobby_hint.text = "Tus amigos la verán en \"Salas encontradas\".\nSi no, que escriban esta IP: %s" % ", ".join(PackedStringArray(Net.local_ips()))
	else:
		_lobby_hint.text = "Toca un asiento de CPU para cambiarte de sitio."
	var you: int = info.you
	for v in 4:
		var seat: Dictionary = info.seats[(v + you) % 4]
		var b: FancyButton = _seat_btns[v]
		if v == 0:
			b.text = "%s\n(tú)" % seat.name
		elif seat.human:
			b.text = seat.name
		else:
			b.text = "CPU\ntoca para sentarte"
	_diff_btn.text = "Nivel de las CPU: %s" % DIFF_NAMES[info.difficulty]
	_diff_btn.disabled = not info.host
	_start_btn.visible = info.host
	_wait_lbl.visible = not info.host


func _cycle_difficulty() -> void:
	if not net.room_info.is_empty():
		net.send("sv_difficulty", [(int(net.room_info.difficulty) + 1) % 3])


func _sit(v: int) -> void:
	if v != 0 and not net.room_info.is_empty():
		net.send("sv_sit", [(v + int(net.room_info.you)) % 4])


func _on_game_event() -> void:
	# El primer evento de una partida es el reparto (o, si vuelvo a una partida
	# en marcha, su estado actual): se pasa a la mesa.
	if not _started and not net.events.is_empty() and net.events[0].type in ["hand_start", "resume"]:
		_started = true
		start_game.emit()


func _on_failed(message: String) -> void:
	_show_entry()
	_status.text = message


func _leave() -> void:
	_click()
	if _lobby.visible:
		net.leave()
		_show_entry()
	else:
		back.emit()


# ----------------------------------------------------------------------- piezas

func _click() -> void:
	if sfx != null:
		sfx.play("click")


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
	b.pressed.connect(_click)
	return b


func _field(parent: Node, rect: Rect2, placeholder: String, text: String, max_length: int) -> LineEdit:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.05, 0.03, 0.92)
	sb.border_color = Color(0.85, 0.65, 0.3, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	var le := LineEdit.new()
	le.add_theme_stylebox_override("normal", sb)
	le.add_theme_stylebox_override("focus", sb)
	le.add_theme_font_size_override("font_size", 26)
	le.add_theme_color_override("font_color", CREAM)
	le.add_theme_color_override("font_placeholder_color", Color(CREAM, 0.4))
	le.placeholder_text = placeholder
	le.text = text
	le.max_length = max_length
	le.position = rect.position
	le.size = rect.size
	parent.add_child(le)
	return le
