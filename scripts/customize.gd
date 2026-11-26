extends ColorRect
## Panel de personalización: avatar, manos, fichas, mesa y bebida, con vista previa.
## También es la tienda: algunas fichas y mesas se compran con monedas (ver
## Wallet.PRICES). Se pueden probar en la vista previa antes de comprarlas.

signal changed
signal closed

const Settings = preload("res://scripts/settings.gd")
const Tile = preload("res://scripts/tile.gd")
const Table = preload("res://scripts/table.gd")
const Hand = preload("res://scripts/hand.gd")
const Glass = preload("res://scripts/glass.gd")
const FancyButton = preload("res://scripts/fancy_button.gd")
const Avatar = preload("res://scripts/avatar.gd")

const UI = preload("res://scripts/ui_theme.gd")
const Wallet = preload("res://scripts/wallet.gd")
const CoinIcon = preload("res://scripts/coin_icon.gd")
const UISkin = preload("res://scripts/ui_skin.gd")

const GOLD := UI.GOLD
const CREAM := UI.CREAM
## Títulos de fila: beige claro, como en el resto de paneles del kit.
const LABEL := UI.LABEL
const ROW_H := 104.0
## Alto de la vista previa (mesa en miniatura y mano con fichas).
const PREVIEW_H := 190.0
## Alto de flechas, círculos de color y casillas de valor: zona táctil de ~38 dp.
const CONTROL_H := 70.0
## Alto del título de cada fila; el control va justo debajo.
const TITLE_H := 34.0

var sfx: Node
var _panel: Panel
var _swatches := {}
var _values := {}
var _mini_table: Table
var _box_style := StyleBoxFlat.new()
var _hand: Hand
var _tiles: Array = []
var _glass: Glass
var _avatar: Avatar
var _avatar_name: Label
var _avatar_note: Label
var _photo_btn: FancyButton
var _web_cb: JavaScriptObject
var _coins_lbl: Label
var _close_btn: FancyButton
var _buy_btn: FancyButton
## Opción que tenía al abrir (comprada o gratis), por clave de la tienda.
var _before := {}


func _ready() -> void:
	color = Color(0, 0, 0, 0.72)
	# Más grande que la pantalla para cubrir también los márgenes de un teléfono.
	position = Vector2(-1500, -1500)
	size = Vector2(4280, 3720)
	visible = false

	_panel = Panel.new()
	_panel.position = Vector2(20, 24) - position
	_panel.size = Vector2(680, 1232)
	_panel.pivot_offset = _panel.size * 0.5
	add_child(_panel)
	UISkin.dress(_panel)
	UISkin.title(_text("Personalizar", UI.TITLE, GOLD, Rect2(0, 12, 680, 60), HORIZONTAL_ALIGNMENT_CENTER))

	# Vista previa arriba; las opciones debajo, una por fila.
	_avatar_row(270.0)
	var y := 270.0 + ROW_H + 6.0
	_cycle_row(y, "Manos (si no, un atril sostiene las fichas)", Settings.SHOW_HANDS_NAMES, "show_hands")
	_swatch_row(y + ROW_H, "Color de piel", Settings.SKINS, "skin")
	_cycle_row(y + ROW_H * 2, "Manos", Settings.HAND_NAMES, "hand_style")
	_swatch_row(y + ROW_H * 3, "Color de uñas / guantes", Settings.ACCENTS, "accent")
	_cycle_row(y + ROW_H * 4, "Fichas", Settings.TILE_NAMES, "tile_style")
	_cycle_row(y + ROW_H * 5, "Mesa", Settings.TABLE_NAMES, "table_style")
	_cycle_row(y + ROW_H * 6, "Tu bebida (en la partida, tócala para beber)", Settings.DRINK_NAMES, "drink")

	_build_preview()
	# Saldo arriba a la derecha, para la tienda: pastilla hundida con la moneda.
	var pill := Panel.new()
	pill.add_theme_stylebox_override("panel", UISkin.field_box())
	pill.position = Vector2(516, 22)
	pill.size = Vector2(136, 44)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(pill)
	var coin: CoinIcon = CoinIcon.new()
	coin.position = Vector2(500, 16)
	coin.size = Vector2(56, 56)
	_panel.add_child(coin)
	_coins_lbl = _text("", UI.BODY, GOLD, Rect2(556, 22, 86, 44), HORIZONTAL_ALIGNMENT_RIGHT)
	_close_btn = FancyButton.new()
	_close_btn.setup("Listo", UI.PRIMARY, UI.BUTTON + 4)
	_close_btn.position = Vector2(210, 1132)
	_close_btn.size = Vector2(260, UI.TOUCH)
	_panel.add_child(_close_btn)
	_close_btn.pressed.connect(_close)
	# Si lo elegido es de pago y no está comprado, aparece este botón junto a "Listo".
	_buy_btn = FancyButton.new()
	_buy_btn.setup("", UI.BUY, 30)
	_buy_btn.position = Vector2(36, 1132)
	_buy_btn.size = Vector2(370, UI.TOUCH)
	_buy_btn.visible = false
	_panel.add_child(_buy_btn)
	_buy_btn.pressed.connect(_buy)
	_refresh()


