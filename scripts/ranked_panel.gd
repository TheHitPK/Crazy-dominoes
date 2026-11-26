extends "res://scripts/popup.gd"
## Ranked en línea: escudo de la liga, PR, temporada, cola de búsqueda y dos
## pestañas (premios de temporada y clasificación). Los datos llegan del
## servidor por `net` (ver net.gd, RankedNet); aquí solo se muestran.

signal coins_changed

const Ranked = preload("res://scripts/ranked.gd")
const Settings = preload("res://scripts/settings.gd")
const Wallet = preload("res://scripts/wallet.gd")

const W := 640.0
## Sin respuesta del servidor en este tiempo, se avisa (servidor dormido o viejo).
const HELLO_PATIENCE := 90.0

var net: Node
var _shield: Control
var _rank_lbl: Label
var _pr_lbl: Label
var _bar_fill: Panel
var _season_lbl: Label
var _record_lbl: Label
var _status: Label
var _tabs: Array = []
var _ladder: Control
var _top: Control
var _top_rows: Array = []
var _reward_btn: FancyButton
var _go: FancyButton
var _queued := false
var _waiting_since := 0.0
var _tab := 0


func _ready() -> void:
	frame(Rect2(40, 22, W, 1236), "Ranked")
	_shield = Control.new()
	_shield.position = Vector2(W * 0.5 - 75, 78)
	_shield.size = Vector2(150, 150)
	_shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_shield)
	_shield.draw.connect(_draw_shield)
	_rank_lbl = label("", UI.TITLE, UI.GOLD, Rect2(0, 230, W, 56))
	_rank_lbl.add_theme_font_override("font", UISkin.serif())
	_rank_lbl.add_theme_color_override("font_outline_color", UISkin.TITLE_OUTLINE)
	_rank_lbl.add_theme_constant_override("outline_size", 10)
	well(Rect2(70, 292, W - 140, 30))
	_bar_fill = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UI.GOLD
	sb.set_corner_radius_all(9)
	_bar_fill.add_theme_stylebox_override("panel", sb)
	_bar_fill.position = Vector2(76, 297)
	_bar_fill.size = Vector2(10, 20)
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_bar_fill)
	_pr_lbl = label("", UI.CAPTION, UI.CREAM, Rect2(0, 324, W, 34))
	_season_lbl = label("", UI.CAPTION - 2, UI.CREAM_MUTED, Rect2(0, 356, W, 30))
	_record_lbl = label("", UI.CAPTION - 2, UI.CREAM_MUTED, Rect2(0, 384, W, 30))

	# Pestañas: premios de temporada o clasificación.
	for i in 2:
		var b := button(["Premios", "Clasificación"][i], UI.NEUTRAL, Rect2(30 + i * 296, 422, 284, 64), UI.BODY - 2)
		b.pressed.connect(_set_tab.bind(i))
		_tabs.append(b)
	_ladder = Control.new()
	_ladder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_ladder)
	for d in Ranked.DIVISIONS.size():
		var row := well(Rect2(30, 500 + d * 52, W - 60, 46), _ladder)
		label(Ranked.DIVISIONS[d], UI.CAPTION, Ranked.DIV_COLORS[d], Rect2(16, 0, 300, 46), row,
				HORIZONTAL_ALIGNMENT_LEFT)
		coin(Vector2(W - 210, 6), 34.0, row)
		label(thousands(Ranked.SEASON_REWARD[d]), UI.CAPTION, UI.GOLD, Rect2(W - 170, 0, 90, 46), row,
				HORIZONTAL_ALIGNMENT_RIGHT)
	para("2 contra 2 contra otras personas. Si en %d s no hay 4, se rellenan los asientos con CPU. Ganar da %d PR (más en racha); perder quita %d, la mitad en Bronce y Plata. Salir a mitad cuenta como derrota." % [Ranked.FILL_AFTER, Ranked.WIN, Ranked.LOSS],
			UI.CAPTION - 4, UI.CREAM_MUTED, Rect2(30, 812, W - 60, 96), _ladder)
	_top = Control.new()
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_top)
	var box := well(Rect2(30, 500, W - 60, 410), _top)
	for i in 10:
		var rank := label("", UI.CAPTION, UI.CREAM, Rect2(16, 8 + i * 39, W - 92, 38), box, HORIZONTAL_ALIGNMENT_LEFT)
		var pr := label("", UI.CAPTION, UI.GOLD, Rect2(16, 8 + i * 39, W - 92, 38), box, HORIZONTAL_ALIGNMENT_RIGHT)
		_top_rows.append([rank, pr])

	_status = para("", UI.CAPTION, UI.WARN, Rect2(30, 912, W - 60, 70))
	_reward_btn = button("", UI.BUY, Rect2(70, 984, W - 140, UI.TOUCH), UI.BUTTON - 4)
	_reward_btn.pressed.connect(func() -> void: net.ranked_claim())
	_go = button("Buscar partida", UI.PRIMARY, Rect2(70, 984, W - 140, UI.TOUCH), UI.BUTTON)
	_go.set_icon("shield", 44)
	_go.pressed.connect(_toggle_queue)
	var back := button("Volver", UI.NEUTRAL, Rect2(195, 1124, 250, UI.TOUCH_SMALL), 28)
	back.pressed.connect(close)

	net.ranked_profile.connect(func(_r: Dictionary) -> void: refresh())
	net.ranked_queue_changed.connect(_on_queue)
	net.ranked_top.connect(_on_top)
	net.ranked_claimed.connect(func(coins: int) -> void:
		Wallet.add_coins(coins)
		play("win")
		coins_changed.emit()
		_status.text = "+%s monedas del premio de temporada." % thousands(coins))
	net.failed.connect(func(message: String) -> void:
		_queued = false
		_status.text = message
		refresh())
	_set_tab(0)


