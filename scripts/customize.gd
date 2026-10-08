extends ColorRect
## Panel de personalización: manos, fichas, mesa y bebida, con vista previa.

signal changed
signal closed

const Settings = preload("res://scripts/settings.gd")
const Tile = preload("res://scripts/tile.gd")
const Table = preload("res://scripts/table.gd")
const Hand = preload("res://scripts/hand.gd")
const Glass = preload("res://scripts/glass.gd")
const FancyButton = preload("res://scripts/fancy_button.gd")

const GOLD := Color(1.0, 0.84, 0.3)
const CREAM := Color(0.97, 0.93, 0.82)
const ROW_H := 108.0

var sfx: Node
var _panel: Panel
var _swatches := {}
var _values := {}
var _mini_table: Table
var _box_style := StyleBoxFlat.new()
var _hand: Hand
var _tiles: Array = []
var _glass: Glass


func _ready() -> void:
	color = Color(0, 0, 0, 0.72)
	# Más grande que la pantalla para cubrir también los márgenes de un teléfono.
	position = Vector2(-1500, -1500)
	size = Vector2(4280, 3720)
	visible = false

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.08, 0.05, 0.98)
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.position = Vector2(30, 70) - position
	_panel.size = Vector2(660, 1140)
	_panel.pivot_offset = _panel.size * 0.5
	add_child(_panel)
	_text("Personalizar", 32, GOLD, Rect2(0, 12, 660, 44), HORIZONTAL_ALIGNMENT_CENTER)

	# Vista previa arriba; las opciones debajo, una por fila.
	var y := 336.0
	_swatch_row(y, "Color de piel", Settings.SKINS, "skin")
	_cycle_row(y + ROW_H, "Manos", Settings.HAND_NAMES, "hand_style")
	_swatch_row(y + ROW_H * 2, "Color de uñas / guantes", Settings.ACCENTS, "accent")
	_cycle_row(y + ROW_H * 3, "Fichas", Settings.TILE_NAMES, "tile_style")
	_cycle_row(y + ROW_H * 4, "Mesa", Settings.TABLE_NAMES, "table_style")
	_cycle_row(y + ROW_H * 5, "Tu bebida", Settings.DRINK_NAMES, "drink")
	_text("En la partida, toca tu vaso (abajo a la derecha) para beber.", 16,
			Color(CREAM, 0.75), Rect2(0, 986, 660, 24), HORIZONTAL_ALIGNMENT_CENTER)

	_build_preview()
	var close: FancyButton = FancyButton.new()
	close.setup("Listo", Color(0.25, 0.62, 0.3), 24)
	close.position = Vector2(200, 1040)
	close.size = Vector2(260, 70)
	_panel.add_child(close)
	close.pressed.connect(_close)
	_refresh()


func _close() -> void:
	_click()
	visible = false
	closed.emit()


func open() -> void:
	visible = true
	modulate.a = 0.0
	_panel.scale = Vector2(0.7, 0.7)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _text(text: String, font_size: int, col: Color, rect: Rect2, align: HorizontalAlignment) -> Label:
	var lb := Label.new()
	lb.text = text
	lb.add_theme_font_size_override("font_size", font_size)
	lb.add_theme_color_override("font_color", col)
	lb.horizontal_alignment = align
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.position = rect.position
	lb.size = rect.size
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(lb)
	return lb


## Fila de círculos de color.
func _swatch_row(y: float, title: String, colors: Array, key: String) -> void:
	_text(title, 21, GOLD, Rect2(36, y, 500, 28), HORIZONTAL_ALIGNMENT_LEFT)
	var list: Array = []
	for i in colors.size():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.position = Vector2(36 + i * 74.0, y + 32.0)
		b.size = Vector2(60, 60)
		_panel.add_child(b)
		b.pressed.connect(_choose.bind(key, i))
		list.append(b)
	_swatches[key] = [list, colors]


## Fila con flechas para pasar de una opción a otra.
func _cycle_row(y: float, title: String, names: Array, key: String) -> void:
	_text(title, 21, GOLD, Rect2(36, y, 500, 28), HORIZONTAL_ALIGNMENT_LEFT)
	var n := names.size()
	_arrow("<", Vector2(36, y + 32.0), key, n - 1, n)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.35)
	sb.set_corner_radius_all(8)
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", sb)
	bg.position = Vector2(116, y + 32.0)
	bg.size = Vector2(428, 60)
	_panel.add_child(bg)
	_values[key] = [_text("", 24, CREAM, Rect2(116, y + 32.0, 428, 60), HORIZONTAL_ALIGNMENT_CENTER), names]
	_arrow(">", Vector2(552, y + 32.0), key, 1, n)


