extends BaseButton
## Botón redondo de los lados de arriba del menú (tienda, desafío, récords,
## monedas por anuncio): icono en un círculo con aro dorado y el nombre debajo.
## Es para lo secundario: no compite con los bloques grandes de jugar.

const UI = preload("res://scripts/ui_theme.gd")
const UISkin = preload("res://scripts/ui_skin.gd")

## Diámetro del círculo; el botón mide un poco más para el nombre de debajo.
const D := 72.0
const FONT := 19

var color := UI.NEUTRAL
var text := ""
## Globo rojo en la esquina ("!", un número...). Vacío, sin globo.
var badge := ""
var _icon: Texture2D
var _pulse: Tween
## Diámetro de este botón (D por defecto; más pequeño dentro de una tarjeta).
var _d := D


func setup(icon_name: String, label: String, col: Color, diameter: float = D) -> void:
	_icon = UISkin.tex("kit_icon_" + icon_name)
	text = label
	color = col
	_d = diameter
	focus_mode = Control.FOCUS_NONE
	size = Vector2(_d + 26, _d + (30 if label != "" else 8))
	pivot_offset = Vector2(size.x * 0.5, _d * 0.5)
	button_down.connect(func() -> void: scale = Vector2(0.92, 0.92))
	button_up.connect(func() -> void: scale = Vector2.ONE)


func set_badge(t: String) -> void:
	badge = t
	queue_redraw()


## Late suave para llamar la atención (regalo listo, anuncio disponible...).
func pulse(on: bool) -> void:
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	modulate = Color.WHITE
	if not on:
		return
	_pulse = create_tween().set_loops()
	_pulse.tween_property(self, "modulate", Color(1.25, 1.2, 1.05), 0.7).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(self, "modulate", Color.WHITE, 0.7).set_trans(Tween.TRANS_SINE)


func _draw() -> void:
	var c := Vector2(size.x * 0.5, _d * 0.5 + 2)
	var r := _d * 0.5
	var col := color.lerp(Color(0.42, 0.42, 0.42), 0.7) if disabled else color
	draw_circle(c + Vector2(0, 4), r, Color(0, 0, 0, 0.45), true, -1.0, true)
	draw_circle(c, r, UISkin.TITLE_OUTLINE, true, -1.0, true)
	draw_circle(c, r - 3, Color(0.97, 0.8, 0.4), true, -1.0, true)
	draw_circle(c, r - 7, Color(0.62, 0.42, 0.14), true, -1.0, true)
	draw_circle(c, r - 9, col.darkened(0.3), true, -1.0, true)
	draw_circle(c - Vector2(0, 3), r - 11, col, true, -1.0, true)
	# Brillo de arriba, como las bolas de color de Personalizar.
	draw_circle(c + Vector2(-r * 0.22, -r * 0.34), r * 0.3, Color(1, 1, 1, 0.16), true, -1.0, true)
	if _icon != null:
		var s := _d * 0.56
		draw_texture_rect(_icon, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false,
				Color(1, 1, 1, 0.55 if disabled else 1.0))
	var font := UISkin.heavy()
	var base := Vector2(0, _d + 26)
	draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_CENTER, size.x, FONT, 6, UISkin.TITLE_OUTLINE)
	draw_string(font, base, text, HORIZONTAL_ALIGNMENT_CENTER, size.x, FONT, UISkin.CREAM)
	if badge != "":
		var bc := c + Vector2(r * 0.74, -r * 0.7)
		var br := 14.0 if badge.length() < 2 else 17.0
		draw_circle(bc, br + 2, UISkin.TITLE_OUTLINE, true, -1.0, true)
		draw_circle(bc, br, UI.DANGER, true, -1.0, true)
		draw_string(font, bc + Vector2(-br, 7), badge, HORIZONTAL_ALIGNMENT_CENTER, br * 2, 18, Color.WHITE)