## Cierra el panel. Lo que se estaba probando sin comprar vuelve a lo que tenía.
func _close() -> void:
	_click()
	for key: String in Wallet.PRICES.keys():
		if not Wallet.owns(key, int(Settings.data[key])):
			Settings.data[key] = _before.get(key, 0)
	Settings.save()
	changed.emit()
	visible = false
	closed.emit()


## Primera opción elegida de pago y sin comprar, como [clave, índice]; vacío si no hay.
func _unpaid() -> Array:
	for key: String in Wallet.PRICES.keys():
		var i := int(Settings.data[key])
		if not Wallet.owns(key, i):
			return [key, i]
	return []


func _buy() -> void:
	var item := _unpaid()
	if item.is_empty():
		return
	if Wallet.buy(item[0], item[1]):
		if sfx != null:
			sfx.play("win")
		_before[item[0]] = item[1]
	elif sfx != null:
		sfx.play("bad")
	_refresh()


func open() -> void:
	# Lo que tengo ahora (comprado o gratis), para volver a ello si pruebo algo y no lo compro.
	for key: String in Wallet.PRICES.keys():
		_before[key] = int(Settings.data[key])
	_refresh()
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
	_text(title, UI.CAPTION, LABEL, Rect2(36, y, 600, TITLE_H), HORIZONTAL_ALIGNMENT_LEFT)
	var list: Array = []
	for i in colors.size():
		# Bola de color con brillo; la elegida lleva además un aro dorado.
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.position = Vector2(36 + i * 76.0, y + TITLE_H + 2.0)
		b.size = Vector2(66, 66)
		_panel.add_child(b)
		for part: Array in [["kit_orb_gloss", 0.0], ["kit_orb_ring", -6.0]]:
			var tr := TextureRect.new()
			tr.texture = UISkin.tex(part[0])
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.position = Vector2(part[1], part[1])
			tr.size = b.size - Vector2(part[1], part[1]) * 2.0
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(tr)
		b.pressed.connect(_choose.bind(key, i))
		list.append(b)
	_swatches[key] = [list, colors]


## Fila con flechas para pasar de una opción a otra.
func _cycle_row(y: float, title: String, names: Array, key: String) -> void:
	_text(title, UI.CAPTION, LABEL, Rect2(36, y, 600, TITLE_H), HORIZONTAL_ALIGNMENT_LEFT)
	var n := names.size()
	_arrow("<", Vector2(36, y + TITLE_H), key, n - 1, n)
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", UISkin.field_box())
	bg.position = Vector2(132, y + TITLE_H)
	bg.size = Vector2(416, CONTROL_H)
	_panel.add_child(bg)
	_values[key] = [_text("", 28, CREAM, Rect2(132, y + TITLE_H, 416, CONTROL_H), HORIZONTAL_ALIGNMENT_CENTER), names]
	_arrow(">", Vector2(560, y + TITLE_H), key, 1, n)


func _arrow(text: String, pos: Vector2, key: String, delta: int, n: int) -> void:
	var b := _arrow_btn(text == "<", pos)
	b.pressed.connect(func() -> void: _choose(key, (int(Settings.data[key]) + delta) % n))


