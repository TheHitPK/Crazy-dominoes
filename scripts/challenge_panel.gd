extends "res://scripts/popup.gd"
## Desafío del día: el mismo reparto para todos, un intento gratis y los demás
## viendo un anuncio.

signal play_match

const Daily = preload("res://scripts/daily_challenge.gd")
const State = preload("res://scripts/domino_state.gd")
const Ads = preload("res://scripts/ads.gd")

const W := 620.0
var _mode_lbl: Label
var _reward_lbl: Label
var _streak_lbl: Label
var _go: FancyButton


func _ready() -> void:
	frame(Rect2(50, 250, W, 760), "Desafío del día")
	var icon := TextureRect.new()
	icon.texture = UISkin.tex("kit_icon_calendar")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.position = Vector2(W * 0.5 - 50, 88)
	icon.size = Vector2(100, 100)
	panel.add_child(icon)
	para("Hoy todos juegan el mismo reparto, en parejas contra la CPU difícil y a %d puntos. Gánalo para cobrar y no romper la racha." % Daily.TARGET,
			UI.CAPTION, UI.CREAM_MUTED, Rect2(30, 200, W - 60, 110))
	var box := well(Rect2(30, 320, W - 60, 190))
	_mode_lbl = label("", UI.BODY, UI.LABEL, Rect2(0, 14, W - 60, 44), box)
	coin(Vector2(W * 0.5 - 110, 66), 48.0, box)
	_reward_lbl = label("", UI.TITLE, UI.GOLD, Rect2(W * 0.5 - 56, 62, 200, 56), box, HORIZONTAL_ALIGNMENT_LEFT)
	_streak_lbl = label("", UI.CAPTION, UI.CREAM, Rect2(0, 128, W - 60, 44), box)
	_go = button("", UI.PRIMARY, Rect2(60, 536, W - 120, UI.TOUCH), UI.BUTTON)
	_go.pressed.connect(_on_go)
	var back := button("Volver", UI.NEUTRAL, Rect2(185, 646, 250, UI.TOUCH_SMALL), 28)
	back.pressed.connect(close)


func refresh() -> void:
	_mode_lbl.text = "Modo de hoy: %s" % State.MODE_NAMES[Daily.mode()]
	_reward_lbl.text = thousands(Daily.reward())
	var s := int(Daily.data.streak)
	_streak_lbl.text = "Racha: %d %s" % [s, "día" if s == 1 else "días"] if s > 0 else "Empieza tu racha hoy"
	if Daily.done():
		_go.text = "¡Superado! Vuelve mañana"
		_go.disabled = true
		_go.icon = null
	elif Daily.free_try():
		_go.text = "Jugar el desafío"
		_go.disabled = false
		_go.icon = null
	else:
		_go.text = "Otro intento"
		_go.disabled = false
		_go.set_icon("video", 40)


func _on_go() -> void:
	if Daily.free_try():
		_start()
		return
	var ads := Ads.get_ads()
	if ads != null:
		ads.show_rewarded(_start)


func _start() -> void:
	Daily.use_try()
	visible = false
	play_match.emit()
