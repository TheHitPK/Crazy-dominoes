extends Control
## Chat de la sala: emojis rápidos, frases hechas y texto libre. Se usa igual
## en la sala (online.gd) y en la mesa (game.gd); los mensajes pasan siempre
## por el servidor (net.gd), que los revisa y los reparte a todos.

signal sent

const FancyButton = preload("res://scripts/fancy_button.gd")
const UI = preload("res://scripts/ui_theme.gd")

enum { TEXT, EMOJI }
## Emojis de Twemoji (ver emoji/CREDITOS.txt): imágenes, para que se vean
## igual en todos los teléfonos y en la web.
const EMOJIS := [preload("res://emoji/1f602.png"), preload("res://emoji/1f60e.png"),
		preload("res://emoji/1f62e.png"), preload("res://emoji/1f621.png"), preload("res://emoji/1f62d.png"),
		preload("res://emoji/1f914.png"), preload("res://emoji/1f634.png"), preload("res://emoji/1f44d.png"),
		preload("res://emoji/1f44f.png"), preload("res://emoji/1f525.png"), preload("res://emoji/1f4aa.png"),
		preload("res://emoji/1f340.png")]
const PHRASES := ["¡Buena jugada!", "¡Apúrate!", "¡Capicúa!", "Gracias, pareja", "Mala suerte", "¡Revancha!"]
const MAX_LENGTH := 80
## Mínimo entre dos mensajes del mismo jugador (lo exige el servidor).
const GAP_MS := 700
## Mensajes que se guardan para verlos al abrir el chat.
const KEEP := 40
const W := 680.0
## Palabras que se tapan con asteriscos (en minúsculas y sin tildes). Las de 5
## letras o más tapan también sus variantes ("pendejos", "mierdero"); las
## cortas, solo la palabra o su plural, para no tapar palabras normales.
const BAD_WORDS := ["mierda", "coño", "verga", "puta", "puto", "marico", "marica", "maricon", "mamaguevo",
		"mamahuevo", "mamaguebo", "mmg", "mmgv", "guevon", "huevon", "webon", "gueva", "pendejo", "cabron",
		"malparido", "hijueputa", "gonorrea", "culo", "culero", "zorra", "perra", "pinga", "polla",
		"conchetumadre", "ctm", "hdp", "joder", "imbecil", "estupido", "fuck", "shit", "bitch", "nigga", "nigger"]
const LEET := {"0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "@": "a", "$": "s",
		"á": "a", "é": "e", "í": "i", "ó": "o", "ú": "u", "ü": "u"}

var net: Node
var sfx: Node
## Alto de diseño que gana un teléfono por arriba (Table.pad): el panel se pega
## al borde de arriba para que el teclado no lo tape.
var top := 0.0

