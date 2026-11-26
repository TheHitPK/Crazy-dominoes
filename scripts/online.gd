extends Control
## Pantalla "Jugar con amigos": crear o unirse a una sala en el servidor, ver
## las salas públicas y, ya dentro, elegir asiento y empezar. (La sala por wifi
## sigue en net.gd para las pruebas por argumentos, pero ya no sale aquí.)
##
## Tres vistas: entrar (_entry), salas públicas (_public) y sala (_lobby).
## Medidas y colores salen de ui_theme.gd.

signal back
signal start_game

const Settings = preload("res://scripts/settings.gd")
const Table = preload("res://scripts/table.gd")
const FancyButton = preload("res://scripts/fancy_button.gd")
const Net = preload("res://scripts/net.gd")
const OnlineConfig = preload("res://scripts/online_config.gd")
const UI = preload("res://scripts/ui_theme.gd")
const UISkin = preload("res://scripts/ui_skin.gd")
const Chat = preload("res://scripts/chat.gd")
const SignalMeter = preload("res://scripts/signal_meter.gd")
const State = preload("res://scripts/domino_state.gd")
const RankedPanel = preload("res://scripts/ranked_panel.gd")
const ProfilePanel = preload("res://scripts/profile_panel.gd")
const Avatar = preload("res://scripts/avatar.gd")

const DIFF_NAMES := ["Fácil", "Intermedio", "Difícil"]
const REMOTE_WAIT := "Conectando… Si el servidor estaba dormido puede tardar un minuto."
## Asientos de la sala, vistos desde el mío: abajo, derecha, arriba, izquierda.
const SEAT_RECTS := [Rect2(210, 690, 300, 124), Rect2(380, 520, 310, 124), Rect2(210, 350, 300, 124), Rect2(30, 520, 310, 124)]
## Cada cuánto se vuelve a pedir la lista de salas públicas mientras se mira.
const PUBLIC_REFRESH := 4.0
const PUBLIC_MAX := 6

var sfx: Node
var net: Net
## Mensaje a mostrar al abrir (por ejemplo, "se perdió la conexión").
var notice := ""
## Abrir directamente la pantalla del ranked (botón Ranked del menú, o al
## volver de una partida de ranked).
var start_ranked := false
## Pruebas: dirección del servidor en lugar de la de Render (--server-addr).
static var server_override := ""
var _ranked_panel: RankedPanel

var _entry: Control
var _public: Control
var _lobby: Control
var _code: LineEdit
var _me_avatar: Avatar
var _me_name: Label
var _profile: ProfilePanel
var _status: Label
var _public_list: Control
var _public_timer := 0.0
var _public_waiting := false
var _lobby_title: Label
var _lobby_hint: Label
var _visibility_btn: FancyButton
var _visibility_lbl: Label
var _seat_btns: Array = []
var _diff_btn: FancyButton
var _mode_btn: FancyButton
var _target_btn: FancyButton
var _start_btn: FancyButton
var _wait_lbl: Label
var _started := false
## Crear la sala ya como pública (desde la lista de salas públicas).
var _want_public := false
## Al crear una sala se le pone el modo y la meta del menú (una vez; luego manda el anfitrión).
var _want_rules := false
var _chat: Chat
var _chat_btn: FancyButton
var _invite_btn: FancyButton
var _unread := 0


func _ready() -> void:
	size = Vector2(720, 1280)
	add_child(Table.new())
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.02, 0.0, 0.66)
	shade.position = Vector2(-1500, -1500)
	shade.size = Vector2(4280, 3720)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_build_entry()
	_build_public()
	_build_lobby()
	_status = _label(self, "", UI.CAPTION, UI.WARN, Rect2(40, 1000, 640, 84))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var exit_btn := _button(self, "Volver", UI.NEUTRAL, Rect2(215, 1100, 290, UI.TOUCH), UI.BUTTON)
	exit_btn.pressed.connect(_leave)

	net.room_changed.connect(_on_room)
	net.failed.connect(_on_failed)
	net.closed.connect(_on_failed.bind("Se perdió la conexión con la sala."))
	net.game_event.connect(_on_game_event)
	net.public_rooms.connect(_on_public_rooms)
	net.chat_message.connect(_on_chat)
	_chat = Chat.new()
	_chat.net = net
	_chat.sfx = sfx
	_chat.top = Table.pad
	add_child(_chat)
	_status.text = notice
	_ranked_panel = RankedPanel.new()
	_ranked_panel.net = net
	_ranked_panel.sfx = sfx
	add_child(_ranked_panel)
	# El perfil va encima de todo (también del botón Volver).
	move_child(_profile, -1)
	_ranked_panel.closed.connect(func() -> void:
		net.ranked_mode = false
		net.leave()
		back.emit())
	if start_ranked:
		# La sala de la partida de ranked ya se cerró en el servidor.
		net.room_info = {}
		for v in [_entry, _public, _lobby]:
			v.visible = false
		_ranked_panel.start(_server_address(), _player_name())
	elif net.room_info.is_empty():
		_show(_entry)
	else:
		_on_room(net.room_info)


