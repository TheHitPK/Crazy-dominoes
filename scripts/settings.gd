extends RefCounted
## Personalización del jugador. Se guarda en user://settings.cfg.

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

static var data := {"skin": 1, "hand_style": 0, "accent": 0, "tile_style": 0, "table_style": 0, "drink": 0}
## Datos para jugar con amigos: nombre y, a distancia, dirección del servidor.
static var profile := {"name": "", "server": ""}


static func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key in data.keys():
		data[key] = int(cfg.get_value("look", key, data[key]))
	for key in profile.keys():
		profile[key] = str(cfg.get_value("net", key, profile[key]))


static func save() -> void:
	var cfg := ConfigFile.new()
	for key in data.keys():
		cfg.set_value("look", key, data[key])
	for key in profile.keys():
		cfg.set_value("net", key, profile[key])
	cfg.save(PATH)


## Aspecto de mis manos y mi bebida, para que los demás jugadores me vean igual.
static func my_look() -> Dictionary:
	return {"skin": data.skin, "hand_style": data.hand_style, "accent": data.accent, "drink": data.drink}


static func skin_color() -> Color:
	return SKINS[clampi(data.skin, 0, SKINS.size() - 1)]


static func accent_color() -> Color:
	return ACCENTS[clampi(data.accent, 0, ACCENTS.size() - 1)]
