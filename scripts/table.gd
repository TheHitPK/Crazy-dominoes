extends Node2D
## Mesa de dominó dibujada por código: superficie (tablas con veta o tapete),
## borde de madera y un posavasos empotrado en cada esquina. El acabado sale
## de los ajustes.

const Settings = preload("res://scripts/settings.gd")

## Diseño base en vertical (teléfono de pie).
const SCREEN := Vector2(720, 1280)
## Margen extra arriba y abajo en pantallas más altas que 16:9 (casi todos los
## teléfonos). El contenido central sigue en y 0..1280; la mesa crece de -pad a 1280+pad.
static var pad := 0.0
## Margen extra a izquierda y derecha. Es 0 en el teléfono; la versión web en un
## ordenador lo usa para ensanchar la mesa hasta hacerla cuadrada (ver main.gd).
## El contenido central sigue en x 0..720; la mesa crece de -side a 720+side.
static var side := 0.0
## Los posavasos de abajo van por encima de las fichas del jugador.
const CUP_BOTTOM_RAISE := 160.0
const FLOOR := Color(0.07, 0.055, 0.045)
const RIM := 44.0
const CUP_R := 38.0
const CUP_INSET := 60.0
## Acabados: superficie, borde, veta, si es tapete, nudos y ancho de las juntas.
const STYLES := [
	{"wood": Color(0.64, 0.41, 0.2), "rim": Color(0.27, 0.14, 0.07), "grain": Color(0.25, 0.12, 0.04), "felt": false, "knots": 4, "gap": 2.0},
	{"wood": Color(0.36, 0.22, 0.12), "rim": Color(0.14, 0.08, 0.05), "grain": Color(0.1, 0.05, 0.02), "felt": false, "knots": 3, "gap": 2.0},
	{"wood": Color(0.86, 0.68, 0.42), "rim": Color(0.55, 0.36, 0.17), "grain": Color(0.55, 0.35, 0.15), "felt": false, "knots": 7, "gap": 2.0},
	{"wood": Color(0.55, 0.2, 0.12), "rim": Color(0.25, 0.07, 0.05), "grain": Color(0.2, 0.04, 0.02), "felt": false, "knots": 2, "gap": 2.0},
	{"wood": Color(0.1, 0.42, 0.24), "rim": Color(0.27, 0.14, 0.07), "grain": Color(0.02, 0.15, 0.08), "felt": true, "knots": 0, "gap": 0.0},
	{"wood": Color(0.52, 0.46, 0.38), "rim": Color(0.25, 0.2, 0.16), "grain": Color(0.2, 0.17, 0.13), "felt": false, "knots": 11, "gap": 5.0},
]


static func outer() -> Rect2:
	return Rect2(10.0 - side, 10.0 - pad, 700.0 + side * 2.0, 1260.0 + pad * 2.0)


static func style() -> Dictionary:
	return STYLES[clampi(Settings.data.table_style, 0, STYLES.size() - 1)]


static func cup_centers() -> Array:
	var r := outer().grow(-RIM - CUP_INSET)
	var bottom := r.end.y - CUP_BOTTOM_RAISE
	return [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, bottom), Vector2(r.end.x, bottom)]


func _draw() -> void:
	var st := style()
	var rim: Color = st.rim
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261005
	var ci := get_canvas_item()
	var inner := outer().grow(-RIM)

	draw_rect(Rect2(-2000, -2000, 5280, 4720), FLOOR)

	var body := StyleBoxFlat.new()
	body.bg_color = rim
	body.set_corner_radius_all(40)
	body.shadow_color = Color(0, 0, 0, 0.65)
	body.shadow_size = 22
	body.draw(ci, outer())

	if st.felt:
		_draw_felt(inner, st, rng)
	else:
		# Las tablas corren a lo largo de la mesa: se dibujan "tumbadas" con los
		# ejes intercambiados.
		var swap := Transform2D(Vector2(0, 1), Vector2(1, 0), inner.position)
		draw_set_transform_matrix(swap)
		_draw_planks(Rect2(0, 0, inner.size.y, inner.size.x), st, rng, swap)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_vignette(inner)

	var frame := StyleBoxFlat.new()
	frame.draw_center = false
	frame.border_color = rim
	frame.set_border_width_all(int(RIM))
	frame.set_corner_radius_all(40)
	frame.draw(ci, outer())
	_draw_rim_grain(inner, rng)
	_outline(outer().grow(-2.0), 2, Color(1.0, 0.8, 0.55, 0.22), 38)
	_outline(inner.grow(3.0), 3, Color(0, 0, 0, 0.5), 5)
	_outline(inner.grow(6.0), 1, Color(1.0, 0.85, 0.6, 0.2), 7)

	for c: Vector2 in cup_centers():
		_draw_cup(c)


