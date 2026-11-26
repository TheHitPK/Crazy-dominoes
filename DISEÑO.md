# Guía de diseño de Crazy Dominoes

El estilo es el de un **salón de juego de madera y oro**: paneles marrón oscuro
con marco dorado, botones de cristal con aro dorado, campos hundidos y títulos
serif dorados. La guía dice qué pieza usar en cada caso. Cada pieza ya está
hecha en código: no hay que dibujar nada nuevo para una pantalla nueva.

- Medidas y colores: [scripts/ui_theme.gd](scripts/ui_theme.gd).
- Piezas: [scripts/ui_skin.gd](scripts/ui_skin.gd) y
  [scripts/fancy_button.gd](scripts/fancy_button.gd).
- Texturas: `assets/ui/kit_*`, generadas con `python tools/generar_kit.py`.

## 1. Principios

1. **Una acción principal por pantalla**, en verde y abajo ("¡Jugar!",
   "Listo"). Si hay dos botones grandes juntos, solo uno es verde.
2. **El oro se usa para lo importante**: marcos, títulos, lo elegido y el
   dinero. Si todo brilla, nada destaca.
3. **Se toca con el pulgar**: nada que se pulse mide menos de 70 de alto
   (unos 38 dp). Las acciones frecuentes van en la mitad de abajo.
4. **Todo responde al tocarlo**: el botón crece al pasar el ratón, se hunde al
   pulsar y suena un clic. Lo que no se puede usar se ve apagado y dice por
   qué ("nivel 3").
5. **El texto nunca pisa el dibujo del botón** ni se sale: se encoge solo
   (ver `UISkin.TEXT_ROOM`).

## 2. Color

| Ficha | Valor | Para qué |
|---|---|---|
| `UI.PRIMARY` | verde `#4cc742` | La acción principal: Jugar, Listo, Seguir jugando, Crear sala |
| `UI.SECONDARY` | azul `#2985f2` | Acción secundaria: En línea, Otra foto, Unirse |
| `UI.ACCENT` | turquesa | Opciones de red y listas (Salas públicas) |
| `UI.NEUTRAL` | madera `#9e6638` | Navegar, volver, cerrar, flechas y opciones sin elegir |
| `UI.BUY` | oro `#f2a81f` | Comprar con monedas |
| `UI.DANGER` | rojo `#d93d33` | Salir de la partida, borrar |
| `UI.GOLD` | `#ffd64d` | Títulos, cifras de monedas, lo elegido |
| `UI.LABEL` | beige `#f2deb3` | Títulos de fila dentro de paneles ("Color de piel") |
| `UI.CREAM` | `#f7edd1` | Texto normal y valores |
| `UI.CREAM_MUTED` | crema al 86 % | Explicaciones y textos de ayuda |
| `UI.WARN` | naranja claro | Avisos ("No se pudo abrir esa imagen") |
| `UI.TEAM_US` / `UI.TEAM_THEM` | azul / rojo | Solo para equipos en la mesa |

El color del botón tiñe una cara en grises, así que **cualquier color sirve**,
pero usa los de la tabla. El de los equipos no se usa en botones.

## 3. Tipografía

| Uso | Fuente | Tamaño | Cómo |
|---|---|---|---|
| Logo del menú | por defecto, gruesa | 104 (`UI.DISPLAY`) | `UISkin.heavy()` + `title_material` |
| Título de panel o pantalla | serif (Georgia / Noto Serif) | 40-44 (`UI.TITLE`) | `UISkin.title(label)` |
| Botón grande | por defecto | 34 (`UI.BUTTON`) | `FancyButton.setup` |
| Texto normal y valores | por defecto | 30 (`UI.BODY`) | |
| Títulos de fila, ayudas | por defecto | 26 (`UI.CAPTION`) | nunca por debajo de 26 |

Todo el texto en español, con frases cortas y verbos: "Recoger +100", no
"Recompensa disponible".

## 4. Piezas

### Panel (`UISkin.dress(panel)`)
Marco dorado con adornos en las esquinas y fondo marrón medio, casi plano. Se
usa en todo lo que se abre encima de una pantalla: Personalizar, Prepara tu
partida, Reglas, Regalo diario, Ajustes, fin de mano, chat, tienda, torneo,
ranked, desafío y récords.
- Detrás, una capa negra al 50 % que cubre toda la pantalla.
- Los paneles nuevos heredan de [scripts/popup.gd](scripts/popup.gd), que ya
  monta capa, marco, título y animación, y trae `label`, `para`, `button`,
  `well` (caja hundida) y `coin`.
- El título va centrado a 12-20 del borde de arriba, con `UISkin.title`.
- Margen interior de 36 a los lados.
- Se abre creciendo de 0,7 a 1 con `TRANS_BACK` en 0,3-0,35 s.