func _exit_tree() -> void:
	net.listen_lan(false)


func _process(delta: float) -> void:
	# Mientras se mira la lista de salas públicas, se refresca sola.
	if _public.visible and not _public_waiting:
		_public_timer -= delta
		if _public_timer <= 0.0:
			_request_public()
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


func _show(view: Control) -> void:
	if _chat != null and view != _lobby:
		_chat.close()
	for v in [_entry, _public, _lobby]:
		v.visible = v == view
	if view == _entry:
		_started = false


# ------------------------------------------------------------------- vista: entrar

## Todo va al servidor de Render (OnlineConfig.SERVER_URL, dentro del juego):
## crear sala, ver las públicas o entrar con un código. El nombre sale del
## perfil, no se escribe aquí.
func _build_entry() -> void:
	_entry = Control.new()
	add_child(_entry)
	UISkin.title(_label(_entry, "Jugar con amigos", UI.TITLE, UI.GOLD, Rect2(0, 64, 720, 70)))

	# Quién soy: avatar, nombre y "Cambiar" (abre el perfil).
	var me := Panel.new()
	me.add_theme_stylebox_override("panel", UISkin.field_box())
	me.position = Vector2(60, 156)
	me.size = Vector2(600, 104)
	_entry.add_child(me)
	_me_avatar = Avatar.new()
	_me_avatar.position = Vector2(16, 14)
	_me_avatar.size = Vector2(76, 76)
	_me_avatar.ring = UI.GOLD
	me.add_child(_me_avatar)
	_label(me, "Juegas como", UI.CAPTION, UI.LABEL, Rect2(110, 10, 300, 36), HORIZONTAL_ALIGNMENT_LEFT)
	_me_name = _label(me, "", UI.BODY, UI.CREAM, Rect2(110, 46, 290, 48), HORIZONTAL_ALIGNMENT_LEFT)
	_me_name.add_theme_font_override("font", UISkin.heavy())
	var edit := _button(me, "Cambiar", UI.NEUTRAL, Rect2(416, 22, 168, 60), 26)
	edit.pressed.connect(func() -> void: _profile.open())
	_profile = ProfilePanel.new()
	_profile.show_customize = false
	_profile.sfx = sfx
	add_child(_profile)
	_profile.closed.connect(_refresh_me)
	_refresh_me()

	# Tarjeta con las tres formas de jugar, con el marco de las del menú.
	var card := Panel.new()
	card.position = Vector2(40, 290)
	card.size = Vector2(640, 680)
	_entry.add_child(card)
	UISkin.dress(card)
	var head := _label(card, "Sala privada", 40, UI.CREAM, Rect2(0, 22, 640, 60))
	_title_style(head)
	_label(card, "Crea la sala y pasa el código a tus amigos.", UI.CAPTION, UI.CREAM_MUTED, Rect2(40, 84, 560, 40))
	var create_btn := _button(card, "Crear sala", UI.PRIMARY, Rect2(50, 132, 540, 96), UI.BUTTON + 4)
	create_btn.set_icon("smile", 50)
	create_btn.pressed.connect(_create_remote.bind(false))

	_label(card, "¿Te pasaron un código?", UI.CAPTION, UI.LABEL, Rect2(50, 252, 540, 40), HORIZONTAL_ALIGNMENT_LEFT)
	_code = _field(card, Rect2(50, 296, 250, 90), "Código", Settings.profile.last_code, 4)
	_code.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code.add_theme_font_size_override("font_size", UI.TITLE)
	_code.add_theme_font_override("font", UISkin.heavy())
	var join_btn := _button(card, "Unirse", UI.SECONDARY, Rect2(316, 296, 274, 90), UI.BUTTON + 2)
	join_btn.set_icon("share", 44)
	join_btn.pressed.connect(_join_remote)

	var sep := ColorRect.new()
	sep.color = Color(UI.GOLD, 0.35)
	sep.position = Vector2(50, 420)
	sep.size = Vector2(540, 2)
	card.add_child(sep)
	var pub := _label(card, "Salas públicas", 34, UI.CREAM, Rect2(0, 436, 640, 52))
	_title_style(pub)
	_label(card, "Entra en una sala abierta con jugadores de todas partes.", UI.CAPTION, UI.CREAM_MUTED,
			Rect2(40, 488, 560, 64))
	var list_btn := _button(card, "Ver salas públicas", UI.ACCENT, Rect2(50, 560, 540, 90), UI.BUTTON)
	list_btn.set_icon("globe", 46)
	list_btn.pressed.connect(_open_public)


