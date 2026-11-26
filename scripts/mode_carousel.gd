extends Control
## Carrusel de modos de juego del menú: una tarjeta grande por modo, que se
## pasa deslizando el dedo a izquierda o derecha (o tocando la que asoma a un
## lado, o con las pestañas de los bordes). Las vecinas se ven más pequeñas
## y apagadas.

signal changed(index: int)
## Toque en la tarjeta del centro (las de torneo y ranked lo usan para entrar).
signal tapped(index: int)
## Botón "Aprende" (la bombilla junto al nombre del modo): partida guiada.
signal learn
## Botones "Contra la CPU" (online = false) y "En línea" de las tarjetas de modo.
signal play(online: bool)
## Botón "Entrar" de las tarjetas de torneo y ranked.
signal enter(event: String)

const Tile = preload("res://scripts/tile.gd")
const UI = preload("res://scripts/ui_theme.gd")
const State = preload("res://scripts/domino_state.gd")
const UISkin = preload("res://scripts/ui_skin.gd")
const FancyButton = preload("res://scripts/fancy_button.gd")
const RoundButton = preload("res://scripts/round_button.gd")

## La tarjeta lleva dentro los botones de jugar: por eso es alta.
const CARD := Vector2(540, 660)
## Distancia entre los centros de dos tarjetas seguidas.
const SPACING := 560.0
## Márgenes 9-slice de card_frame.png (al doble): la cabecera no se estira al alargar la tarjeta.
const FRAME_MARGINS := [48, 210, 48, 48]
## Cuánto hay que deslizar (en unidades) para pasar de tarjeta aunque no se llegue a la mitad.
const FLICK := 60.0
const DRAG_START := 12.0
## Alto de la cabecera de madera de la tarjeta (ver card_frame.png).
const HEAD := 84.0
const ARROW := Vector2(44, 110)
## Por modo: color de la cabecera, texto, y fichas del dibujo [arriba, abajo, giro].
const CARDS := [
	[Color(0.85, 0.6, 0.2), "El de siempre: la pareja que domina suma las fichas de las cuatro manos.",
			[[6, 6, -0.35], [6, 3, 0.0], [3, 1, 0.35]]],
	[Color(0.8, 0.25, 0.22), "Solo suman las fichas que les quedaron a los rivales: partidas más ajustadas.",
			[[5, 5, -0.2], [2, 4, 0.2]]],
	[Color(0.15, 0.58, 0.62), "Domina con una ficha que case en los dos extremos y gana %d puntos extra." % State.CAPICUA_BONUS,
			[[3, 3, -0.4], [3, 5, 0.0], [5, 5, 0.4]]],
	[Color(0.35, 0.6, 0.22), "Si los extremos suman 5, 10, 15… te apuntas esos puntos al momento. Solo contra la CPU.",
			[[5, 5, -0.35], [0, 5, 0.0], [4, 6, 0.35]]],
	# Después de las reglas, las dos competiciones. No son una regla de puntos
	# (no se guardan en Settings.rules.mode): abren su propia pantalla.
	[Color(0.95, 0.66, 0.12), "8 jugadores, eliminatoria contra la CPU. Paga la entrada y gana hasta 5 veces lo apostado.",
			"trophy", "Torneo"],
	[Color(0.56, 0.32, 0.86), "2 contra 2 en línea contra personas reales. Sube de liga y gana premios cada temporada.",
			"shield", "Ranked"],
]
## Las primeras tarjetas son los modos de puntos (State.MODE_NAMES); las demás, eventos.
const EVENTS := ["tournament", "ranked"]

var index := 0
var _scroll := 0.0
var _cards: Array = []
## Botones de cada tarjeta; solo responden los de la del centro.
var _card_btns: Array = []
var _prev: TextureButton
var _next: TextureButton
var _pressed := false
var _dragging := false
var _press_x := 0.0
var _press_scroll := 0.0
var _tw: Tween


## "" si la tarjeta `i` es un modo de puntos; si no, el evento ("tournament", "ranked").
static func event_of(i: int) -> String:
	var k := i - State.MODE_NAMES.size()
	return EVENTS[k] if k >= 0 and k < EVENTS.size() else ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	for i in CARDS.size():
		_cards.append(_make_card(i))
	# Pestañas a los lados de la pantalla para pasar de modo sin deslizar.
	# Van después de las tarjetas para quedar por encima.
	_prev = _arrow("arrow_nav_left", 0.0, -1)
	_next = _arrow("arrow_nav_right", size.x - ARROW.x, 1)
	_scroll = index
	_place()


