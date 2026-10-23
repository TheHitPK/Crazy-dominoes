extends Control
## Círculo con la foto o el icono de un jugador, rodeado por un aro del color
## de su equipo. Los iconos se dibujan por código, como las manos y las fichas.

const ICON_NAMES := ["Inicial", "Dominó", "Corona", "Estrella", "Corazón", "Sol", "Luna", "Música",
		"Trébol", "Rayo", "Sonrisa"]
enum { INITIAL, DOMINO, CROWN, STAR, HEART, SUN, MOON, MUSIC, CLOVER, BOLT, SMILE }
## Fondo de cada icono.
const BACKS := [Color(0.3, 0.22, 0.16), Color(0.12, 0.36, 0.3), Color(0.42, 0.14, 0.2), Color(0.16, 0.22, 0.45),
		Color(0.55, 0.1, 0.16), Color(0.85, 0.45, 0.12), Color(0.1, 0.12, 0.3), Color(0.35, 0.16, 0.45),
		Color(0.12, 0.42, 0.2), Color(0.18, 0.18, 0.2), Color(0.12, 0.45, 0.6)]
## Lado de la foto guardada y de la que se manda a los demás jugadores.
const PHOTO_SIZE := 128
const NET_PHOTO_SIZE := 64
## Una foto que pese más que esto no se acepta de otros jugadores.
const MAX_NET_PHOTO := 16000

var icon := INITIAL:
	set(v):
		icon = clampi(v, 0, ICON_NAMES.size() - 1)
		queue_redraw()
## Letra que se muestra con el icono "Inicial".
var initial := "?":
	set(v):
		initial = v
		queue_redraw()
var photo: Texture2D:
	set(v):
		photo = v
		queue_redraw()
var ring := Color(0.85, 0.7, 0.3):
	set(v):
		ring = v
		queue_redraw()
var ring_width := 4.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Aplica el avatar que un jugador eligió (ver Settings.my_look). Sin datos,
## por ejemplo con una versión vieja del juego, se ve la inicial de su nombre.
func show_look(look: Dictionary, player_name: String) -> void:
	initial = first_letter(player_name)
	icon = int(look.get("avatar", INITIAL))
	photo = null
	var bytes = look.get("photo", null)
	if bytes is PackedByteArray and bytes.size() <= MAX_NET_PHOTO:
		var img := image_from_bytes(bytes)
		if img != null and img.get_width() <= PHOTO_SIZE and img.get_height() <= PHOTO_SIZE:
			photo = ImageTexture.create_from_image(img)


static func first_letter(player_name: String) -> String:
	var n := player_name.strip_edges()
	return n.left(1).to_upper() if n != "" else "?"


## Lee una imagen PNG, JPG o WebP según sus primeros bytes (en Android el
## selector de archivos da direcciones sin extensión). null si no es ninguna.
static func image_from_bytes(bytes: PackedByteArray) -> Image:
	if bytes.size() < 12:
		return null
	var img := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	if bytes[0] == 0x89 and bytes[1] == 0x50:
		err = img.load_png_from_buffer(bytes)
	elif bytes[0] == 0xFF and bytes[1] == 0xD8:
		err = img.load_jpg_from_buffer(bytes)
	elif bytes.slice(0, 4).get_string_from_ascii() == "RIFF" and bytes.slice(8, 12).get_string_from_ascii() == "WEBP":
		err = img.load_webp_from_buffer(bytes)
	return img if err == OK and not img.is_empty() else null


## Recorta el centro de la foto en cuadrado y la reduce a `side` píxeles.
static func square(img: Image, side: int) -> Image:
	var out := img.duplicate() as Image
	out.decompress()
	out.convert(Image.FORMAT_RGB8)
	var m := mini(out.get_width(), out.get_height())
	out = out.get_region(Rect2i((out.get_width() - m) / 2, (out.get_height() - m) / 2, m, m))
	out.resize(side, side, Image.INTERPOLATE_LANCZOS)
	return out


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5
	var c := size * 0.5
	draw_circle(c + Vector2(0, r * 0.06), r, Color(0, 0, 0, 0.35), true, -1.0, true)
	draw_circle(c, r, ring, true, -1.0, true)
	var ir := r - ring_width
	if photo != null:
		# La foto recortada en círculo.
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for i in 40:
			var d := Vector2.from_angle(TAU * i / 40.0)
			pts.append(c + d * ir)
			uvs.append(Vector2(0.5, 0.5) + d * 0.5)
		draw_colored_polygon(pts, Color.WHITE, uvs, photo)
		return
	var back: Color = BACKS[icon]
	draw_circle(c, ir, back, true, -1.0, true)
	# Brillo arriba, como un botón de vidrio.
	draw_circle(c - Vector2(0, ir * 0.35), ir * 0.7, Color(1, 1, 1, 0.07), true, -1.0, true)
	if icon == INITIAL:
		var font := ThemeDB.fallback_font
		var fs := int(ir * 1.15)
		var base := c.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
		draw_string(font, Vector2(c.x - ir, base), initial, HORIZONTAL_ALIGNMENT_CENTER, ir * 2.0, fs,
				Color(1.0, 0.9, 0.7))
		return
	# Cada icono se dibuja en un cuadro de -1 a 1.
	draw_set_transform(c, 0.0, Vector2.ONE * ir * 0.62)
	_draw_icon(back)
	draw_set_transform(Vector2.ZERO)