## Letra de los títulos de las tarjetas del menú (mode_carousel.gd).
func _title_style(lb: Label) -> void:
	lb.add_theme_font_override("font", UISkin.serif())
	lb.add_theme_color_override("font_outline_color", UISkin.TITLE_OUTLINE)
	lb.add_theme_constant_override("outline_size", 6)
	lb.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	lb.add_theme_constant_override("shadow_offset_y", 3)


func _refresh_me() -> void:
	_me_name.text = Settings.player_name()
	Settings.apply_avatar(_me_avatar)


func _player_name() -> String:
	return Settings.player_name()


## Servidor en línea: el incorporado en el juego (o el de pruebas, --server-addr).
func _server_address() -> String:
	if server_override != "":
		return server_override
	return OnlineConfig.SERVER_URL if OnlineConfig.SERVER_URL != "" else str(Settings.profile.server)


## Crea una sala en línea: privada (solo con código) o, desde la lista, pública.
func _create_remote(public: bool) -> void:
	_want_public = public
	_want_rules = true
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


# ------------------------------------------------------------ vista: salas públicas

func _build_public() -> void:
	_public = Control.new()
	_public.visible = false
	add_child(_public)
	UISkin.title(_label(_public, "Salas públicas", UI.TITLE, UI.GOLD, Rect2(0, 64, 720, 70)))
	_label(_public, "Salas abiertas que esperan jugadores.\nToca una para entrar.", UI.CAPTION, UI.CREAM_MUTED,
			Rect2(40, 140, 640, 80))
	_public_list = Control.new()
	_public_list.position = Vector2(60, 236)
	_public.add_child(_public_list)
	var refresh := _button(_public, "Actualizar", UI.NEUTRAL, Rect2(60, 900, 290, UI.TOUCH), UI.BUTTON)
	refresh.pressed.connect(_request_public)
	var create := _button(_public, "Crear pública", UI.PRIMARY, Rect2(370, 900, 290, UI.TOUCH), UI.BUTTON)
	create.pressed.connect(_create_remote.bind(true))


func _open_public() -> void:
	_player_name()
	_status.text = REMOTE_WAIT
	_show(_public)
	_fill_public([], "Buscando salas…")
	_request_public()


func _request_public() -> void:
	_public_waiting = true
	_public_timer = PUBLIC_REFRESH
	net.browse(_server_address())
	# Si el servidor aún no tiene salas públicas (versión vieja) no contesta: se deja de esperar.
	get_tree().create_timer(10.0).timeout.connect(func() -> void:
		if _public_waiting and _public.visible:
			_public_waiting = false
			_status.text = ""
			_fill_public([], "No hay salas públicas abiertas ahora mismo."))


func _on_public_rooms(list: Array) -> void:
	_public_waiting = false
	_status.text = ""
	if _public.visible:
		_fill_public(list, "No hay salas públicas abiertas ahora mismo.\n¡Crea una y que entren otros!")


func _fill_public(list: Array, empty_text: String) -> void:
	for c in _public_list.get_children():
		c.queue_free()
	if list.is_empty():
		_label(_public_list, empty_text, UI.BODY, UI.CREAM_MUTED, Rect2(0, 120, 600, 160))
		return
	var i := 0
	for room: Dictionary in list:
		if i >= PUBLIC_MAX:
			break
		var text := "Sala de %s  ·  %d/4  ·  %s" % [room.host, room.players, DIFF_NAMES[clampi(room.difficulty, 0, 2)]]
		if room.has("mode"):
			text = "Sala de %s  ·  %d/4\n%s  ·  %s  ·  a %d" % [room.host, room.players,
					DIFF_NAMES[clampi(room.difficulty, 0, 2)],
					State.MODE_NAMES[clampi(int(room.mode), 0, State.MODE_NAMES.size() - 1)], int(room.target)]
		var b := _button(_public_list, text, UI.SECONDARY, Rect2(0, i * (UI.TOUCH + 14.0), 600, UI.TOUCH), UI.CAPTION + 2)
		b.pressed.connect(_join.bind(_server_address(), str(room.code)))
		i += 1


