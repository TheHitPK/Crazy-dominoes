extends Node2D
## Manos dibujadas por código que sujetan el abanico de fichas de un jugador.
## El eje +Y local apunta hacia fuera de la mesa (hacia el cuerpo del jugador).
## La palma y los dedos van detrás de las fichas; los pulgares, por delante y
## en el borde exterior de cada mano.
##
## Todas las medidas van en "u" = ancho de una ficha de este asiento. La ficha
## ocupa de y = -u (canto de arriba) a y = +u (canto de abajo).

const TILE_W := 40.0
enum { NATURAL, NAILS, GLOVES }
## Hasta dónde asoma cada dedo sobre las fichas (en u), del meñique al índice.
## El índice es el más cercano al pulgar, o sea, el de fuera.
const FINGER_REACH := [1.03, 1.14, 1.2, 1.11]

## Escala de las fichas de este asiento.
var k := 1.0
var gap := 8.0
var fan := 0.00045
var arc := 0.00035
var skin := Color(0.94, 0.76, 0.6)
var sleeve := Color(0.2, 0.4, 0.8)
## NATURAL, NAILS (uñas largas pintadas) o GLOVES.
var style := NATURAL
## Color de las uñas o de los guantes.
var accent := Color(0.85, 0.1, 0.22)

## Distancia de cada mano al centro del abanico.
var spread := 0.0:
	set(v):
		spread = v
		refresh()
## 1 = dos manos, 0 = una sola (la izquierda se desvanece).
var two := 1.0:
	set(v):
		two = v
		refresh()

var _front: Node2D
var _tw: Tween
var _box := StyleBoxFlat.new()


func _ready() -> void:
	_front = Node2D.new()
	_front.z_index = 2
	add_child(_front)
	_front.draw.connect(_draw_front)
	modulate.a = 0.0


func step() -> float:
	return TILE_W * k + gap


## Posición y giro globales de la ficha i de n.
func slot(i: int, n: int) -> Array:
	var x := (i - (n - 1) * 0.5) * step()
	return [to_global(Vector2(x, x * x * arc)), global_rotation + x * fan]


func set_count(n: int) -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "spread", step() * n * 0.27 if n >= 4 else 0.0, 0.35)
	_tw.tween_property(self, "two", 1.0 if n >= 4 else 0.0, 0.35)
	_tw.tween_property(self, "modulate:a", 1.0 if n > 0 else 0.0, 0.35)


## Color con el que se ve la mano: la piel, o el guante si lo lleva.
func fill() -> Color:
	return accent if style == GLOVES else skin


func refresh() -> void:
	queue_redraw()
	if _front != null:
		_front.queue_redraw()


func _hands() -> Array:
	# [x, lado, alfa]
	return [[-spread, -1.0, two], [spread, 1.0, 1.0]]


# ------------------------------------------------------------------ colores

func _outline_color() -> Color:
	var f := fill()
	# Un guante negro necesita contorno claro para que se distinga.
	return f.lightened(0.3) if f.get_luminance() < 0.12 else f.darkened(0.42)


## Tono de las zonas iluminadas (dorso de los dedos, monte del pulgar).
func _light() -> Color:
	return fill().lightened(0.22)


## Tono de pliegues y sombras.
func _shade() -> Color:
	var f := fill()
	return f.lightened(0.18) if f.get_luminance() < 0.12 else f.darkened(0.2)


func _edge() -> float:
	return maxf(1.0, 1.2 * k)


# ------------------------------------------------------------------- piezas