var _panel: Panel
var _log: RichTextLabel
var _field: LineEdit
var _lines := 0
var _mute_row: Control


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.position = Vector2(-1500, -1500)
	shade.size = Vector2(4280, 3720)
	add_child(shade)
	# Tocar fuera del panel lo cierra.
	shade.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			close())

	var sb := StyleBoxFlat.new()
	sb.bg_color = UI.SURFACE
	sb.border_color = UI.GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(UI.RADIUS)
	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.position = Vector2(20, 24.0 - top)
	_panel.size = Vector2(W, 1046)
	_panel.pivot_offset = Vector2(W * 0.5, 0)
	add_child(_panel)

	var title := Label.new()
	title.text = "Chat de la sala"
	title.add_theme_font_size_override("font_size", UI.TITLE)
	title.add_theme_color_override("font_color", UI.GOLD)
	title.position = Vector2(24, 10)
	title.size = Vector2(500, 70)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_panel.add_child(title)
	var close_btn := _button("X", UI.NEUTRAL, Rect2(W - 104, 8, 84, 76), UI.BUTTON)
	close_btn.tooltip_text = "Cerrar"
	close_btn.pressed.connect(close)

	var log_sb := StyleBoxFlat.new()
	log_sb.bg_color = Color(0, 0, 0, 0.3)
	log_sb.set_corner_radius_all(UI.RADIUS)
	log_sb.set_content_margin_all(14)
	_log = RichTextLabel.new()
	_log.add_theme_stylebox_override("normal", log_sb)
	_log.add_theme_font_size_override("normal_font_size", UI.CAPTION)
	_log.add_theme_font_size_override("bold_font_size", UI.CAPTION)
	_log.add_theme_color_override("default_color", UI.CREAM)
	_log.scroll_following = true
	_log.position = Vector2(20, 92)
	_log.size = Vector2(W - 40, 290)
	_panel.add_child(_log)

	var field_sb := StyleBoxFlat.new()
	field_sb.bg_color = UI.SURFACE_SOFT
	field_sb.border_color = UI.BORDER
	field_sb.set_border_width_all(2)
	field_sb.set_corner_radius_all(UI.RADIUS)
	field_sb.content_margin_left = 18
	field_sb.content_margin_right = 18
	var focus_sb := field_sb.duplicate() as StyleBoxFlat
	focus_sb.border_color = UI.GOLD
	focus_sb.set_border_width_all(4)
	_field = LineEdit.new()
	_field.add_theme_stylebox_override("normal", field_sb)
	_field.add_theme_stylebox_override("focus", focus_sb)
	_field.add_theme_font_size_override("font_size", UI.BODY)
	_field.add_theme_color_override("font_color", UI.CREAM)
	_field.add_theme_color_override("font_placeholder_color", Color(UI.CREAM, 0.5))
	_field.placeholder_text = "Escribe un mensaje"
	_field.max_length = MAX_LENGTH
	_field.position = Vector2(20, 396)
	_field.size = Vector2(W - 220, UI.TOUCH)
	_field.text_submitted.connect(func(_t: String) -> void: _send_text())
	_panel.add_child(_field)
	_button("Enviar", UI.PRIMARY, Rect2(W - 190, 396, 170, UI.TOUCH), UI.BUTTON).pressed.connect(_send_text)

	# Emojis: dos filas de seis.
	for i in EMOJIS.size():
		var b := _button("", UI.SURFACE_SOFT, Rect2(20 + (i % 6) * 108.0, 500 + (i / 6) * 96.0, 100, 88), 1)
		b.tooltip_text = "Emoji"
		var img := TextureRect.new()
		img.texture = EMOJIS[i]
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.position = Vector2(22, 14)
		img.size = Vector2(56, 56)
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(img)
		b.pressed.connect(_send.bind(EMOJI, str(i)))
	# Frases hechas: dos columnas.
	for i in PHRASES.size():
		var b := _button(PHRASES[i], UI.NEUTRAL, Rect2(20 + (i % 2) * 324.0, 700 + (i / 2) * 80.0, 316, 72), UI.CAPTION)
		b.pressed.connect(_send.bind(TEXT, PHRASES[i]))

	# Silenciar: un botón por cada persona de la sala (se rehace al abrir).
	_mute_row = Control.new()
	_mute_row.position = Vector2(20, 948)
	_panel.add_child(_mute_row)
	net.chat_message.connect(_add_line)
	for msg: Dictionary in net.chat_log:
		_add_line(msg)


func open() -> void:
	visible = true
	_fill_mute_row()
	_panel.scale = Vector2(0.9, 0.9)
	_panel.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.15)