func _outline(rect: Rect2, width: int, color: Color, radius: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = color
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.draw(get_canvas_item(), rect)


## `base` es la transformación ya activa (ejes intercambiados), para los nudos.
func _draw_planks(r: Rect2, st: Dictionary, rng: RandomNumberGenerator, base: Transform2D) -> void:
	var wood: Color = st.wood
	var grain: Color = st.grain
	var gap: float = st.gap
	var planks := 8
	var ph := r.size.y / planks
	var steps := int(r.size.x / 36.0) + 1
	for i in planks:
		var tint := rng.randf_range(-0.05, 0.05)
		var col := wood.lightened(tint) if tint > 0.0 else wood.darkened(-tint)
		var pr := Rect2(r.position.x, r.position.y + i * ph, r.size.x, ph)
		draw_rect(pr, col)
		# Veta: líneas onduladas a lo largo de la tabla.
		for j in 24:
			var y0 := pr.position.y + rng.randf_range(3.0, ph - 3.0)
			var amp := rng.randf_range(0.6, 3.2)
			var f := rng.randf_range(0.004, 0.012)
			var phase := rng.randf() * TAU
			var pts := PackedVector2Array()
			for q in steps + 1:
				var x := r.position.x + r.size.x * q / steps
				var y := y0 + sin(x * f + phase) * amp + sin(x * f * 2.7 + phase) * amp * 0.4
				pts.append(Vector2(x, clampf(y, pr.position.y + 1.0, pr.end.y - 1.0)))
			draw_polyline(pts, Color(grain, rng.randf_range(0.05, 0.2)), rng.randf_range(1.0, 2.2), true)
		# Junta entre tablas y una unión a tope por tabla.
		if i > 0:
			draw_line(pr.position, Vector2(pr.end.x, pr.position.y), Color(grain.darkened(0.4), 0.8), gap)
			draw_line(pr.position + Vector2(0, gap), Vector2(pr.end.x, pr.position.y + gap), Color(1, 0.9, 0.7, 0.1), 1.0)
		var jx := rng.randf_range(pr.position.x + 150.0, pr.end.x - 150.0)
		draw_line(Vector2(jx, pr.position.y), Vector2(jx, pr.end.y), Color(grain.darkened(0.4), 0.6), maxf(1.5, gap * 0.7))
	# Nudos.
	var knots: int = st.knots
	for kn in knots:
		var pos := Vector2(rng.randf_range(r.position.x + 180.0, r.end.x - 180.0),
				rng.randf_range(r.position.y + 60.0, r.end.y - 60.0))
		draw_set_transform_matrix(base * Transform2D(rng.randf_range(-0.2, 0.2), Vector2(2.0, 1.0), 0.0, pos))
		for ring in 5:
			draw_arc(Vector2.ZERO, 2.0 + ring * 2.4, 0.0, TAU, 24,
					Color(grain.darkened(0.2), 0.42 - ring * 0.07), 1.6, true)
		draw_set_transform_matrix(base)


func _draw_felt(r: Rect2, st: Dictionary, rng: RandomNumberGenerator) -> void:
	var felt: Color = st.wood
	draw_rect(r, felt)
	# Pelusa del paño.
	for i in 1400:
		var p := Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
		var d := Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4))
		draw_line(p, p + d, Color(1, 1, 1, 0.045) if i % 2 == 0 else Color(0, 0, 0, 0.07), 1.0)
	_outline(r.grow(-16.0), 2, Color(1.0, 0.95, 0.7, 0.16), 10)


func _draw_vignette(r: Rect2) -> void:
	var d := 110.0
	var dark := Color(0.05, 0.02, 0.0, 0.42)
	var clear := Color(0.05, 0.02, 0.0, 0.0)
	var a := r.position
	var b := Vector2(r.end.x, r.position.y)
	var c := r.end
	var e := Vector2(r.position.x, r.end.y)
	var cols := PackedColorArray([dark, dark, clear, clear])
	draw_polygon(PackedVector2Array([a, b, b + Vector2(-d, d), a + Vector2(d, d)]), cols)
	draw_polygon(PackedVector2Array([b, c, c + Vector2(-d, -d), b + Vector2(-d, d)]), cols)
	draw_polygon(PackedVector2Array([c, e, e + Vector2(d, -d), c + Vector2(-d, -d)]), cols)
	draw_polygon(PackedVector2Array([e, a, a + Vector2(d, d), e + Vector2(d, -d)]), cols)


func _draw_rim_grain(inner: Rect2, rng: RandomNumberGenerator) -> void:
	for j in 14:
		var col := Color(0.0, 0.0, 0.0, rng.randf_range(0.15, 0.35))
		var t := rng.randf_range(5.0, RIM - 5.0)
		var x0 := outer().position.x + 46.0
		var x1 := outer().end.x - 46.0
		var y0 := outer().position.y + 46.0
		var y1 := outer().end.y - 46.0
		match j % 4:
			0: draw_line(Vector2(x0, outer().position.y + t), Vector2(x1, outer().position.y + t), col, 1.2)
			1: draw_line(Vector2(x0, inner.end.y + t), Vector2(x1, inner.end.y + t), col, 1.2)
			2: draw_line(Vector2(outer().position.x + t, y0), Vector2(outer().position.x + t, y1), col, 1.2)
			3: draw_line(Vector2(inner.end.x + t, y0), Vector2(inner.end.x + t, y1), col, 1.2)


## Posavasos empotrado (el vaso es un nodo aparte, ver glass.gd).
func _draw_cup(c: Vector2) -> void:
	draw_circle(c + Vector2(0, 3), CUP_R + 8.0, Color(0, 0, 0, 0.35), true, -1.0, true)
	draw_circle(c, CUP_R + 5.0, Color(0.66, 0.63, 0.58), true, -1.0, true)
	draw_circle(c, CUP_R + 2.5, Color(0.36, 0.34, 0.32), true, -1.0, true)
	draw_circle(c, CUP_R, Color(0.09, 0.055, 0.035), true, -1.0, true)
	draw_circle(c + Vector2(2, 3), CUP_R - 5.0, Color(0.17, 0.1, 0.06), true, -1.0, true)
	draw_arc(c, CUP_R + 3.7, PI * 1.05, PI * 1.6, 24, Color(1, 1, 1, 0.6), 2.0, true)