func _capsule(c: CanvasItem, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	c.draw_line(a, b, col, w, true)
	c.draw_circle(a, w * 0.5, col, true, -1.0, true)
	c.draw_circle(b, w * 0.5, col, true, -1.0, true)


## Tramo de dedo de un solo color: más grueso en `a` (radio r0) que en `b` (r1).
func _taper(c: CanvasItem, a: Vector2, b: Vector2, r0: float, r1: float, col: Color) -> void:
	var n := (b - a).normalized().orthogonal()
	var quad := PackedVector2Array([a + n * r0, b + n * r1, b - n * r1, a - n * r0])
	c.draw_colored_polygon(quad, col)
	# Los polígonos no llevan suavizado: se repasan los dos lados largos.
	c.draw_line(quad[0], quad[1], col, 1.0, true)
	c.draw_line(quad[3], quad[2], col, 1.0, true)
	c.draw_circle(a, r0, col, true, -1.0, true)
	c.draw_circle(b, r1, col, true, -1.0, true)


## Dedo completo: contorno, relleno y una franja de luz a lo largo.
func _digit(c: CanvasItem, a: Vector2, b: Vector2, r0: float, r1: float, al: float) -> void:
	var e := _edge()
	_taper(c, a, b, r0 + e, r1 + e, Color(_outline_color(), al))
	_taper(c, a, b, r0, r1, Color(fill(), al))
	var n := (b - a).normalized().orthogonal()
	c.draw_line(a.lerp(b, 0.2) + n * r0 * 0.4, b + n * r1 * 0.4, Color(_light(), 0.7 * al), maxf(1.0, r1 * 0.45), true)


## Rectángulo de esquinas redondeadas (palma, puño de la camisa...).
func _rounded(c: CanvasItem, rect: Rect2, radii: Array, col: Color) -> void:
	_box.bg_color = col
	_box.corner_radius_top_left = int(radii[0])
	_box.corner_radius_top_right = int(radii[1])
	_box.corner_radius_bottom_right = int(radii[2])
	_box.corner_radius_bottom_left = int(radii[3])
	_box.draw(c.get_canvas_item(), rect)


## Uña en la punta de un dedo que apunta hacia `dir`. `w` es el ancho del dedo ahí.
func _nail(c: CanvasItem, tip: Vector2, dir: Vector2, w: float, al: float, thumb: bool) -> void:
	var u := TILE_W * k
	if style == GLOVES:
		return
	var e := _edge()
	if style == NATURAL:
		if thumb:
			# Uña corta: una placa clara que no llega al borde de la yema.
			var from := tip - dir * w * 0.42
			var to := tip + dir * w * 0.08
			_capsule(c, from, to, w * 0.74 + e, Color(_shade(), al))
			_capsule(c, from, to, w * 0.74, Color(1.0, 0.93, 0.88, al))
			c.draw_line(from - dir.orthogonal() * w * 0.14, to - dir.orthogonal() * w * 0.14,
					Color(1, 1, 1, 0.6 * al), maxf(1.0, w * 0.12), true)
		else:
			# De los otros dedos se ve la yema: basta el pliegue de la falange.
			var side := dir.orthogonal() * w * 0.36
			var at := tip - dir * w * 0.95
			c.draw_line(at - side, at + side, Color(_shade(), 0.8 * al), e, true)
		return
	# Uña larga de punta redonda: una cápsula que sobresale de la yema.
	var base := tip - dir * w * 0.1
	var end := base + dir * 0.3 * u
	_capsule(c, base, end, w * 0.84 + e * 2.0, Color(accent.darkened(0.45), al))
	_capsule(c, base, end, w * 0.84, Color(accent, al))
	# Brillo del esmalte.
	var shine := dir.orthogonal() * w * 0.18
	c.draw_line(base + shine, end + shine - dir * w * 0.2, Color(1, 1, 1, 0.55 * al), maxf(1.0, 1.4 * k), true)


# -------------------------------------------------------- detrás de las fichas

func _draw() -> void:
	var u := TILE_W * k
	var e := _edge()
	for h in _hands():
		var hx: float = h[0]
		var s: float = h[1]
		var al: float = h[2]
		if al < 0.02:
			continue
		var fill_c := Color(fill(), al)
		var line_c := Color(_outline_color(), al)
		_draw_sleeve(hx, u, al)

		# Dedos: nacen en lo alto de la palma, se abren un poco en abanico y
		# asoman sobre las fichas. j = 0 es el meñique (dentro); j = 3, el índice.
		for j in 4:
			var bx := hx + s * (-0.56 + j * 0.375) * u
			var reach: float = FINGER_REACH[j]
			var root := Vector2(bx, 0.86 * u)
			var tip := Vector2(bx + s * (j - 1.5) * 0.035 * u, -reach * u)
			var r_root := (0.165 if j > 0 else 0.15) * u
			var r_tip := (0.132 if j > 0 else 0.12) * u
			_digit(self, root, tip, r_root, r_tip, al)
			_nail(self, tip, (tip - root).normalized(), r_tip * 2.0, al, false)

		# Palma: ancha en los nudillos y más estrecha hacia la muñeca. Encima va
		# el monte del pulgar, con contorno solo por su lado de fuera para que
		# se funda con la palma en una sola silueta.
		var palm := _palm_shape(hx, u)
		var mound := Vector2(hx + s * 0.6 * u, 1.66 * u)
		draw_colored_polygon(palm, fill_c)
		draw_polyline(palm, line_c, e * 1.6, true)
		draw_circle(mound, 0.44 * u, fill_c, true, -1.0, true)
		var out_from := PI * -0.42 if s > 0.0 else PI * 0.5
		draw_arc(mound, 0.44 * u, out_from, out_from + PI * 0.92, 16, line_c, e * 1.6, true)
		# Luz en el monte del pulgar y sombra en el talón de la mano.
		draw_circle(mound + Vector2(-s * 0.06, -0.08) * u, 0.25 * u, Color(_light(), 0.5 * al), true, -1.0, true)
		draw_arc(Vector2(hx, 1.56 * u), 0.6 * u, PI * 0.25, PI * 0.75, 12, Color(_shade(), 0.5 * al), 0.06 * u, true)
		if style == GLOVES:
			# Costuras del dorso y ribete del guante.
			for j in 3:
				var sx := hx + s * (-0.36 + j * 0.36) * u
				draw_line(Vector2(sx, 0.95 * u), Vector2(sx, 1.5 * u), Color(_shade(), 0.9 * al), e, true)
			var band := Rect2(hx - 0.72 * u, 2.04 * u, 1.44 * u, 0.34 * u)
			var br := [0.1 * u, 0.1 * u, 0.1 * u, 0.1 * u]
			_rounded(self, band.grow(e), br, line_c)
			_rounded(self, band, br, Color(accent.lightened(0.25), al))
		else:
			# Pliegues de la palma: la línea de la vida rodea el monte del pulgar.
			var from := PI * 0.72 if s > 0.0 else PI * -0.38
			draw_arc(mound, 0.56 * u, from, from + PI * 0.66, 12, Color(_shade(), 0.75 * al), e, true)
			draw_line(Vector2(hx - s * 0.6 * u, 1.2 * u), Vector2(hx + s * 0.3 * u, 1.02 * u),
					Color(_shade(), 0.6 * al), e, true)


## Silueta de la palma (cerrada, lista para draw_polyline): de los nudillos,
## arriba, al talón redondeado de la mano, abajo.
func _palm_shape(hx: float, u: float) -> PackedVector2Array:
	var right := PackedVector2Array()
	var steps := 12
	for i in steps + 1:
		var t := float(i) / steps
		var half := lerpf(0.86, 0.55, smoothstep(0.15, 1.0, t)) * u
		right.append(Vector2(half, lerpf(0.72, 2.16, t) * u))
	var pts := PackedVector2Array()
	# Esquina de los nudillos redondeada, lado derecho hacia abajo...
	pts.append(Vector2(hx + right[0].x - 0.14 * u, right[0].y - 0.06 * u))
	for p in right:
		pts.append(Vector2(hx + p.x, p.y))
	# ...talón de la mano en arco...
	for i in range(1, 8):
		var a := PI * i / 8.0
		pts.append(Vector2(hx + cos(a) * 0.55 * u, 2.16 * u + sin(a) * 0.2 * u))
	# ...y lado izquierdo hacia arriba.
	for i in range(steps, -1, -1):
		pts.append(Vector2(hx - right[i].x, right[i].y))
	pts.append(Vector2(hx - right[0].x + 0.14 * u, right[0].y - 0.06 * u))
	pts.append(pts[0])
	return pts


## Antebrazo: muñeca, manga con pliegues y puño de camisa con botón.
func _draw_sleeve(hx: float, u: float, al: float) -> void:
	var e := _edge()
	var dark := Color(sleeve.darkened(0.35), al)
	# Muñeca.
	var wrist := Rect2(hx - 0.5 * u, 2.1 * u, 1.0 * u, 0.5 * u)
	draw_rect(wrist.grow(e), Color(_outline_color(), al))
	draw_rect(wrist, Color(fill(), al))
	# Manga, algo más ancha hacia el codo.
	var arm := PackedVector2Array([Vector2(hx - 0.7 * u, 2.6 * u), Vector2(hx + 0.7 * u, 2.6 * u),
			Vector2(hx + 0.86 * u, 4.0 * u), Vector2(hx - 0.86 * u, 4.0 * u)])
	draw_colored_polygon(arm, Color(sleeve, al))
	draw_line(arm[0], arm[3], dark, e, true)
	draw_line(arm[1], arm[2], dark, e, true)
	for fold in [-0.3, 0.26]:
		draw_line(Vector2(hx + fold * u, 2.9 * u), Vector2(hx + fold * 1.25 * u, 3.9 * u),
				Color(sleeve.darkened(0.2), al), maxf(1.0, 0.05 * u), true)
	# Puño.
	var cuff := Rect2(hx - 0.76 * u, 2.4 * u, 1.52 * u, 0.36 * u)
	var cr := [0.1 * u, 0.1 * u, 0.1 * u, 0.1 * u]
	_rounded(self, cuff.grow(e), cr, dark)
	_rounded(self, cuff, cr, Color(sleeve.lightened(0.4), al))
	draw_circle(Vector2(hx, 2.58 * u), 0.06 * u, dark, true, -1.0, true)


# ------------------------------------------------------- delante de las fichas

func _draw_front() -> void:
	var u := TILE_W * k
	var e := _edge()
	for h in _hands():
		var hx: float = h[0]
		var s: float = h[1]
		var al: float = h[2]
		if al < 0.02:
			continue
		# Pulgar en dos falanges. Sale del monte del pulgar, abierto hacia fuera,
		# y solo pisa el canto inferior de la ficha: no tapa los puntos.
		var root := Vector2(hx + s * 0.9 * u, 1.72 * u)
		var knuckle := Vector2(hx + s * 0.82 * u, 1.36 * u)
		var tip := Vector2(hx + s * 0.47 * u, 1.09 * u)
		var line_c := Color(_outline_color(), al)
		var fill_c := Color(fill(), al)
		# Contorno de las dos falanges y después el relleno, para que no quede
		# una raya oscura en la articulación.
		_taper(_front, root, knuckle, 0.25 * u + e, 0.21 * u + e, line_c)
		_taper(_front, knuckle, tip, 0.21 * u + e, 0.17 * u + e, line_c)
		_taper(_front, root, knuckle, 0.25 * u, 0.21 * u, fill_c)
		_taper(_front, knuckle, tip, 0.21 * u, 0.17 * u, fill_c)
		var dir := (tip - knuckle).normalized()
		var n := dir.orthogonal()
		# Luz a lo largo y pliegue del nudillo.
		_front.draw_line(knuckle.lerp(tip, 0.1) + n * s * 0.08 * u, tip + n * s * 0.06 * u - dir * 0.1 * u,
				Color(_light(), 0.7 * al), maxf(1.0, 0.07 * u), true)
		_front.draw_line(knuckle - n * 0.12 * u, knuckle + n * 0.12 * u, Color(_shade(), 0.8 * al), e, true)
		_nail(_front, tip, dir, 0.34 * u, al, true)