## Abre la pantalla y conecta con el servidor para pedir mi ficha.
func start(address: String, player_name: String) -> void:
	_waiting_since = Time.get_ticks_msec() / 1000.0
	_status.text = "Conectando… (si el servidor dormía, puede tardar un minuto)" if net.ranked_me.is_empty() else ""
	var last: Dictionary = net.ranked_last
	if not last.is_empty():
		var text := "%s  %+d PR  ·  %s" % ["¡Victoria!" if last.get("won", false) else "Derrota", int(last.delta),
				str(last.rank)]
		if last.get("promoted", false):
			text = "¡Subes a %s!  %+d PR" % [str(last.rank), int(last.delta)]
		_status.text = text
		net.ranked_last = {}
	net.ranked_connect(address, player_name, Settings.player_token())
	open()


func refresh() -> void:
	var me: Dictionary = net.ranked_me
	var ready := not me.is_empty()
	var pr := int(me.get("pr", 0))
	var d := Ranked.division(pr)
	_rank_lbl.text = Ranked.rank_name(pr) if ready else "…"
	_rank_lbl.add_theme_color_override("font_color", Ranked.DIV_COLORS[d])
	var master := pr >= Ranked.MASTER
	var k := 1.0 if master else Ranked.tier_progress(pr) / float(Ranked.PER_TIER)
	_bar_fill.size.x = maxf((W - 152) * k, 10.0)
	_pr_lbl.text = "%d PR" % pr if master else "%d / %d PR para subir" % [Ranked.tier_progress(pr), Ranked.PER_TIER]
	_season_lbl.text = "Temporada %s  ·  quedan %d días" % [str(me.get("season", Ranked.season_id())), Ranked.days_left()]
	_record_lbl.text = "Esta temporada: %d ganadas de %d  ·  racha %d" % [int(me.get("wins", 0)), int(me.get("games", 0)),
			int(me.get("streak", 0))]
	var reward := int(me.get("reward", 0))
	_reward_btn.visible = reward > 0 and not _queued
	_reward_btn.text = "Recoger premio de temporada  +%s" % thousands(reward)
	_go.visible = not _reward_btn.visible
	_go.disabled = not ready
	_go.text = "Cancelar búsqueda" if _queued else "Buscar partida"
	_go.set_color(UI.DANGER if _queued else UI.PRIMARY)
	if ready and _status.text.begins_with("Conectando"):
		_status.text = ""
	_shield.queue_redraw()


