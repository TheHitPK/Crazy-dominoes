extends Control
## Menú principal: modo y meta, mesa contra la CPU o partida en línea, monedas,
## nivel y regalo diario, reglas y Personalizar (con la tienda).

signal start_game(difficulty: int)
signal open_online
## Partida de torneo, desafío del día, rápida o guiada ("tournament", "daily"...).
signal start_event(kind: String)
## Pantalla del ranked en línea.
signal open_ranked

const Tile = preload("res://scripts/tile.gd")
const Table = preload("res://scripts/table.gd")
const FancyButton = preload("res://scripts/fancy_button.gd")
const UI = preload("res://scripts/ui_theme.gd")
const Customize = preload("res://scripts/customize.gd")
const Settings = preload("res://scripts/settings.gd")
const State = preload("res://scripts/domino_state.gd")
const Carousel = preload("res://scripts/mode_carousel.gd")
const Wallet = preload("res://scripts/wallet.gd")
const CoinIcon = preload("res://scripts/coin_icon.gd")
const UISkin = preload("res://scripts/ui_skin.gd")
const Shop = preload("res://scripts/shop.gd")
const TournamentPanel = preload("res://scripts/tournament_panel.gd")
const ChallengePanel = preload("res://scripts/challenge_panel.gd")
const StatsPanel = preload("res://scripts/stats_panel.gd")
const OverlayPanel = preload("res://scripts/popup.gd")
const Stats = preload("res://scripts/stats.gd")
const RoundButton = preload("res://scripts/round_button.gd")
const Ads = preload("res://scripts/ads.gd")
const Daily = preload("res://scripts/daily_challenge.gd")
const GemIcon = preload("res://scripts/gem_icon.gd")
const SettingsPanel = preload("res://scripts/settings_panel.gd")
const ProfilePanel = preload("res://scripts/profile_panel.gd")

## Círculos a los lados del título, lo secundario: [icono, texto, color, panel
## que abre ("ad" = ver un anuncio por monedas), posición].
const SIDE_NAV := [["cart", "Tienda", Color(0.3, 0.72, 0.26), "shop", Vector2(4, 92)],
		["calendar", "Desafío", Color(0.16, 0.52, 0.95), "daily", Vector2(4, 194)],
		["chart", "Récords", Color(0.62, 0.36, 0.7), "stats", Vector2(618, 92)],
		["video", "Gratis", Color(0.9, 0.3, 0.22), "ad", Vector2(618, 194)]]

