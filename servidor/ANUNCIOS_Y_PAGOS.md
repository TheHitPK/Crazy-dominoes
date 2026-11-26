# Anuncios y pagos: de modo prueba a real

Ahora el juego funciona en **modo prueba**:
- Los anuncios son una pantalla simulada con cuenta atrás ([scripts/ads.gd](../scripts/ads.gd)).
- Las compras se confirman sin cobrar nada ([scripts/store.gd](../scripts/store.gd)).

Todo el flujo funciona igual que funcionará con los reales: doblar premio,
monedas gratis, pista, otro intento del desafío, paquetes, sin anuncios y VIP.

## Lo que ya está hecho

| Dónde | Tipo | Regla |
|---|---|---|
| Fin de partida con apuesta ganada | Con premio | Botón "x2": dobla las monedas ganadas |
| Tienda, "Monedas gratis" | Con premio | +100, hasta 5 al día |
| Pista en la partida | Con premio | Solo si no tienes las 20 monedas que cuesta |
| Desafío del día | Con premio | Intentos después del primero |
| Entre partidas | Pantalla completa | 1 cada 3 partidas y 3 min como mínimo; nunca en las 3 primeras partidas, ni a mitad de mano, ni con "Sin anuncios" o VIP |

Productos (IDs que hay que crear **iguales** en Google Play Console):

| ID | Qué da | Tipo en Play |
|---|---|---|
| `starter_pack` | 5.000 monedas y 100 gemas, una sola vez | Producto único (no consumible) |
| `gems_80`, `gems_500`, `gems_1100`, `gems_3000` | Gemas | Consumible |
| `no_ads` | Quita los anuncios entre partidas | Producto único |
| `vip_month` | 30 días sin anuncios y regalo diario doble | Suscripción mensual |

Con dinero solo se compran gemas (y los tres productos de arriba). Las monedas
se compran con gemas dentro del juego (`Wallet.GEM_EXCHANGE`), igual que las
skins exclusivas (`Wallet.GEM_ITEMS`). Así hay menos productos que crear en
Play y los precios del juego se equilibran sin tocar la consola.

## Pasos para pasarlo a real

### 1. Cuentas (tú)
- **Google Play Console**: 25 US$, pago único. Crea la app con el nombre de
  paquete definitivo. Ahora mismo es `com.example.$genname` en
  `export_presets.cfg` y hay que cambiarlo **antes** de publicar.
- **AdMob**: es gratis. Crea la app, un bloque "Bonificado" y otro
  "Intersticial", y apunta el ID de la app (`ca-app-pub-…~…`) y los dos IDs de
  bloque.
- Rellena en Play Console el formulario de **clasificación por edad** (IARC)
  y el de **seguridad de datos** (AdMob recoge el ID de publicidad).
- Las apuestas con monedas que se pueden comprar pueden contar como "juegos de
  azar simulados" en las políticas de Google Play. Las monedas nunca se pueden
  cambiar por dinero. Revisa la política vigente antes de publicar.

### 2. Plugins (lo hago yo cuando tengas las cuentas)
1. Instalar la plantilla de compilación de Android de Godot
   (Proyecto → Instalar plantilla de compilación de Android) y activar
   `gradle_build/use_gradle_build` en el perfil Android.
2. **AdMob**: el plugin de AdMob para Godot 4 (Poing Studios). En
   `ads.gd`, `show_rewarded` y `after_match` llaman al plugin en lugar de a
   `_simulated`, con las mismas reglas de frecuencia. Mientras se prueba, con
   los IDs de prueba de Google; al publicar, con los tuyos. El aviso de
   consentimiento de Europa (UMP) viene con el plugin.
3. **Google Play Billing**: el plugin oficial `GodotGooglePlayBilling`. En
   `store.gd`, `test_mode()` pasa a ser falso al detectarlo. Al pulsar un
   precio se abre el pago de Google, y `deliver()` se llama cuando se
   confirma la compra.

### 3. Validar compras en el servidor (necesita las cuentas de jugador)
Ahora las monedas viven en el teléfono (`user://wallet.cfg`), así que con un
teléfono manipulado se podrían inventar compras. Para que sea seguro:
- Cuentas de jugador en el servidor (Supabase, junto con el ranked en línea,
  y el inicio de sesión con Google Play Juegos).
- El teléfono manda al servidor el *purchase token* de Google. El servidor lo
  comprueba con la API de Google Play Developer y solo entonces suma las
  monedas en la cuenta.

### 4. iOS
- La misma lista de productos en App Store Connect, con StoreKit.
- Cuenta de desarrollador de Apple: 99 US$ al año.

### 5. Web
AdMob y Google Play no funcionan en el navegador. En la web, lo normal es:
- Anuncios: el SDK del portal donde se publique (Poki, CrazyGames) o AdSense para juegos.
- Pagos: sin compras, o con Stripe más adelante.
