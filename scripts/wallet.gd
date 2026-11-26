extends RefCounted
## Monedas, gemas, experiencia y nivel, regalo diario, ayuda gratis y compras
## de la tienda. Se guarda en user://wallet.cfg.
##
## Dos monedas con papeles distintos: las monedas se ganan jugando y sirven
## para apostar y para las skins normales; las gemas son escasas (subir de
## nivel, campeón de torneo, desafío del día) o se compran, y sirven para las
## skins exclusivas y para cambiarlas por monedas. Nunca hacen falta para jugar.
##
## Por ahora todo vive en este teléfono y solo se usa contra la CPU: sin
## cuentas ni base de datos, el servidor no puede guardar saldos. La firma
## (_sign) solo evita que se edite el archivo a mano; no protege contra quien
## modifique el juego. Las monedas no se pueden cambiar por dinero.

const Settings = preload("res://scripts/settings.gd")

const PATH := "user://wallet.cfg"
const START_COINS := 500
const START_GEMS := 20
## Apuestas que se pueden hacer contra la CPU y nivel con que se desbloquea cada una.
const BETS := [50, 100, 250, 500, 1000, 2500]
const BET_LEVEL := [1, 1, 2, 3, 5, 7]
## Por dificultad: cuánto se multiplica la apuesta al ganar, y nivel con que se desbloquea.
const PAYOUT := [1.8, 2.2, 2.8]
## Multiplicador extra por formato (State.PAIRS, SOLO, DUEL): en todos contra
## todos solo gana uno de cuatro, así que el premio sube.
const FORMAT_PAYOUT := [1.0, 1.75, 1.0]
const DIFF_LEVEL := [1, 2, 3]
## Experiencia por partida, por dificultad: [ganada, perdida]. Se multiplica por meta / 100.
const XP := [[30, 10], [50, 18], [80, 28]]
## Regalo cada DAILY_EVERY segundos, según las veces seguidas que se recogió
## (el 7.º se repite). Si pasan más de DAILY_KEEP sin recogerlo, la racha vuelve a empezar.
const DAILY := [100, 150, 200, 250, 300, 400, 600]
const DAILY_EVERY := 86400
const DAILY_KEEP := 2 * 86400
## Ayuda cuando no alcanza ni para la apuesta más baja, cada RESCUE_EVERY segundos.
const RESCUE := 200
const RESCUE_EVERY := 3600
## Monedas por cada nivel nuevo: LEVEL_BONUS * nivel.
const LEVEL_BONUS := 150
## Gemas por cada nivel nuevo.
const LEVEL_GEMS := 5
## Precio de cada skin de la tienda; 0 = gratis. Mismo orden que en Settings.
## Las de GEM_ITEMS cuestan gemas; el resto, monedas.
const PRICES := {
	"tile_style": [0, 0, 0, 800, 1200, 2000, 3000, 4000, 6000, 150, 200, 300],
	"table_style": [0, 0, 0, 800, 1500, 2500, 2000, 3000, 4000, 150, 200, 300],
}
const GEM_ITEMS := {"tile_style": [9, 10, 11], "table_style": [9, 10, 11]}
## Monedas que se compran con gemas en la tienda: [gemas, monedas].
const GEM_EXCHANGE := [[80, 1000], [400, 6000], [800, 13000], [2000, 35000]]
## Cambia si alguien edita el archivo; no es un secreto real (va dentro del juego).
const _SALT := "crazy-dominoes/wallet/1"

## "owned": compras hechas, como "clave:índice". "daily_at" y "rescue_at": hora
## Unix del último regalo y de la última ayuda. "daily_day" es de la primera
## versión (regalo por día del calendario) y solo se usa para pasar de ella.
## "flags": compras con dinero que no son monedas ("no_ads", "starter").
## "vip_until": hora Unix en que acaba el VIP. "ad_coins_day"/"ad_coins_n":
## monedas gratis por anuncio vistas hoy (ver ad_coins_left).
static var data := {"coins": START_COINS, "xp": 0, "daily_day": "", "streak": 0, "rescue_at": 0, "owned": [],
		"daily_at": 0, "flags": [], "vip_until": 0, "ad_coins_day": "", "ad_coins_n": 0, "gems": START_GEMS}

## Monedas por ver un anuncio en la tienda, y cuántas veces al día.
const AD_COINS := 100
const AD_COINS_PER_DAY := 5
## Precio de una pista en la partida (o un anuncio si no alcanza).
const HINT_COST := 20


static func load_wallet() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	var loaded := {}
	for key in data.keys():
		loaded[key] = cfg.get_value("wallet", key, data[key])
	var sig := str(cfg.get_value("wallet", "sig", ""))
	if sig == _sign_v1(loaded) and not cfg.has_section_key("wallet", "daily_at"):
		# Monedero de la primera versión: si ya recogió el regalo hoy, cuenta desde ahora.
		loaded.daily_at = _now() if str(loaded.daily_day) == _day() else 0
	elif sig == _sign_v2(loaded) and not cfg.has_section_key("wallet", "flags"):
		pass  # Segunda versión, sin compras con dinero: se pasa tal cual.
	elif sig == _sign_v3(loaded) and not cfg.has_section_key("wallet", "gems"):
		pass  # Tercera versión, sin gemas: empieza con las de regalo.
	elif sig != _sign(loaded):
		# Archivo editado a mano: se empieza de cero.
		return
	data = loaded