const GOLD := Color(1.0, 0.84, 0.3)
## Ancho de la barra de experiencia de arriba.
const XP_BAR := 150.0
const XP_H := 26.0
## Formatos contra la CPU (State.PAIRS, SOLO, DUEL): nombre del botón y explicación.
const FORMATS := [
	["Parejas", "2 contra 2: tú y tu compañero contra dos CPU"],
	["Todos", "4 jugadores, cada uno por su cuenta (premio x1,75)"],
	["1 contra 1", "Tú contra una CPU; si no puedes jugar, robas del pozo"],
]
## Juegos de fichas contra la CPU (Settings.rules.nine).
const SETS := ["Doble seis (28)", "Doble nueve (55)"]
const DIFFICULTIES := [
	["Fácil", "Las CPU juegan relajadas y casi al azar", Color(0.25, 0.62, 0.3)],
	["Intermedio", "Sueltan fichas pesadas y cuidan su mano", Color(0.85, 0.55, 0.12)],
	["Difícil", "Cuentan fichas, leen tus pases y simulan la mano", Color(0.78, 0.2, 0.18)],
]
const RULES := """[font_size=30][color=#ffd64d][b]Objetivo[/b][/color][/font_size]
Dominó en parejas: tú y tu compañero (sentado enfrente) contra las dos CPU de los lados. Gana la partida la primera pareja que llegue a la [b]meta[/b] elegida: 50, 100, 150 o 200 puntos.

[font_size=30][color=#ffd64d][b]Modos de juego[/b][/color][/font_size]
• [b]Clásico[/b]: la pareja que gana la mano suma las fichas de las cuatro manos.
• [b]Por rivales[/b]: solo suma las fichas que les quedaron a los rivales.
• [b]Capicúa[/b]: como el clásico, pero si dominas con una ficha que casaba en los dos extremos ganas [b]25 puntos extra[/b].
• [b]Cincos[/b] (solo contra la CPU): cada vez que, tras tu jugada, los extremos suman 5, 10, 15… te apuntas esa suma al momento. Un doble en un extremo cuenta sus dos mitades. Al dominar sumas las fichas de los rivales redondeadas a 5.

[font_size=30][color=#ffd64d][b]Jugadores[/b][/color][/font_size]
Contra la CPU puedes elegir cómo se juega:
• [b]Parejas[/b]: 2 contra 2, como se explica aquí.
• [b]Todos contra todos[/b]: cuatro jugadores sin compañero. La mano y sus puntos son solo para quien domina (o para quien tenga menos puntos si se tranca). Como es más difícil ganar, el premio es mayor.
• [b]1 contra 1[/b]: tú contra una CPU, 7 fichas cada uno. Las otras 14 quedan boca abajo en el [b]pozo[/b]: si no tienes ficha que case, robas automáticamente hasta que salga una. Solo se pasa cuando el pozo está vacío. Si el doble seis quedó en el pozo, abre el doble más alto repartido.
En línea siempre se juega en parejas.

[font_size=30][color=#ffd64d][b]Doble nueve[/b][/color][/font_size]
Contra la CPU puedes jugar con las [b]55 fichas[/b] del doble nueve: 10 fichas cada uno. En parejas y en todos contra todos sobran 15, que quedan [b]dormidas[/b]: nadie las ve ni se roban, así que las trancas son más frecuentes. En 1 contra 1, las que sobran van al pozo. Abre el doble más alto repartido.

[font_size=30][color=#ffd64d][b]Monedas y niveles[/b][/color][/font_size]
Contra la CPU eliges el modo, la meta, la dificultad y cuántas monedas [b]apuestas[/b]. Si ganas la partida cobras la apuesta multiplicada: [b]x1,8[/b] en fácil, [b]x2,2[/b] en intermedio y [b]x2,8[/b] en difícil. Si pierdes o abandonas, la pierdes. Ganes o pierdas sumas experiencia, y cada nivel nuevo trae monedas de regalo y desbloquea apuestas más altas y CPU más difíciles.
Cada [b]24 horas[/b] hay un regalo que crece si lo recoges seguido, y si te quedas sin monedas puedes pedir [b]ayuda[/b] gratis cada hora. Con las monedas se compran fichas y mesas en Personalizar. Las monedas son solo del juego: se pueden conseguir en la tienda, pero nunca se cambian por dinero.

[font_size=30][color=#ffd64d][b]Torneo, ranked y desafío[/b][/color][/font_size]
• [b]Torneo[/b]: 8 jugadores, eliminación directa (cuartos, semifinal y final) a 1 contra 1. Pagas la entrada y cobras según hasta dónde llegues.
• [b]Ranked[/b]: subes de liga (Bronce a Maestro) ganando puntos de clasificación. Cada mes empieza una temporada con premio.
• [b]Desafío del día[/b]: el mismo reparto para todos ese día. Gánalo para cobrar y mantener la racha.
• [b]Aprende[/b] (la bombilla de cada modo): una partida guiada que te explica cada jugada.
Abandonar una partida de torneo o ranked cuenta como derrota.

[font_size=30][color=#ffd64d][b]Reparto[/b][/color][/font_size]
Se juega con las 28 fichas del doble seis. Se revuelven boca abajo y cada jugador toma 7. No sobra ninguna, así que [b]no se roba[/b].

[font_size=30][color=#ffd64d][b]Salida[/b][/color][/font_size]
En la primera mano sale quien tenga el [b]doble seis[/b] y debe abrir con esa ficha. En las siguientes manos sale el jugador que ganó la mano anterior, con la ficha que quiera. Si la mano quedó empatada, repite el mismo jugador.

[font_size=30][color=#ffd64d][b]Turnos[/b][/color][/font_size]
El turno pasa de jugador en jugador alrededor de la mesa, alternando parejas. En tu turno colocas una ficha que tenga el mismo número que uno de los dos extremos abiertos de la cadena. Los dobles se colocan atravesados.

[font_size=30][color=#ffd64d][b]Pasar[/b][/color][/font_size]
Si ninguna de tus fichas casa con los extremos, pasas. Si tienes una ficha jugable estás obligado a jugar. ¡Ojo!: cuando alguien pasa, todos saben qué números no tiene.

[font_size=30][color=#ffd64d][b]Dominar[/b][/color][/font_size]
El primer jugador que coloca su última ficha [b]domina[/b] y gana la mano para su pareja.

[font_size=30][color=#ffd64d][b]Tranca[/b][/color][/font_size]
Si nadie puede jugar, el juego se tranca. Cada jugador cuenta los puntos de su mano y gana la pareja del jugador que tenga [b]menos puntos[/b]. Si los dos mejores son de parejas contrarias y empatan, nadie suma.

[font_size=30][color=#ffd64d][b]Puntuación[/b][/color][/font_size]
En el modo clásico, la pareja ganadora suma los puntos de [b]todas[/b] las fichas que quedaron sin jugar en las cuatro manos (ver Modos de juego).

[font_size=30][color=#ffd64d][b]Controles[/b][/color][/font_size]
Tus fichas jugables brillan en dorado. Hay dos formas de jugarlas:
• [b]Tocar[/b] la ficha. Si cabe en los dos extremos, aparecen dos marcadores sobre la mesa: toca cerca del que prefieras.
• [b]Arrastrarla[/b] hasta la mesa y soltarla junto al extremo donde la quieres. Si la sueltas fuera de la mesa, vuelve a tu mano.
Si no tienes ninguna ficha que case, [b]pasas automáticamente[/b]. Tu vaso es el de abajo a la derecha: tócalo para beber un trago.
En partidas con amigos, el botón [b]Chat[/b] abre el chat de la sala: emojis, frases rápidas o lo que quieras escribir.

[font_size=22][color=#bfb39a]Emojis del chat: Twemoji, de Twitter, Inc. y colaboradores, con licencia CC-BY 4.0.[/color][/font_size]
"""

var sfx: Node
var _rules: Control
var _customize: Customize
var _table: Table
var _floating: Array = []
var _carousel: Carousel
## Tarjeta "Prepara tu partida" (ver _build_setup).
var _setup: Control
var _setup_is_online := false
var _setup_title: Label
var _setup_sub: Label
var _setup_cpu: Control
var _setup_online: Label
var _setup_prize: Label
var _setup_note: Label
var _setup_go: FancyButton
var _target_chips: Array = []
var _diff_chips: Array = []
var _format_chips: Array = []
var _set_chips: Array = []
var _format_desc: Label
var _diff_desc: Label
var _bet_chips: Array = []
var _level_num: Label
var _level_lbl: Label
var _xp_fill: Panel
var _xp_text: Label
var _meta_btn: FancyButton
var _coins_lbl: Label
var _gems_lbl: Label
var _gift_btn: FancyButton
var _daily: Control
var _daily_sub: Label
var _daily_boxes: Array = []
var _daily_btn: FancyButton
## Círculos de los lados del título, por clave de SIDE_NAV.
var _side := {}
## Paneles de la barra de abajo, por clave de NAV.
var _panels := {}
## Panel que se abre nada más entrar (al volver de un torneo, ranked o desafío).
var open_panel := ""


