extends ColorRect
## Base de los paneles que se abren encima del menú (tienda, torneo, ranked,
## desafío, estadísticas): capa oscura a pantalla completa, panel con el marco
## del kit, título dorado y la animación de abrir (DISEÑO.md, "Panel").
## Cada panel hace `extends "res://scripts/popup.gd"`, llama a frame() en su
## _ready y pinta su contenido en refresh().

signal closed

const UI = preload("res://scripts/ui_theme.gd")
const UISkin = preload("res://scripts/ui_skin.gd")
const FancyButton = preload("res://scripts/fancy_button.gd")
const CoinIcon = preload("res://scripts/coin_icon.gd")
const GemIcon = preload("res://scripts/gem_icon.gd")

var sfx: Node
var panel: Panel
var title_lbl: Label


## Monta la capa y el panel en `rect` (coordenadas del lienzo 720x1280).
func frame(rect: Rect2, title: String) -> void:
	color = Color(0, 0, 0, 0.5)
	# Más grande que la pantalla para cubrir también los márgenes de un teléfono.
	position = Vector2(-1500, -1500)
	size = Vector2(4280, 3720)
	visible = false
	panel = Panel.new()
	panel.position = rect.position - position
	panel.size = rect.size
	panel.pivot_offset = rect.size * 0.5
	add_child(panel)
	UISkin.dress(panel)
	title_lbl = label(title, UI.TITLE, UI.GOLD, Rect2(0, 16, rect.size.x, 60))
	UISkin.title(title_lbl)


func open() -> void:
	refresh()
	visible = true
	modulate.a = 0.0
	panel.scale = Vector2(0.7, 0.7)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	click()
	visible = false
	closed.emit()


## Lo redefine cada panel para poner al día su contenido al abrirse.
func refresh() -> void:
	pass


func click() -> void:
	if sfx != null:
		sfx.play("click")


func play(id: String) -> void:
	if sfx != null:
		sfx.play(id)


func label(text: String, font_size: int, col: Color, rect: Rect2, parent: Node = null,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var lb := Label.new()
	lb.text = text
	lb.add_theme_font_size_override("font_size", font_size)
	lb.add_theme_color_override("font_color", col)
	lb.horizontal_alignment = align
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.position = rect.position
	lb.size = rect.size
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else panel).add_child(lb)
	return lb


## Texto de varias líneas que se parte solo.
func para(text: String, font_size: int, col: Color, rect: Rect2, parent: Node = null) -> Label:
	# El ajuste de línea va antes que el texto: si no, la etiqueta crece a lo ancho.
	var lb := label("", font_size, col, rect, parent)
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb.text = text
	lb.size = rect.size
	return lb


func button(text: String, col: Color, rect: Rect2, font_size: int = UI.BUTTON, parent: Node = null) -> FancyButton:
	var b: FancyButton = FancyButton.new()
	b.setup(text, col, font_size)
	b.position = rect.position
	b.size = rect.size
	(parent if parent != null else panel).add_child(b)
	b.pressed.connect(click)
	return b


## Caja hundida (DISEÑO.md, "Campo hundido") para agrupar contenido.
func well(rect: Rect2, parent: Node = null) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", UISkin.field_box())
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else panel).add_child(p)
	return p


func coin(pos: Vector2, side: float = 34.0, parent: Node = null) -> void:
	var c: CoinIcon = CoinIcon.new()
	c.position = pos
	c.size = Vector2(side, side)
	(parent if parent != null else panel).add_child(c)


func gem(pos: Vector2, side: float = 34.0, parent: Node = null) -> void:
	var g: Control = GemIcon.new()
	g.position = pos
	g.size = Vector2(side, side)
	(parent if parent != null else panel).add_child(g)


## "1.250": miles con punto, como en el resto del juego.
static func thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