static func save() -> void:
	var cfg := ConfigFile.new()
	for key in data.keys():
		cfg.set_value("wallet", key, data[key])
	cfg.set_value("wallet", "sig", _sign(data))
	cfg.save(PATH)


static func _sign(d: Dictionary) -> String:
	return ("%s|%d" % [_sign_v3(d), int(d.gems)]).sha256_text()


## Firma de la tercera versión, sin gemas.
static func _sign_v3(d: Dictionary) -> String:
	return ("%s|%s|%d|%s|%d" % [_sign_v2(d), ",".join(PackedStringArray(d.flags)), int(d.vip_until),
			str(d.ad_coins_day), int(d.ad_coins_n)]).sha256_text()


## Firma de la segunda versión, sin compras con dinero.
static func _sign_v2(d: Dictionary) -> String:
	return ("%s|%d" % [_sign_v1(d), int(d.daily_at)]).sha256_text()


## Firma de la primera versión, sin "daily_at".
static func _sign_v1(d: Dictionary) -> String:
	var text := "%s|%d|%d|%s|%d|%d|%s" % [_SALT, int(d.coins), int(d.xp), str(d.daily_day), int(d.streak),
			int(d.rescue_at), ",".join(PackedStringArray(d.owned))]
	return text.sha256_text()


static func _now() -> int:
	return int(Time.get_unix_time_from_system())


static func coins() -> int:
	return int(data.coins)


static func add_coins(n: int) -> void:
	data.coins = maxi(coins() + n, 0)
	save()


static func gems() -> int:
	return int(data.gems)


static func add_gems(n: int) -> void:
	data.gems = maxi(gems() + n, 0)
	save()


## Cambia gemas por monedas (una fila de GEM_EXCHANGE). false si no alcanzan.
static func exchange(index: int) -> bool:
	var offer: Array = GEM_EXCHANGE[index]
	if gems() < int(offer[0]):
		return false
	data.gems = gems() - int(offer[0])
	data.coins = coins() + int(offer[1])
	save()
	return true


# ------------------------------------------------------------------ nivel

## Experiencia que hace falta para pasar del nivel `level` al siguiente.
static func xp_to_next(level: int) -> int:
	return 100 + 50 * (level - 1)


static func level() -> int:
	return progress()[0]


## [nivel, experiencia dentro del nivel, experiencia para el siguiente].
static func progress() -> Array:
	var lv := 1
	var left := int(data.xp)
	while left >= xp_to_next(lv):
		left -= xp_to_next(lv)
		lv += 1
	return [lv, left, xp_to_next(lv)]


# ------------------------------------------------------------------ mesas

## Lo que se cobra al ganar con esa apuesta y esa dificultad (en múltiplos de 5).
static func prize(difficulty: int, bet: int, format: int = 0) -> int:
	var k: float = PAYOUT[clampi(difficulty, 0, PAYOUT.size() - 1)] * FORMAT_PAYOUT[clampi(format, 0, FORMAT_PAYOUT.size() - 1)]
	return roundi(bet * k / 5.0) * 5


static func bet_level(bet: int) -> int:
	var i := BETS.find(bet)
	return BET_LEVEL[i] if i >= 0 else 999


## Por qué no se puede jugar con esa dificultad y esa apuesta, o "" si se puede.
static func cant_play(difficulty: int, bet: int) -> String:
	var need: int = DIFF_LEVEL[clampi(difficulty, 0, DIFF_LEVEL.size() - 1)]
	if level() < need:
		return "Esa dificultad se desbloquea en el nivel %d." % need
	if level() < bet_level(bet):
		return "Esa apuesta se desbloquea en el nivel %d." % bet_level(bet)
	if coins() < bet:
		return "Te faltan %d monedas para apostar %d." % [bet - coins(), bet]
	return ""


## Cobra la apuesta. Devuelve false si no se puede jugar así.
static func pay_entry(difficulty: int, bet: int) -> bool:
	if cant_play(difficulty, bet) != "":
		return false
	add_coins(-bet)
	return true


## Fin de una partida con apuesta: premio si se ganó y experiencia siempre.
## Devuelve {coins, xp, level_up, level, bonus, gems}.
static func finish_match(won: bool, difficulty: int, target: int, bet: int, format: int = 0) -> Dictionary:
	var k := target / 100.0
	var before := level()
	var won_coins: int = prize(difficulty, bet, format) if won else 0
	var xp := roundi(XP[clampi(difficulty, 0, XP.size() - 1)][0 if won else 1] * k)
	data.xp = int(data.xp) + xp
	var after := level()
	var bonus := 0
	for lv in range(before + 1, after + 1):
		bonus += LEVEL_BONUS * lv
	var level_gems := LEVEL_GEMS * (after - before)
	data.coins = coins() + won_coins + bonus
	data.gems = gems() + level_gems
	save()
	return {"coins": won_coins, "xp": xp, "level_up": after > before, "level": after, "bonus": bonus,
			"gems": level_gems}


