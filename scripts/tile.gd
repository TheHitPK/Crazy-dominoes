extends Node2D
## Ficha de dominó dibujada por código. Mide 40x80 y está centrada en el origen;
## `top` es la mitad superior y `bottom` la inferior. El material sale de los ajustes.

const Settings = preload("res://scripts/settings.gd")

const W := 40.0
const H := 80.0
enum { IVORY, WOOD, CERAMIC, EBONY, COLORS, STONE }
## Paleta de cada material: cuerpo, borde, puntos, divisor, dorso y dibujo del dorso.
const STYLES := [
	{"body": Color(0.97, 0.95, 0.88), "edge": Color(0.62, 0.57, 0.46), "pip": Color(0.09, 0.09, 0.11),
		"line": Color(0.45, 0.42, 0.36), "back": Color(0.13, 0.2, 0.36), "motif": Color(0.86, 0.7, 0.32)},
	{"body": Color(0.78, 0.57, 0.33), "edge": Color(0.42, 0.26, 0.12), "pip": Color(0.16, 0.08, 0.03),
		"line": Color(0.4, 0.24, 0.1), "back": Color(0.52, 0.33, 0.17), "motif": Color(0.3, 0.17, 0.07)},
	{"body": Color(0.98, 0.98, 1.0), "edge": Color(0.6, 0.68, 0.82), "pip": Color(0.1, 0.25, 0.65),
		"line": Color(0.45, 0.58, 0.82), "back": Color(0.12, 0.3, 0.68), "motif": Color(1, 1, 1)},
	{"body": Color(0.1, 0.1, 0.12), "edge": Color(0.34, 0.32, 0.3), "pip": Color(0.95, 0.93, 0.86),
		"line": Color(0.78, 0.62, 0.26), "back": Color(0.07, 0.07, 0.08), "motif": Color(0.8, 0.65, 0.25)},
	{"body": Color(0.97, 0.95, 0.88), "edge": Color(0.62, 0.57, 0.46), "pip": Color(0.09, 0.09, 0.11),
		"line": Color(0.45, 0.42, 0.36), "back": Color(0.5, 0.14, 0.2), "motif": Color(0.98, 0.85, 0.4)},
	{"body": Color(0.63, 0.61, 0.56), "edge": Color(0.36, 0.34, 0.3), "pip": Color(0.14, 0.13, 0.12),
		"line": Color(0.33, 0.31, 0.28), "back": Color(0.3, 0.3, 0.33), "motif": Color(0.62, 0.6, 0.55)},
]
## Color de los puntos según el número, para el estilo "Puntos de colores".
const PIP_COLORS := [Color.BLACK, Color(0.1, 0.4, 0.85), Color(0.12, 0.6, 0.25), Color(0.85, 0.15, 0.15),
		Color(0.55, 0.2, 0.7), Color(0.92, 0.5, 0.08), Color(0.05, 0.6, 0.62)]

var code: int = 0
var top: int = 0
var bottom: int = 0
## Posición y giro en coordenadas del tablero una vez jugada.
var board_pos := Vector2.ZERO
var board_rot := 0.0

## 1 = boca arriba, 0 = boca abajo.
var flip: float = 1.0:
	set(v):
		flip = v
		queue_redraw()
## Halo dorado (ficha jugable / última jugada).
var glow: float = 0.0:
	set(v):
		glow = v
		queue_redraw()
## Oscurecido (ficha no jugable).
var dim: float = 0.0:
	set(v):
		dim = v
		queue_redraw()

var _style := 0
var _tw: Tween
var _flip_tw: Tween
var _mark_tw: Tween
var _body := StyleBoxFlat.new()
var _back := StyleBoxFlat.new()
var _halo := StyleBoxFlat.new()
var _shade := StyleBoxFlat.new()


