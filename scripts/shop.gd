extends "res://scripts/popup.gd"
## Tienda por pestañas, con los productos en cuadrícula (una tarjeta por
## producto, con su miniatura):
## - Fichas y Mesas: todas las skins. Las normales se pagan con monedas y las
##   exclusivas con gemas (Wallet.PRICES y GEM_ITEMS). Si ya es tuya, "Usar".
## - Monedas: monedas gratis por anuncio y monedas a cambio de gemas.
## - Gemas: gemas con dinero real (Store), oferta de inicio, sin anuncios y VIP.

signal coins_changed
## Se compró o se eligió una ficha o una mesa: el menú repinta lo que se ve.
signal look_changed

const Wallet = preload("res://scripts/wallet.gd")
const Store = preload("res://scripts/store.gd")
const Ads = preload("res://scripts/ads.gd")
const Settings = preload("res://scripts/settings.gd")
const Tile = preload("res://scripts/tile.gd")
const Table = preload("res://scripts/table.gd")

enum { TILES, TABLES, COINS, GEMS }
const TAB_NAMES := ["Fichas", "Mesas", "Monedas", "Gemas"]
const W := 640.0
## Zona de tarjetas, con desplazamiento vertical.
const AREA := Rect2(20, 226, 600, 880)
## Tarjetas de skins: tres por fila.
const SKIN_CARD := Vector2(184, 272)
const GAP := 14.0

var _tab := TILES
var _tabs: Array = []
var _scroll: ScrollContainer
var _content: Control
var _coins_lbl: Label
var _gems_lbl: Label
var _confirm: Control
var _confirm_text: Label
var _confirm_yes: FancyButton
var _on_yes := Callable()


func _ready() -> void:
	frame(Rect2(40, 22, W, 1236), "Tienda")
	# Saldo: gemas y monedas.
	well(Rect2(30, 86, 280, 54))
	gem(Vector2(40, 88), 50.0)
	_gems_lbl = label("", UI.BODY, UI.CREAM, Rect2(96, 86, 200, 54), null, HORIZONTAL_ALIGNMENT_RIGHT)
	well(Rect2(330, 86, 280, 54))
	coin(Vector2(336, 84), 58.0)
	_coins_lbl = label("", UI.BODY, UI.GOLD, Rect2(396, 86, 200, 54), null, HORIZONTAL_ALIGNMENT_RIGHT)

	for i in TAB_NAMES.size():
		var b := button(TAB_NAMES[i], UI.NEUTRAL, Rect2(30 + i * 148, 152, 136, 62), UI.BODY - 4)
		b.pressed.connect(_set_tab.bind(i))
		_tabs.append(b)

	_scroll = ScrollContainer.new()
	_scroll.position = AREA.position
	_scroll.size = AREA.size
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone = 14
	panel.add_child(_scroll)
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_content)

	var test := label("Modo prueba: las compras con dinero no cobran nada." if Store.test_mode() else "",
			UI.CAPTION - 4, UI.WARN, Rect2(0, 1108, W, 30))
	test.visible = Store.test_mode()
	var back := button("Volver", UI.NEUTRAL, Rect2(195, 1140, 250, UI.TOUCH_SMALL), 28)
	back.pressed.connect(close)
	_build_confirm()


## Abre la tienda en una pestaña (TILES, TABLES, COINS o GEMS).
func open_tab(tab: int) -> void:
	_tab = tab
	open()


func refresh() -> void:
	_coins_lbl.text = thousands(Wallet.coins())
	_gems_lbl.text = thousands(Wallet.gems())
	for k in _tabs.size():
		_tabs[k].set_color(UI.BUY if k == _tab else UI.NEUTRAL.darkened(0.35))
	for c in _content.get_children():
		c.queue_free()
	match _tab:
		TILES:
			_skins("tile_style")
		TABLES:
			_skins("table_style")
		COINS:
			_coin_offers()
		GEMS:
			_gem_offers()


func _set_tab(i: int) -> void:
	_tab = i
	_scroll.scroll_vertical = 0
	refresh()


func _set_height(h: float) -> void:
	_content.custom_minimum_size = Vector2(AREA.size.x - 16, h)


# ------------------------------------------------------------------ skins

