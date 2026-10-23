extends RefCounted
## Personalización del jugador. Se guarda en user://settings.cfg.

const Avatar = preload("res://scripts/avatar.gd")

const PATH := "user://settings.cfg"

const SKINS := [Color(0.98, 0.86, 0.74), Color(0.94, 0.76, 0.6), Color(0.85, 0.63, 0.45),
		Color(0.7, 0.48, 0.33), Color(0.52, 0.35, 0.24), Color(0.34, 0.22, 0.16)]
## Colores para las uñas o los guantes.
const ACCENTS := [Color(0.85, 0.1, 0.22), Color(0.95, 0.4, 0.65), Color(0.55, 0.2, 0.75),
		Color(0.15, 0.45, 0.9), Color(0.1, 0.7, 0.6), Color(0.98, 0.8, 0.2),
		Color(0.96, 0.96, 0.94), Color(0.12, 0.12, 0.14)]
const HAND_NAMES := ["Natural", "Uñas largas pintadas", "Guantes"]
const TILE_NAMES := ["Marfil clásico", "Madera", "Cerámica", "Ébano", "Puntos de colores", "Piedra rústica"]
const TABLE_NAMES := ["Roble", "Nogal oscuro", "Pino claro", "Caoba", "Tapete verde", "Tablones rústicos"]
const DRINK_NAMES := ["Refresco", "Cerveza", "Limonada", "Café", "Agua"]

const SHOW_HANDS_NAMES := ["Ocultas", "Visibles"]
## Mi foto de perfil, ya recortada (ver Avatar.square). "avatar_photo" = 1: se
## muestra la foto; 0: el icono "avatar" (índice en Avatar.ICON_NAMES).
const PHOTO_PATH := "user://avatar.png"

## "show_hands": 1 = se dibujan las manos que sujetan las fichas (las mías y las
## de los demás); 0 = las fichas se paran en un atril de madera. Es una preferencia de mi pantalla:
## no cambia cómo me ven los otros jugadores.
static var data := {"skin": 1, "hand_style": 0, "accent": 0, "tile_style": 0, "table_style": 0, "drink": 0,
		"show_hands": 1, "avatar": 0, "avatar_photo": 0}
## Datos para jugar con amigos: nombre y, a distancia, dirección del servidor.
## "player_id" es una clave privada de esta instalación (ver player_token) y
## "last_code", la última sala en línea, para volver a ella con un toque.
static var profile := {"name": "", "server": "", "player_id": "", "last_code": ""}
## Sonido: 1 = activado, 0 = silenciado. "pass_voice" son los audios grabados
## que suenan al pasar; "sfx", el resto de efectos; "music", la música de fondo.
static var audio := {"pass_voice": 1, "sfx": 1, "music": 1}


static func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key in data.keys():
		data[key] = int(cfg.get_value("look", key, data[key]))
	for key in profile.keys():
		profile[key] = str(cfg.get_value("net", key, profile[key]))
	for key in audio.keys():
		audio[key] = int(cfg.get_value("audio", key, audio[key]))


static func save() -> void:
	var cfg := ConfigFile.new()
	for key in data.keys():
		cfg.set_value("look", key, data[key])
	for key in profile.keys():
		cfg.set_value("net", key, profile[key])
	for key in audio.keys():
		cfg.set_value("audio", key, audio[key])
	cfg.save(PATH)


## Clave privada de esta instalación, creada al azar la primera vez. El servidor
## la guarda junto al asiento: si me salgo de una partida en marcha, solo quien
## presente esta misma clave puede recuperar ese asiento. Nunca se muestra ni se
## manda a otros jugadores.
static func player_token() -> String:
	if profile.player_id == "":
		profile.player_id = Crypto.new().generate_random_bytes(16).hex_encode()
		save()
	return profile.player_id


## Aspecto de mis manos, mi bebida y mi avatar, para que los demás jugadores me
## vean igual. La foto va pequeña y en JPG para que la sala no pese.
static func my_look() -> Dictionary:
	var look := {"skin": data.skin, "hand_style": data.hand_style, "accent": data.accent, "drink": data.drink,
			"avatar": data.avatar}
	var tex := photo_texture()
	if tex != null:
		var img := tex.get_image()
		img.resize(Avatar.NET_PHOTO_SIZE, Avatar.NET_PHOTO_SIZE, Image.INTERPOLATE_LANCZOS)
		var jpg := img.save_jpg_to_buffer(0.8)
		if jpg.size() <= Avatar.MAX_NET_PHOTO:
			look["photo"] = jpg
	return look


static var _photo: Texture2D
static var _photo_loaded := false


## Mi foto, o null si no tengo o elegí un icono.
static func photo_texture() -> Texture2D:
	if data.avatar_photo == 0:
		return null
	if not _photo_loaded:
		_photo_loaded = true
		var img := Image.load_from_file(PHOTO_PATH) if FileAccess.file_exists(PHOTO_PATH) else null
		_photo = ImageTexture.create_from_image(img) if img != null else null
	return _photo


## Guarda una foto nueva (bytes de un PNG, JPG o WebP) y la deja elegida.
## Devuelve false si no se pudo leer como imagen.
static func set_photo(bytes: PackedByteArray) -> bool:
	var img := Avatar.image_from_bytes(bytes)
	if img == null:
		return false
	img = Avatar.square(img, Avatar.PHOTO_SIZE)
	img.save_png(PHOTO_PATH)
	_photo = ImageTexture.create_from_image(img)
	_photo_loaded = true
	data.avatar_photo = 1
	save()
	return true


## Pone mi avatar (foto o icono) en un círculo.
static func apply_avatar(av: Avatar) -> void:
	av.initial = Avatar.first_letter(profile.name if profile.name != "" else "Tú")
	av.icon = data.avatar
	av.photo = photo_texture()


static func skin_color() -> Color:
	return SKINS[clampi(data.skin, 0, SKINS.size() - 1)]


static func accent_color() -> Color:
	return ACCENTS[clampi(data.accent, 0, ACCENTS.size() - 1)]
