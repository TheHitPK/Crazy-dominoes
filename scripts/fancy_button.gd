extends Button
## Botón con relieve y animación de escala al pasar el ratón y al pulsar.

var _tw: Tween
var _pulse: Tween


func setup(txt: String, color: Color, font_size: int = 24) -> void:
	text = txt
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_font_size_override("font_size", font_size)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		add_theme_color_override(c, Color.WHITE)
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	add_theme_constant_override("outline_size", 5)
	add_theme_stylebox_override("normal", _style(color, 6))
	add_theme_stylebox_override("hover", _style(color.lightened(0.2), 6))
	add_theme_stylebox_override("pressed", _style(color.darkened(0.15), 2))
	add_theme_stylebox_override("hover_pressed", _style(color.darkened(0.15), 2))
	add_theme_stylebox_override("disabled", _style(color.darkened(0.25), 6))
	add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.8))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	mouse_entered.connect(_scale_to.bind(1.08, 0.22))
	mouse_exited.connect(_scale_to.bind(1.0, 0.22))
	button_down.connect(_scale_to.bind(0.93, 0.08))
	# En pantalla táctil no hay "mouse_exited" al levantar el dedo: vuelve a su tamaño.
	button_up.connect(_scale_to.bind(1.0, 0.18))


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
