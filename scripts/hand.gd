extends Node2D
## Manos dibujadas por código que sujetan el abanico de fichas de un jugador.
## El eje +Y local apunta hacia fuera de la mesa (hacia el cuerpo del jugador).
## La palma y los dedos van detrás de las fichas; los pulgares, por delante y
## en el borde exterior de cada mano.

const TILE_W := 40.0
enum { NATURAL, NAILS, GLOVES }

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


func _outline_color() -> Color:
	var f := fill()
	# Un guante negro necesita contorno claro para que se distinga.
	return f.lightened(0.3) if f.get_luminance() < 0.12 else f.darkened(0.38)


func _capsule(c: CanvasItem, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	c.draw_line(a, b, col, w, true)
	c.draw_circle(a, w * 0.5, col, true, -1.0, true)
	c.draw_circle(b, w * 0.5, col, true, -1.0, true)


func _finger(c: CanvasItem, a: Vector2, b: Vector2, w: float, al: float) -> void:
	_capsule(c, a, b, w + maxf(2.0, 2.4 * k), Color(_outline_color(), al))
	_capsule(c, a, b, w, Color(fill(), al))


## Uña en la punta de un dedo que apunta hacia `dir`.
func _nail(c: CanvasItem, tip: Vector2, dir: Vector2, w: float, al: float, thumb: bool) -> void:
	var u := TILE_W * k
	if style == GLOVES:
		return
	if style == NATURAL:
		if thumb:
			c.draw_circle(tip + dir * 0.03 * u, 0.13 * u, Color(1.0, 0.93, 0.88, 0.85 * al), true, -1.0, true)
		return
	# Uña larga de punta redonda: una cápsula que sobresale de la yema.
	var base := tip - dir * w * 0.1
	var end := base + dir * 0.3 * u
	var edge := maxf(1.0, 1.2 * k)
	_capsule(c, base, end, w + edge * 2.0, Color(accent.darkened(0.45), al))
	_capsule(c, base, end, w, Color(accent, al))
	# Brillo del esmalte.
	var side := dir.orthogonal() * w * 0.2
	c.draw_line(base + side, end + side - dir * w * 0.2, Color(1, 1, 1, 0.5 * al), maxf(1.0, 1.4 * k), true)


func _draw() -> void:
	var u := TILE_W * k
	for h in _hands():
		var hx: float = h[0]
		var s: float = h[1]
		var al: float = h[2]
		if al < 0.02:
			continue
		# Manga y puño.
		draw_colored_polygon(PackedVector2Array([
			Vector2(hx - 0.82 * u, 3.9 * u), Vector2(hx + 0.82 * u, 3.9 * u),
			Vector2(hx + 0.68 * u, 2.3 * u), Vector2(hx - 0.68 * u, 2.3 * u)]), Color(sleeve, al))
		draw_line(Vector2(hx - 0.7 * u, 2.4 * u), Vector2(hx + 0.7 * u, 2.4 * u),
				Color(sleeve.lightened(0.4), al), 0.2 * u)
		# Dedos por detrás; las yemas asoman sobre las fichas.
		var tips := [1.08, 1.17, 1.15, 1.05]
		for j in 4:
			var fx := hx + s * (-0.58 + j * 0.385) * u
			var tip := Vector2(fx, -tips[j] * u)
			_finger(self, Vector2(fx, 0.9 * u), tip, 0.3 * u, al)
			_nail(self, tip, Vector2.UP, 0.24 * u, al, false)
		# Palma.
		var palm := Vector2(hx, 1.55 * u)
		draw_circle(palm, 1.08 * u + maxf(1.0, 1.2 * k), Color(_outline_color(), al), true, -1.0, true)
		draw_circle(palm, 1.08 * u, Color(fill(), al), true, -1.0, true)
		if style == GLOVES:
			# Puño del guante.
			draw_line(Vector2(hx - 0.72 * u, 2.2 * u), Vector2(hx + 0.72 * u, 2.2 * u),
					Color(_outline_color(), al), 0.34 * u)
			draw_line(Vector2(hx - 0.7 * u, 2.2 * u), Vector2(hx + 0.7 * u, 2.2 * u),
					Color(accent.lightened(0.25), al), 0.26 * u)


func _draw_front() -> void:
	var u := TILE_W * k
	for h in _hands():
		var hx: float = h[0]
		var s: float = h[1]
		var al: float = h[2]
		if al < 0.02:
			continue
		# El pulgar sale del borde exterior de cada mano y se cierra sobre las fichas.
		var base := Vector2(hx + s * 0.8 * u, 1.55 * u)
		var tip := Vector2(hx + s * 0.3 * u, 0.48 * u)
		_finger(_front, base, tip, 0.44 * u, al)
		_nail(_front, tip, (tip - base).normalized(), 0.3 * u, al, true)