## Botones "Silenciar" de las demás personas de la sala. Quien está silenciado
## no me aparece en el chat ni en bocadillos, y no veo su foto.
func _fill_mute_row() -> void:
	for c in _mute_row.get_children():
		c.queue_free()
	var x := 0.0
	var seats: Array = net.room_info.get("seats", [])
	for i in seats.size():
		var seat: Dictionary = seats[i]
		var who := str(seat.name)
		if not seat.human or who == "" or i == int(net.room_info.get("you", -1)):
			continue
		var on: bool = net.muted.has(who)
		var b: FancyButton = FancyButton.new()
		b.setup("%s\n%s" % [who, "Silenciado" if on else "Silenciar"], UI.DANGER if on else UI.NEUTRAL, 22)
		b.position = Vector2(x, 0)
		b.size = Vector2(204, 80)
		_mute_row.add_child(b)
		b.pressed.connect(func() -> void:
			net.set_muted(who, not on)
			_fill_mute_row())
		x += 216.0
	if x == 0.0:
		var lb := Label.new()
		lb.text = "Si alguien molesta, aquí podrás silenciarlo."
		lb.add_theme_font_size_override("font_size", UI.CAPTION)
		lb.add_theme_color_override("font_color", UI.CREAM_MUTED)
		lb.size = Vector2(W - 40, 80)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_mute_row.add_child(lb)


func close() -> void:
	_field.release_focus()
	visible = false


func _send_text() -> void:
	var text := _field.text.strip_edges()
	if text == "":
		return
	_field.text = ""
	_send(TEXT, text)


func _send(kind: int, text: String) -> void:
	if sfx != null:
		sfx.play("click")
	net.chat(kind, text)
	sent.emit()
	# Un emoji o una frase rápida se mandan y el chat se cierra solo, para
	# seguir jugando; tras escribir, queda abierto por si se sigue hablando.
	if kind == EMOJI or PHRASES.has(text):
		close()


## Añade un mensaje al historial: nombre en el color de su equipo y después el
## texto o el emoji. El texto se añade tal cual (sin BBCode).
func _add_line(msg: Dictionary) -> void:
	var you: int = net.room_info.get("you", 0)
	var mine: bool = int(msg.seat) == you
	var team := UI.TEAM_US if int(msg.seat) % 2 == you % 2 else UI.TEAM_THEM
	if _lines > 0:
		_log.newline()
	_lines += 1
	_log.push_bold()
	_log.push_color(UI.GOLD if mine else team.lightened(0.45))
	_log.add_text("Tú" if mine else str(msg.name))
	_log.pop()
	_log.pop()
	_log.add_text(":  ")
	if int(msg.kind) == EMOJI:
		_log.add_image(EMOJIS[clampi(str(msg.text).to_int(), 0, EMOJIS.size() - 1)], 38, 38)
	else:
		_log.add_text(str(msg.text))


func _button(text: String, color: Color, rect: Rect2, font_size: int) -> FancyButton:
	var b: FancyButton = FancyButton.new()
	b.setup(text, color, font_size)
	b.position = rect.position
	b.size = rect.size
	_panel.add_child(b)
	return b


## Tapa las groserías de un texto: "mierda" -> "m*****". Lo aplica el servidor
## a cada mensaje y a los nombres, así que todos ven lo mismo.
static func censor(text: String) -> String:
	var words := RegEx.create_from_string("[\\p{L}0-9@$]+")
	var out := text
	for m in words.search_all(text):
		var word := m.get_string()
		if _is_bad(word):
			out = out.substr(0, m.get_start()) + word.left(1) + "*".repeat(word.length() - 1) + out.substr(m.get_end())
	return out


static func _is_bad(word: String) -> bool:
	var w := ""
	for ch in word.to_lower():
		w += LEET.get(ch, ch)
	# "mierdaaaa" -> "mierda": tres letras iguales seguidas cuentan como una.
	w = RegEx.create_from_string("(.)\\1{2,}").sub(w, "$1", true)
	for bad: String in BAD_WORDS:
		if w == bad or w == bad + "s" or w == bad + "es" or (bad.length() >= 5 and w.begins_with(bad)):
			return true
	return false


## Imagen de un emoji del chat, o null si el índice no es válido.
static func emoji(text: String) -> Texture2D:
	if not text.is_valid_int():
		return null
	var i := text.to_int()
	return EMOJIS[i] if i >= 0 and i < EMOJIS.size() else null