func _draw_icon(back: Color) -> void:
	var cream := Color(0.98, 0.94, 0.84)
	var gold := Color(1.0, 0.8, 0.25)
	var dark := Color(0.1, 0.08, 0.06)
	match icon:
		DOMINO:
			var body := Rect2(-0.55, -1.0, 1.1, 2.0)
			draw_rect(body, cream)
			draw_line(Vector2(-0.4, 0), Vector2(0.4, 0), dark, 0.08)
			for p: Vector2 in [Vector2(0, -0.5), Vector2(-0.27, 0.23), Vector2(0, 0.5), Vector2(0.27, 0.77)]:
				draw_circle(p, 0.12, dark)
		CROWN:
			draw_colored_polygon(PackedVector2Array([Vector2(-0.95, 0.55), Vector2(-0.95, -0.45), Vector2(-0.45, 0.05),
					Vector2(0, -0.75), Vector2(0.45, 0.05), Vector2(0.95, -0.45), Vector2(0.95, 0.55)]), gold)
			draw_rect(Rect2(-0.95, 0.55, 1.9, 0.3), gold.darkened(0.2))
			for p: Vector2 in [Vector2(-0.95, -0.5), Vector2(0, -0.82), Vector2(0.95, -0.5)]:
				draw_circle(p, 0.13, gold)
			draw_circle(Vector2(0, 0.25), 0.14, Color(0.85, 0.15, 0.25))
		STAR:
			var pts := PackedVector2Array()
			for i in 10:
				pts.append(Vector2.from_angle(-PI * 0.5 + PI * i / 5.0) * (1.0 if i % 2 == 0 else 0.42) + Vector2(0, 0.08))
			draw_colored_polygon(pts, gold)
		HEART:
			var red := Color(0.95, 0.3, 0.38)
			draw_circle(Vector2(-0.44, -0.3), 0.5, red)
			draw_circle(Vector2(0.44, -0.3), 0.5, red)
			draw_colored_polygon(PackedVector2Array([Vector2(-0.92, -0.15), Vector2(0.92, -0.15), Vector2(0, 0.95)]), red)
		SUN:
			for i in 8:
				var d := Vector2.from_angle(TAU * i / 8.0)
				draw_line(d * 0.66, d * 1.0, Color(1.0, 0.92, 0.5), 0.16)
			draw_circle(Vector2.ZERO, 0.52, Color(1.0, 0.92, 0.5))
		MOON:
			draw_circle(Vector2.ZERO, 0.85, cream)
			draw_circle(Vector2(0.42, -0.28), 0.72, back)
			draw_circle(Vector2(0.6, 0.5), 0.08, cream)
			draw_circle(Vector2(0.15, 0.75), 0.05, cream)
		MUSIC:
			draw_circle(Vector2(-0.45, 0.6), 0.27, cream)
			draw_circle(Vector2(0.5, 0.42), 0.27, cream)
			draw_line(Vector2(-0.22, 0.6), Vector2(-0.22, -0.6), cream, 0.12)
			draw_line(Vector2(0.73, 0.42), Vector2(0.73, -0.8), cream, 0.12)
			draw_colored_polygon(PackedVector2Array([Vector2(-0.28, -0.6), Vector2(0.79, -0.8),
					Vector2(0.79, -0.5), Vector2(-0.28, -0.3)]), cream)
		CLOVER:
			var green := Color(0.6, 0.9, 0.55)
			for p: Vector2 in [Vector2(0, -0.45), Vector2(-0.45, 0.02), Vector2(0.45, 0.02)]:
				draw_circle(p, 0.42, green)
			draw_line(Vector2(0, 0.1), Vector2(0.25, 0.95), green, 0.16)
		BOLT:
			draw_colored_polygon(PackedVector2Array([Vector2(0.2, -1.0), Vector2(-0.6, 0.15), Vector2(-0.05, 0.15),
					Vector2(-0.3, 1.0), Vector2(0.6, -0.22), Vector2(0.05, -0.22)]), Color(1.0, 0.85, 0.2))
		SMILE:
			draw_circle(Vector2.ZERO, 0.95, Color(1.0, 0.85, 0.3))
			draw_circle(Vector2(-0.33, -0.25), 0.12, dark)
			draw_circle(Vector2(0.33, -0.25), 0.12, dark)
			draw_arc(Vector2(0, 0.05), 0.5, PI * 0.15, PI * 0.85, 16, dark, 0.12)