func _arrow(tex: String, x: float, step: int) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = UISkin.tex(tex)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.position = Vector2(x, 8.0 + CARD.y * 0.5 - ARROW.y * 0.5)
	b.size = ARROW
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(func() -> void: go_to(index + step))
	add_child(b)
	return b


## Va a la tarjeta `i` con una animación (o de golpe si `animate` es false).
func go_to(i: int, animate: bool = true) -> void:
	var target := clampi(i, 0, CARDS.size() - 1)
	var moved := target != index
	index = target
	if _tw != null and _tw.is_valid():
		_tw.kill()
	if animate:
		_tw = create_tween()
		_tw.tween_method(_set_scroll, _scroll, float(index), 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_set_scroll(index)
	if moved:
		changed.emit(index)


func _set_scroll(v: float) -> void:
	_scroll = v
	_place()


func _make_card(i: int) -> Control:
	var spec: Array = CARDS[i]
	var card := Panel.new()
	card.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	card.size = CARD
	card.add_child(UISkin.nine("card_frame", FRAME_MARGINS))
	card.pivot_offset = CARD * 0.5
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)

	if i > 0:
		# La cabecera de madera se tiñe con el color del modo (el clásico la deja tal cual).
		var tint := Panel.new()
		var hb := StyleBoxFlat.new()
		hb.bg_color = Color(spec[0], 0.55)
		hb.corner_radius_top_left = 14
		hb.corner_radius_top_right = 14
		tint.add_theme_stylebox_override("panel", hb)
		tint.position = Vector2(12, 12)
		tint.size = Vector2(CARD.x - 24, HEAD)
		tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(tint)
	var event := event_of(i) != ""
	var title := _label(card, spec[3] if event else State.MODE_NAMES[i], 40, UISkin.CREAM, Rect2(0, 10, CARD.x, HEAD))
	title.add_theme_font_override("font", UISkin.serif())
	title.add_theme_color_override("font_outline_color", UISkin.TITLE_OUTLINE)
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	title.add_theme_constant_override("shadow_offset_y", 3)

	if event:
		# Eventos: el icono grande (copa o escudo) sobre un círculo de su color.
		var orb := Control.new()
		orb.position = Vector2(CARD.x * 0.5 - 85, HEAD + 18)
		orb.size = Vector2(170, 170)
		orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var col: Color = spec[0]
		var icon := UISkin.tex("kit_icon_" + spec[2])
		orb.draw.connect(func() -> void:
			var c := orb.size * 0.5
			orb.draw_circle(c + Vector2(0, 5), 82, Color(0, 0, 0, 0.4), true, -1.0, true)
			orb.draw_circle(c, 82, UISkin.TITLE_OUTLINE, true, -1.0, true)
			orb.draw_circle(c, 78, Color(0.97, 0.8, 0.4), true, -1.0, true)
			orb.draw_circle(c, 70, col.darkened(0.3), true, -1.0, true)
			orb.draw_circle(c - Vector2(0, 4), 66, col, true, -1.0, true)
			orb.draw_circle(c + Vector2(-20, -28), 24, Color(1, 1, 1, 0.16), true, -1.0, true)
			orb.draw_texture_rect(icon, Rect2(c - Vector2(52, 52), Vector2(104, 104)), false))
		card.add_child(orb)
	var btns: Array = []
	if event:
		var kind := event_of(i)
		btns.append(_card_button(card, "Entrar al torneo" if kind == "tournament" else "Jugar ranked", spec[2],
				spec[0], Rect2(34, 478, CARD.x - 68, 110), func() -> void: enter.emit(kind)))
	else:
		# La bombilla, pegada al nombre del modo: partida guiada que enseña a jugar.
		var bulb: RoundButton = RoundButton.new()
		bulb.setup("bulb", "", UI.ACCENT, 46.0)
		var w := UISkin.serif().get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
		bulb.position = Vector2(minf(CARD.x * 0.5 + w * 0.5 + 2.0, CARD.x - bulb.size.x - 14.0),
				12.0 + HEAD * 0.5 - 25.0)
		bulb.pressed.connect(func() -> void: learn.emit())
		card.add_child(bulb)
		btns.append(bulb)
		# Dónde jugar este modo: cada uno abre "Prepara tu partida".
		btns.append(_card_button(card, "Contra la CPU", "cpu", UI.PRIMARY, Rect2(34, 430, CARD.x - 68, 92),
				func() -> void: play.emit(false)))
		btns.append(_card_button(card, "En línea", "globe", UI.SECONDARY, Rect2(34, 536, CARD.x - 68, 92),
				func() -> void: play.emit(true)))
	_card_btns.append(btns)
	var tiles: Array = [] if event else spec[2]
	# Dibujo del modo hecho con fichas de verdad, en abanico.
	for k in tiles.size():
		var t: Tile = Tile.new()
		var v: Array = tiles[k]
		t.set_values(v[0], v[1])
		t.rotation = v[2]
		t.scale = Vector2(1.35, 1.35)
		t.position = Vector2(CARD.x * 0.5 + (k - (tiles.size() - 1) * 0.5) * 88.0, 190.0 + absf(v[2]) * 30.0)
		if i == State.CAPICUA and k == 1:
			# La ficha que cierra la capicúa: casa con los dos dobles de los lados.
			t.glow = 1.0
		card.add_child(t)

	_label(card, spec[1], 25, UISkin.CREAM, Rect2(30, 276 if event else 264, CARD.x - 60, 104), true)

	# Indicador de página con fichas pequeñas: encendidas hasta la de este modo.
	var n := CARDS.size()
	for k in n:
		var mini := TextureRect.new()
		mini.texture = UISkin.tex("mini_tile")
		mini.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mini.size = Vector2(20, 34)
		mini.position = Vector2(CARD.x * 0.5 + (k - (n - 1) * 0.5) * 30.0 - 10.0, 404.0 if event else 388.0)
		mini.rotation = 0.18 if k % 2 else -0.08
		mini.modulate = Color.WHITE if k <= i else Color(0.45, 0.3, 0.2, 0.45)
		mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(mini)
	return card


