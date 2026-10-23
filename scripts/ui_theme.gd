extends RefCounted
## Medidas y colores comunes de la interfaz, para que todas las pantallas se
## vean y se usen igual.
##
## Las medidas van en unidades del juego. El diseño mide 720 de ancho, que en
## un teléfono son unos 360-410 dp: 1 dp ≈ 1,8-2 unidades. De ahí salen:
##   - zona táctil mínima de 48 dp  -> TOUCH = 88 unidades de alto;
##   - texto normal de 16 dp        -> BODY = 30;
##   - nada por debajo de ~13 dp    -> CAPTION = 26, solo para textos secundarios.

# --- Tipografía
const DISPLAY := 104
const TITLE := 44
const BUTTON := 34
const BODY := 30
const CAPTION := 26

# --- Tamaños y espaciado
const TOUCH := 88
## Alto de los botones secundarios dentro de paneles (sigue por encima de 44 dp).
const TOUCH_SMALL := 84
const GAP := 16
const MARGIN := 40
const RADIUS := 16

# --- Colores con significado
const GOLD := Color(1.0, 0.84, 0.3)
const CREAM := Color(0.97, 0.93, 0.82)
## Texto secundario: crema algo apagado, pero con contraste suficiente sobre la madera oscura.
const CREAM_MUTED := Color(0.97, 0.93, 0.82, 0.86)
const WARN := Color(1.0, 0.72, 0.42)
const SURFACE := Color(0.13, 0.08, 0.05, 0.97)
const SURFACE_SOFT := Color(0.08, 0.05, 0.03, 0.88)
const BORDER := Color(0.85, 0.65, 0.3, 0.9)
const PRIMARY := Color(0.25, 0.6, 0.3)
const SECONDARY := Color(0.2, 0.45, 0.85)
const ACCENT := Color(0.15, 0.5, 0.6)
const NEUTRAL := Color(0.45, 0.33, 0.22)
const DANGER := Color(0.72, 0.2, 0.18)
const TEAM_US := Color(0.2, 0.45, 0.85)
const TEAM_THEM := Color(0.8, 0.22, 0.2)
const SWITCH_ON := Color(0.2, 0.5, 0.6)
const SWITCH_OFF := Color(0.4, 0.32, 0.26)