func _init() -> void:
	for sb: StyleBoxFlat in [_body, _back]:
		sb.set_corner_radius_all(7)
		sb.set_border_width_all(1)
		sb.border_width_bottom = 3
		sb.shadow_color = Color(0, 0, 0, 0.4)
		sb.shadow_size = 5
	_halo.draw_center = false
	_halo.set_corner_radius_all(9)
	_halo.set_border_width_all(3)
	_halo.shadow_size = 10
	_shade.set_corner_radius_all(7)
	refresh_style()


## Vuelve a leer el material elegido en los ajustes.
func refresh_style() -> void:
	_style = clampi(Settings.data.tile_style, 0, STYLES.size() - 1)
	var st: Dictionary = STYLES[_style]
	_body.bg_color = st.body
	_body.border_color = st.edge
	_back.bg_color = st.back
	_back.border_color = st.back.darkened(0.5)
	var r := 4 if _style == STONE else 7
	_body.set_corner_radius_all(r)
	_back.set_corner_radius_all(r)
	_shade.set_corner_radius_all(r)
	queue_redraw()


func set_values(t: int, b: int) -> void:
	top = t
	bottom = b
	queue_redraw()


func fly_to(pos: Vector2, rot: float, scl: float, dur: float = 0.35, delay: float = 0.0) -> Tween:
	_kill(_tw)
	_tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "position", pos, dur).set_delay(delay)
	_tw.tween_property(self, "rotation", _nearest(rot), dur).set_delay(delay)
	_tw.tween_property(self, "scale", Vector2(scl, scl), dur).set_delay(delay)
	return _tw


