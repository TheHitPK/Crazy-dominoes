extends Control
## Gema del juego (la moneda escasa: ver Wallet), para el saldo, los precios y
## las recompensas. La imagen (assets/ui/gem.png) es un recorte de la referencia
## de la tienda (tools/recortar_tienda.py). Se ajusta al control sin deformarse.

const UISkin = preload("res://scripts/ui_skin.gd")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var tex := UISkin.tex("gem")
	var k := minf(size.x / tex.get_width(), size.y / tex.get_height())
	var s := tex.get_size() * k
	draw_texture_rect(tex, Rect2((size - s) * 0.5, s), false)