func _skins(key: String) -> void:
	var names: Array = Settings.TILE_NAMES if key == "tile_style" else Settings.TABLE_NAMES
	var cols := 3
	for i in names.size():
		var pos := Vector2((i % cols) * (SKIN_CARD.x + GAP), (i / cols) * (SKIN_CARD.y + GAP))
		_skin_card(key, i, names[i], Rect2(pos, SKIN_CARD))
	_set_height(ceili(names.size() / float(cols)) * (SKIN_CARD.y + GAP))


func _skin_card(key: String, i: int, item_name: String, rect: Rect2) -> void:
	var box := well(rect, _content)
	var in_use := int(Settings.data[key]) == i
	if in_use:
		# Marco dorado en la que se está usando.
		var ring := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.border_color = UI.GOLD
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(14)
		ring.add_theme_stylebox_override("panel", sb)
		ring.size = rect.size
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(ring)
	# Miniatura.
	if key == "tile_style":
		for k in 2:
			var t: Tile = Tile.new()
			t.painter = true
			t.style_index = i
			t.code = 53 if k == 0 else 0
			t.set_values(6, 5)
			t.refresh_style()
			t.flip = 1.0 if k == 0 else 0.0
			t.position = Vector2(rect.size.x * 0.5 + (k - 0.5) * 58.0, 92)
			t.rotation = -0.14 if k == 0 else 0.14
			t.scale = Vector2(1.3, 1.3)
			box.add_child(t)
	else:
		var full := Table.outer().size
		var k := 150.0 / full.y
		var clip := Control.new()
		clip.clip_contents = true
		clip.size = full * k
		clip.position = Vector2((rect.size.x - clip.size.x) * 0.5, 14)
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(clip)
		var mini: Table = Table.new()
		mini.style_index = i
		mini.scale = Vector2(k, k)
		mini.position = -Table.outer().position * k
		clip.add_child(mini)
	if Wallet.costs_gems(key, i):
		_ribbon("Exclusiva", box, rect.size.x)
	label(item_name, UI.CAPTION - 4, UI.LABEL, Rect2(6, 170, rect.size.x - 12, 36), box)
	var b_rect := Rect2(12, 208, rect.size.x - 24, 54)
	var owned := Wallet.owns(key, i)
	var b: FancyButton
	if in_use:
		b = button("En uso", UI.PRIMARY, b_rect, UI.CAPTION - 2, box)
	elif owned:
		b = button("Usar", UI.SECONDARY, b_rect, UI.CAPTION - 2, box)
		b.pressed.connect(_equip.bind(key, i))
	else:
		b = button("      " + thousands(Wallet.price(key, i)), UI.BUY, b_rect, UI.CAPTION - 2, box)
		if Wallet.costs_gems(key, i):
			gem(Vector2(12, 9), 36.0, b)
		else:
			coin(Vector2(10, 7), 40.0, b)
		b.pressed.connect(_ask_skin.bind(key, i, item_name))
	b.mouse_filter = Control.MOUSE_FILTER_PASS


func _ribbon(text: String, parent: Control, width: float) -> void:
	var w := maxf(104.0, text.length() * 11.0 + 16.0)
	var tag := label(text, UI.CAPTION - 8, Color(0.15, 0.08, 0.02), Rect2(width - w - 8, -8, w, 26), parent)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UI.GOLD
	sb.set_corner_radius_all(9)
	tag.add_theme_stylebox_override("normal", sb)


func _equip(key: String, i: int) -> void:
	Settings.data[key] = i
	Settings.save()
	look_changed.emit()
	refresh()


func _ask_skin(key: String, i: int, item_name: String) -> void:
	var price := Wallet.price_text(key, i)
	if not Wallet.can_afford(key, i):
		var gems := Wallet.costs_gems(key, i)
		var have := Wallet.gems() if gems else Wallet.coins()
		var missing := Wallet.price(key, i) - have
		_confirm_box("Te faltan %s %s para %s." % [thousands(missing), "gemas" if gems else "monedas", item_name],
				"Conseguir", func() -> void: _set_tab(GEMS if gems else COINS))
		play("bad")
		return
	_confirm_box("¿Comprar %s por %s?" % [item_name, price], "Comprar", func() -> void:
		if Wallet.buy(key, i):
			play("win")
			coins_changed.emit()
			_equip(key, i))


# ------------------------------------------------------------------ monedas

