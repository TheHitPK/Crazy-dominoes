extends RefCounted
## Compras con dinero real: catálogo y entrega de lo comprado.
##
## Los IDs de producto son los que hay que crear igual en Google Play Console
## (y en App Store Connect para iOS). Los precios de aquí son solo de muestra:
## la tienda real enseña los de cada país.
##
## MODO PRUEBA: sin el plugin de Google Play Billing (ver
## servidor/ANUNCIOS_Y_PAGOS.md), la compra se simula con un aviso y no se
## cobra nada. Con el plugin, buy() abrirá el pago de Google y deliver() se
## llamará cuando el servidor confirme la compra.

const Wallet = preload("res://scripts/wallet.gd")

## "coins" y "gems": lo que da. "once": solo se puede comprar una vez.
## "tag": cinta destacada en la tienda. Con dinero se compran gemas; las
## monedas se compran con gemas dentro del juego (Wallet.GEM_EXCHANGE).
const PRODUCTS := [
	{"id": "starter_pack", "name": "Oferta de inicio", "coins": 5000, "gems": 100, "price": "1,99 US$",
			"once": true, "tag": "Solo una vez"},
	{"id": "gems_80", "name": "Puñado de gemas", "coins": 0, "gems": 80, "price": "0,99 US$"},
	{"id": "gems_500", "name": "Bolsa de gemas", "coins": 0, "gems": 500, "price": "4,99 US$", "tag": "+25 %"},
	{"id": "gems_1100", "name": "Cofre de gemas", "coins": 0, "gems": 1100, "price": "9,99 US$", "tag": "Más popular"},
	{"id": "gems_3000", "name": "Tesoro de gemas", "coins": 0, "gems": 3000, "price": "19,99 US$",
			"tag": "Mejor valor"},
	{"id": "no_ads", "name": "Sin anuncios", "coins": 0, "gems": 0, "price": "2,99 US$", "once": true},
	{"id": "vip_month", "name": "VIP 30 días", "coins": 0, "gems": 0, "price": "3,99 US$"},
]


static func product(id: String) -> Dictionary:
	for p: Dictionary in PRODUCTS:
		if p.id == id:
			return p
	return {}


## Ya comprado y no se puede repetir.
static func owned(id: String) -> bool:
	match id:
		"starter_pack":
			return Wallet.has_flag("starter")
		"no_ads":
			return Wallet.has_flag("no_ads")
	return false


static func test_mode() -> bool:
	return not Engine.has_singleton("GodotGooglePlayBilling")


## Da lo comprado. Lo llama la tienda al confirmarse el pago.
static func deliver(id: String) -> void:
	var p := product(id)
	if p.is_empty():
		return
	if int(p.coins) > 0:
		Wallet.add_coins(int(p.coins))
	if int(p.get("gems", 0)) > 0:
		Wallet.add_gems(int(p.gems))
	match id:
		"starter_pack":
			Wallet.set_flag("starter")
		"no_ads":
			Wallet.set_flag("no_ads")
		"vip_month":
			Wallet.add_vip(30)
