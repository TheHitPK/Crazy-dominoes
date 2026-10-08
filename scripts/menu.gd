extends Control
## Menú principal: elección de dificultad y panel de reglas.

signal start_game(difficulty: int)
signal open_online

const Tile = preload("res://scripts/tile.gd")
const Table = preload("res://scripts/table.gd")
const FancyButton = preload("res://scripts/fancy_button.gd")
const Customize = preload("res://scripts/customize.gd")

const GOLD := Color(1.0, 0.84, 0.3)
const DIFFICULTIES := [
	["Fácil", "Las CPU juegan relajadas y casi al azar", Color(0.25, 0.62, 0.3)],
	["Intermedio", "Sueltan fichas pesadas y cuidan su mano", Color(0.85, 0.55, 0.12)],
	["Difícil", "Cuentan fichas, leen tus pases y simulan la mano", Color(0.78, 0.2, 0.18)],
]
const RULES := """[font_size=22][color=#ffd64d][b]Objetivo[/b][/color][/font_size]
Dominó en parejas: tú y tu compañero (sentado enfrente) contra las dos CPU de los lados. Gana la partida la primera pareja que llegue a [b]100 puntos[/b].

[font_size=22][color=#ffd64d][b]Reparto[/b][/color][/font_size]
Se juega con las 28 fichas del doble seis. Se revuelven boca abajo y cada jugador toma 7. No sobra ninguna, así que [b]no se roba[/b].

[font_size=22][color=#ffd64d][b]Salida[/b][/color][/font_size]
En la primera mano sale quien tenga el [b]doble seis[/b] y debe abrir con esa ficha. En las siguientes manos sale el jugador que ganó la mano anterior, con la ficha que quiera. Si la mano quedó empatada, repite el mismo jugador.

[font_size=22][color=#ffd64d][b]Turnos[/b][/color][/font_size]
El turno pasa de jugador en jugador alrededor de la mesa, alternando parejas. En tu turno colocas una ficha que tenga el mismo número que uno de los dos extremos abiertos de la cadena. Los dobles se colocan atravesados.

[font_size=22][color=#ffd64d][b]Pasar[/b][/color][/font_size]
Si ninguna de tus fichas casa con los extremos, pasas. Si tienes una ficha jugable estás obligado a jugar. ¡Ojo!: cuando alguien pasa, todos saben qué números no tiene.

[font_size=22][color=#ffd64d][b]Dominar[/b][/color][/font_size]
El primer jugador que coloca su última ficha [b]domina[/b] y gana la mano para su pareja.

[font_size=22][color=#ffd64d][b]Tranca[/b][/color][/font_size]
Si nadie puede jugar, el juego se tranca. Cada jugador cuenta los puntos de su mano y gana la pareja del jugador que tenga [b]menos puntos[/b]. Si los dos mejores son de parejas contrarias y empatan, nadie suma.

[font_size=22][color=#ffd64d][b]Puntuación[/b][/color][/font_size]
La pareja ganadora suma los puntos de [b]todas[/b] las fichas que quedaron sin jugar en las cuatro manos.

[font_size=22][color=#ffd64d][b]Controles[/b][/color][/font_size]
Tus fichas jugables brillan en dorado. Toca una para jugarla. Si cabe en los dos extremos, aparecen dos marcadores sobre la mesa: toca cerca del extremo que prefieras. Si no puedes jugar, pulsa [b]Pasar[/b]. Tu vaso es el de abajo a la derecha: tócalo para beber un trago.
"""

var sfx: Node
var _rules: Control
var _customize: Customize
var _table: Table
var _floating: Array = []


