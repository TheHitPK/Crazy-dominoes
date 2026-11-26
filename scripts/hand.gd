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
## Sin manos (preferencia del jugador): las fichas se paran en un atril de
## madera, el posa dominós. Su tabla de atrás va detrás de las fichas y el
## reborde de delante pisa solo su canto inferior, como el pulgar.
var rack := false:
	set(v):
		rack = v
		refresh()
## Largo del atril: el de las fichas, con un mínimo (ver set_count).
var span := 0.0:
	set(v):
		span = v
		refresh()
const RACK_WOOD := Color(0.45, 0.26, 0.13)
## Fichas que caben en el atril más corto (de 7 al empezar).
const RACK_MIN := 5

## Largo máximo del abanico (0 = sin límite).
var max_span := 0.0

var _front: Node2D
var _tw: Tween
var _box := StyleBoxFlat.new()

## Rendimiento: cada mano tiene unas 120 piezas (dedos, uñas, pliegues...), y
## cada pieza suavizada es una llamada de dibujo. Con cuatro jugadores eran
## ~950 por imagen, demasiado para la GPU de un teléfono de gama media. Por eso
## cada mano se pinta una sola vez en una imagen (como las caras de las fichas,
## ver tile.gd) y luego se dibuja esa imagen. Hasta que está lista, se dibuja
## a mano como antes.
## Caja de una mano alrededor de su centro (en u) y escala de la imagen.
const BAKE_BOX := Rect2(-1.45, -1.85, 2.9, 6.0)
const BAKE_SCALE := 1.5
## Imágenes ya pintadas: clave -> {tex, ready, viewport}. Compartidas.
static var _baked := {}
static var _bake_holder: Node
static var _waiting: Array = []
## Pintor de una imagen: una sola mano en x = 0, del lado _p_side; detrás de
## las fichas (palma y dedos) o, con _p_front, delante (el pulgar).
var painter := false
var _p_side := 1.0
var _p_front := false


func _ready() -> void:
	if painter:
		_front = self
		return
	_front = Node2D.new()
	_front.z_index = 2
	add_child(_front)
	_front.draw.connect(_draw_front)
	modulate.a = 0.0


func step() -> float:
	return TILE_W * k + gap


## Separación entre fichas cuando hay n: la normal o, si no caben en
## max_span (1 contra 1 tras robar mucho), más juntas y solapadas.
func step_for(n: int) -> float:
	if max_span <= 0.0 or n < 2:
		return step()
	return minf(step(), (max_span - TILE_W * k) / (n - 1))


## Largo que ocupan n fichas.
func width_for(n: int) -> float:
	return step_for(n) * (n - 1) + TILE_W * k if n > 0 else 0.0


## Posición y giro globales de la ficha i de n.
func slot(i: int, n: int) -> Array:
	var x := (i - (n - 1) * 0.5) * step_for(n)
	return [to_global(Vector2(x, x * x * arc)), global_rotation + x * fan]


func set_count(n: int) -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "spread", (width_for(n) + gap) * 0.27 if n >= 4 else 0.0, 0.35)
	_tw.tween_property(self, "two", 1.0 if n >= 4 else 0.0, 0.35)
	# El atril encoge un poco al quedar menos fichas, pero nunca por debajo del
	# largo de RACK_MIN fichas: si no, con una o dos fichas quedaba diminuto.
	_tw.tween_property(self, "span", maxf(width_for(n), width_for(RACK_MIN)), 0.35)
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


func _draw() -> void:
	if painter:
		if _p_front:
			_front_hand(0.0, _p_side, 1.0)
		else:
			_back_hand(0.0, _p_side, 1.0)
		return
	if rack:
		_draw_rack_back()
		return
	for h in _hands():
		if h[2] >= 0.02 and not _draw_baked(self, h[0], h[1], h[2], false):
			_back_hand(h[0], h[1], h[2])


# ------------------------------------------------------------ imágenes pintadas

func _bake_key(s: float, front: bool) -> String:
	return "%d|%s|%s|%s|%d|%d|%.3f" % [style, skin.to_html(), sleeve.to_html(), accent.to_html(),
			int(s), int(front), k]


## Dibuja la mano ya pintada en `c`; si aún no está, la encarga y devuelve false.
func _draw_baked(c: CanvasItem, hx: float, s: float, al: float, front: bool) -> bool:
	var key := _bake_key(s, front)
	var entry: Dictionary = _baked.get(key, {})
	if entry.get("ready", false):
		var u := TILE_W * k
		var box := Rect2(BAKE_BOX.position * u + Vector2(hx, 0.0), BAKE_BOX.size * u)
		c.draw_texture_rect(entry.tex, box, false, Color(1, 1, 1, al))
		return true
	if entry.is_empty():
		_bake.call_deferred(s, front)
	if not _waiting.has(self):
		_waiting.append(self)
	return false


func _bake(s: float, front: bool) -> void:
	var key := _bake_key(s, front)
	if _baked.has(key) or not is_inside_tree():
		return
	if _baked.size() > 48:
		# Muchas combinaciones (otros jugadores, cambios de color): se empieza de nuevo.
		for e: Dictionary in _baked.values():
			if is_instance_valid(e.viewport):
				e.viewport.queue_free()
		_baked.clear()
	var tree := get_tree()
	if _bake_holder == null or not is_instance_valid(_bake_holder):
		_bake_holder = Node.new()
		_bake_holder.name = "HandImages"
		tree.root.add_child(_bake_holder)
	var u := TILE_W * k
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.size = Vector2i((BAKE_BOX.size * u * BAKE_SCALE).ceil())
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var p: Node2D = (get_script() as GDScript).new()
	p.painter = true
	p._p_side = s
	p._p_front = front
	p.k = k
	p.skin = skin
	p.sleeve = sleeve
	p.style = style
	p.accent = accent
	p.position = -BAKE_BOX.position * u * BAKE_SCALE
	p.scale = Vector2.ONE * BAKE_SCALE
	vp.add_child(p)
	_bake_holder.add_child(vp)
	_baked[key] = {"tex": vp.get_texture(), "ready": false, "viewport": vp}
	tree.create_timer(0.08, true, false, true).timeout.connect(_baked_ready.bind(key))


