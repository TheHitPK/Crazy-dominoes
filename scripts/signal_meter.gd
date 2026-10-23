extends Control
## Señal de la conexión con el servidor: tres barras (verde, amarilla o roja)
## y el retraso de ida y vuelta en milisegundos. Solo se ve en partidas a
## distancia o como invitado en la wifi; el anfitrión de la wifi es el servidor.

const UI = preload("res://scripts/ui_theme.gd")

## Por debajo de esto la conexión es buena (3 barras) o regular (2).
const GOOD_MS := 150
const FAIR_MS := 300

var net: Node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	net.latency_changed.connect(func(_ms: int) -> void: queue_redraw())
	visible = net.online and not net.serving


func _draw() -> void:
	var ms: int = net.latency_ms
	var bars := 0
	var col := Color(0.9, 0.3, 0.25)
	var text := "…"
	if ms >= 0:
		text = "%d ms" % ms
		bars = 3 if ms < GOOD_MS else (2 if ms < FAIR_MS else 1)
		col = Color(0.35, 0.85, 0.4) if bars == 3 else (Color(1.0, 0.8, 0.25) if bars == 2 else col)
	elif net.get("_last_rtt") != 0:
		text = "sin señal"
	var h := size.y
	for i in 3:
		var bh := h * (0.4 + 0.3 * i)
		var r := Rect2(i * 9.0, h - bh, 6.0, bh)
		draw_rect(r, col if i < bars else Color(1, 1, 1, 0.22))
	var font := ThemeDB.fallback_font
	var fs := 20
	var base := (h + font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	draw_string_outline(font, Vector2(32, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.7))
	draw_string(font, Vector2(32, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.CREAM)