func _ready() -> void:
	# El contenido usa coordenadas del diseño base (720x1280); main.gd lo centra.
	size = Vector2(720, 1280)
	if sfx != null:
		sfx.music(true, "menu")
	_table = Table.new()
	add_child(_table)
	_spawn_floating_tiles()

	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.02, 0.0, 0.5)
	_cover_screen(shade)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var title := _label("CRAZY\nDOMINOES", 80, GOLD, Rect2(0, 86, 720, 190))
	title.add_theme_constant_override("line_spacing", -18)
	title.add_theme_font_override("font", UISkin.heavy())
	title.material = UISkin.title_material(title.size.y)
	title.add_theme_color_override("font_outline_color", UISkin.TITLE_OUTLINE)
	title.add_theme_constant_override("outline_size", 16)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_y", 8)
	title.pivot_offset = title.size * 0.5
	title.scale = Vector2(0.3, 0.3)
	var tin := create_tween()
	tin.tween_property(title, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var bob := create_tween().set_loops()
	bob.tween_property(title, "position:y", 94.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(title, "position:y", 84.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_build_top_bar()

	# Primero se elige el modo (deslizando las tarjetas); luego, dónde jugarlo y,
	# en la tarjeta que se abre, la meta y la apuesta.
	_label("Elige el modo de juego", UI.CAPTION, UISkin.CREAM, Rect2(0, 284, 720, 38))
	_carousel = Carousel.new()
	_carousel.position = Vector2(0, 318)
	_carousel.size = Vector2(720, 680)
	_carousel.index = clampi(Settings.rules.mode, 0, State.MODE_NAMES.size() - 1)
	add_child(_carousel)
	_carousel.changed.connect(_on_mode)
	_carousel.learn.connect(func() -> void:
		_click()
		start_event.emit("tutorial"))
	_carousel.play.connect(_open_setup)
	_carousel.enter.connect(func(event: String) -> void:
		_click()
		_open_panel(event))
	_carousel.modulate.a = 0.0
	create_tween().tween_property(_carousel, "modulate:a", 1.0, 0.4).set_delay(0.15)
	# Placa de la meta: cada toque pasa a la siguiente (50, 100, 150, 200 y vuelta).
	# También se puede cambiar en "Prepara tu partida".
	_meta_btn = FancyButton.new()
	_meta_btn.setup("", UI.NEUTRAL, UI.CAPTION)
	_meta_btn.set_texture("plaque_meta")
	_meta_btn.position = Vector2(210, 994)
	_meta_btn.size = Vector2(300, 58)
	add_child(_meta_btn)
	_meta_btn.pressed.connect(_next_target)
	_refresh_meta()
	_meta_btn.visible = Carousel.event_of(_carousel.index) == ""

	var row: Array = [[_button("Reglas", Color(0.6, 0.62, 0.66), Rect2(0, 1070, 170, 80), 28, 0.55), 170.0]]
	row[0][0].set_icon("book", 40)
	row[0][0].pressed.connect(_toggle_rules.bind(true))
	row.append([_button("Personalizar", Color(0.62, 0.3, 0.62), Rect2(0, 1070, 236, 80), 28, 0.6), 236.0])
	row[1][0].set_icon("brush", 36)
	row[1][0].pressed.connect(open_customize)
	# Ajustes: sonido, vibración, manos y (donde se puede) salir del juego.
	row.append([_button("Ajustes", Color(0.4, 0.38, 0.36), Rect2(0, 1070, 190, 80), 28, 0.65), 190.0])
	row[2][0].set_icon("gear", 40)
	row[2][0].pressed.connect(_open_panel.bind("settings"))
	# La fila se centra según cuántos botones tenga.
	var total := (row.size() - 1) * 12.0
	for item: Array in row:
		total += item[1]
	var x := 360.0 - total * 0.5
	for item: Array in row:
		item[0].position.x = x
		x += item[1] + 12.0
	_build_nav()
	_refresh_side()

	_build_setup()
	_build_daily()
	_build_rules()
	_customize = Customize.new()
	_customize.sfx = sfx
	add_child(_customize)
	_customize.changed.connect(_apply_look)
	# Las compras de la tienda cambian el saldo.
	_customize.closed.connect(_refresh_wallet)
	_build_panels()
	if open_panel != "" and _panels.has(open_panel):
		_panels[open_panel].open.call_deferred()
	elif Settings.rules.tutorial == 0 and int(Stats.data.matches) == 0 and int(Wallet.data.xp) == 0 and open_panel == "":
		# Primera vez: se ofrece la partida guiada antes que nada.
		get_tree().create_timer(0.8).timeout.connect(_offer_tutorial)
	elif Wallet.daily_available():
		# El regalo del día se ofrece solo al abrir el menú.
		get_tree().create_timer(0.7).timeout.connect(func() -> void:
			if is_inside_tree() and not _customize.visible and not _setup.visible:
				_toggle_daily(true))
	# La cuenta atrás del próximo regalo se actualiza sola.
	var tick := Timer.new()
	tick.wait_time = 20.0
	tick.autostart = true
	tick.timeout.connect(_refresh_wallet)
	add_child(tick)


## Extiende un fondo más allá de 720x1280 para cubrir los márgenes de un teléfono.
static func _cover_screen(c: Control) -> void:
	c.position = Vector2(-1500, -1500)
	c.size = Vector2(4280, 3720)


func open_customize() -> void:
	_customize.open()


## Torneo y Ranked son tarjetas del carrusel (ver mode_carousel.gd). Tienda,
## desafío, récords y monedas gratis van en círculos a los lados del título,
## más discretos.
func _build_nav() -> void:
	for i in SIDE_NAV.size():
		var item: Array = SIDE_NAV[i]
		var rb: RoundButton = RoundButton.new()
		rb.setup(item[0], item[1], item[2])
		rb.position = item[4]
		rb.modulate.a = 0.0
		add_child(rb)
		create_tween().tween_property(rb, "modulate:a", 1.0, 0.3).set_delay(0.3 + i * 0.06)
		rb.pressed.connect(_click)
		if item[3] == "ad":
			rb.pressed.connect(_watch_ad)
		else:
			rb.pressed.connect(_open_panel.bind(item[3]))
		_side[item[3]] = rb


## Monedas por ver un anuncio (las mismas que en la tienda, con su límite diario).
func _watch_ad() -> void:
	var ads := Ads.get_ads()
	if ads == null or Wallet.ad_coins_left() <= 0:
		return
	ads.show_rewarded(func() -> void:
		if Wallet.claim_ad_coins() > 0:
			_coins_won(Wallet.AD_COINS))


## Globos de los círculos: desafío sin jugar hoy y anuncios que quedan.
func _refresh_side() -> void:
	if _side.is_empty():
		return
	_side.daily.set_badge("!" if Daily.free_try() and not Daily.done() else "")
	var left := Wallet.ad_coins_left()
	_side.ad.set_badge(str(left) if left > 0 else "")
	_side.ad.disabled = left <= 0
	_side.ad.text = "+%d" % Wallet.AD_COINS if left > 0 else "Mañana"
	_side.ad.queue_redraw()


func _build_panels() -> void:
	_panels.shop = Shop.new()
	_panels.shop.look_changed.connect(_apply_look)
	_panels.tournament = TournamentPanel.new()
	_panels.tournament.play_match.connect(func() -> void: start_event.emit("tournament"))
	_panels.daily = ChallengePanel.new()
	_panels.daily.play_match.connect(func() -> void: start_event.emit("daily"))
	_panels.stats = StatsPanel.new()
	_panels.settings = SettingsPanel.new()
	_panels.profile = ProfilePanel.new()
	_panels.profile.customize.connect(open_customize)
	for key: String in _panels.keys():
		var pn: Control = _panels[key]
		pn.sfx = sfx
		add_child(pn)
		pn.closed.connect(_refresh_wallet)
		if pn.has_signal("coins_changed"):
			pn.coins_changed.connect(_refresh_wallet)


func _open_panel(key: String) -> void:
	if key == "ranked":
		# El ranked es en línea: se abre en la pantalla de red.
		open_ranked.emit()
		return
	_panels[key].open()


## Bienvenida de la primera vez: partida guiada o, si no, no se vuelve a ofrecer
## (sigue en el botón "Aprende").
func _offer_tutorial() -> void:
	if not is_inside_tree():
		return
	var pop = OverlayPanel.new()
	pop.sfx = sfx
	add_child(pop)
	pop.frame(Rect2(60, 360, 600, 520), "¡Bienvenido!")
	var icon := TextureRect.new()
	icon.texture = UISkin.tex("kit_icon_bulb")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.position = Vector2(256, 88)
	icon.size = Vector2(88, 88)
	pop.panel.add_child(icon)
	pop.para("¿Es tu primera vez? Juega una partida guiada contra la CPU fácil: te explicamos cada paso y ganas 200 monedas.",
			UI.BODY - 2, UI.CREAM, Rect2(36, 186, 528, 130))
	var go: FancyButton = pop.button("Partida guiada", UI.PRIMARY, Rect2(70, 330, 460, UI.TOUCH))
	go.pressed.connect(func() -> void:
		pop.visible = false
		start_event.emit("tutorial"))
	var later: FancyButton = pop.button("Ahora no", UI.NEUTRAL, Rect2(170, 430, 260, 70), 28)
	later.pressed.connect(func() -> void:
		Settings.rules.tutorial = 2
		Settings.save()
		pop.close()
		if Wallet.daily_available():
			_toggle_daily(true))
	pop.open()


## El modo elegido en el carrusel vale para la CPU y para las salas que yo cree.
func _on_mode(index: int) -> void:
	_click()
	# La meta no pinta nada en torneo y ranked.
	_meta_btn.visible = Carousel.event_of(index) == ""
	# Torneo y ranked no son una regla de puntos: no se guardan como modo.
	if Carousel.event_of(index) != "":
		return
	Settings.rules.mode = index
	Settings.save()


## Capa oscura a pantalla completa con un panel centrado llamado "Panel" (ver _pop).
func _overlay(rect: Rect2) -> Panel:
	var layer := ColorRect.new()
	layer.color = Color(0, 0, 0, 0.5)
	_cover_screen(layer)
	layer.visible = false
	add_child(layer)
	var pn := Panel.new()
	pn.name = "Panel"
	# La capa empieza fuera de pantalla (ver _cover_screen): se descuenta su origen.
	pn.position = rect.position - layer.position
	pn.size = rect.size
	pn.pivot_offset = pn.size * 0.5
	layer.add_child(pn)
	UISkin.dress(pn)
	return pn


## Tarjeta "Prepara tu partida", que se abre tras elegir el modo: la meta y,
## contra la CPU, la dificultad y la apuesta, con lo que se cobra si se gana.
## En línea solo se elige la meta: las apuestas en línea necesitan cuentas de
## jugador guardadas en el servidor (aún no las hay).
func _build_setup() -> void:
	var pn := _overlay(Rect2(40, 22, 640, 1236))
	_setup = pn.get_parent()
	_setup_title = _label("", UI.TITLE, GOLD, Rect2(0, 18, 640, 56), pn)
	UISkin.title(_setup_title)
	_setup_sub = _label("", UI.CAPTION, UI.CREAM_MUTED, Rect2(0, 70, 640, 36), pn)

	# Filas compactas (chips de 72) para que quepa también "Fichas".
	_label("Meta de puntos", UI.BODY, UI.LABEL, Rect2(36, 106, 568, 40), pn, HORIZONTAL_ALIGNMENT_LEFT)
	for i in State.TARGETS.size():
		var b := _chip(pn, "%d" % State.TARGETS[i], Rect2(36 + i * 146, 144, 134, 72))
		b.pressed.connect(_pick.bind("target", State.TARGETS[i]))
		_target_chips.append(b)

	# Solo contra la CPU.
	_setup_cpu = Control.new()
	_setup_cpu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pn.add_child(_setup_cpu)
	_label("Jugadores", UI.BODY, UI.LABEL, Rect2(36, 226, 568, 40), _setup_cpu, HORIZONTAL_ALIGNMENT_LEFT)
	for i in FORMATS.size():
		var b := _chip(_setup_cpu, FORMATS[i][0], Rect2(36 + i * 194, 264, 180, 72))
		b.pressed.connect(_pick.bind("format", i))
		_format_chips.append(b)
	_format_desc = _label("", UI.CAPTION, UI.CREAM_MUTED, Rect2(10, 338, 620, 34), _setup_cpu)
	# Doble seis (28 fichas, 7 cada uno) o doble nueve (55, 10 cada uno).
	_label("Fichas", UI.BODY, UI.LABEL, Rect2(36, 374, 568, 40), _setup_cpu, HORIZONTAL_ALIGNMENT_LEFT)
	for i in SETS.size():
		var b := _chip(_setup_cpu, SETS[i], Rect2(36 + i * 291, 412, 277, 72))
		b.pressed.connect(_pick.bind("nine", i))
		_set_chips.append(b)
	_label("Dificultad", UI.BODY, UI.LABEL, Rect2(36, 494, 568, 40), _setup_cpu, HORIZONTAL_ALIGNMENT_LEFT)
	for i in DIFFICULTIES.size():
		var b := _chip(_setup_cpu, "", Rect2(36 + i * 194, 532, 180, 72))
		b.pressed.connect(_pick.bind("difficulty", i))
		_diff_chips.append(b)
	_diff_desc = _label("", UI.CAPTION, UI.CREAM_MUTED, Rect2(10, 606, 620, 34), _setup_cpu)
	_label("Apuesta", UI.BODY, UI.LABEL, Rect2(36, 642, 568, 40), _setup_cpu, HORIZONTAL_ALIGNMENT_LEFT)
	for i in Wallet.BETS.size():
		var b := _chip(_setup_cpu, "", Rect2(36 + (i % 3) * 194, 680 + (i / 3) * 82, 180, 72))
		var coin: CoinIcon = CoinIcon.new()
		coin.position = Vector2(14, 19)
		coin.size = Vector2(34, 34)
		b.add_child(coin)
		b.pressed.connect(_pick.bind("bet", Wallet.BETS[i]))
		_bet_chips.append(b)
	_setup_prize = _label("", UI.BODY, GOLD, Rect2(10, 846, 620, 48), _setup_cpu)

	# Solo en línea.
	_setup_online = _label("", UI.BODY, UI.CREAM_MUTED, Rect2(40, 280, 560, 360), pn)
	# El ajuste de línea va antes que el texto: si no, la etiqueta ya creció a lo ancho.
	_setup_online.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_setup_online.text = "En línea, la meta vale para las salas que tú crees.\n\nPor ahora se juega sin apostar monedas: las apuestas en línea llegarán con las cuentas de jugador."

	_setup_note = _label("", UI.CAPTION, UI.WARN, Rect2(20, 896, 600, 80), pn)
	_setup_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_setup_go = FancyButton.new()
	_setup_go.setup("", UI.PRIMARY, UI.TITLE)
	_setup_go.position = Vector2(70, 988)
	_setup_go.size = Vector2(500, 108)
	pn.add_child(_setup_go)
	_setup_go.pressed.connect(_setup_play)
	var close: FancyButton = FancyButton.new()
	close.setup("Volver", UI.NEUTRAL, UI.BUTTON)
	close.position = Vector2(190, 1120)
	close.size = Vector2(260, UI.TOUCH)
	pn.add_child(close)
	close.pressed.connect(_click)
	close.pressed.connect(func() -> void:
		_setup.visible = false
		_refresh_meta())


## Botón de opción de la tarjeta (meta, dificultad o apuesta).
func _chip(parent: Node, text: String, rect: Rect2) -> FancyButton:
	var b: FancyButton = FancyButton.new()
	b.setup(text, UI.NEUTRAL, UI.BODY)
	b.position = rect.position
	b.size = rect.size
	parent.add_child(b)
	return b


func _open_setup(online: bool) -> void:
	_click()
	_setup_is_online = online
	# Si la apuesta de la última vez ya no se puede pagar, se propone la mayor que sí.
	if not online and Wallet.cant_play(0, Settings.rules.bet) != "":
		for bet: int in Wallet.BETS:
			if Wallet.cant_play(0, bet) == "":
				Settings.rules.bet = bet
	_setup_note.text = ""
	_refresh_setup()
	_pop(_setup, true)


func _refresh_meta() -> void:
	_meta_btn.text = "Meta:  %d puntos" % Settings.rules.target


func _next_target() -> void:
	_click()
	var i := State.TARGETS.find(Settings.rules.target)
	Settings.rules.target = State.TARGETS[(i + 1) % State.TARGETS.size()]
	Settings.save()
	_refresh_meta()


func _pick(key: String, value: int) -> void:
	_click()
	Settings.rules[key] = value
	Settings.save()
	_setup_note.text = ""
	_refresh_setup()
	_refresh_meta()


## Pinta la opción elegida en dorado y las bloqueadas por nivel, apagadas.
func _refresh_setup() -> void:
	var online := _setup_is_online
	_setup_title.text = State.MODE_NAMES[clampi(Settings.rules.mode, 0, State.MODE_NAMES.size() - 1)]
	_setup_sub.text = "En línea con amigos" if online else "Contra la CPU  ·  tienes %s monedas" % _thousands(Wallet.coins())
	_setup_cpu.visible = not online
	_setup_online.visible = online
	## Elegido en oro; sin elegir, madera oscura para que el oro destaque (DISEÑO.md).
	var chosen := UI.BUY
	var idle := UI.NEUTRAL.darkened(0.35)
	for i in _target_chips.size():
		_target_chips[i].set_color(chosen if State.TARGETS[i] == Settings.rules.target else idle)
	var fmt: int = clampi(Settings.rules.get("format", 0), 0, FORMATS.size() - 1)
	for i in _format_chips.size():
		_format_chips[i].set_color(chosen if i == fmt else idle)
	_format_desc.text = FORMATS[fmt][1]
	var nine: int = clampi(Settings.rules.get("nine", 0), 0, 1)
	for i in _set_chips.size():
		_set_chips[i].set_color(chosen if i == nine else idle)
	var level := Wallet.level()
	for i in _diff_chips.size():
		var need: int = Wallet.DIFF_LEVEL[i]
		var b: FancyButton = _diff_chips[i]
		b.disabled = level < need
		b.text = DIFFICULTIES[i][0] if not b.disabled else "%s\nnivel %d" % [DIFFICULTIES[i][0], need]
		b.add_theme_font_size_override("font_size", UI.CAPTION + 2 if b.disabled else UI.BODY)
		b.set_color(chosen if i == Settings.rules.difficulty else idle)
	var diff: int = clampi(Settings.rules.difficulty, 0, DIFFICULTIES.size() - 1)
	_diff_desc.text = DIFFICULTIES[diff][1]
	for i in _bet_chips.size():
		var bet: int = Wallet.BETS[i]
		var b: FancyButton = _bet_chips[i]
		b.disabled = level < Wallet.BET_LEVEL[i]
		# La moneda solo en las que se pueden elegir; en las bloqueadas, el nivel que falta.
		b.text = "   " + _thousands(bet) if not b.disabled else "nivel %d" % Wallet.BET_LEVEL[i]
		b.get_child(b.get_child_count() - 1).visible = not b.disabled
		# Las que no alcanzan se ven, pero más apagadas.
		b.modulate.a = 0.55 if Wallet.coins() < bet else 1.0
		b.set_color(chosen if bet == Settings.rules.bet else idle)
	_setup_prize.text = "Apuestas %s   →   si ganas, %s" % [_thousands(Settings.rules.bet),
			_thousands(Wallet.prize(diff, Settings.rules.bet, fmt))]
	_setup_go.text = "Continuar" if online else "¡Jugar!"
	_setup_note.text = ""
	if online and Settings.rules.mode >= State.NET_MODES:
		_setup_note.text = "%s es solo contra la CPU: en línea se juega Clásico." % State.MODE_NAMES[Settings.rules.mode]


## Empieza: en línea pasa a "Jugar con amigos"; contra la CPU cobra la apuesta
## y abre la partida, o explica por qué no se puede.
func _setup_play() -> void:
	if _setup_is_online:
		_click()
		open_online.emit()
		return
	var diff: int = Settings.rules.difficulty
	var reason := Wallet.cant_play(diff, Settings.rules.bet)
	if reason != "":
		if sfx != null:
			sfx.play("bad")
		if Wallet.rescue_available():
			reason += " Toca «Ayuda» arriba para recibir %d gratis." % Wallet.RESCUE
		elif Wallet.daily_available():
			reason += " Recoge tu regalo arriba."
		_setup_note.text = reason
		return
	_click()
	Wallet.pay_entry(diff, Settings.rules.bet)
	start_game.emit(diff)


# ------------------------------------------------------------ monedas y nivel

## Barra de arriba: nivel con su experiencia, botón de regalo o ayuda, y saldo.
func _build_top_bar() -> void:
	var badge := TextureRect.new()
	badge.texture = UISkin.tex("level_badge")
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.position = Vector2(18, 10)
	badge.size = Vector2(72, 72)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(badge)
	_level_num = _label("", 30, UISkin.CREAM, Rect2(0, -2, 72, 72), badge)
	_level_num.add_theme_color_override("font_outline_color", UISkin.TITLE_OUTLINE)
	_level_num.add_theme_constant_override("outline_size", 6)
	_level_lbl = _label("", UI.CAPTION, UISkin.CREAM, Rect2(100, 6, 150, 36), self, HORIZONTAL_ALIGNMENT_LEFT)
	_level_lbl.clip_text = true
	var bar_bg := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#1a120b")
	sb.border_color = Color(1, 1, 1, 0.18)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(XP_H * 0.5))
	bar_bg.add_theme_stylebox_override("panel", sb)
	bar_bg.position = Vector2(100, 46)
	bar_bg.size = Vector2(XP_BAR, XP_H)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar_bg)
	_xp_fill = Panel.new()
	# Esta sí es 9-slice: cambia de ancho con la experiencia.
	var fb := StyleBoxTexture.new()
	fb.texture = UISkin.tex("xp_fill")
	fb.texture_margin_left = 9
	fb.texture_margin_right = 9
	_xp_fill.add_theme_stylebox_override("panel", fb)
	_xp_fill.position = Vector2(3, 3)
	_xp_fill.size = Vector2(0, XP_H - 6)
	_xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.add_child(_xp_fill)
	_xp_text = _label("", 18, Color.WHITE, Rect2(0, 0, XP_BAR, XP_H - 1), bar_bg)
	_xp_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_xp_text.add_theme_constant_override("outline_size", 4)

	# Tocar el nivel abre el perfil (nombre en línea y avatar).
	var me := Button.new()
	me.flat = true
	me.focus_mode = Control.FOCUS_NONE
	me.position = Vector2(10, 4)
	me.size = Vector2(244, 82)
	add_child(me)
	me.pressed.connect(func() -> void:
		_click()
		_open_panel("profile"))

	_gift_btn = _button("", UI.DANGER, Rect2(258, 18, 130, 58), 28, 0.1)
	_gift_btn.pressed.connect(_on_gift)

	# Saldo: gemas y monedas. Cada píldora abre la tienda en su pestaña.
	var gems := _pill(Rect2(404, 18, 132, 58), GemIcon.new(), Rect2(-16, -4, 64, 64), Shop.GEMS)
	_gems_lbl = _pill_label(gems, Rect2(42, 0, 82, 58))
	var coins := _pill(Rect2(552, 18, 152, 58), CoinIcon.new(), Rect2(-22, -9, 76, 76), Shop.COINS)
	_coins_lbl = _pill_label(coins, Rect2(50, 0, 94, 58))
	_refresh_wallet()


## Píldora oscura con el icono asomando por la izquierda; al tocarla, la tienda
## se abre en la pestaña `tab`.
func _pill(rect: Rect2, icon: Control, icon_rect: Rect2, tab: int) -> Control:
	var pill := Button.new()
	pill.focus_mode = Control.FOCUS_NONE
	var pb := StyleBoxFlat.new()
	pb.bg_color = Color("#1a120b", 0.9)
	pb.border_color = Color(1, 1, 1, 0.15)
	pb.set_border_width_all(2)
	pb.set_corner_radius_all(30)
	for state in ["normal", "hover", "pressed", "focus"]:
		pill.add_theme_stylebox_override(state, pb)
	pill.position = rect.position
	pill.size = rect.size
	add_child(pill)
	icon.position = icon_rect.position
	icon.size = icon_rect.size
	pill.add_child(icon)
	pill.pressed.connect(func() -> void:
		_click()
		_panels.shop.open_tab(tab))
	return pill


func _pill_label(pill: Control, rect: Rect2) -> Label:
	var lb := _label("", UI.CAPTION, UISkin.CREAM, rect, pill, HORIZONTAL_ALIGNMENT_RIGHT)
	lb.add_theme_font_override("font", UISkin.heavy())
	lb.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	lb.add_theme_constant_override("shadow_offset_y", 2)
	return lb


func _refresh_wallet() -> void:
	var p := Wallet.progress()
	_level_num.text = str(p[0])
	_level_lbl.text = "Nivel %d" % p[0]
	_xp_fill.size.x = maxf((XP_BAR - 6.0) * p[1] / float(p[2]), 18.0)
	_xp_text.text = "%d/%d" % [p[1], p[2]]
	_coins_lbl.text = _thousands(Wallet.coins())
	_gems_lbl.text = _thousands(Wallet.gems())
	# Regalo listo, ayuda si no queda ni para la apuesta más baja, o cuánto falta
	# para el próximo regalo.
	var can_claim := Wallet.daily_available() or Wallet.rescue_available()
	_gift_btn.text = "Regalo" if Wallet.daily_available() else "Ayuda" if can_claim else _short_wait(Wallet.daily_wait())
	_gift_btn.add_theme_font_size_override("font_size", 28 if can_claim else 24)
	_gift_btn.set_color(UI.DANGER if can_claim else UI.NEUTRAL)
	_gift_btn.pulse(can_claim)
	# Esperando el próximo regalo, el botón se encoge: es un dato, no una llamada
	# a la acción. Con escala (y no tamaño) para no pelear con su animación de entrada.
	_gift_btn.pivot_offset = _gift_btn.size * 0.5
	_gift_btn.scale = Vector2.ONE if can_claim else Vector2(0.72, 0.72)
	_refresh_side()


## 19800 -> "5 h 30 min"; menos de una hora, solo los minutos.
static func _wait_text(seconds: int) -> String:
	var minutes := ceili(seconds / 60.0)
	if minutes < 60:
		return "%d min" % minutes
	return "%d h %02d min" % [minutes / 60, minutes % 60]


## Para el botón del regalo: 19800 -> "5h 30m"; menos de una hora, "45m".
static func _short_wait(seconds: int) -> String:
	var minutes := ceili(seconds / 60.0)
	if minutes < 60:
		return "%dm" % minutes
	return "%dh %02dm" % [minutes / 60, minutes % 60]


## 12500 -> "12.500".
static func _thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out


func _on_gift() -> void:
	_click()
	if Wallet.rescue_available() and not Wallet.daily_available():
		_coins_won(Wallet.claim_rescue())
	else:
		# Listo para recoger o, si no, la racha y cuánto falta.
		_toggle_daily(true)


## Monedas recibidas: el saldo se actualiza y salta un "+N" junto a él.
func _coins_won(amount: int) -> void:
	_refresh_wallet()
	if sfx != null:
		sfx.play("win")
	var lb := _label("+%d" % amount, UI.TITLE, GOLD, Rect2(470, 70, 226, 60))
	lb.add_theme_color_override("font_outline_color", Color(0.2, 0.08, 0.02))
	lb.add_theme_constant_override("outline_size", 10)
	var tw := lb.create_tween().set_parallel(true)
	tw.tween_property(lb, "position:y", 30.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(lb, "modulate:a", 0.0, 0.9).set_delay(0.4)
	tw.chain().tween_callback(lb.queue_free)


## Regalo diario: siete días seguidos, cada uno con más monedas. Si se falta
## un día, la racha vuelve al primero.
func _build_daily() -> void:
	var pn := _overlay(Rect2(50, 330, 620, 560))
	_daily = pn.get_parent()
	UISkin.title(_label("Regalo diario", UI.TITLE, GOLD, Rect2(0, 20, 620, 56), pn))
	_daily_sub = _label("", UI.CAPTION, UI.CREAM_MUTED, Rect2(0, 74, 620, 36), pn)
	for i in Wallet.DAILY.size():
		# Cuatro casillas arriba y tres abajo, centradas.
		var row := 0 if i < 4 else 1
		var col := i if i < 4 else i - 4
		var count := 4 if row == 0 else 3
		var x := 310.0 - (count * 130.0 + (count - 1) * 12.0) * 0.5 + col * 142.0
		var box := Panel.new()
		box.position = Vector2(x, 128.0 + row * 128.0)
		box.size = Vector2(130, 116)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pn.add_child(box)
		_label("Día %d" % (i + 1), UI.CAPTION, UI.CREAM, Rect2(0, 8, 130, 36), box)
		var coin: CoinIcon = CoinIcon.new()
		coin.position = Vector2(14, 60)
		coin.size = Vector2(32, 32)
		box.add_child(coin)
		_label(str(Wallet.DAILY[i]), UI.BODY, GOLD, Rect2(46, 46, 80, 60), box)
		_daily_boxes.append(box)
	_daily_btn = FancyButton.new()
	_daily_btn.setup("", UI.PRIMARY, UI.BUTTON)
	_daily_btn.position = Vector2(110, 436)
	_daily_btn.size = Vector2(400, UI.TOUCH)
	pn.add_child(_daily_btn)
	_daily_btn.pressed.connect(_claim_daily)


func _toggle_daily(on: bool) -> void:
	var available := Wallet.daily_available()
	# Sin regalo listo se marca el último recogido, no el que viene.
	var today := Wallet.daily_streak() if available else mini(int(Wallet.data.streak), Wallet.DAILY.size())
	today = maxi(today, 1)
	_daily_sub.text = "Día %d seguido. Hay regalo cada 24 horas." % today if available \
			else "Próximo regalo en %s." % _wait_text(Wallet.daily_wait())
	for i in _daily_boxes.size():
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(12)
		sb.set_border_width_all(4 if i == today - 1 else 2)
		sb.border_color = GOLD if i == today - 1 else UI.BORDER
		# Los días ya recogidos de esta racha se ven apagados.
		sb.bg_color = Color(0.3, 0.5, 0.25, 0.9) if i == today - 1 else Color(0, 0, 0, 0.35 if i >= today else 0.7)
		_daily_boxes[i].add_theme_stylebox_override("panel", sb)
		_daily_boxes[i].modulate.a = 0.55 if i < today - 1 else 1.0
	_daily_btn.text = "Recoger  +%d" % Wallet.daily_amount() if available else "Cerrar"
	_daily_btn.set_color(UI.PRIMARY if available else UI.NEUTRAL)
	_pop(_daily, on)


func _claim_daily() -> void:
	_click()
	var amount := Wallet.claim_daily()
	_daily.visible = false
	if amount > 0:
		_coins_won(amount)


## Aplica al fondo del menú el aspecto recién elegido.
func _apply_look() -> void:
	_table.refresh()
	for t: Tile in _floating:
		t.refresh_style()


func _label(text: String, font_size: int, color: Color, rect: Rect2, parent: Node = null,
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
	(parent if parent != null else self).add_child(lb)
	return lb


## Botón que entra deslizándose desde abajo tras `delay` segundos.
func _button(text: String, color: Color, rect: Rect2, font_size: int, delay: float) -> FancyButton:
	var b: FancyButton = FancyButton.new()
	b.setup(text, color, font_size)
	_slide_in(b, rect, delay)
	return b


func _slide_in(b: FancyButton, rect: Rect2, delay: float) -> void:
	b.position = rect.position + Vector2(0, 40)
	b.size = rect.size
	b.modulate.a = 0.0
	add_child(b)
	b.pressed.connect(_click)
	var tw := b.create_tween().set_parallel(true)
	tw.tween_property(b, "position:y", rect.position.y, 0.45).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "modulate:a", 1.0, 0.3).set_delay(delay)


func _click() -> void:
	if sfx != null:
		sfx.play("click")


func _spawn_floating_tiles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var spots := [Vector2(110, 130), Vector2(610, 120), Vector2(90, 440), Vector2(640, 450),
			Vector2(60, 640), Vector2(665, 700), Vector2(55, 860), Vector2(660, 900),
			Vector2(130, 1140), Vector2(590, 1160), Vector2(360, 1200), Vector2(360, 80)]
	# Salen de las 28 fichas del juego barajadas: ninguna se repite.
	var set: Array = []
	for a in 7:
		for b in range(a, 7):
			set.append(Vector2i(a, b))
	for i in range(set.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Vector2i = set[i]
		set[i] = set[j]
		set[j] = tmp
	# En modo ligero, la mitad: cada ficha que flota se anima en cada imagen.
	for k in (spots.size() / 2 if Settings.lite_mode() else spots.size()):
		var pos: Vector2 = spots[k]
		var t: Tile = Tile.new()
		t.set_values(set[k].x, set[k].y)
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
	_rules.color = Color(0, 0, 0, 0.5)
	_cover_screen(_rules)
	_rules.visible = false
	add_child(_rules)

	var pn := Panel.new()
	pn.name = "Panel"
	UISkin.dress(pn)
	# _rules empieza fuera de pantalla (ver _cover_screen): se descuenta su origen.
	pn.position = Vector2(30, 120) - _rules.position
	pn.size = Vector2(660, 1040)
	pn.pivot_offset = pn.size * 0.5
	_rules.add_child(pn)

	var head := Label.new()
	head.text = "Reglas del dominó en parejas"
	head.add_theme_font_size_override("font_size", 34)
	head.add_theme_color_override("font_color", GOLD)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.position = Vector2(0, 16)
	head.size = Vector2(660, 48)
	pn.add_child(head)
	UISkin.title(head)

	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.text = RULES
	body.add_theme_font_size_override("normal_font_size", UI.CAPTION)
	body.add_theme_font_size_override("bold_font_size", UI.CAPTION)
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
	close.setup("Entendido", UI.PRIMARY, UI.BUTTON)
	close.position = Vector2(200, 940)
	close.size = Vector2(260, UI.TOUCH)
	pn.add_child(close)
	close.pressed.connect(_click)
	close.pressed.connect(_toggle_rules.bind(false))


func _toggle_rules(on: bool) -> void:
	_pop(_rules, on)


## Muestra (con un pequeño rebote) u oculta una capa con su panel "Panel".
func _pop(layer: Control, on: bool) -> void:
	layer.visible = on
	if not on:
		return
	var pn: Panel = layer.get_node("Panel")
	pn.scale = Vector2(0.7, 0.7)
	layer.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(layer, "modulate:a", 1.0, 0.2)
	tw.tween_property(pn, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