### Botón (`FancyButton.setup(texto, color, tamaño)`)
Cara de cristal del color pedido, aro dorado, brillo arriba y sombra abajo.
| Tipo | Alto | Ancho | Ejemplo |
|---|---|---|---|
| Principal | 88 (`UI.TOUCH`) | 260-500 | Listo, ¡Jugar! |
| Secundario | 84 (`UI.TOUCH_SMALL`) | 180-350 | Volver, Salir al menú |
| Chip de opción | 84 | 134-180 | 50 / 100 / 150, Fácil |
| Flecha de selector | 70 | 84 | `<` `>` de Personalizar |

- **Chip elegido**: `UI.BUY` (oro); sin elegir, `UI.NEUTRAL.darkened(0.35)`
  (madera oscura), como en "Prepara tu partida".
- **Desactivado**: la cara se vuelve gris, y al lado o debajo se dice por qué
  ("Se desbloquea en el nivel 3").
- **Barra de abajo del menú**: botones de 128x116 con el icono arriba
  (`vertical_icon_alignment = TOP`) y el texto en 22. Es la única excepción al
  mínimo de 26, porque las palabras son cortas y el icono ya las explica.

### Iconos (`button.set_icon("nombre", ancho)`)
Iconos crema con sombra, en `assets/ui/kit_icon_*.png` y generados en
`tools/generar_kit.py`. Van a la izquierda del texto (40-50 de ancho) o solos.

| Icono | Uso |
|---|---|
| `cpu` | Contra la CPU |
| `globe` | En línea |
| `book` | Reglas |
| `brush` | Personalizar, fichas y mesas |
| `exit` | Salir |
| `cart` | Tienda |
| `trophy` | Torneo, copas |
| `shield` | Ranked |
| `calendar` | Desafío del día |
| `chart` | Récords |
| `bulb` | Pista, Aprende (partida guiada) |
| `video` | Cualquier cosa que se consigue viendo un anuncio |
| `share` | Invitar |
| `smile` | Reacciones |
| `bolt` | Partida rápida |
| `gift` | Regalo (reservado) |

**Regla de los anuncios**: todo lo que se consigue con un anuncio lleva el
icono `video`, para que nunca sea una sorpresa.

### Caja hundida para agrupar (`well(rect)` en popup.gd)
Tarjetas de la tienda, copas del torneo, filas de récords y ligas del ranked.
Lo destacado dentro de una caja lleva una cinta dorada arriba a la derecha
("Mejor valor", "Solo una vez").

### Selector con flechas
`[<] [ valor ] [>]`: dos flechas de madera con chevron dorado
(`kit_chev_l/r`) y en medio un campo hundido (`UISkin.field_box()`) con el
valor en crema 28. Si la opción es de pago y no la tienes, el valor va en oro
con el precio ("Ébano · 300").

### Campo hundido (`UISkin.field_box()`)
Fondo casi negro con sombra interior y un filo dorado abajo. Se usa para
valores, el saldo de monedas, LineEdit (con `field_focus_box` al escribir) y
el historial del chat.

### Círculo de color
Bola del color con brillo (`kit_orb_gloss`). La elegida lleva aro dorado
(`kit_orb_ring`). Mide 66 y hay 76 entre una y otra.

### Moneda
Siempre `CoinIcon` a la izquierda de la cifra, y la cifra en oro. En barras,
dentro de una pastilla hundida (`field_box`).

## 5. Movimiento y sonido

| Qué | Cómo |
|---|---|
| Pasar el ratón | escala 1,08 en 0,22 s, cara un 15 % más clara |
| Pulsar | escala 0,93 en 0,08 s, cara un 18 % más oscura, el texto baja 3 |
| Abrir panel | fundido de la capa 0,2 s y el panel de 0,7 a 1 con rebote |
| Llamar la atención | `pulse(true)`: latido de brillo cada 0,9 s (regalo disponible) |
| Clic | `sfx.play("click")` en todo lo que se pulsa |
| Ganar o comprar | `sfx.play("win")`; error o sin dinero: `sfx.play("bad")` |

## 6. Al hacer una pantalla nueva

1. Contenedor: un script que hereda de `popup.gd` y llama a `frame()`, o un
   `Panel` + `UISkin.dress()` sobre una capa negra al 50 %.
2. Título con `UISkin.title()`.
3. Filas: título de fila en `UI.LABEL` 26, control debajo y 104 entre filas.
4. Botones con `FancyButton` y los colores de la tabla. Uno verde como mucho.
5. Nada de `StyleBoxFlat` con colores sueltos: si falta una pieza, añádela al
   kit (`tools/generar_kit.py` + `ui_skin.gd`) y apúntala aquí.
6. Prueba en 720x1280 con `--shot` y comprueba que nada se sale ni se pisa.

## 7. Pendiente

- **La mesa**: marcadores, placas de jugador y botón Menú. Ahora usan
  `StyleBoxFlat`. Necesitan una versión pequeña del marco, porque el adorno de
  las esquinas no cabe en 76 de alto.
- **Iconos en la partida**: el botón Menú y el de Chat siguen sin icono.
