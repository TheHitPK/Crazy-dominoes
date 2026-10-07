extends Node2D
## Vaso visto desde arriba, apoyado en un posavasos. El jugador puede cogerlo
## y beber: el vaso se levanta, va hacia él, se inclina y baja de nivel.

const R := 32.0
enum { SODA, BEER, LEMONADE, COFFEE, WATER }
const LIQUIDS := [Color(0.27, 0.11, 0.05, 0.95), Color(0.93, 0.63, 0.14, 0.95), Color(0.95, 0.9, 0.35, 0.9),
		Color(0.42, 0.25, 0.13, 1.0), Color(0.6, 0.82, 0.95, 0.55)]

var drink := SODA:
	set(v):
		drink = v
		queue_redraw()
## 1 = lleno, 0 = vacío.
var level := 1.0:
	set(v):
		level = v
		queue_redraw()
## 0 = apoyado, 1 = levantado en la mano.
var lift := 0.0:
	set(v):
		lift = v
		scale = Vector2.ONE * (1.0 + 0.3 * v)
		queue_redraw()
## 0 = recto, 1 = inclinado para beber.
var tilt := 0.0:
	set(v):
		tilt = v
		queue_redraw()
## Color de la mano que lo agarra.
var grip := Color(0.94, 0.76, 0.6)
## Dirección hacia el jugador dueño del vaso.
var toward := Vector2.DOWN
var busy := false


func hit(global_point: Vector2) -> bool:
	return to_local(global_point).length() <= R + 6.0


## Bebe un trago llevando el vaso hasta `target`. `on_gulp` suena al tragar.
func sip(target: Vector2, on_gulp: Callable) -> void:
	if busy or level <= 0.02:
		return
	busy = true
	var home := position
	z_index = 22
	var tw := create_tween()
	tw.tween_property(self, "lift", 1.0, 0.2)
	tw.tween_property(self, "position", target, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "tilt", 1.0, 0.25)
	tw.tween_callback(on_gulp)
	tw.tween_property(self, "level", maxf(level - 0.25, 0.0), 0.6)
	tw.tween_property(self, "tilt", 0.0, 0.2)
	tw.tween_property(self, "position", home, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "lift", 0.0, 0.15)
	tw.tween_callback(_put_down)


func refill() -> void:
	if not busy and level < 0.99:
		create_tween().tween_property(self, "level", 1.0, 0.7)


func _put_down() -> void:
	busy = false
	z_index = 6


func _draw() -> void:
	# Sombra: se aleja cuanto más levantado está.
	draw_circle(Vector2(3, 4) * (1.0 + 3.0 * lift), R, Color(0, 0, 0, 0.32 - 0.12 * lift), true, -1.0, true)
	# +Y local apunta al jugador; al inclinarse el vaso se achata en ese eje.
	draw_set_transform(Vector2.ZERO, toward.angle() - PI * 0.5, Vector2(1.0, 1.0 - 0.3 * tilt))
	var liquid: Color = LIQUIDS[drink]
	var lr := (R - 5.0) * (0.45 + 0.55 * level)
	var lpos := Vector2(0, tilt * (R - 5.0 - lr + 4.0))
	if drink == COFFEE:
		draw_arc(Vector2(R + 2.0, 0), 9.0, -PI * 0.5, PI * 0.5, 14, Color(0.93, 0.92, 0.88), 6.0, true)
		draw_circle(Vector2.ZERO, R, Color(0.95, 0.94, 0.9), true, -1.0, true)
		draw_circle(Vector2.ZERO, R - 5.0, Color(0.78, 0.76, 0.7), true, -1.0, true)
		if level > 0.02:
			draw_circle(lpos, lr, liquid, true, -1.0, true)
			# Espuma de leche en espiral.
			draw_arc(lpos, lr * 0.62, PI * 0.2, PI * 1.7, 20, Color(0.93, 0.8, 0.62, 0.9), 3.5, true)
			draw_arc(lpos, lr * 0.3, PI * 1.2, PI * 2.6, 14, Color(0.93, 0.8, 0.62, 0.9), 3.0, true)
	else:
		draw_circle(Vector2.ZERO, R, Color(0.85, 0.93, 1.0, 0.3), true, -1.0, true)
		if level > 0.02:
			draw_circle(lpos, lr, liquid, true, -1.0, true)
			if drink == BEER:
				draw_arc(lpos, lr - 2.5, 0.0, TAU, 40, Color(1, 0.98, 0.9, 0.95), 5.0, true)
				for b in [Vector2(-7, -5), Vector2(6, 4), Vector2(-2, 9), Vector2(9, -8)]:
					draw_circle(lpos + b * (lr / R), 3.5, Color(1, 0.98, 0.9, 0.85), true, -1.0, true)
			if drink == LEMONADE:
				var lp := Vector2(8, -7)
				draw_circle(lp, 10.0, Color(0.98, 0.85, 0.15), true, -1.0, true)
				draw_circle(lp, 8.0, Color(1.0, 0.96, 0.6), true, -1.0, true)
				for s in 6:
					draw_line(lp, lp + Vector2.RIGHT.rotated(s * TAU / 6.0) * 8.0, Color(0.98, 0.85, 0.15), 1.2, true)
		if drink != BEER:
			for cube in [[Vector2(-8, -6), 0.4], [Vector2(9, 5), 1.1], [Vector2(-3, 11), 0.1]]:
				var cp: Vector2 = cube[0]
				_ice(cp, cube[1])
		draw_arc(Vector2.ZERO, R, 0.0, TAU, 48, Color(1, 1, 1, 0.65), 1.5, true)
		draw_arc(Vector2.ZERO, R - 7.0, PI * 1.1, PI * 1.5, 16, Color(1, 1, 1, 0.5), 2.0, true)
	# Dedos del jugador rodeando el vaso por su lado.
	if lift > 0.05:
		var dark := Color(grip.darkened(0.38), lift)
		for j in 4:
			var ang := PI * 0.5 + (j - 1.5) * 0.36
			var d := Vector2(cos(ang), sin(ang))
			var a := d * (R + 9.0)
			var b := d * (R - 10.0)
			draw_line(a, b, dark, 12.0, true)
			draw_circle(b, 6.0, dark, true, -1.0, true)
			draw_line(a, b, Color(grip, lift), 9.0, true)
			draw_circle(b, 4.5, Color(grip, lift), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)


func _ice(at: Vector2, rot: float) -> void:
	var pts := PackedVector2Array()
	for corner in [Vector2(-6.5, -6.5), Vector2(6.5, -6.5), Vector2(6.5, 6.5), Vector2(-6.5, 6.5), Vector2(-6.5, -6.5)]:
		pts.append(at + corner.rotated(rot))
	draw_colored_polygon(pts.slice(0, 4), Color(1, 1, 1, 0.42))
	draw_polyline(pts, Color(1, 1, 1, 0.6), 1.0, true)
