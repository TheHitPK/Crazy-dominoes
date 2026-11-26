extends "res://scripts/popup.gd"
## Torneo: elegir copa (entrada, premio) y, con uno en marcha, el cuadro de
## cuartos, semifinal y final con el botón para jugar la ronda que toca.

signal play_match
signal coins_changed

const Tournament = preload("res://scripts/tournament.gd")
const Wallet = preload("res://scripts/wallet.gd")

const W := 640.0
## Columnas del cuadro: cuartos, semifinal, final y campeón.
const COL_X := [16.0, 168.0, 320.0, 472.0]
const BOX := Vector2(150, 52)
const TOP := 104.0
const STEP := 92.0

var _pick: Control
var _bracket: Control
var _cup_btns: Array = []
var _cup_notes: Array = []
var _status: Label
var _go: FancyButton
var _note: Label


func _ready() -> void:
	frame(Rect2(40, 22, W, 1236), "Torneo")
	_build_pick()
	_bracket = Control.new()
	_bracket.size = panel.size
	_bracket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_bracket)
	_bracket.draw.connect(_draw_lines)
	_status = para("", UI.BODY, UI.CREAM, Rect2(30, 860, W - 60, 110), _bracket)
	_go = button("", UI.PRIMARY, Rect2(70, 984, W - 140, UI.TOUCH), UI.BUTTON)
	_go.pressed.connect(_on_go)
	var back := button("Volver", UI.NEUTRAL, Rect2(195, 1124, 250, UI.TOUCH_SMALL), 28)
	back.pressed.connect(close)


## Elegir copa: explicación y una tarjeta por copa.
func _build_pick() -> void:
	_pick = Control.new()
	_pick.size = panel.size
	_pick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_pick)
	para("8 jugadores, eliminación directa: cuartos, semifinal y final. Tus partidas son 1 contra 1 a 50 puntos "
			+ "(la final, a 100). Si pierdes, quedas fuera y cobras según hasta dónde llegaste.",
			UI.CAPTION - 2, UI.CREAM_MUTED, Rect2(30, 80, W - 60, 170), _pick)
	for i in Tournament.CUPS.size():
		var c: Dictionary = Tournament.CUPS[i]
		var box := well(Rect2(30, 262 + i * 210, W - 60, 192), _pick)
		var icon := TextureRect.new()
		icon.texture = UISkin.tex("kit_icon_trophy")
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.modulate = c.color
		icon.position = Vector2(18, 22)
		icon.size = Vector2(80, 80)
		box.add_child(icon)
		label(c.name, UI.BODY + 4, c.color, Rect2(116, 14, 300, 44), box, HORIZONTAL_ALIGNMENT_LEFT)
		var entry := int(c.entry)
		label("Entrada %s  ·  Campeón %s" % [thousands(entry), thousands(roundi(entry * Tournament.PRIZE[3]))],
				UI.CAPTION, UI.CREAM, Rect2(116, 58, 460, 36), box, HORIZONTAL_ALIGNMENT_LEFT)
		label("Finalista %s  ·  Semifinal %s" % [thousands(roundi(entry * Tournament.PRIZE[2])),
				thousands(roundi(entry * Tournament.PRIZE[1]))], UI.CAPTION - 2, UI.CREAM_MUTED,
				Rect2(116, 92, 460, 32), box, HORIZONTAL_ALIGNMENT_LEFT)
		_cup_notes.append(para("", UI.CAPTION - 4, UI.WARN, Rect2(18, 128, 330, 56), box))
		_cup_notes[-1].horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var b := button("Entrar", UI.PRIMARY, Rect2(W - 260, 120, 190, 64), UI.BODY, box)
		b.set_icon("trophy", 34)
		b.pressed.connect(_enter.bind(i))
		_cup_btns.append(b)
	_note = para("", UI.CAPTION, UI.WARN, Rect2(30, 900, W - 60, 80), _pick)


func refresh() -> void:
	var on := Tournament.active()
	_pick.visible = not on
	_bracket.visible = on
	_go.visible = on
	_note.text = ""
	if not on:
		title_lbl.text = "Torneo"
		for i in _cup_btns.size():
			var why := Tournament.cant_enter(i)
			_cup_btns[i].disabled = why != ""
			_cup_notes[i].text = why
		return
	title_lbl.text = Tournament.cup().name
	_fill_bracket()