## Botón de madera con flecha dorada (selectores de opción).
func _arrow_btn(left: bool, pos: Vector2) -> FancyButton:
	var b: FancyButton = FancyButton.new()
	var chev := UISkin.tex("kit_chev_l" if left else "kit_chev_r")
	b.setup("" if chev != null else ("<" if left else ">"), UI.NEUTRAL, UI.BUTTON)
	b.icon = chev
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.position = pos
	b.size = Vector2(84, CONTROL_H)
	_panel.add_child(b)
	return b


## Fila del avatar: el círculo como se verá en la mesa, flechas para pasar de
## un icono a otro (y a mi foto, si subí una) y el botón para subir foto.
func _avatar_row(y: float) -> void:
	_text("Tu avatar", UI.CAPTION, LABEL, Rect2(36, y, 200, TITLE_H), HORIZONTAL_ALIGNMENT_LEFT)
	_avatar_note = _text("", UI.CAPTION, UI.WARN, Rect2(200, y, 444, TITLE_H), HORIZONTAL_ALIGNMENT_RIGHT)
	_avatar = Avatar.new()
	_avatar.position = Vector2(36, y + TITLE_H)
	_avatar.size = Vector2(CONTROL_H, CONTROL_H)
	_avatar.ring = GOLD
	_panel.add_child(_avatar)
	for i in 2:
		var b := _arrow_btn(i == 0, Vector2(118 if i == 0 else 392, y + TITLE_H))
		b.pressed.connect(_step_avatar.bind(-1 if i == 0 else 1))
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", UISkin.field_box())
	bg.position = Vector2(210, y + TITLE_H)
	bg.size = Vector2(174, CONTROL_H)
	_panel.add_child(bg)
	_avatar_name = _text("", 26, CREAM, Rect2(210, y + TITLE_H, 174, CONTROL_H), HORIZONTAL_ALIGNMENT_CENTER)
	_photo_btn = FancyButton.new()
	_photo_btn.setup("Subir foto", UI.SECONDARY, 26)
	_photo_btn.position = Vector2(484, y + TITLE_H)
	_photo_btn.size = Vector2(160, CONTROL_H)
	_panel.add_child(_photo_btn)
	_photo_btn.pressed.connect(_pick_photo)


## Pasa al icono anterior o siguiente. Si hay una foto guardada, es una opción
## más, antes del primer icono.
func _step_avatar(delta: int) -> void:
	var options: Array = range(Avatar.ICON_NAMES.size())
	if FileAccess.file_exists(Settings.PHOTO_PATH):
		options.push_front(-1)
	var now: int = -1 if Settings.data.avatar_photo != 0 else Settings.data.avatar
	var next: int = options[posmod(maxi(options.find(now), 0) + delta, options.size())]
	Settings.data.avatar_photo = 1 if next < 0 else 0
	if next >= 0:
		Settings.data.avatar = next
	_choose("avatar", Settings.data.avatar)


func _pick_photo() -> void:
	_click()
	_avatar_note.text = ""
	if OS.has_feature("web"):
		_pick_photo_web()
	elif DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show("Elige tu foto", "", "", false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
				PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp;Imágenes;image/png,image/jpeg,image/webp"]),
				func(ok: bool, paths: PackedStringArray, _filter: int) -> void:
					if ok and not paths.is_empty():
						_use_photo.call_deferred(FileAccess.get_file_as_bytes(paths[0])))
	else:
		_avatar_note.text = "Aquí no se pueden elegir fotos"


## En la web no hay selector nativo: se abre el del navegador con un <input>
## y la foto vuelve en base64.
func _pick_photo_web() -> void:
	_web_cb = JavaScriptBridge.create_callback(func(args: Array) -> void:
		_use_photo(Marshalls.base64_to_raw(str(args[0]))))
	JavaScriptBridge.get_interface("window").godotAvatarPhoto = _web_cb
	JavaScriptBridge.eval("""(function () {
		var input = document.createElement('input');
		input.type = 'file';
		input.accept = 'image/png,image/jpeg,image/webp';
		input.onchange = function () {
			var file = input.files[0];
			if (!file) return;
			var reader = new FileReader();
			reader.onload = function () {
				var s = reader.result;
				window.godotAvatarPhoto(s.substring(s.indexOf(',') + 1));
			};
			reader.readAsDataURL(file);
		};
		input.click();
	})();""", true)