# ---------------------------------------------------------- regalos

## Fecha local (AAAA-MM-DD) desplazada `days` días desde hoy.
static func _day(days: int = 0) -> String:
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	return Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) + bias * 60 + days * 86400)


static func daily_available() -> bool:
	return daily_wait() == 0


## Segundos que faltan para el próximo regalo.
static func daily_wait() -> int:
	return maxi(int(data.daily_at) + DAILY_EVERY - _now(), 0)


## Vez de la racha que tocaría recoger ahora (1..7).
static func daily_streak() -> int:
	var at := int(data.daily_at)
	var next: int = int(data.streak) + 1 if at > 0 and _now() - at <= DAILY_KEEP else 1
	return mini(next, DAILY.size())


## Con VIP, el regalo diario es doble.
static func daily_amount() -> int:
	return DAILY[daily_streak() - 1] * (2 if is_vip() else 1)


## Recoge el regalo de hoy. Devuelve las monedas recibidas (0 si ya se recogió).
static func claim_daily() -> int:
	if not daily_available():
		return 0
	var amount := daily_amount()
	data.streak = daily_streak()
	data.daily_at = _now()
	data.daily_day = _day()
	data.coins = coins() + amount
	save()
	return amount


## Sin monedas ni para la apuesta más baja, y pasó el tiempo de espera.
static func rescue_available() -> bool:
	return coins() < BETS[0] and rescue_wait() == 0


## Segundos que faltan para poder pedir otra ayuda.
static func rescue_wait() -> int:
	return maxi(int(data.rescue_at) + RESCUE_EVERY - int(Time.get_unix_time_from_system()), 0)


static func claim_rescue() -> int:
	if not rescue_available():
		return 0
	data.rescue_at = int(Time.get_unix_time_from_system())
	data.coins = coins() + RESCUE
	save()
	return RESCUE


# ---------------------------------------------------------------- tienda

static func price(key: String, index: int) -> int:
	var list: Array = PRICES.get(key, [])
	return list[index] if index >= 0 and index < list.size() else 0


## La skin se paga con gemas (si no, con monedas).
static func costs_gems(key: String, index: int) -> bool:
	return GEM_ITEMS.get(key, []).has(index)


## Alcanza para comprarla (con la moneda que toque).
static func can_afford(key: String, index: int) -> bool:
	return (gems() if costs_gems(key, index) else coins()) >= price(key, index)


## "3.000 monedas" o "150 gemas".
static func price_text(key: String, index: int) -> String:
	var n := price(key, index)
	var s := str(n)
	if n >= 1000:
		s = "%d.%03d" % [n / 1000, n % 1000]
	return "%s %s" % [s, "gemas" if costs_gems(key, index) else "monedas"]


static func owns(key: String, index: int) -> bool:
	return price(key, index) == 0 or data.owned.has("%s:%d" % [key, index])


## Si el aspecto guardado usa algo que no se compró (por ejemplo, se cerró el
## juego mientras se probaba en Personalizar), vuelve a la opción gratis.
static func sanitize_look() -> void:
	var changed := false
	for key: String in PRICES.keys():
		if not owns(key, int(Settings.data[key])):
			Settings.data[key] = 0
			changed = true
	if changed:
		Settings.save()


## Compra una opción de la tienda. Devuelve false si no alcanza.
static func buy(key: String, index: int) -> bool:
	if owns(key, index):
		return true
	if not can_afford(key, index):
		return false
	if costs_gems(key, index):
		data.gems = gems() - price(key, index)
	else:
		data.coins = coins() - price(key, index)
	data.owned.append("%s:%d" % [key, index])
	save()
	return true


# ------------------------------------------------------- compras con dinero

static func has_flag(flag: String) -> bool:
	return data.flags.has(flag)


static func set_flag(flag: String) -> void:
	if not has_flag(flag):
		data.flags.append(flag)
		save()


static func is_vip() -> bool:
	return int(data.vip_until) > _now()


## Suma `days` días de VIP (desde ahora o desde que acabe el actual).
static func add_vip(days: int) -> void:
	data.vip_until = maxi(int(data.vip_until), _now()) + days * 86400
	save()


## Sin anuncios a pantalla completa: comprado o con VIP. Los anuncios con
## premio siguen disponibles, porque los pide el jugador.
static func ads_removed() -> bool:
	return has_flag("no_ads") or is_vip()


## Monedas gratis por anuncio que quedan hoy.
static func ad_coins_left() -> int:
	if str(data.ad_coins_day) != _day():
		return AD_COINS_PER_DAY
	return maxi(AD_COINS_PER_DAY - int(data.ad_coins_n), 0)


static func claim_ad_coins() -> int:
	if ad_coins_left() <= 0:
		return 0
	if str(data.ad_coins_day) != _day():
		data.ad_coins_day = _day()
		data.ad_coins_n = 0
	data.ad_coins_n = int(data.ad_coins_n) + 1
	data.coins = coins() + AD_COINS
	save()
	return AD_COINS