func _enter(i: int) -> void:
	if not Tournament.start(i):
		_note.text = Tournament.cant_enter(i)
		play("bad")
		return
	coins_changed.emit()
	play("shuffle")
	refresh()


# ------------------------------------------------------------ cuadro

## Casilla de la ronda `r` (0-3), posición `i` dentro de la ronda.
func _box_rect(r: int, i: int) -> Rect2:
	var span := STEP * pow(2, r)
	var y := TOP + span * i + (span - STEP) * 0.5
	return Rect2(Vector2(COL_X[r], y), BOX)


func _fill_bracket() -> void:
	for c in _bracket.get_children():
		if c != _status:
			c.queue_free()
	var players: Array = Tournament.data.players
	var rounds: Array = Tournament.data.rounds
	for r in 4:
		var names: Array = Tournament.alive(r) if r <= rounds.size() else []
		if r > rounds.size():
			names = []
		var count := 8 >> r
		for i in count:
			var rect := _box_rect(r, i)
			var who: int = names[i] if i < names.size() else -1
			var box := well(rect, _bracket)
			# Quien perdió en la ronda siguiente se ve apagado.
			var lost: bool = r < rounds.size() and who >= 0 and not rounds[r].has(who)
			var col := UI.GOLD if who == 0 else UI.CREAM
			if lost:
				col = Color(UI.CREAM, 0.35)
			var text := "—" if who < 0 else str(players[who])
			if r == 3 and who >= 0:
				col = UI.GOLD
			var lb := label(text, UI.CAPTION - 4, col, Rect2(Vector2(6, 0), rect.size - Vector2(12, 0)), box)
			lb.clip_text = true
	var head := ["Cuartos", "Semifinal", "Final", "Campeón"]
	for r in 4:
		label(head[r], UI.CAPTION - 4, UI.LABEL, Rect2(COL_X[r], TOP - 34, BOX.x, 30), _bracket)
	_bracket.queue_redraw()
	var r := Tournament.round_no()
	if Tournament.data.out:
		var champ: int = rounds[2][0]
		_status.text = "¡Eres el campeón de la %s!" % Tournament.cup().name if champ == 0 \
				else "Quedaste fuera en %s. Ganó %s." % [Tournament.ROUND_NAMES[_my_exit()].to_lower(), players[champ]]
		_go.text = "Cerrar torneo"
		_go.set_color(UI.NEUTRAL)
	else:
		_status.text = "%s contra %s, a %d puntos." % [Tournament.ROUND_NAMES[r], Tournament.opponent_name(),
				Tournament.target()]
		_go.text = "Jugar %s" % Tournament.ROUND_NAMES[r].to_lower()
		_go.set_color(UI.PRIMARY)


## Ronda en la que caí (o 2 si llegué a la final).
func _my_exit() -> int:
	var rounds: Array = Tournament.data.rounds
	for r in rounds.size():
		if not rounds[r].has(0):
			return r
	return 2


func _draw_lines() -> void:
	if not Tournament.active():
		return
	var line := Color(UI.GOLD, 0.6)
	for r in 3:
		for i in 8 >> (r + 1):
			var a := _box_rect(r, i * 2)
			var b := _box_rect(r, i * 2 + 1)
			var to := _box_rect(r + 1, i)
			var x0 := a.end.x
			var xm := x0 + (to.position.x - x0) * 0.5
			for src: Rect2 in [a, b]:
				var y := src.get_center().y
				_bracket.draw_line(Vector2(x0, y), Vector2(xm, y), line, 2.0)
			_bracket.draw_line(Vector2(xm, a.get_center().y), Vector2(xm, b.get_center().y), line, 2.0)
			_bracket.draw_line(Vector2(xm, to.get_center().y), Vector2(to.position.x, to.get_center().y), line, 2.0)


func _on_go() -> void:
	if Tournament.data.out:
		Tournament.close()
		refresh()
		return
	visible = false
	play_match.emit()