func _use_photo(bytes: PackedByteArray) -> void:
	if Settings.set_photo(bytes):
		_refresh()
		changed.emit()
	else:
		_avatar_note.text = "No se pudo abrir esa imagen"


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
	var origin := Vector2(36, 72)
	# La mesa entera en miniatura. En un teléfono es más alta (Table.pad), así
	# que se encoge para que quepa entera en el alto de la vista previa.
	# La cuadrada de la web de escritorio (Table.side) además se limita por el ancho.
	var full := Table.SCREEN + Vector2(Table.side, Table.pad) * 2.0
	var mini := minf(PREVIEW_H / full.y, 140.0 / full.x)
	var clip := Control.new()
	clip.position = origin + Vector2(0, (PREVIEW_H - full.y * mini) * 0.5)
	clip.size = full * mini
	clip.clip_contents = true
	_panel.add_child(clip)
	_mini_table = Table.new()
	_mini_table.scale = Vector2(mini, mini)
	_mini_table.position = Vector2(Table.side, Table.pad) * mini
	clip.add_child(_mini_table)

	# Un trozo de mesa con tu mano, tus fichas y tu vaso.
	_box_style.set_corner_radius_all(12)
	_box_style.border_color = UI.BORDER
	_box_style.set_border_width_all(3)
	var box := Panel.new()
	box.add_theme_stylebox_override("panel", _box_style)
	box.position = origin + Vector2(156, 0)
	box.size = Vector2(452, PREVIEW_H)
	box.clip_contents = true
	_panel.add_child(box)

	_hand = Hand.new()
	_hand.position = Vector2(186, 126)
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
	_glass.position = Vector2(392, 60)
	box.add_child(_glass)


func _refresh() -> void:
	for key in _swatches.keys():
		var list: Array = _swatches[key][0]
		var colors: Array = _swatches[key][1]
		for i in list.size():
			var selected: bool = Settings.data[key] == i
			var sb := StyleBoxFlat.new()
			sb.bg_color = colors[i]
			sb.set_corner_radius_all(33)
			var b: Button = list[i]
			for state in ["normal", "hover", "pressed", "focus"]:
				b.add_theme_stylebox_override(state, sb)
			b.get_child(1).visible = selected
	for key in _values.keys():
		var lb: Label = _values[key][0]
		var names: Array = _values[key][1]
		var i := clampi(Settings.data[key], 0, names.size() - 1)
		lb.text = names[i]
		if not Wallet.owns(key, i):
			lb.text += "  ·  %s" % Wallet.price_text(key, i)
		lb.add_theme_color_override("font_color", CREAM if Wallet.owns(key, i) else GOLD)
	_coins_lbl.text = str(Wallet.coins())
	var item := _unpaid()
	_buy_btn.visible = not item.is_empty()
	# Con algo por comprar, "Listo" se corre a la derecha y lo deshace.
	_close_btn.position.x = 420.0 if _buy_btn.visible else 210.0
	_close_btn.size.x = 224.0 if _buy_btn.visible else 260.0
	if not item.is_empty():
		var cost := Wallet.price(item[0], item[1])
		var gems := Wallet.costs_gems(item[0], item[1])
		var have := Wallet.gems() if gems else Wallet.coins()
		_buy_btn.text = "Comprar por %s" % Wallet.price_text(item[0], item[1]) if have >= cost \
				else "Te faltan %d %s" % [cost - have, "gemas" if gems else "monedas"]
		_buy_btn.disabled = have < cost
	_mini_table.refresh()
	_box_style.bg_color = Table.style().wood
	_hand.skin = Settings.skin_color()
	_hand.style = Settings.data.hand_style
	_hand.accent = Settings.accent_color()
	_hand.refresh()
	_hand.rack = Settings.data.show_hands == 0
	Settings.apply_avatar(_avatar)
	var photo: bool = Settings.data.avatar_photo != 0 and Settings.photo_texture() != null
	_avatar_name.text = "Tu foto" if photo else Avatar.ICON_NAMES[clampi(Settings.data.avatar, 0, Avatar.ICON_NAMES.size() - 1)]
	_photo_btn.text = "Otra foto" if FileAccess.file_exists(Settings.PHOTO_PATH) else "Subir foto"
	for t: Tile in _tiles:
		t.refresh_style()
	_glass.drink = Settings.data.drink
	_glass.grip = _hand.fill()
