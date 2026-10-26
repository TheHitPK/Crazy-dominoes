# Crazy Dominoes

Dominó en parejas (doble seis, 2 contra 2) hecho en **Godot 4.7.2** con GDScript.
Se juega contra la CPU, con amigos en la misma wifi o en línea a través de un
servidor de salas. Sale para Android (APK), para navegador (web) y, preparado
pero sin publicar, para iOS.

## Qué tiene

- **Contra la CPU**, en tres niveles. El difícil deduce qué números le faltan a
  cada rival por sus pases y simula la mano cientos de veces (Monte Carlo).
- **Con amigos en la misma wifi**: un teléfono crea la sala, hace de servidor y
  la anuncia por la red local.
- **En línea**: servidor dedicado en Render con salas de código de 4 letras y
  salas públicas. Si alguien se sale, una CPU juega por esa persona hasta que
  vuelve a su asiento.
- **Chat de sala**: emojis, frases hechas y texto libre, con filtro de
  groserías, límite de mensajes por jugador y opción de silenciar.
- **Personalización**: avatar (icono o foto), manos, fichas, mesa y bebida.
  Los demás jugadores te ven con tu aspecto.
- **Sonido**: efectos sintetizados por código, audios grabados al pasar y
  música de fondo.

## Cómo está construido

**Casi no hay escenas ni imágenes.** [scenes/main.tscn](scenes/main.tscn) es un
solo nodo con [scripts/main.gd](scripts/main.gd), y todo lo demás (pantallas,
mesa, fichas, manos, botones) se crea y se dibuja desde código con `_draw()`.
Los únicos recursos son los audios de `audio/` y los emoji de `emoji/`.

```
project.godot          Configuración: 720x1280 vertical, renderizador Compatibility, 60 fps
scenes/main.tscn       Escena raíz (un nodo)
scripts/
  main.gd              Raíz: lee argumentos, cambia de pantalla con fundido, arranca el servidor con --server
  menu.gd              Menú principal, reglas y acceso a Personalizar
  online.gd            "Jugar con amigos": entrar, salas públicas y sala de espera
  game.gd              La partida: turnos, animaciones, arrastre de fichas, marcador, HUD (local y en red)
  domino_state.gd      Reglas puras del dominó (sin nodos): reparto, jugadas legales, tranca, puntos
  domino_ai.gd         IA de la CPU: fácil, intermedio (heurística) y difícil (Monte Carlo)
  net.gd               Red: cliente, servidor de salas, wifi (UDP) y chat
  online_config.gd     Dirección fija del servidor de Render
  settings.gd          Ajustes y perfil guardados en user://settings.cfg
  chat.gd              Panel de chat y filtro de groserías
  avatar.gd            Círculo de avatar: foto o icono dibujado
  customize.gd         Panel de personalización con vista previa
  table.gd, tile.gd, hand.gd, glass.gd, chalk_board.gd   Mesa, fichas, manos, vasos y pizarras, dibujados por código
  fancy_button.gd, ui_theme.gd, signal_meter.gd          Botón, medidas y colores comunes, indicador de señal
audio/pass/            Audios que suenan al pasar (uno al azar)
audio/music/           Música de fondo de la partida
emoji/                 Emojis del chat (Twemoji)
web/                   Export web ya generado (lo publica Render como sitio estático)
servidor/              Guías de despliegue y .bat para probar el servidor en este PC
Dockerfile, render.yaml   Servidor en Render y sitio web estático
export_presets.cfg     Perfiles de export: Android, iOS y Web
```

### Las tres capas

1. **Reglas** ([domino_state.gd](scripts/domino_state.gd)): una ficha es el
   entero `a*8+b` con `a<=b`, y una jugada es `ficha*2+lado`. Las parejas son
   0-2 contra 1-3. No depende de nodos, así que la usan igual la partida local,
   el servidor y la IA.
2. **IA** ([domino_ai.gd](scripts/domino_ai.gd)): nunca mira manos ajenas. En
   Android y en el servidor piensa en un hilo aparte (`WorkerThreadPool`). En
   la web no hay hilos: piensa en el hilo principal con menos tiempo (160 ms en
   vez de 450 ms).
3. **Presentación** ([game.gd](scripts/game.gd) y los scripts de dibujo): para
   que vaya fluido en teléfonos modestos, la mesa y cada cara de ficha se pintan
   una vez en un `SubViewport` y luego se muestran como imagen. Además el
   proyecto usa `low_processor_mode` y un máximo de 60 fps.

### Red

Siempre hay un servidor con autoridad: reparte, valida cada jugada, mueve las
CPU y manda a cada jugador solo sus fichas. Los clientes solo muestran lo que
pasa y piden jugadas.

- **Wifi**: el teléfono anfitrión abre un `WebSocketMultiplayerPeer` en el
  puerto 8910 y se anuncia por UDP en el 8911.
- **En línea**: el mismo proyecto arrancado sin ventana con `--server`, en
  Docker sobre Render. La conexión es `wss://` y el puerto sale de la variable
  `PORT`.
- Las RPC viven en `/root/Main/Net` y, las añadidas después de la primera
  versión, en `/root/Main/Net/Lobby`. Esa ruta tiene que ser igual en todos los
  equipos.

## Ejecutar

Abre la carpeta en Godot 4.7.2 y pulsa F5. Para pruebas hay argumentos de línea
de comandos, que van después de `--` (la lista completa está en
[main.gd](scripts/main.gd)):

```
godot --path . -- --play --diff=2          # partida directa en difícil
godot --path . -- --auto --speed=4         # la CPU juega sola, x4
godot --path . -- --shot=captura.png       # captura y cierra
godot --headless --path . -- --server --port=8910     # servidor de salas local
godot --headless --path . -- --net-create=localhost:8910 --net-humans=1   # cliente de prueba
```

## Compilar y publicar

| Qué | Cómo | Guía |
|---|---|---|
| APK Android | Godot → Proyecto → Exportar → Android | — |
| Web | `godot --headless --path . --export-release "Web" web/index.html` y subir `web/` | [servidor/WEB.md](servidor/WEB.md) |
| Servidor en línea | `git push` a la rama conectada a Render (Docker) | [servidor/RENDER.md](servidor/RENDER.md) |
| Servidor en un VPS o en este PC | `servidor/iniciar_servidor.bat` o export Linux dedicado | [servidor/LEEME.md](servidor/LEEME.md) |

**El servidor y los clientes tienen que llevar la misma versión de las reglas y
la red.** Cuando cambies algo en `scripts/`, publica a la vez el servidor, la
web y un APK nuevo.

## Créditos y licencias

- Emojis: [Twemoji](https://github.com/twitter/twemoji), CC-BY 4.0 (ver
  [emoji/CREDITOS.txt](emoji/CREDITOS.txt)).
- `audio/music/jazz_de_la_casa.ogg`: generada por código, libre.
- Las pistas comerciales que haya en `audio/music/` no se publican en la web
  (están excluidas en el perfil "Web") y no deben ir en una versión pública.