## Coloca cada tarjeta según el desplazamiento: la del centro grande y la de los lados apagada.
func _place() -> void:
	var cx := size.x * 0.5
	# La tarjeta más centrada se dibuja encima de las otras (por orden, no con
	# z_index, que la pondría también por encima de los paneles del menú).
	var front := clampi(roundi(_scroll), 0, _cards.size() - 1)
	move_child(_cards[front], _cards.size() - 1)
	for i in _cards.size():
		var c: Control = _cards[i]
		var off := i - _scroll
		var near := clampf(1.0 - absf(off), 0.0, 1.0)
		var s := lerpf(0.82, 1.0, near)
		c.scale = Vector2(s, s)
		c.position = Vector2(cx + off * SPACING - CARD.x * 0.5, 8.0)
		c.modulate = Color(1, 1, 1, lerpf(0.55, 1.0, near))
		c.visible = absf(off) < 1.6
		for b: Control in _card_btns[i]:
			b.mouse_filter = Control.MOUSE_FILTER_STOP if absf(off) < 0.3 else Control.MOUSE_FILTER_IGNORE
	_prev.modulate.a = 0.35 if index == 0 else 1.0
	_next.modulate.a = 0.35 if index == CARDS.size() - 1 else 1.0


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_pressed = true
			_dragging = false
			_press_x = button.position.x
			_press_scroll = _scroll
			if _tw != null and _tw.is_valid():
				_tw.kill()
		elif _pressed:
			_pressed = false
			var moved := button.position.x - _press_x
			if not _dragging:
				# Un toque en la tarjeta que asoma a un lado la trae al centro.
				var side := button.position.x - size.x * 0.5
				if absf(side) > CARD.x * 0.5:
					go_to(index + (1 if side > 0.0 else -1))
				else:
					go_to(index)
					tapped.emit(index)
			elif absf(moved) > FLICK:
				go_to(index + (-1 if moved > 0.0 else 1))
			else:
				go_to(roundi(_scroll))
		accept_event()
	elif event is InputEventMouseMotion and _pressed:
		var dx: float = (event as InputEventMouseMotion).position.x - _press_x
		if absf(dx) > DRAG_START:
			_dragging = true
		if _dragging:
			# Más allá de la primera y la última tarjeta se resiste un poco.
			_set_scroll(clampf(_press_scroll - dx / SPACING, -0.3, CARDS.size() - 0.7))
		accept_event()


func _card_button(card: Control, text: String, icon: String, color: Color, rect: Rect2,
		on_press: Callable) -> FancyButton:
	var b: FancyButton = FancyButton.new()
	b.setup(text, color, UI.BUTTON)
	b.position = rect.position
	b.size = rect.size
	card.add_child(b)
	b.set_icon(icon, 50)
	b.pressed.connect(on_press)
	return b


func _label(parent: Node, text: String, font_size: int, color: Color, rect: Rect2, wrap: bool = false) -> Label:
	var lb := Label.new()
	# El ajuste de línea va antes que el texto: si no, la etiqueta ya creció a lo ancho.
	if wrap:
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb.text = text
	lb.add_theme_font_size_override("font_size", font_size)
	lb.add_theme_color_override("font_color", color)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.position = rect.position
	lb.size = rect.size
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lb)
	return lb