## Vuelo de jugada: la ficha se levanta, viaja y cae de golpe sobre la mesa.
func play_to(pos: Vector2, rot: float, scl: float, dur: float = 0.45) -> Tween:
	_kill(_tw)
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(self, "position", pos, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tw.tween_property(self, "rotation", _nearest(rot), dur * 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "scale", Vector2(scl, scl) * 1.4, dur * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tw.chain().tween_property(self, "scale", Vector2(scl, scl), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return _tw


func flip_to(v: float, dur: float = 0.3, delay: float = 0.0) -> void:
	_kill(_flip_tw)
	_flip_tw = create_tween()
	_flip_tw.tween_property(self, "flip", v, dur).set_delay(delay)


func tween_marks(g: float, d: float) -> void:
	_kill(_mark_tw)
	_mark_tw = create_tween().set_parallel(true)
	_mark_tw.tween_property(self, "glow", g, 0.18)
	_mark_tw.tween_property(self, "dim", d, 0.18)


## Sacudida de "esa ficha no se puede jugar".
func wiggle() -> void:
	var base := rotation
	var tw := create_tween()
	for off in [0.12, -0.1, 0.06, 0.0]:
		tw.tween_property(self, "rotation", base + off, 0.05)


func hit(global_point: Vector2) -> bool:
	var l := to_local(global_point)
	return absf(l.x) <= W * 0.5 + 3.0 and absf(l.y) <= H * 0.5 + 3.0


func _kill(tw: Tween) -> void:
	if tw != null and tw.is_valid():
		tw.kill()


func _nearest(rot: float) -> float:
	return rotation + wrapf(rot - rotation, -PI, PI)


func _draw() -> void:
	var st: Dictionary = STYLES[_style]
	var sx := maxf(absf(cos(flip * PI)), 0.03)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sx, 1.0))
	var rect := Rect2(-W * 0.5, -H * 0.5, W, H)
	var ci := get_canvas_item()
	if glow > 0.01:
		_halo.border_color = Color(1.0, 0.82, 0.2, glow)
		_halo.shadow_color = Color(1.0, 0.72, 0.1, 0.55 * glow)
		_halo.draw(ci, rect.grow(3.0))
	if flip >= 0.5:
		_body.draw(ci, rect)
		_draw_material(st)
		draw_line(Vector2(-W * 0.5 + 5.0, 0), Vector2(W * 0.5 - 5.0, 0), st.line, 1.5, true)
		_draw_pips(top, -H * 0.25, st)
		_draw_pips(bottom, H * 0.25, st)
		draw_circle(Vector2.ZERO, 3.2, Color(0.72, 0.55, 0.2), true, -1.0, true)
		draw_circle(Vector2(-0.8, -0.8), 1.2, Color(1.0, 0.9, 0.6), true, -1.0, true)
	else:
		_back.draw(ci, rect)
		var motif: Color = st.motif
		draw_polyline(PackedVector2Array([Vector2(0, -24), Vector2(11, 0), Vector2(0, 24),
				Vector2(-11, 0), Vector2(0, -24)]), motif, 1.5, true)
		draw_circle(Vector2.ZERO, 3.0, motif, true, -1.0, true)
	if dim > 0.01:
		# Sobre el ébano un velo negro no se nota: se usa gris.
		_shade.bg_color = Color(0.5, 0.5, 0.5, 0.5 * dim) if _style == EBONY else Color(0, 0, 0, 0.42 * dim)
		_shade.draw(ci, rect)


## Textura propia de cada material, distinta en cada ficha.
func _draw_material(st: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = code * 7919 + 13
	match _style:
		WOOD:
			var grain: Color = st.edge
			for i in 8:
				var x := rng.randf_range(-W * 0.5 + 3.0, W * 0.5 - 3.0)
				var amp := rng.randf_range(0.5, 2.0)
				var ph := rng.randf() * TAU
				var pts := PackedVector2Array()
				for q in 9:
					var y := -H * 0.5 + 3.0 + (H - 6.0) * q / 8.0
					pts.append(Vector2(clampf(x + sin(y * 0.08 + ph) * amp, -W * 0.5 + 2.0, W * 0.5 - 2.0), y))
				draw_polyline(pts, Color(grain, rng.randf_range(0.12, 0.32)), 1.2, true)
		CERAMIC:
			# Brillo de esmalte.
			draw_colored_polygon(PackedVector2Array([Vector2(-17, -36), Vector2(-6, -36),
					Vector2(-17, -14)]), Color(0.7, 0.85, 1.0, 0.35))
			draw_line(Vector2(13, 10), Vector2(16, 34), Color(0.6, 0.75, 1.0, 0.25), 2.0, true)
		EBONY:
			draw_line(Vector2(-14, -36), Vector2(14, -36), Color(1, 1, 1, 0.16), 1.5, true)
		STONE:
			for i in 34:
				var p := Vector2(rng.randf_range(-17, 17), rng.randf_range(-37, 37))
				var light := rng.randf() < 0.45
				draw_circle(p, rng.randf_range(0.6, 1.5),
						Color(1, 1, 1, 0.16) if light else Color(0, 0, 0, 0.16))
			# Vetas y desconchones.
			for i in 2:
				var a := Vector2(rng.randf_range(-17, 17), rng.randf_range(-36, 36))
				draw_line(a, a + Vector2(rng.randf_range(-12, 12), rng.randf_range(-10, 10)), Color(0, 0, 0, 0.14), 1.0, true)


func _draw_pips(n: int, cy: float, st: Dictionary) -> void:
	var g := 10.5
	var pts: Array = []
	if n % 2 == 1:
		pts.append(Vector2.ZERO)
	if n >= 2:
		pts.append(Vector2(-g, -g))
		pts.append(Vector2(g, g))
	if n >= 4:
		pts.append(Vector2(g, -g))
		pts.append(Vector2(-g, g))
	if n == 6:
		pts.append(Vector2(-g, 0))
		pts.append(Vector2(g, 0))
	var col: Color = PIP_COLORS[n] if _style == COLORS else st.pip
	for p: Vector2 in pts:
		var c := p + Vector2(0, cy)
		if _style == STONE or _style == WOOD:
			# Puntos tallados: un reborde más claro abajo.
			draw_circle(c + Vector2(0.6, 0.9), 4.1, Color(1, 1, 1, 0.22), true, -1.0, true)
		draw_circle(c, 3.9, col, true, -1.0, true)
		draw_circle(c + Vector2(-1.1, -1.1), 1.0, Color(1, 1, 1, 0.28), true, -1.0, true)
