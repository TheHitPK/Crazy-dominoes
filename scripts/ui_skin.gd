extends RefCounted
## Texturas y fuentes del menú (assets/ui/, las genera tools/generar_ui.py).
##
## Se cargan con load() y no con preload: main.gd precarga menu.gd y el
## servidor de Docker compila main.gd sin la carpeta assets/. Así el servidor
## no necesita las imágenes (ver Dockerfile).

const DIR := "res://assets/ui/%s.png"
const CREAM := Color("#f5efe6")
const TITLE_OUTLINE := Color("#2b1a0e")

## Hueco del texto en cada textura, en píxeles de pantalla: [izquierda,
## derecha]. Deja fuera el bisel, los tornillos de la placa y el dibujo de la
## derecha (engranaje, globo, ficha) para que las letras nunca los pisen.
const TEXT_ROOM := {
	"btn_green_cpu": [12, 62],
	"btn_blue_online": [12, 62],
	"btn_purple_custom": [10, 44],
	"plaque_meta": [28, 28],
}
## Sin entrada en TEXT_ROOM: solo el bisel.
const TEXT_EDGE := 10

static var _cache := {}
static var _serif: Font
static var _heavy: Font
static var _title_shader: Shader


static func tex(name: String) -> Texture2D:
	if not _cache.has(name):
		_cache[name] = load(DIR % name)
	return _cache[name]


## Caja de textura que se estira entera (cada pieza ya tiene la proporción con
## la que se usa). Con `modulate` se aclara u oscurece para hover y pulsado.
static func box(name: String, modulate := Color.WHITE, push := 0.0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex(name)
	sb.modulate_color = modulate
	var room: Array = TEXT_ROOM.get(name, [TEXT_EDGE, TEXT_EDGE])
	sb.content_margin_left = room[0]
	sb.content_margin_right = room[1]
	# Centrado en la cara del botón, no en la sombra de apoyo de abajo. Pulsado:
	# el texto baja un poco, como si el botón se hundiera.
	sb.content_margin_top = push * 2.0
	sb.content_margin_bottom = 4.0
	return sb


## Serif clásica para los títulos de las tarjetas (Georgia en Windows, Noto
## Serif en Android; en la web cae en la fuente por defecto).
static func serif() -> Font:
	if _serif == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Georgia", "Noto Serif", "DejaVu Serif", "serif"])
		f.font_weight = 700
		_serif = f
	return _serif


## La fuente por defecto, más gruesa y algo más espaciada, para el título.
static func heavy() -> Font:
	if _heavy == null:
		var f := FontVariation.new()
		f.base_font = ThemeDB.fallback_font
		f.variation_embolden = 0.9
		f.spacing_glyph = 3
		_heavy = f
	return _heavy


## Degradado vertical de oro claro a oro tostado para el relleno de las letras.
## Solo tiñe lo claro (el relleno): el contorno y la sombra, oscuros, se quedan.
static func title_material(height: float, lines := 2) -> ShaderMaterial:
	if _title_shader == null:
		_title_shader = Shader.new()
		_title_shader.code = """
shader_type canvas_item;
uniform vec4 top : source_color = vec4(0.965, 0.827, 0.451, 1.0);
uniform vec4 bottom : source_color = vec4(0.784, 0.573, 0.212, 1.0);
uniform float height = 190.0;
uniform float lines = 2.0;
varying float y;
void vertex() { y = VERTEX.y; }
void fragment() {
	vec4 c = COLOR;
	float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	// Cada renglón tiene su propio degradado.
	float t = fract(y / (height / lines));
	vec3 g = mix(top.rgb, bottom.rgb, smoothstep(0.25, 0.8, t));
	c.rgb = mix(c.rgb, g, smoothstep(0.35, 0.6, lum));
	COLOR = c;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _title_shader
	m.set_shader_parameter("height", height)
	m.set_shader_parameter("lines", float(lines))
	return m


# --- Kit común (assets/ui/kit_*, de tools/generar_kit.py; guía en DISEÑO.md)

## Márgenes 9-slice de cada pieza del kit, en píxeles de la textura.
const KIT_PANEL := 72
const KIT_BTN := [56, 54, 56, 60]
const KIT_FIELD := 16


## Pieza 9-slice al doble de resolución montada a escala 0,5: esquinas nítidas
## en pantallas grandes sin verse al doble de grandes. `margins` es [izq, arriba,
## der, abajo] en píxeles de la textura. Se ancla de 0 a 2 sobre su padre: a
## escala 0,5 lo cubre entero y lo sigue al cambiar de tamaño.
static func nine(name: String, margins: Array) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = tex(name)
	n.patch_margin_left = margins[0]
	n.patch_margin_top = margins[1]
	n.patch_margin_right = margins[2]
	n.patch_margin_bottom = margins[3]
	n.scale = Vector2(0.5, 0.5)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.anchor_right = 2.0
	n.anchor_bottom = 2.0
	return n


## Viste un panel con el marco dorado del kit (sustituye su StyleBoxFlat). El
## marco es un hijo interno delante de los demás: queda debajo de todo lo que
## se añade al panel y no sale en get_children() (hay paneles que vacían sus
## hijos para rehacerse, como el de fin de mano).
static func dress(panel: Control) -> void:
	if tex("kit_panel") == null:
		return
	if panel is Panel:
		panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var m := KIT_PANEL
	panel.add_child(nine("kit_panel", [m, m, m, m]), false, Node.INTERNAL_MODE_FRONT)


## Campo hundido para valores y textos (selectores, LineEdit). A tamaño real:
## son degradados suaves y no pierden nada al estirarse.
static func field_box(pad := 16.0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex("kit_field")
	sb.set_texture_margin_all(KIT_FIELD)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	return sb


## El mismo campo mientras se escribe en él: más claro y con tinte dorado.
static func field_focus_box(pad := 16.0) -> StyleBoxTexture:
	var sb := field_box(pad)
	sb.modulate_color = Color(1.9, 1.5, 0.9)
	return sb


## Título de panel: serif con degradado dorado y contorno oscuro.
static func title(lb: Label) -> void:
	lb.add_theme_font_override("font", serif())
	lb.add_theme_color_override("font_outline_color", TITLE_OUTLINE)
	lb.add_theme_constant_override("outline_size", 10)
	lb.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	lb.add_theme_constant_override("shadow_offset_y", 3)
	lb.material = title_material(lb.size.y, 1)
