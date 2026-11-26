extends "res://scripts/popup.gd"
## Ajustes del menú principal: sonido, vibración y manos (los mismos que el
## panel "Menú" de la partida, game.gd) y salir del juego.

const Settings = preload("res://scripts/settings.gd")

const W := 600.0
## [clave, texto]. Las de sonido van en Settings.audio; "show_hands", en Settings.data.
const OPTIONS := [["music", "Música"], ["sfx", "Efectos de sonido"], ["pass_voice", "Audios de voz"],
		["vibrate", "Vibración"], ["show_hands", "Manos visibles"]]
const ROW := 84.0

var _switches := {}


func _ready() -> void:
	# iOS no deja que una app se cierre sola, y en el navegador no tiene sentido.
	var can_quit := OS.get_name() != "iOS" and not OS.has_feature("web")
	var h := 110.0 + OPTIONS.size() * ROW + (230.0 if can_quit else 140.0)
	frame(Rect2(60, (1280 - h) * 0.5, W, h), "Ajustes")
	var y := 96.0
	for opt: Array in OPTIONS:
		var row := well(Rect2(30, y, W - 60, ROW - 12))
		label(opt[1], UI.BODY, UI.CREAM, Rect2(22, 0, 300, ROW - 12), row, HORIZONTAL_ALIGNMENT_LEFT)
		var b := button("", UI.NEUTRAL, Rect2(W - 60 - 150, 8, 136, ROW - 28), UI.CAPTION, row)
		b.pressed.connect(_toggle.bind(opt[0]))
		_switches[opt[0]] = b
		y += ROW
	y += 14.0
	if can_quit:
		var quit := button("Salir del juego", UI.DANGER, Rect2(100, y, W - 200, UI.TOUCH_SMALL), 28)
		quit.set_icon("exit", 36)
		quit.pressed.connect(func() -> void: get_tree().quit())
		y += 90.0
	var back := button("Volver", UI.NEUTRAL, Rect2(175, y, 250, UI.TOUCH_SMALL), 28)
	back.pressed.connect(close)
	var ver := str(ProjectSettings.get_setting("application/config/version", ""))
	label("Crazy Dominoes %s · Catatumbo Games" % ver if ver != "" else "Crazy Dominoes · Catatumbo Games",
			18, UI.LABEL, Rect2(0, h - 44, W, 30))


func refresh() -> void:
	for key: String in _switches.keys():
		var on := _is_on(key)
		var b: FancyButton = _switches[key]
		b.text = "Sí" if on else "No"
		b.set_color(UI.PRIMARY if on else UI.NEUTRAL)


func _is_on(key: String) -> bool:
	if key == "show_hands":
		return Settings.data.show_hands != 0
	return Settings.audio[key] != 0


func _toggle(key: String) -> void:
	var v := 0 if _is_on(key) else 1
	if key == "show_hands":
		Settings.data.show_hands = v
	else:
		Settings.audio[key] = v
	Settings.save()
	if sfx != null:
		sfx.refresh_audio()
	refresh()