static func _baked_ready(key: String) -> void:
	if not _baked.has(key):
		return
	_baked[key].ready = true
	for h in _waiting:
		if is_instance_valid(h):
			h.refresh()
	_waiting.clear()


# -------------------------------------------------------- detrás de las fichas

## Palma, dedos y manga de una mano (centro hx, lado s), sin pintar.
func _back_hand(hx: float, s: float, al: float) -> void:
	var u := TILE_W * k
	var e := _edge()
	if true:
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
	if rack:
		_draw_rack_front()
		return
	for h in _hands():
		if h[2] >= 0.02 and not _draw_baked(_front, h[0], h[1], h[2], true):
			_front_hand(h[0], h[1], h[2])


## Pulgar de una mano (centro hx, lado s), sin pintar.
func _front_hand(hx: float, s: float, al: float) -> void:
	var u := TILE_W * k
	var e := _edge()
	if true:
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


# ------------------------------------------------------------------- atril

## Esquinas del atril (en u): pequeñas, para que parezca una tabla cortada y no una píldora.
const RACK_CORNER := 0.08


## Franja del atril de y0 a y1 (en u) con los extremos rectos y las esquinas
## apenas redondeadas. Sigue la misma curva que el abanico de fichas (ver slot).
func _rack_strip(c: CanvasItem, half: float, y0: float, y1: float, col: Color) -> void:
	var u := TILE_W * k
	var r := minf(RACK_CORNER * u, (y1 - y0) * 0.5 * u)
	var end_y := half * half * arc
	var pts := PackedVector2Array()
	var steps := 12
	# Canto de arriba, esquinas de la derecha, canto de abajo y esquinas de la izquierda.
	for i in steps + 1:
		var x := lerpf(-half + r, half - r, float(i) / steps)
		pts.append(Vector2(x, x * x * arc + y0 * u))
	_rack_corner(pts, Vector2(half - r, end_y + y0 * u + r), r, -PI * 0.5)
	_rack_corner(pts, Vector2(half - r, end_y + y1 * u - r), r, 0.0)
	for i in range(steps, -1, -1):
		var x := lerpf(-half + r, half - r, float(i) / steps)
		pts.append(Vector2(x, x * x * arc + y1 * u))
	_rack_corner(pts, Vector2(-half + r, end_y + y1 * u - r), r, PI * 0.5)
	_rack_corner(pts, Vector2(-half + r, end_y + y0 * u + r), r, PI)
	c.draw_colored_polygon(pts, col)


## Cuarto de círculo de una esquina del atril, desde el ángulo `from`.
func _rack_corner(pts: PackedVector2Array, center: Vector2, r: float, from: float) -> void:
	for i in 5:
		pts.append(center + Vector2.from_angle(from + PI * 0.5 * i / 4.0) * r)


## Línea a lo largo del atril (vetas, filo, filete del color del equipo).
func _rack_line(c: CanvasItem, half: float, y: float, col: Color, width: float) -> void:
	var u := TILE_W * k
	var pts := PackedVector2Array()
	for i in 13:
		var x := lerpf(-half, half, i / 12.0)
		pts.append(Vector2(x, x * x * arc + y * u))
	c.draw_polyline(pts, col, width, true)


## Tabla de atrás, en la que se apoyan las fichas: asoma por los extremos y
## entre ficha y ficha.
func _draw_rack_back() -> void:
	var u := TILE_W * k
	# Sin los extremos redondos, la tabla se alarga un poco para que siga asomando.
	var half := span * 0.5 + 0.3 * u
	_rack_strip(self, half + 0.04 * u, -0.66, 1.0, RACK_WOOD.darkened(0.55))
	_rack_strip(self, half, -0.62, 0.96, RACK_WOOD.darkened(0.25))
	_rack_line(self, half - 0.2 * u, -0.5, Color(RACK_WOOD.lightened(0.25), 0.6), maxf(1.0, 0.04 * u))


## Reborde de delante, con su sombra sobre la mesa, el canto iluminado arriba,
## un par de vetas y un filete del color del equipo.
func _draw_rack_front() -> void:
	var u := TILE_W * k
	var half := span * 0.5 + 0.42 * u
	var e := _edge()
	_rack_strip(_front, half, 1.02, 1.5, Color(0, 0, 0, 0.3))
	_rack_strip(_front, half + e, 0.9 - e / u, 1.4 + e / u, RACK_WOOD.darkened(0.5))
	_rack_strip(_front, half, 0.9, 1.4, RACK_WOOD)
	_rack_strip(_front, half - 0.02 * u, 0.91, 1.02, RACK_WOOD.lightened(0.3))
	for y in [1.12, 1.2]:
		_rack_line(_front, half - 0.25 * u, y, Color(RACK_WOOD.darkened(0.3), 0.5), maxf(1.0, 0.025 * u))
	_rack_line(_front, half - 0.12 * u, 1.3, Color(sleeve.lightened(0.15), 0.9), maxf(1.0, 0.05 * u))
