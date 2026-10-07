extends Node2D
## Pizarra del marcador de una pareja. Los puntos se anotan con rayas de tiza
## (una por cada 10 puntos, en grupos de cinco tachados) junto al número, y una
## tiza descansa al lado del número y se mueve para escribir cada anotación.

const SIZE := Vector2(196, 88)
const CHALK := Color(0.96, 0.96, 0.92)
const MAX_MARKS := 10
const REST := Vector2(164, 64)

var title := "NOSOTROS"
var tint := Color(0.6, 0.8, 1.0)
## Número que se muestra (cuenta hacia arriba al anotar).
var shown := 0:
	set(v):
		shown = v
		queue_redraw()
## Rayas dibujadas; fraccional mientras la tiza traza una.
var marks := 0.0:
	set(v):
		marks = v
		queue_redraw()
## 0..1 mientras la tiza escribe el número.
var writing := 0.0:
	set(v):
		writing = v
		queue_redraw()

var _score := 0
var _tw: Tween
var _font: Font = ThemeDB.fallback_font
var _frame := StyleBoxFlat.new()
var _slate := StyleBoxFlat.new()
var _stick := StyleBoxFlat.new()


func _init() -> void:
	_frame.bg_color = Color(0.46, 0.29, 0.14)
	_frame.border_color = Color(0.27, 0.15, 0.07)
	_frame.set_border_width_all(2)
	_frame.set_corner_radius_all(7)
	_frame.shadow_color = Color(0, 0, 0, 0.45)
	_frame.shadow_size = 6
	_slate.bg_color = Color(0.12, 0.15, 0.14)
	_slate.set_corner_radius_all(3)
	_stick.bg_color = CHALK
	_stick.border_color = Color(0.6, 0.6, 0.56)
	_stick.border_width_bottom = 2
	_stick.set_corner_radius_all(3)
	_stick.shadow_color = Color(0, 0, 0, 0.35)
	_stick.shadow_size = 3


## Anota una puntuación. Con `animate`, la tiza escribe el número y traza las rayas nuevas.
func set_score(value: int, animate: bool) -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	var target_marks := float(mini(value / 10, MAX_MARKS))
	var from := _score
	_score = value
	if not animate or value <= from:
		shown = value
		marks = target_marks
		writing = 0.0
		return
	_tw = create_tween()
	_tw.tween_property(self, "writing", 1.0, 0.7)
	_tw.parallel().tween_property(self, "shown", value, 0.7)
	_tw.tween_property(self, "writing", 0.0, 0.01)
	if target_marks > marks:
		_tw.tween_property(self, "marks", target_marks, 0.32 * (target_marks - marks))


## Extremos de la raya k: cuatro verticales y la quinta cruzada en diagonal.
func _stroke(k: int) -> Array:
	var gx := 16.0 + (k / 5) * 44.0
	var i := k % 5
	if i < 4:
		var x := gx + i * 8.0
		return [Vector2(x + (k * 37 % 3) - 1.0, 38.0), Vector2(x + (k * 53 % 3) - 1.0, 74.0)]
	return [Vector2(gx - 5.0, 68.0), Vector2(gx + 29.0, 43.0)]


func _chalk_line(a: Vector2, b: Vector2) -> void:
	var n := (b - a).normalized().orthogonal()
	draw_line(a, b, Color(CHALK, 0.88), 2.4, true)
	draw_line(a + n * 1.3, b + n * 1.1, Color(CHALK, 0.3), 1.2, true)
	draw_line(a - n * 1.2, b - n * 1.4, Color(CHALK, 0.25), 1.2, true)


func _draw() -> void:
	var ci := get_canvas_item()
	_frame.draw(ci, Rect2(Vector2.ZERO, SIZE))
	_slate.draw(ci, Rect2(Vector2.ZERO, SIZE).grow(-6.0))
	# Restos de tiza borrada.
	for sm in [[Vector2(20, 30), Vector2(120, 22)], [Vector2(60, 70), Vector2(180, 62)], [Vector2(30, 52), Vector2(150, 48)]]:
		draw_line(sm[0], sm[1], Color(1, 1, 1, 0.035), 14.0, true)

	draw_string(_font, Vector2(14, 26), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(tint, 0.95))
	draw_line(Vector2(14, 31), Vector2(SIZE.x - 14.0, 31), Color(CHALK, 0.3), 1.0, true)

	var chalk_at := REST
	var chalk_rot := -0.95
	# Rayas.
	for k in MAX_MARKS:
		var f := clampf(marks - k, 0.0, 1.0)
		if f <= 0.0:
			break
		var s := _stroke(k)
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var tip := a.lerp(b, f)
		_chalk_line(a, tip)
		if f < 1.0:
			chalk_at = tip
			chalk_rot = -0.6
	# Número.
	var num := str(shown)
	var num_rect := Rect2(94, 34, 64, 44)
	# Con tres cifras la letra se achica para no pisar las rayas.
	var num_size := 36 if shown < 100 else 29
	for off in [Vector2.ZERO, Vector2(0.8, 0.5)]:
		draw_string(_font, num_rect.position + Vector2(0, 36) + off, num, HORIZONTAL_ALIGNMENT_RIGHT,
				num_rect.size.x, num_size, Color(CHALK, 0.9 if off == Vector2.ZERO else 0.35))
	if writing > 0.0:
		chalk_at = Vector2(132, 58) + Vector2(sin(writing * 34.0) * 16.0, cos(writing * 23.0) * 10.0)
		chalk_rot = -0.6
	# La tiza: la punta toca la pizarra y el cuerpo sube hacia la derecha.
	draw_set_transform(chalk_at, chalk_rot)
	_stick.draw(ci, Rect2(0, -5.5, 36, 11))
	draw_line(Vector2(3, -2.5), Vector2(32, -2.5), Color(1, 1, 1, 0.8), 1.5, true)
	draw_set_transform(Vector2.ZERO)