# -------------------------------------------------------------------- vista: sala

func _build_lobby() -> void:
	_lobby = Control.new()
	_lobby.visible = false
	add_child(_lobby)
	_lobby_title = _label(_lobby, "", UI.TITLE, UI.GOLD, Rect2(0, 60, 720, 70))
	UISkin.title(_lobby_title)
	_lobby_hint = _label(_lobby, "", UI.CAPTION, UI.CREAM_MUTED, Rect2(40, 134, 640, 96))
	_lobby_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_visibility_btn = _button(_lobby, "", UI.SWITCH_OFF, Rect2(80, 238, 560, UI.TOUCH_SMALL), UI.CAPTION + 2)
	_visibility_btn.pressed.connect(func() -> void: net.set_public(not net.room_info.get("public", false)))
	_visibility_lbl = _label(_lobby, "", UI.CAPTION, UI.CREAM_MUTED, Rect2(40, 238, 640, UI.TOUCH_SMALL))
	for v in 4:
		var b := _button(_lobby, "", UI.TEAM_US if v % 2 == 0 else UI.TEAM_THEM, SEAT_RECTS[v], UI.CAPTION)
		b.pressed.connect(_sit.bind(v))
		_seat_btns.append(b)
	# Nivel, modo y meta: el anfitrión los cambia tocando; los demás solo los ven.
	_diff_btn = _button(_lobby, "", UI.NEUTRAL, Rect2(40, 838, 206, UI.TOUCH_SMALL), UI.CAPTION)
	_diff_btn.pressed.connect(_cycle_difficulty)
	_mode_btn = _button(_lobby, "", UI.NEUTRAL, Rect2(257, 838, 206, UI.TOUCH_SMALL), UI.CAPTION)
	_mode_btn.pressed.connect(_cycle_rule.bind("mode"))
	_target_btn = _button(_lobby, "", UI.NEUTRAL, Rect2(474, 838, 206, UI.TOUCH_SMALL), UI.CAPTION)
	_target_btn.pressed.connect(_cycle_rule.bind("target"))
	_start_btn = _button(_lobby, "Empezar partida", UI.PRIMARY, Rect2(110, 936, 500, 96), 38)
	_start_btn.pressed.connect(func() -> void: net.send("sv_start"))
	_wait_lbl = _label(_lobby, "Esperando a que el anfitrión empiece…", UI.BODY, UI.CREAM, Rect2(0, 950, 720, 70))
	_chat_btn = _button(_lobby, "Chat", UI.ACCENT, Rect2(530, 1100, 160, UI.TOUCH), UI.BUTTON)
	# Invitar: abre WhatsApp con el código de la sala y el enlace del juego.
	_invite_btn = _button(_lobby, "Invitar por WhatsApp", Color(0.15, 0.68, 0.38), Rect2(30, 1100, 480, UI.TOUCH), 28)
	_invite_btn.set_icon("share", 40)
	_invite_btn.pressed.connect(_invite)
	_chat_btn.pressed.connect(_open_chat)
	var meter: SignalMeter = SignalMeter.new()
	meter.net = net
	meter.name = "Meter"
	meter.position = Vector2(560, 20)
	meter.size = Vector2(140, 28)
	_lobby.add_child(meter)


func _invite() -> void:
	var code := str(net.room_info.get("code", ""))
	var text := "¡Juega dominó conmigo en Crazy Dominoes! Entra en %s, pulsa En línea y escribe el código %s" % [
			OnlineConfig.WEB_URL, code]
	OS.shell_open("https://wa.me/?text=" + text.uri_encode())


