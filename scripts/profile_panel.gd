extends "res://scripts/popup.gd"
## Perfil: el nombre con el que me ven en las salas en línea y en el ranked, y
## mi avatar. Se abre tocando el nivel del menú o "Cambiar" en Jugar con amigos.
## Cuando el juego inicie sesión con Google Play Juegos, el nombre de partida
## será el de esa cuenta (y aquí se podrá seguir cambiando).

## Se pidió cambiar el avatar: quien abre el panel muestra Personalizar.
signal customize
## El nombre cambió.
signal name_changed

const Settings = preload("res://scripts/settings.gd")
const Avatar = preload("res://scripts/avatar.gd")
const Wallet = preload("res://scripts/wallet.gd")

const W := 600.0
const H := 600.0

var _avatar: Avatar
var _name: LineEdit
var _level: Label
var _note: Label
## Sin el botón de Personalizar (en la pantalla en línea no hay menú detrás).
var show_customize := true


func _ready() -> void:
	frame(Rect2(60, 170, W, H), "Tu perfil")
	_avatar = Avatar.new()
	_avatar.position = Vector2(W * 0.5 - 60, 92)
	_avatar.size = Vector2(120, 120)
	_avatar.ring = UI.GOLD
	_avatar.ring_width = 5.0
	panel.add_child(_avatar)
	_level = label("", UI.CAPTION, UI.LABEL, Rect2(0, 220, W, 36))
	label("Tu nombre", UI.CAPTION, UI.LABEL, Rect2(50, 268, 300, 36), null, HORIZONTAL_ALIGNMENT_LEFT)
	_name = LineEdit.new()
	_name.add_theme_stylebox_override("normal", UISkin.field_box(20.0))
	_name.add_theme_stylebox_override("focus", UISkin.field_focus_box(20.0))
	_name.add_theme_font_size_override("font_size", UI.BODY)
	_name.add_theme_color_override("font_color", UI.CREAM)
	_name.add_theme_color_override("font_placeholder_color", Color(UI.CREAM, 0.5))
	_name.placeholder_text = "Escribe tu nombre"
	_name.max_length = Settings.NAME_MAX
	_name.position = Vector2(50, 306)
	_name.size = Vector2(W - 100, UI.TOUCH)
	_name.text_submitted.connect(func(_t: String) -> void: _save())
	panel.add_child(_name)
	_note = para("Así te verán en las salas en línea y en el ranked.", UI.CAPTION, UI.CREAM_MUTED,
			Rect2(40, 394, W - 80, 76))
	var y := 486.0
	if show_customize:
		var av := button("Cambiar avatar", UI.SECONDARY, Rect2(50, y, 240, UI.TOUCH_SMALL), 26)
		av.pressed.connect(func() -> void:
			_save()
			visible = false
			closed.emit()
			customize.emit())
		var ok := button("Guardar", UI.PRIMARY, Rect2(310, y, 240, UI.TOUCH_SMALL), 28)
		ok.pressed.connect(_save_and_close)
	else:
		var ok := button("Guardar", UI.PRIMARY, Rect2(150, y, 300, UI.TOUCH_SMALL), 28)
		ok.pressed.connect(_save_and_close)


func refresh() -> void:
	_name.text = Settings.player_name()
	Settings.apply_avatar(_avatar)
	_level.text = "Nivel %d" % int(Wallet.progress()[0])
	_note.add_theme_color_override("font_color", UI.CREAM_MUTED)


func _save() -> bool:
	var n := _name.text.strip_edges()
	if n == "":
		return false
	if n != Settings.player_name():
		Settings.set_player_name(n)
		name_changed.emit()
	Settings.apply_avatar(_avatar)
	return true


func _save_and_close() -> void:
	if not _save():
		_note.text = "Escribe un nombre."
		_note.add_theme_color_override("font_color", UI.WARN)
		return
	close()