func _coin_offers() -> void:
	# Monedas gratis viendo un anuncio, a lo ancho.
	var free := well(Rect2(0, 0, 584, 120), _content)
	label("Monedas gratis", UI.BODY, UI.LABEL, Rect2(20, 10, 300, 40), free, HORIZONTAL_ALIGNMENT_LEFT)
	var left := Wallet.ad_coins_left()
	label("Quedan %d hoy" % left if left > 0 else "Vuelve mañana", UI.CAPTION, UI.CREAM_MUTED,
			Rect2(20, 56, 300, 40), free, HORIZONTAL_ALIGNMENT_LEFT)
	var ad := button("+%d" % Wallet.AD_COINS, UI.SECONDARY, Rect2(344, 18, 220, 84), UI.BUTTON, free)
	ad.set_icon("video", 40)
	ad.disabled = left <= 0
	ad.pressed.connect(_watch_ad)
	ad.mouse_filter = Control.MOUSE_FILTER_PASS
	# Monedas a cambio de gemas, de dos en dos.
	var names := ["Puñado de monedas", "Bolsa de monedas", "Cofre de monedas", "Tesoro de monedas"]
	var card := Vector2(285, 262)
	for i in Wallet.GEM_EXCHANGE.size():
		var offer: Array = Wallet.GEM_EXCHANGE[i]
		var rect := Rect2((i % 2) * (card.x + GAP), 136 + (i / 2) * (card.y + GAP), card.x, card.y)
		var box := well(rect, _content)
		label(names[i], UI.CAPTION, UI.LABEL, Rect2(10, 8, card.x - 20, 40), box)
		_art(box, "shop_coins_%d" % (i + 1), card.x, thousands(int(offer[1])), UI.GOLD)
		var b := button("      " + thousands(int(offer[0])), UI.BUY, Rect2(22, 186, card.x - 44, 62), UI.BODY, box)
		gem(Vector2(16, 12), 38.0, b)
		b.pressed.connect(_ask_exchange.bind(i, names[i]))
		b.mouse_filter = Control.MOUSE_FILTER_PASS
	_set_height(136 + 2 * (card.y + GAP))


## Dibujo del paquete (puñado, bolsa, cofre o tesoro: tools/recortar_tienda.py)
## y la cantidad encima de su parte de abajo, con contorno para que se lea.
func _art(box: Control, tex: String, width: float, amount: String, col: Color) -> void:
	var art := TextureRect.new()
	art.texture = UISkin.tex(tex)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.position = Vector2(8, 40)
	art.size = Vector2(width - 16, 130)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(art)
	var lb := label(amount, UI.TITLE, col, Rect2(0, 136, width, 52), box)
	lb.add_theme_color_override("font_outline_color", UISkin.TITLE_OUTLINE)
	lb.add_theme_constant_override("outline_size", 10)


func _ask_exchange(i: int, item_name: String) -> void:
	var offer: Array = Wallet.GEM_EXCHANGE[i]
	if Wallet.gems() < int(offer[0]):
		_confirm_box("Te faltan %s gemas para el %s." % [thousands(int(offer[0]) - Wallet.gems()), item_name.to_lower()],
				"Conseguir", func() -> void: _set_tab(GEMS))
		play("bad")
		return
	_confirm_box("¿Cambiar %s gemas por %s monedas?" % [thousands(int(offer[0])), thousands(int(offer[1]))],
			"Cambiar", func() -> void:
				if Wallet.exchange(i):
					play("win")
					coins_changed.emit()
					refresh())


func _watch_ad() -> void:
	var ads := Ads.get_ads()
	if ads == null:
		return
	ads.show_rewarded(func() -> void:
		if Wallet.claim_ad_coins() > 0:
			play("win")
			coins_changed.emit()
		refresh())


# ------------------------------------------------------------------ gemas (dinero real)

func _gem_offers() -> void:
	var y := 0.0
	if not Store.owned("starter_pack"):
		_product("starter_pack", Rect2(0, 0, 584, 150))
		y = 166.0
	var ids := ["gems_80", "gems_500", "gems_1100", "gems_3000"]
	var card := Vector2(285, 262)
	for i in ids.size():
		_product(ids[i], Rect2((i % 2) * (card.x + GAP), y + (i / 2) * (card.y + GAP), card.x, card.y))
	y += 2 * (card.y + GAP)
	_product("no_ads", Rect2(0, y, card.x, 220))
	_product("vip_month", Rect2(card.x + GAP, y, card.x, 220))
	_set_height(y + 220)


