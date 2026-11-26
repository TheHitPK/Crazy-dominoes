extends Control
## Moneda del juego (assets/ui/coin_domino.png), para el saldo, los precios y
## los premios. Se ajusta al cuadrado más grande que quepa en el control.

const UISkin = preload("res://scripts/ui_skin.gd")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var side := minf(size.x, size.y)
	draw_texture_rect(UISkin.tex("coin_domino"), Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side)), false)