func _ready() -> void:
	# El contenido usa coordenadas del diseño base (720x1280); main.gd lo centra.
	size = Vector2(720, 1280)
	_table = Table.new()
	add_child(_table)
	_spawn_floating_tiles()

	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.02, 0.0, 0.5)
	_cover_screen(shade)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var title := _label("CRAZY\nDOMINOES", 104, GOLD, Rect2(0, 150, 720, 270))
	title.add_theme_constant_override("line_spacing", -22)
	title.add_theme_color_override("font_outline_color", Color(0.2, 0.08, 0.02))
	title.add_theme_constant_override("outline_size", 18)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_y", 8)
	title.pivot_offset = title.size * 0.5
	title.scale = Vector2(0.3, 0.3)
	var tin := create_tween()
	tin.tween_property(title, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var bob := create_tween().set_loops()
	bob.tween_property(title, "position:y", 160.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(title, "position:y", 146.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_label("Dominó en parejas  ·  2 contra 2", 26, Color(0.97, 0.93, 0.82), Rect2(0, 430, 720, 40))

	for i in DIFFICULTIES.size():
		var d: Array = DIFFICULTIES[i]
		var y := 510.0 + i * 138.0
		var b := _button(d[0], d[2], Rect2(110, y, 500, 86), 38, 0.25 + i * 0.12)
		b.pressed.connect(func() -> void: start_game.emit(i))
		_label(d[1], 19, Color(0.95, 0.9, 0.78, 0.9), Rect2(40, y + 90.0, 640, 28))

	var friends_btn := _button("Jugar con amigos", Color(0.15, 0.5, 0.6), Rect2(110, 924, 500, 80), 32, 0.6)
	friends_btn.pressed.connect(func() -> void: open_online.emit())
	var rules_btn := _button("Reglas", Color(0.3, 0.42, 0.6), Rect2(60, 1028, 290, 72), 28, 0.68)
	rules_btn.pressed.connect(_toggle_rules.bind(true))
	var look_btn := _button("Personalizar", Color(0.55, 0.3, 0.6), Rect2(370, 1028, 290, 72), 28, 0.74)
	look_btn.pressed.connect(open_customize)
	var quit_btn := _button("Salir", Color(0.45, 0.33, 0.22), Rect2(215, 1120, 290, 64), 26, 0.8)
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	# iOS no permite que una app se cierre sola, y en el navegador no tiene sentido.
	quit_btn.visible = OS.get_name() != "iOS" and not OS.has_feature("web")

	_build_rules()
	_customize = Customize.new()
	_customize.sfx = sfx
	add_child(_customize)
	_customize.changed.connect(_apply_look)


## Extiende un fondo más allá de 720x1280 para cubrir los márgenes de un teléfono.
static func _cover_screen(c: Control) -> void:
	c.position = Vector2(-1500, -1500)
	c.size = Vector2(4280, 3720)


func open_customize() -> void:
	_customize.open()


## Aplica al fondo del menú el aspecto recién elegido.
func _apply_look() -> void:
	_table.queue_redraw()
	for t: Tile in _floating:
		t.refresh_style()


func _label(text: String, font_size: int, color: Color, rect: Rect2) -> Label:
	var lb := Label.new()
	lb.text = text
	lb.add_theme_font_size_override("font_size", font_size)
	lb.add_theme_color_override("font_color", color)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.position = rect.position
	lb.size = rect.size
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lb)
	return lb


## Botón que entra deslizándose desde abajo tras `delay` segundos.
func _button(text: String, color: Color, rect: Rect2, font_size: int, delay: float) -> FancyButton:
	var b: FancyButton = FancyButton.new()
	b.setup(text, color, font_size)
	b.position = rect.position + Vector2(0, 40)
	b.size = rect.size
	b.modulate.a = 0.0
	add_child(b)
	b.pressed.connect(_click)
	var tw := b.create_tween().set_parallel(true)
	tw.tween_property(b, "position:y", rect.position.y, 0.45).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "modulate:a", 1.0, 0.3).set_delay(delay)
	return b


func _click() -> void:
	if sfx != null:
		sfx.play("click")


func _spawn_floating_tiles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var spots := [Vector2(110, 130), Vector2(610, 120), Vector2(90, 440), Vector2(640, 450),
			Vector2(60, 640), Vector2(665, 700), Vector2(55, 860), Vector2(660, 900),
			Vector2(130, 1140), Vector2(590, 1160), Vector2(360, 1200), Vector2(360, 80)]
	for pos: Vector2 in spots:
		var t: Tile = Tile.new()
		var a := rng.randi_range(0, 6)
		var b := rng.randi_range(0, 6)
		t.set_values(a, b)
		t.position = pos
		t.rotation = rng.randf_range(-0.6, 0.6)
		t.scale = Vector2.ONE * rng.randf_range(1.0, 1.5)
		add_child(t)
		_floating.append(t)
		var dur := rng.randf_range(1.8, 3.0)
		var tw := t.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(t, "position:y", pos.y - 16.0, dur)
		tw.parallel().tween_property(t, "rotation", t.rotation + 0.18, dur)
		tw.tween_property(t, "position:y", pos.y, dur)
		tw.parallel().tween_property(t, "rotation", t.rotation, dur)
		# De vez en cuando la ficha se voltea.
		var fl := t.create_tween().set_loops()
		fl.tween_interval(rng.randf_range(3.0, 9.0))
		fl.tween_property(t, "flip", 0.0, 0.4)
		fl.tween_interval(rng.randf_range(1.0, 2.5))
		fl.tween_property(t, "flip", 1.0, 0.4)


func _build_rules() -> void:
	_rules = ColorRect.new()
	_rules.color = Color(0, 0, 0, 0.7)
	_cover_screen(_rules)
	_rules.visible = false
	add_child(_rules)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.08, 0.05, 0.98)
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	var pn := Panel.new()
	pn.name = "Panel"
	pn.add_theme_stylebox_override("panel", sb)
	# _rules empieza fuera de pantalla (ver _cover_screen): se descuenta su origen.
	pn.position = Vector2(30, 120) - _rules.position
	pn.size = Vector2(660, 1040)
	pn.pivot_offset = pn.size * 0.5
	_rules.add_child(pn)

	var head := Label.new()
	head.text = "Reglas del dominó en parejas"
	head.add_theme_font_size_override("font_size", 30)
	head.add_theme_color_override("font_color", GOLD)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.position = Vector2(0, 14)
	head.size = Vector2(660, 44)
	pn.add_child(head)

	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.text = RULES
	body.add_theme_font_size_override("normal_font_size", 19)
	body.add_theme_font_size_override("bold_font_size", 19)
	body.add_theme_color_override("default_color", Color(0.97, 0.93, 0.82))
	# El texto va dentro de un ScrollContainer para poder deslizarlo con el dedo.
	body.fit_content = true
	body.scroll_active = false
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.custom_minimum_size = Vector2(592, 0)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.position = Vector2(24, 70)
	scroll.size = Vector2(612, 860)
	scroll.add_child(body)
	pn.add_child(scroll)

	var close: FancyButton = FancyButton.new()
	close.setup("Entendido", Color(0.25, 0.62, 0.3), 24)
	close.position = Vector2(200, 950)
	close.size = Vector2(260, 68)
	pn.add_child(close)
	close.pressed.connect(_click)
	close.pressed.connect(_toggle_rules.bind(false))


func _toggle_rules(on: bool) -> void:
	_rules.visible = on
	if not on:
		return
	var pn: Panel = _rules.get_node("Panel")
	pn.scale = Vector2(0.7, 0.7)
	_rules.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_rules, "modulate:a", 1.0, 0.2)
	tw.tween_property(pn, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
