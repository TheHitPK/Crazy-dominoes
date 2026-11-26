extends Button
## Botón con relieve y animación de escala al pasar el ratón y al pulsar.

const UISkin = preload("res://scripts/ui_skin.gd")

var _tw: Tween
var _pulse: Tween
var _color := Color.WHITE
## Capas del kit: cara teñida y aro dorado (ver set_color).
var _body: NinePatchRect
var _frame: NinePatchRect


func setup(txt: String, color: Color, font_size: int = 24) -> void:
	text = txt
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_font_size_override("font_size", font_size)
	# Misma letra que los títulos de las tarjetas del menú (mode_carousel.gd):
	# serif en negrita con contorno marrón oscuro y sombra.
	add_theme_font_override("font", UISkin.serif())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		add_theme_color_override(c, Color.WHITE)
	add_theme_color_override("font_outline_color", UISkin.TITLE_OUTLINE)
	add_theme_constant_override("outline_size", 6)
	add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	add_theme_constant_override("shadow_offset_y", 3)
	add_theme_constant_override("shadow_offset_x", 0)
	add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.8))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	set_color(color)
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	mouse_entered.connect(_scale_to.bind(1.08, 0.22))
	mouse_exited.connect(_scale_to.bind(1.0, 0.22))
	button_down.connect(_scale_to.bind(0.93, 0.08))
	# En pantalla táctil no hay "mouse_exited" al levantar el dedo: vuelve a su tamaño.
	button_up.connect(_scale_to.bind(1.0, 0.18))


## Cambia el color del botón (por ejemplo, un interruptor encendido/apagado).
## Con el kit (assets/ui/kit_btn_*), el color tiñe la cara y encima va el aro
## dorado con brillo; sin él, un color plano con relieve.
func set_color(color: Color) -> void:
	_color = color
	if _kit_ready():
		var push := [StyleBoxEmpty.new(), StyleBoxEmpty.new()]
		for i in 2:
			push[i].content_margin_left = 14.0
			push[i].content_margin_right = 14.0
			push[i].content_margin_top = 2.0 + i * 3.0
			push[i].content_margin_bottom = 6.0
		for st in ["normal", "hover", "disabled"]:
			add_theme_stylebox_override(st, push[0])
		for st in ["pressed", "hover_pressed"]:
			add_theme_stylebox_override(st, push[1])
		_fit_base = maxi(_fit_base, get_theme_font_size("font_size"))
		_fit_key = ""
		queue_redraw()
		return
	add_theme_stylebox_override("normal", _style(color, 6))
	add_theme_stylebox_override("hover", _style(color.lightened(0.2), 6))
	add_theme_stylebox_override("pressed", _style(color.darkened(0.15), 2))
	add_theme_stylebox_override("hover_pressed", _style(color.darkened(0.15), 2))
	add_theme_stylebox_override("disabled", _style(color.darkened(0.25), 6))


## Crea las capas del kit la primera vez. Van detrás del texto
## (show_behind_parent): la cara teñida y, encima, el aro y el brillo.
func _kit_ready() -> bool:
	if _body != null:
		_body.visible = true
		_frame.visible = true
		return true
	if UISkin.tex("kit_btn_body") == null:
		return false
	_body = UISkin.nine("kit_btn_body", UISkin.KIT_BTN)
	_frame = UISkin.nine("kit_btn_frame", UISkin.KIT_BTN)
	for n: NinePatchRect in [_body, _frame]:
		n.show_behind_parent = true
		add_child(n, false, Node.INTERNAL_MODE_FRONT)
	return true


## Cambia el color plano por una textura de assets/ui/ (los botones del menú):
## un poco más clara al pasar el ratón y más oscura y hundida al pulsar.
func set_texture(name: String) -> void:
	if _body != null:
		_body.queue_free()
		_frame.queue_free()
		_body = null
	# Antes de poner los márgenes del hueco: sin esto el tamaño mínimo (texto
	# más márgenes) ensancharía el botón.
	clip_text = true
	var keep := size
	add_theme_stylebox_override("normal", UISkin.box(name))
	add_theme_stylebox_override("hover", UISkin.box(name, Color(1.1, 1.1, 1.1)))
	add_theme_stylebox_override("pressed", UISkin.box(name, Color(0.85, 0.85, 0.85), 2.0))
	add_theme_stylebox_override("hover_pressed", UISkin.box(name, Color(0.85, 0.85, 0.85), 2.0))
	add_theme_stylebox_override("disabled", UISkin.box(name, Color(0.6, 0.6, 0.6)))
	add_theme_color_override("font_color", UISkin.CREAM)
	add_theme_color_override("font_hover_color", UISkin.CREAM)
	add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	add_theme_constant_override("shadow_offset_y", 3)
	add_theme_constant_override("shadow_offset_x", 0)
	_fit_base = get_theme_font_size("font_size")
	size = keep
	_fit_key = ""
	queue_redraw()