func _arrow(text: String, pos: Vector2, key: String, delta: int, n: int) -> void:
	var b: FancyButton = FancyButton.new()
	b.setup(text, Color(0.45, 0.33, 0.22), 28)
	b.position = pos
	b.size = Vector2(72, 60)
	_panel.add_child(b)
	b.pressed.connect(func() -> void: _choose(key, (int(Settings.data[key]) + delta) % n))


func _choose(key: String, value: int) -> void:
	Settings.data[key] = value
	Settings.save()
	_click()
	_refresh()
	changed.emit()


func _click() -> void:
	if sfx != null:
		sfx.play("click")


func _build_preview() -> void:
	var origin := Vector2(30, 66)
	# La mesa entera en miniatura. En un teléfono es más alta (Table.pad), así
	# que se encoge para que quepa entera en el alto de la vista previa.
	# La cuadrada de la web de escritorio (Table.side) además se limita por el ancho.
	var full := Table.SCREEN + Vector2(Table.side, Table.pad) * 2.0
	var mini := minf(250.0 / full.y, 150.0 / full.x)
	var clip := Control.new()
	clip.position = origin + Vector2(0, (250.0 - full.y * mini) * 0.5)
	clip.size = full * mini
	clip.clip_contents = true
	_panel.add_child(clip)
	_mini_table = Table.new()
	_mini_table.scale = Vector2(mini, mini)
	_mini_table.position = Vector2(Table.side, Table.pad) * mini
	clip.add_child(_mini_table)

	# Un trozo de mesa con tu mano, tus fichas y tu vaso.
	_box_style.set_corner_radius_all(10)
	_box_style.border_color = Color(0, 0, 0, 0.5)
	_box_style.set_border_width_all(2)
	var box := Panel.new()
	box.add_theme_stylebox_override("panel", _box_style)
	box.position = origin + Vector2(160, 0)
	box.size = Vector2(440, 250)
	box.clip_contents = true
	_panel.add_child(box)

	_hand = Hand.new()
	_hand.position = Vector2(180, 150)
	_hand.sleeve = Color(0.2, 0.45, 0.85)
	box.add_child(_hand)
	_hand.set_count(4)
	var samples := [[6, 6], [3, 5], [1, 4], [0, 2]]
	for i in samples.size():
		var t: Tile = Tile.new()
		t.code = samples[i][0] * 8 + samples[i][1]
		t.set_values(samples[i][0], samples[i][1])
		var x := (i - 1.5) * _hand.step()
		t.position = _hand.position + Vector2(x, x * x * _hand.arc)
		t.rotation = x * _hand.fan
		t.z_index = 1
		if i == 3:
			t.flip = 0.0
		box.add_child(t)
		_tiles.append(t)
	_glass = Glass.new()
	_glass.position = Vector2(376, 70)
	box.add_child(_glass)


func _refresh() -> void:
	for key in _swatches.keys():
		var list: Array = _swatches[key][0]
		var colors: Array = _swatches[key][1]
		for i in list.size():
			var selected: bool = Settings.data[key] == i
			var sb := StyleBoxFlat.new()
			sb.bg_color = colors[i]
			sb.set_corner_radius_all(30)
			sb.set_border_width_all(4 if selected else 2)
			sb.border_color = Color.WHITE if selected else Color(0, 0, 0, 0.6)
			var b: Button = list[i]
			for state in ["normal", "hover", "pressed", "focus"]:
				b.add_theme_stylebox_override(state, sb)
	for key in _values.keys():
		var lb: Label = _values[key][0]
		var names: Array = _values[key][1]
		lb.text = names[clampi(Settings.data[key], 0, names.size() - 1)]
	_mini_table.queue_redraw()
	_box_style.bg_color = Table.style().wood
	_hand.skin = Settings.skin_color()
	_hand.style = Settings.data.hand_style
	_hand.accent = Settings.accent_color()
	_hand.refresh()
	for t: Tile in _tiles:
		t.refresh_style()
	_glass.drink = Settings.data.drink
	_glass.grip = _hand.fill()