func _process(_delta: float) -> void:
	if visible and net.ranked_me.is_empty() and _status.text.begins_with("Conectando") \
			and Time.get_ticks_msec() / 1000.0 - _waiting_since > HELLO_PATIENCE:
		_status.text = "El servidor no responde al ranked. Puede que aún no esté actualizado."


func _toggle_queue() -> void:
	_queued = not _queued
	net.ranked_queue(_queued, Settings.my_look())
	_status.text = "Buscando partida…" if _queued else ""
	refresh()


func _on_queue(info: Dictionary) -> void:
	if not info.get("on", false):
		_queued = false
		refresh()
		return
	var left := maxi(int(info.fill) - int(info.secs), 0)
	_status.text = "Buscando partida…  %d:%02d  ·  %d de 4 personas.%s" % [int(info.secs) / 60, int(info.secs) % 60,
			int(info.waiting), "  Se rellena con CPU en %d s." % left if left > 0 else ""]


func _set_tab(i: int) -> void:
	_tab = i
	for k in _tabs.size():
		_tabs[k].set_color(UI.BUY if k == i else UI.NEUTRAL.darkened(0.35))
	_ladder.visible = i == 0
	_top.visible = i == 1
	if i == 1:
		for row: Array in _top_rows:
			row[0].text = ""
			row[1].text = ""
		_top_rows[0][0].text = "Cargando…"
		net.ranked_request_top()


func _on_top(rows: Array, me: int) -> void:
	for i in _top_rows.size():
		var r: Array = _top_rows[i]
		if i < rows.size():
			r[0].text = "%d.  %s   ·  %s" % [i + 1, str(rows[i].name), Ranked.rank_name(int(rows[i].pr))]
			r[1].text = "%d PR" % int(rows[i].pr)
			var col := UI.GOLD if i == me else UI.CREAM
			r[0].add_theme_color_override("font_color", col)
		else:
			r[0].text = "Aún no hay nadie esta temporada." if i == 0 and rows.is_empty() else ""
			r[1].text = ""
	if me >= _top_rows.size():
		_top_rows[9][0].text = "%d.  Tú" % (me + 1)
		_top_rows[9][1].text = "%d PR" % int(net.ranked_me.get("pr", 0))


func _draw_shield() -> void:
	var pr := int(net.ranked_me.get("pr", 0)) if net != null else 0
	var d := Ranked.division(pr)
	var col: Color = Ranked.DIV_COLORS[d]
	var s := _shield.size
	var pts := PackedVector2Array([Vector2(s.x * 0.5, 4), Vector2(s.x - 8, 26), Vector2(s.x - 14, s.y * 0.62),
			Vector2(s.x * 0.5, s.y - 4), Vector2(14, s.y * 0.62), Vector2(8, 26)])
	_shield.draw_colored_polygon(pts, UISkin.TITLE_OUTLINE)
	var c := s * 0.5
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(c + (p - c) * 0.86)
	_shield.draw_colored_polygon(inner, col.darkened(0.25))
	var top := PackedVector2Array()
	for p in inner:
		top.append(Vector2(p.x, minf(p.y, c.y)))
	_shield.draw_colored_polygon(top, col)
	var stars := 1 if d == Ranked.DIVISIONS.size() - 1 else 1 + (pr / Ranked.PER_TIER) % 3
	for i in stars:
		_star(Vector2(c.x + (i - (stars - 1) * 0.5) * 38, c.y + 4), 22.0 if stars > 1 else 34.0)


func _star(at: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		pts.append(at + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	_shield.draw_colored_polygon(pts, Color(1, 0.97, 0.85))


func close() -> void:
	if _queued:
		net.ranked_queue(false, {})
		_queued = false
	super.close()