## Con textura o kit, el texto se ajusta al hueco de la cara (UISkin.TEXT_ROOM):
## si no cabe, baja de tamaño en vez de salirse o pisar el dibujo del botón.
var _fit_base := 0
var _fit_key := ""
## Último tamaño que puso el ajuste; si el de ahora es otro, lo cambió quien
## usa el botón y pasa a ser el tamaño de partida.
var _fit_set := 0
var _fit_pending := false


func _draw() -> void:
	if _body != null:
		# Más clara al pasar el ratón, más oscura al pulsar y apagada si no se puede usar.
		var c := _color
		match get_draw_mode():
			DRAW_HOVER:
				c = c.lightened(0.15)
			DRAW_PRESSED, DRAW_HOVER_PRESSED:
				c = c.darkened(0.18)
			DRAW_DISABLED:
				c = c.lerp(Color(0.36, 0.33, 0.31), 0.75)
		_body.modulate = c
		_frame.modulate = Color(1, 1, 1, 0.7) if disabled else Color.WHITE
	if _fit_base == 0:
		return
	var now := get_theme_font_size("font_size")
	if _fit_set != 0 and now != _fit_set and not _fit_pending:
		_fit_base = now
		_fit_key = ""
	var key := "%s|%d|%d" % [text, int(size.x), _fit_base]
	if key == _fit_key:
		return
	_fit_key = key
	var sb := get_theme_stylebox("normal")
	var room := size.x - sb.content_margin_left - sb.content_margin_right
	# Icono al lado del texto (no encima): le quita ancho.
	if icon != null and text != "" and vertical_icon_alignment == VERTICAL_ALIGNMENT_CENTER:
		room -= get_theme_constant("icon_max_width") + get_theme_constant("h_separation")
	var font := get_theme_font("font")
	var fs := _fit_base
	# Con varias líneas ("Difícil", "nivel 3") cuenta la más larga.
	var widest := ""
	for line in text.split("\n"):
		if line.length() > widest.length():
			widest = line
	while fs > 14 and font.get_string_size(widest, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 1
	_fit_set = fs
	if fs != now:
		# Durante el dibujo no se puede cambiar el tema: se aplica justo después
		# y vuelve a dibujar el botón (la clave evita el bucle).
		_fit_pending = true
		_apply_fit.call_deferred(fs)


func _apply_fit(fs: int) -> void:
	_fit_pending = false
	add_theme_font_size_override("font_size", fs)


## Icono del kit (assets/ui/kit_icon_<name>.png) a la izquierda del texto, o
## solo si no hay texto. `px` es su ancho en pantalla.
func set_icon(name: String, px := 44) -> void:
	# El icono no debe ensanchar el botón: el texto se encoge para caber (ver _draw).
	var keep := size
	clip_text = true
	icon = UISkin.tex("kit_icon_" + name)
	add_theme_constant_override("icon_max_width", px)
	add_theme_constant_override("h_separation", 10)
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if text == "" else HORIZONTAL_ALIGNMENT_LEFT
	size = keep
	_fit_key = ""
	queue_redraw()


## Latido continuo para llamar la atención.
func pulse(on: bool) -> void:
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	modulate = Color.WHITE
	if not on:
		return
	_pulse = create_tween().set_loops()
	_pulse.tween_property(self, "modulate", Color(1.3, 1.3, 1.3), 0.45).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(self, "modulate", Color.WHITE, 0.45).set_trans(Tween.TRANS_SINE)


func _scale_to(s: float, dur: float) -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "scale", Vector2(s, s), dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _style(color: Color, depth: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = color.darkened(0.45)
	sb.border_width_bottom = depth
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_top = 6.0 - depth
	return sb
