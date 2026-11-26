extends Node
## Almacén de cuentas del servidor (solo lo usa el servidor dedicado).
##
## Con las variables de entorno SUPABASE_URL y SUPABASE_SERVICE_KEY habla con
## la base de datos de Supabase por su API REST (tabla `players`, ver
## servidor/supabase.sql). Sin ellas guarda en user://cloud_players.json, que
## sirve para probar en este PC (en Render ese archivo se borra al reiniciar).
##
## La clave de servicio da acceso total a la base de datos: vive solo en el
## servidor (variable de entorno de Render) y nunca va en el juego.
##
## Cada jugador se identifica por su token privado (Settings.player_token), que
## se guarda resumido (sha256): con la base de datos no se puede suplantar a nadie.

const Ranked = preload("res://scripts/ranked.gd")

const FILE := "user://cloud_players.json"
const SALT := "crazy-dominoes/cuenta/1|"
const TOP_LIMIT := 50
## Columnas de la tabla que guarda el servidor.
const FIELDS := ["name", "season", "pr", "best", "games", "wins", "streak", "reward"]

var _url := ""
var _key := ""
## Modo archivo: todas las fichas por token_hash.
var _local := {}


func _ready() -> void:
	_url = OS.get_environment("SUPABASE_URL").strip_edges().trim_suffix("/")
	_key = OS.get_environment("SUPABASE_SERVICE_KEY").strip_edges()
	if remote():
		print("[nube] Supabase: ", _url)
	else:
		print("[nube] sin SUPABASE_URL: cuentas en ", ProjectSettings.globalize_path(FILE))
		var text := FileAccess.get_file_as_string(FILE)
		var data: Variant = JSON.parse_string(text) if text != "" else null
		if data is Dictionary:
			_local = data


func remote() -> bool:
	return _url != "" and _key != ""


static func token_hash(token: String) -> String:
	return (SALT + token).sha256_text()


## Ficha del jugador con ese token (la crea si no existe). Lleva "id" además
## de las columnas de FIELDS. Vacía si falla la base de datos.
func load_player(token: String, player_name: String) -> Dictionary:
	var h := token_hash(token)
	var rec := {}
	if remote():
		var rows: Variant = await _rest("GET", "players?token_hash=eq.%s&select=*" % h)
		if rows is Array and not rows.is_empty():
			rec = rows[0]
		elif rows is Array:
			var fresh := Ranked.new_record(player_name)
			fresh["token_hash"] = h
			var made: Variant = await _rest("POST", "players", fresh, ["Prefer: return=representation"])
			if made is Array and not made.is_empty():
				rec = made[0]
	else:
		if not _local.has(h):
			var fresh := Ranked.new_record(player_name)
			fresh["id"] = h.left(16)
			_local[h] = fresh
			_save_file()
		rec = _local[h].duplicate()
	if rec.is_empty():
		return {}
	# Los números llegan como float desde JSON.
	for key in ["pr", "best", "games", "wins", "streak", "reward"]:
		rec[key] = int(rec.get(key, 0))
	rec["token_hash"] = h
	var changed := Ranked.roll_season(rec)
	if str(rec.name) != player_name and player_name != "":
		rec.name = player_name
		changed = true
	if changed:
		await save_player(rec)
	return rec


func save_player(rec: Dictionary) -> void:
	var body := {}
	for key: String in FIELDS:
		body[key] = rec[key]
	if remote():
		body["updated_at"] = Time.get_datetime_string_from_system(true) + "Z"
		await _rest("PATCH", "players?id=eq.%s" % str(rec.id), body)
	else:
		var h: String = rec.token_hash
		var stored: Dictionary = _local.get(h, {})
		stored.merge(body, true)
		stored["id"] = rec.id
		_local[h] = stored
		_save_file()


## Los mejores de la temporada: [{id, name, pr}], de más a menos PR.
func top() -> Array:
	var season := Ranked.season_id()
	if remote():
		var rows: Variant = await _rest("GET",
				"players?season=eq.%s&games=gt.0&select=id,name,pr&order=pr.desc&limit=%d" % [season, TOP_LIMIT])
		return rows if rows is Array else []
	var out: Array = []
	for rec: Dictionary in _local.values():
		if str(rec.season) == season and int(rec.games) > 0:
			out.append({"id": rec.id, "name": rec.name, "pr": int(rec.pr)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pr > b.pr)
	return out.slice(0, TOP_LIMIT)


func _save_file() -> void:
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_local))


## Llamada a la API REST de Supabase. Devuelve el JSON de la respuesta, o null
## si falla (y lo apunta en el registro del servidor).
func _rest(method: String, path: String, body: Variant = null, extra: Array = []) -> Variant:
	var http := HTTPRequest.new()
	http.timeout = 10.0
	add_child(http)
	var headers := PackedStringArray(["apikey: " + _key, "Authorization: Bearer " + _key,
			"Content-Type: application/json"])
	headers.append_array(PackedStringArray(extra))
	var methods := {"GET": HTTPClient.METHOD_GET, "POST": HTTPClient.METHOD_POST,
			"PATCH": HTTPClient.METHOD_PATCH}
	var err := http.request("%s/rest/v1/%s" % [_url, path], headers, methods[method],
			"" if body == null else JSON.stringify(body))
	if err != OK:
		http.queue_free()
		print("[nube] no se pudo pedir %s %s (%d)" % [method, path.get_slice("?", 0), err])
		return null
	var res: Array = await http.request_completed
	http.queue_free()
	var code: int = res[1]
	var text: String = (res[3] as PackedByteArray).get_string_from_utf8()
	if res[0] != HTTPRequest.RESULT_SUCCESS or code >= 300:
		print("[nube] %s %s -> %d %s" % [method, path.get_slice("?", 0), code, text.left(200)])
		return null
	return JSON.parse_string(text) if text != "" else []