## Tarjeta de un producto con dinero real: nombre, lo que da, cinta y precio.
func _product(id: String, rect: Rect2) -> void:
	var p := Store.product(id)
	var box := well(rect, _content)
	var wide := rect.size.x > 400
	label(p.name, UI.BODY if wide else UI.CAPTION, UI.LABEL, Rect2(16, 8, rect.size.x - 32, 40), box,
			HORIZONTAL_ALIGNMENT_LEFT if wide else HORIZONTAL_ALIGNMENT_CENTER)
	var gems := int(p.get("gems", 0))
	if id == "starter_pack":
		coin(Vector2(16, 56), 46.0, box)
		label(thousands(int(p.coins)), UI.BODY + 4, UI.GOLD, Rect2(66, 54, 130, 50), box, HORIZONTAL_ALIGNMENT_LEFT)
		gem(Vector2(196, 58), 42.0, box)
		label(thousands(gems), UI.BODY + 4, UI.CREAM, Rect2(244, 54, 100, 50), box, HORIZONTAL_ALIGNMENT_LEFT)
	elif gems > 0:
		# Recorte de la referencia (tools/recortar_tienda.py): la cantidad ya va
		# dibujada encima del paquete, como en la imagen.
		var n: int = ["gems_80", "gems_500", "gems_1100", "gems_3000"].find(id) + 1
		var art := TextureRect.new()
		art.texture = UISkin.tex("shop_gems_%d" % n)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.position = Vector2(8, 44)
		art.size = Vector2(rect.size.x - 16, 136)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(art)
	else:
		var icon := TextureRect.new()
		icon.texture = UISkin.tex("kit_icon_" + ("video" if id == "no_ads" else "trophy"))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.position = Vector2((rect.size.x - 48) * 0.5, 52)
		icon.size = Vector2(48, 48)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
		label("Sin anuncios entre partidas" if id == "no_ads" else "Sin anuncios y regalo x2",
				UI.CAPTION - 4, UI.CREAM_MUTED, Rect2(10, 104, rect.size.x - 20, 32), box)
	if p.has("tag"):
		_ribbon(p.tag, box, rect.size.x)
	var buy_rect := Rect2(rect.size.x - 236, 40, 220, 84) if wide else Rect2(22, rect.size.y - 74, rect.size.x - 44, 62)
	var done := Store.owned(id)
	var text: String = "Comprado" if done else p.price
	if id == "vip_month" and Wallet.is_vip():
		text = "Activo · %d días" % ceili((int(Wallet.data.vip_until) - Time.get_unix_time_from_system()) / 86400.0)
	var b := button(text, UI.BUY, buy_rect, UI.BODY, box)
	b.disabled = done
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.pressed.connect(func() -> void:
		var msg := "%s por %s." % [p.name, p.price]
		if Store.test_mode():
			msg += "\n\nCompra de prueba: no se cobra nada."
		_confirm_box(msg, "Comprar", func() -> void:
			# En modo prueba se entrega al momento; con Google Play, al confirmarse el pago.
			Store.deliver(id)
			play("win")
			coins_changed.emit()
			refresh()))


# ------------------------------------------------------------ confirmación

func _build_confirm() -> void:
	_confirm = ColorRect.new()
	_confirm.color = Color(0, 0, 0, 0.5)
	_confirm.position = Vector2.ZERO
	_confirm.size = panel.size
	_confirm.visible = false
	panel.add_child(_confirm)
	var box := Panel.new()
	box.position = Vector2(50, 420)
	box.size = Vector2(W - 100, 360)
	_confirm.add_child(box)
	UISkin.dress(box)
	UISkin.title(label("Tienda", UI.TITLE - 6, UI.GOLD, Rect2(0, 18, W - 100, 56), box))
	_confirm_text = para("", UI.BODY - 2, UI.CREAM, Rect2(30, 84, W - 160, 150), box)
	_confirm_yes = button("", UI.PRIMARY, Rect2(30, 248, 250, UI.TOUCH), UI.BUTTON, box)
	_confirm_yes.pressed.connect(func() -> void:
		_confirm.visible = false
		if _on_yes.is_valid():
			_on_yes.call())
	var no := button("Cancelar", UI.NEUTRAL, Rect2(W - 380, 248, 250, UI.TOUCH), UI.BUTTON, box)
	no.pressed.connect(func() -> void: _confirm.visible = false)


func _confirm_box(text: String, yes: String, on_yes: Callable) -> void:
	_confirm_text.text = text
	_confirm_yes.text = yes
	_on_yes = on_yes
	_confirm.visible = true
