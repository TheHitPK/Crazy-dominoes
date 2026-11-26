extends Control
## Entrada al abrir la app: el logo del estudio (cae el relámpago del Catatumbo
## sobre el lago, destello y nombre) y luego el de Crazy Dominoes mientras se
## cargan las texturas del menú. Todo dibujado en _draw() con las capas que
## genera tools/generar_estudio.py en assets/brand/.
##
## El fondo (intro_fondo.png) es también la pantalla de arranque de Godot
## (project.godot, boot_splash), así que el paso del arranque a la animación
## no se nota. Un toque salta al logo del juego.

signal finished

const Settings = preload("res://scripts/settings.gd")
const UISkin = preload("res://scripts/ui_skin.gd")

## Tiempos (s): cae el rayo, aparece el nombre, entra el logo del juego y,
## como mínimo, cuánto se queda el logo del juego a la vista.
const STRIKE := 0.45
const BOLT_DROP := 0.12
const NAME_AT := 1.0
const GAME_AT := 2.7
const GAME_FADE := 0.45
const GAME_HOLD := 1.1
## Fondo de la imagen del arranque (cielo de arriba), para los bordes.
const SKY := Color(0.039, 0.039, 0.125)

var _t := 0.0
var _bg: Texture2D
var _bolt: Texture2D
var _branches: Texture2D
var _reflection: Texture2D
var _name: Texture2D
var _game: Texture2D
var _vibrated := false
## Efectos de sonido (main.gd lo pasa) para el trueno.
var sfx: Node
var _thundered := false
## Texturas del menú que faltan por cargar (unas pocas por fotograma).
var _to_load: Array = []
var _done := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# load() y no preload: el servidor compila main.gd sin estas imágenes.
	_bg = load("res://assets/brand/intro_fondo.png")
	_bolt = load("res://assets/brand/intro_rayo.png")
	_branches = load("res://assets/brand/intro_ramas.png")
	_reflection = load("res://assets/brand/intro_reflejo.png")
	_name = load("res://assets/brand/intro_nombre.png")
	_game = load("res://assets/brand/splash.png")
	for file in ResourceLoader.list_directory("res://assets/ui/"):
		if file.ends_with(".png"):
			_to_load.append(file.get_basename())


func _process(delta: float) -> void:
	_t += delta
	# Dentro de un CanvasLayer las anclas no siguen al tamaño de la ventana.
	position = Vector2.ZERO
	size = get_viewport_rect().size
	# El trueno arranca cuando el rayo empieza a caer: el chasquido coincide con el golpe.
	if not _thundered and _t >= STRIKE:
		_thundered = true
		if sfx != null:
			sfx.play("thunder")
	if not _vibrated and _t >= STRIKE + BOLT_DROP:
		_vibrated = true
		if Settings.audio.get("vibrate", 1) != 0 and OS.has_feature("mobile"):
			Input.vibrate_handheld(60)
	# Mientras se ve el logo del juego, se cargan las texturas del menú: así el
	# menú no da tirones la primera vez que dibuja botones y paneles.
	if _t >= GAME_AT and not _to_load.is_empty():
		for i in 4:
			if _to_load.is_empty():
				break
			UISkin.tex(_to_load.pop_back())
	if not _done and _t >= GAME_AT + GAME_FADE + GAME_HOLD and _to_load.is_empty():
		_done = true
		finished.emit()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	# Un toque salta al logo del juego (no se salta la carga).
	if event is InputEventMouseButton and event.pressed and _t < GAME_AT:
		_t = GAME_AT
		_vibrated = true
		_thundered = true


## Rectángulo que cubre la pantalla entera con la imagen sin deformarla.
func _cover(tex: Texture2D, zoom := 1.0) -> Rect2:
	var area := size
	var k := maxf(area.x / tex.get_width(), area.y / tex.get_height()) * zoom
	var s := tex.get_size() * k
	return Rect2((area - s) * 0.5, s)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SKY)
	var studio := 1.0 - clampf((_t - GAME_AT) / GAME_FADE, 0.0, 1.0)
	if studio > 0.0:
		_draw_studio(studio)
	if _t > GAME_AT:
		var k := clampf((_t - GAME_AT) / GAME_FADE, 0.0, 1.0)
		var ease := 1.0 - pow(1.0 - k, 3.0)
		draw_texture_rect(_game, _cover(_game, lerpf(1.08, 1.0, ease)), false, Color(1, 1, 1, k))


func _draw_studio(alpha: float) -> void:
	var since := _t - STRIKE
	# Temblor corto cuando el rayo toca el agua.
	var shake := Vector2.ZERO
	var hit := since - BOLT_DROP
	if hit > 0.0 and hit < 0.3:
		var amp := 9.0 * (1.0 - hit / 0.3)
		shake = Vector2(sin(_t * 90.0), cos(_t * 77.0)) * amp
	var r := _cover(_bg)
	r.position += shake
	var white := Color(1, 1, 1, alpha)
	draw_texture_rect(_bg, r, false, white)
	if since <= 0.0:
		return
	# Ramas: parpadean como un relámpago de verdad y se quedan tenues.
	var flick := 0.0
	if since < 0.08:
		flick = 1.0
	elif since < 0.14:
		flick = 0.25
	elif since < 0.24:
		flick = 1.0
	elif since < 0.5:
		flick = lerpf(1.0, 0.0, (since - 0.24) / 0.26)
	elif since < 0.58:
		flick = 0.8
	else:
		flick = lerpf(0.8, 0.35, clampf((since - 0.58) / 0.5, 0.0, 1.0))
	draw_texture_rect(_branches, r, false, Color(1, 1, 1, flick * alpha))
	# El rayo cae de arriba abajo en BOLT_DROP segundos.
	var drop := clampf(since / BOLT_DROP, 0.0, 1.0)
	var region := Rect2(Vector2.ZERO, Vector2(_bolt.get_width(), _bolt.get_height() * drop))
	var shown := Rect2(r.position, Vector2(r.size.x, r.size.y * drop))
	var glow := 1.0 + 0.08 * sin(_t * 9.0)
	draw_texture_rect_region(_bolt, shown, region, Color(glow, glow, glow, alpha))
	if hit > 0.0:
		# Reflejo en el lago y destello blanco violeta de toda la pantalla.
		draw_texture_rect(_reflection, r, false, Color(1, 1, 1, clampf(hit / 0.15, 0.0, 1.0) * alpha))
		var flash := clampf(1.0 - hit / 0.35, 0.0, 1.0)
		if flash > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.93, 0.88, 1.0, 0.85 * flash * alpha))
	# Nombre del estudio sobre el lago: sube y aparece.
	var n := clampf((_t - NAME_AT) / 0.5, 0.0, 1.0)
	if n > 0.0:
		var w := minf(size.x * 0.84, _name.get_width() * r.size.x / _bg.get_width())
		var nsize := Vector2(w, w * _name.get_height() / _name.get_width())
		var y := r.position.y + r.size.y * 0.75 + (1.0 - n) * 30.0
		draw_texture_rect(_name, Rect2(Vector2((size.x - nsize.x) * 0.5, y), nsize), false, Color(1, 1, 1, n * alpha))
