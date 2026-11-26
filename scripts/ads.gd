extends CanvasLayer
## Anuncios. main.gd lo crea como /root/Main/Ads (no en el servidor).
##
## Dos tipos (DISEÑO.md y las reglas de abajo):
##   - Con premio (rewarded): los pide el jugador a cambio de algo (doblar el
##     premio, monedas gratis, una pista, otro intento del desafío). Siempre
##     disponibles, también para quien quitó los anuncios.
##   - A pantalla completa (interstitial): solo entre partidas, como mucho uno
##     cada INTER_EVERY_MATCHES partidas y INTER_MIN_SECONDS segundos, nunca en
##     las primeras partidas ni a quien compró "sin anuncios" o tiene VIP.
##
## MODO PRUEBA: mientras no esté el plugin de AdMob (ver servidor/ANUNCIOS_Y_PAGOS.md)
## se muestra un anuncio simulado con su cuenta atrás, para probar todo el
## flujo en el PC. Con el plugin, show_rewarded y after_match llamarán a
## AdMob en lugar de a _simulated (mismas reglas de frecuencia).

const UI = preload("res://scripts/ui_theme.gd")
const UISkin = preload("res://scripts/ui_skin.gd")
const FancyButton = preload("res://scripts/fancy_button.gd")
const Wallet = preload("res://scripts/wallet.gd")
const Stats = preload("res://scripts/stats.gd")

const REWARDED_SECONDS := 5
const INTER_SECONDS := 3
const INTER_EVERY_MATCHES := 3
const INTER_MIN_SECONDS := 180
## Sin anuncios a pantalla completa hasta haber jugado estas partidas.
const INTER_GRACE_MATCHES := 3

var _matches_since := 0
var _last_inter := 0
var _layer: ColorRect
var _box: Panel
var _count_lbl: Label
var _close_btn: FancyButton
var _busy := false


## El nodo de anuncios del juego (o null en el servidor y en las pruebas).
static func get_ads() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Main/Ads") if tree != null else null


func _ready() -> void:
	layer = 50
	# Sigue el centrado del contenido en pantallas altas (ver main.gd).
	follow_viewport_enabled = true
	_last_inter = Time.get_ticks_msec() / 1000


## Muestra un anuncio con premio. `on_reward` se llama solo si se vio entero;
## `on_done` (si se pasa) se llama siempre al cerrarse.
func show_rewarded(on_reward: Callable, on_done: Callable = Callable()) -> void:
	if _busy:
		return
	_busy = true
	var ok: bool = await _simulated(true)
	_busy = false
	if ok:
		on_reward.call()
	if on_done.is_valid():
		on_done.call()


## Tras una partida: muestra un anuncio a pantalla completa si toca según las
## reglas de frecuencia. Espera a que se cierre.
func after_match() -> void:
	_matches_since += 1
	var now := Time.get_ticks_msec() / 1000
	if Wallet.ads_removed() or _busy or int(Stats.data.matches) < INTER_GRACE_MATCHES:
		return
	if _matches_since < INTER_EVERY_MATCHES or now - _last_inter < INTER_MIN_SECONDS:
		return
	_matches_since = 0
	_last_inter = now
	_busy = true
	await _simulated(false)
	_busy = false


# ------------------------------------------------------------ anuncio simulado

## Anuncio de prueba a pantalla completa. Devuelve true si se vio entero.
func _simulated(rewarded: bool) -> bool:
	_build()
	_layer.visible = true
	var secs := REWARDED_SECONDS if rewarded else INTER_SECONDS
	_close_btn.visible = false
	var watched := [false]
	# Con premio se puede cerrar antes (sin premio); a pantalla completa, no.
	var skip := FancyButton.new()
	skip.setup("Saltar (sin premio)", UI.NEUTRAL, UI.CAPTION)
	skip.position = Vector2(170, 470)
	skip.size = Vector2(300, 70)
	skip.visible = rewarded
	_box.add_child(skip)
	var closed := [false]
	skip.pressed.connect(func() -> void: closed[0] = true)
	for left in range(secs, 0, -1):
		_count_lbl.text = "El anuncio termina en %d…" % left
		await get_tree().create_timer(1.0).timeout
		if closed[0]:
			break
	skip.queue_free()
	if not closed[0]:
		watched[0] = true
		_count_lbl.text = "¡Listo! Ya puedes cerrarlo." if rewarded else ""
		_close_btn.visible = true
		await _close_btn.pressed
	_layer.visible = false
	return watched[0]


func _build() -> void:
	if _layer != null:
		return
	_layer = ColorRect.new()
	_layer.color = Color(0.02, 0.02, 0.03, 0.96)
	_layer.position = Vector2(-1500, -1500)
	_layer.size = Vector2(4280, 3720)
	add_child(_layer)
	_box = Panel.new()
	_box.position = Vector2(40, 340) - _layer.position
	_box.size = Vector2(640, 600)
	_layer.add_child(_box)
	UISkin.dress(_box)
	var t := _text("Anuncio de prueba", UI.TITLE, Rect2(0, 20, 640, 60))
	UISkin.title(t)
	var icon := TextureRect.new()
	icon.texture = UISkin.tex("kit_icon_video")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.position = Vector2(256, 100)
	icon.size = Vector2(128, 128)
	_box.add_child(icon)
	_text("Aquí saldrá un anuncio de Google AdMob cuando la app esté publicada.", UI.CAPTION,
			Rect2(40, 240, 560, 100)).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_count_lbl = _text("", UI.BODY, Rect2(0, 360, 640, 60))
	_close_btn = FancyButton.new()
	_close_btn.setup("Cerrar", UI.PRIMARY, UI.BUTTON)
	_close_btn.position = Vector2(190, 470)
	_close_btn.size = Vector2(260, UI.TOUCH)
	_box.add_child(_close_btn)


func _text(text: String, font_size: int, rect: Rect2) -> Label:
	var lb := Label.new()
	lb.text = text
	lb.add_theme_font_size_override("font_size", font_size)
	lb.add_theme_color_override("font_color", UI.CREAM)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.position = rect.position
	lb.size = rect.size
	_box.add_child(lb)
	return lb