func _on_room(info: Dictionary) -> void:
	if info.get("ranked", false):
		# Partida de ranked encontrada: no hay sala de espera, empieza sola.
		_ranked_panel.visible = false
		_status.text = "¡Partida encontrada!"
		return
	_show(_lobby)
	_lobby.get_node("Meter").visible = net.online and not net.serving
	_status.text = ""
	net.listen_lan(false)
	var lan: bool = info.code == Net.LAN_CODE
	if not lan and Settings.profile.last_code != info.code:
		# Se recuerda la sala: si me salgo sin querer, el código ya está escrito para volver.
		Settings.profile.last_code = info.code
		Settings.save()
	if _want_public and info.host and not lan:
		_want_public = false
		net.set_public(true)
	if _want_rules and info.host and info.has("mode"):
		# La sala que creo empieza con el modo y la meta elegidos en el menú.
		_want_rules = false
		if int(info.mode) != Settings.rules.mode or int(info.target) != Settings.rules.target:
			# Un modo solo contra la CPU (Cincos) se juega en red como Clásico.
			net.set_rules(Settings.rules.mode if Settings.rules.mode < State.NET_MODES else State.CLASSIC,
					Settings.rules.target)
	var public: bool = info.get("public", false)
	_lobby_title.text = "Sala en tu wifi" if lan else "Código:  %s" % info.code
	_invite_btn.visible = not lan
	if not lan:
		_lobby_hint.text = "Pasa este código a tus amigos: solo tienen que escribirlo y pulsar Unirse."
	elif info.host:
		_lobby_hint.text = "Tus amigos la verán en su lista. Si no, que escriban esta IP: %s" % ", ".join(PackedStringArray(Net.local_ips()))
	else:
		_lobby_hint.text = "Toca un asiento de CPU para cambiarte de sitio."
	# Pública o privada: el anfitrión lo cambia; los demás solo lo ven.
	_visibility_btn.visible = info.host and not lan
	_visibility_lbl.visible = not info.host and not lan
	var vis_text := "Pública: sale en la lista" if public else "Privada: solo con código"
	_visibility_btn.text = vis_text + "  (cambiar)"
	_visibility_btn.set_color(UI.ACCENT if public else UI.SWITCH_OFF)
	_visibility_lbl.text = "Sala " + vis_text.to_lower()
	var you: int = info.you
	for v in 4:
		var seat: Dictionary = info.seats[(v + you) % 4]
		var b: FancyButton = _seat_btns[v]
		# El papel va escrito, no solo en el color del asiento.
		var role := "Tú" if v == 0 else ("Tu pareja" if v == 2 else "Rival")
		if v == 0:
			b.text = "%s\n%s" % [seat.name, role]
		elif seat.human:
			b.text = "%s\n%s" % [seat.name, role]
		else:
			b.text = "CPU · %s\nToca para sentarte" % role
	_diff_btn.text = "CPU\n%s" % DIFF_NAMES[info.difficulty]
	_diff_btn.disabled = not info.host
	# Un servidor anterior a los modos no los manda: solo hay clásico a 100.
	var modes: bool = info.has("mode")
	_mode_btn.visible = modes
	_target_btn.visible = modes
	_diff_btn.position.x = 40.0 if modes else 257.0
	if modes:
		_mode_btn.text = "Modo\n%s" % State.MODE_NAMES[clampi(int(info.mode), 0, State.MODE_NAMES.size() - 1)]
		_target_btn.text = "Meta\n%d puntos" % int(info.target)
		_mode_btn.disabled = not info.host
		_target_btn.disabled = not info.host
	_start_btn.visible = info.host
	_wait_lbl.visible = not info.host


func _open_chat() -> void:
	_unread = 0
	_chat_btn.text = "Chat"
	_chat.open()


func _on_chat(msg: Dictionary) -> void:
	if not _chat.visible and int(msg.seat) != int(net.room_info.get("you", -1)):
		_unread += 1
		_chat_btn.text = "Chat %d" % mini(_unread, 9)
		if sfx != null:
			sfx.play("click", 1.5)


func _cycle_difficulty() -> void:
	if not net.room_info.is_empty():
		net.send("sv_difficulty", [(int(net.room_info.difficulty) + 1) % 3])


func _cycle_rule(key: String) -> void:
	var info := net.room_info
	if info.is_empty() or not info.has("mode"):
		return
	var mode := int(info.mode)
	var target := int(info.target)
	if key == "mode":
		mode = (mode + 1) % State.NET_MODES
	else:
		target = State.TARGETS[(State.TARGETS.find(target) + 1) % State.TARGETS.size()]
	net.set_rules(mode, target)


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
	_show(_entry)
	_status.text = message


func _leave() -> void:
	_click()
	if _lobby.visible or _public.visible:
		net.leave()
		_status.text = ""
		_show(_entry)
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
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	var sb := UISkin.field_box(20.0)
	# El campo en uso se distingue con un borde dorado.
	var focus_sb := UISkin.field_focus_box(20.0)
	var le := LineEdit.new()
	le.add_theme_stylebox_override("normal", sb)
	le.add_theme_stylebox_override("focus", focus_sb)
	le.add_theme_font_size_override("font_size", UI.BODY)
	le.add_theme_color_override("font_color", UI.CREAM)
	le.add_theme_color_override("font_placeholder_color", Color(UI.CREAM, 0.5))
	le.placeholder_text = placeholder
	le.text = text
	le.max_length = max_length
	le.position = rect.position
	le.size = rect.size
	parent.add_child(le)
	return le
