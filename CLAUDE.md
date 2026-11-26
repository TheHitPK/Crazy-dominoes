# CLAUDE.md

Juego de dominó en parejas en Godot 4.7.2 (GDScript). La visión general está en
README.md; aquí va lo que no se deduce leyendo el código.

## Convenciones

- Código, comentarios, textos de la interfaz y documentación en **español**.
  Los comentarios `##` explican el porqué; mantén esa densidad.
- **Sin escenas nuevas**: todo se construye y se dibuja por código (`_draw()`).
  `scenes/main.tscn` es solo la raíz.
- Los scripts se cargan con `const X = preload("res://scripts/x.gd")`, no con
  `class_name`.
- La interfaz se maqueta en un lienzo de 720x1280 con `Rect2` absolutos. Usa
  las medidas y colores de `ui_theme.gd` (TOUCH, BODY, CAPTION...).
- Paneles, botones, campos y títulos siguen [DISEÑO.md](DISEÑO.md): `Panel` +
  `UISkin.dress()`, `FancyButton` con los colores de `ui_theme.gd`,
  `UISkin.field_box()` y `UISkin.title()`. No metas `StyleBoxFlat` con colores
  sueltos en pantallas nuevas.

## Doble nueve y Cincos

- Las fichas se codifican `(a << State.shift) | b`: en doble seis `a*8+b`
  (lo que viaja por la red, no se toca) y en doble nueve `a*16+b`. Lee y crea
  fichas siempre con `State.hi()`, `State.lo()` y `State.code()`, nunca con
  `>> 3` o `& 7`. El juego de fichas es estático: `Game` llama a
  `State.use_set()` al empezar y vuelve a doble seis en `_exit_tree`.
- Cincos y doble nueve son solo contra la CPU. `State.NET_MODES` (3) es el
  límite de modos en red: el servidor recorta a él y la sala nunca manda Cincos.

## Torneo, ranked, desafío, anuncios y compras

- Son solo contra la CPU y viven en el teléfono (`user://*.cfg`). No tocan la
  red: las reacciones en línea van por el chat de emojis que ya existía.
- `ads.gd` y `store.gd` están en modo prueba (anuncio simulado, compra sin
  cobrar). Los pasos a real están en `servidor/ANUNCIOS_Y_PAGOS.md`; no metas
  IDs reales de AdMob ni de productos sin que el usuario los dé.
- Validar compras necesita llevar el monedero al servidor (pendiente).
- Salir a mitad de una partida de torneo cuenta como derrota
  (`Game.leave_match`, también con el botón atrás de Android).

## Ranked en línea y cuentas (Supabase)

- Órdenes en el nodo `/root/Main/Net/Ranked` (clase `RankedNet` de `net.gd`).
  Igual que con `Lobby` y `Modes`, no se tocan ni se reordenan: las nuevas van
  en otro nodo hijo.
- Solo lo atiende el servidor dedicado. `cloud.gd` guarda las fichas en
  Supabase (tabla `players`, `servidor/supabase.sql`) con las variables de
  entorno `SUPABASE_URL` y `SUPABASE_SERVICE_KEY`. Sin ellas, en
  `user://cloud_players.json`. La clave de servicio nunca va en el juego ni en
  el repositorio.
- La cuenta es el sha256 del `Settings.player_token`. `ranked.gd` son
  funciones puras sobre esa ficha: las usan el servidor (para calcular) y el
  cliente (para mostrar).
- Cola: con 4 empieza; si el primero lleva `Ranked.FILL_AFTER` s, empieza con
  los que haya y CPU. Al acabar, `_ranked_finish` apunta los PR (quien se
  salió pierde) y cierra la sala.
- Prueba sin pantalla: un servidor con `--server --port=8935` y dos clientes
  con `--net-ranked=localhost:8935 --net-name=Ana`. La pantalla:
  `-- --ranked --server-addr=localhost:8935`.

## Red: reglas que rompen las APK ya instaladas si no se cumplen

- Godot numera las RPC de cada nodo por orden alfabético. **No añadas, quites
  ni renombres `@rpc` en `net.gd` ni en sus clases `Lobby` y `Modes`, ni
  cambies la firma de las que ya existen.** Las APK ya instaladas usan esos
  números. Cada grupo de órdenes nuevas va en **otro nodo hijo nuevo** de
  `Net`, como `Modes` (`/root/Main/Net/Modes`).
- Lo nuevo que cambia cómo se cuenta la partida solo se activa si todos los de
  la sala lo entienden: `_all_know_modes` vuelve a clásico a 100 si alguien no
  dijo `sv_modes_hello`.
- El nodo de red tiene que seguir en `/root/Main/Net` en todos los equipos.
- Los formatos sin parejas (`State.SOLO`, `State.DUEL`) son solo contra la
  CPU: `game.gd` fuerza `PAIRS` en red. Llevarlos a línea necesita un nodo de
  RPC nuevo, como `Modes`, y que el servidor reparta el pozo.
- El servidor es la autoridad: valida todo lo que llega de un cliente
  (`_clean_name`, `_clean_look`, límites del chat) y nunca manda las fichas de
  un jugador a otro.
- El servidor solo manda órdenes del chat a quien dijo `sv_hello`; sigue ese
  patrón para cualquier función nueva que las versiones viejas no entiendan.

## Servidor (Docker/Render)

- La imagen copia solo `project.godot`, `scenes/`, `scripts/`, `emoji/` y
  `assets/brand/` (icono y pantalla de carga que nombra `project.godot`), e
  importa los recursos al construirse. **Si un script que carga el servidor
  (`net.gd` y lo que precarga: `chat.gd`, `avatar.gd`, `domino_*`) hace
  `preload` de un recurso nuevo, añade su carpeta al `Dockerfile` y al
  `.dockerignore`.** Si no, el servidor no compila.
- `main.gd` precarga `menu.gd`, así que el servidor también lo compila. Las
  texturas de `assets/ui/` se cargan con `load()` en `ui_skin.gd`, no con
  `preload`, para que el servidor no las necesite. Sigue igual con las nuevas.
- Con `--server`, `main.gd` sale antes de crear sonido o interfaz: no metas
  ahí nada que necesite pantalla.

## Web

- El export web no tiene hilos (`thread_support=false`): `game.gd` llama a la
  IA en el hilo principal y `main.gd` baja `AI.think_ms`. No uses
  `WorkerThreadPool` sin una rama para `OS.has_feature("web")`.
- En la web no hay sala por wifi (ni UDP ni servidor) ni botón Salir.
- `web/` está versionada y la publica Render tal cual: vuelve a exportarla
  cuando cambies el juego.

## Probar

No hay tests automáticos. Verifica con los argumentos de `main.gd`:

```
godot --headless --path . -- --server --port=8910
godot --headless --path . -- --net-create=localhost:8910 --net-humans=1 --net-say=hola
godot --path . -- --auto --speed=4 --diff=2
godot --path . -- --play --shot=captura.png
```

Tras añadir audios o imágenes, ejecuta `godot --headless --path . --import`
antes de exportar.
