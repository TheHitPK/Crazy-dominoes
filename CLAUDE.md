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

## Red: reglas que rompen las APK ya instaladas si no se cumplen

- Godot numera las RPC de cada nodo por orden alfabético. **No añadas, quites
  ni renombres `@rpc` en `net.gd`, ni cambies la firma de las que ya existen.**
  Las órdenes nuevas van en la clase `Lobby` (`/root/Main/Net/Lobby`) o en
  otro nodo hijo nuevo.
- El nodo de red tiene que seguir en `/root/Main/Net` en todos los equipos.
- El servidor es la autoridad: valida todo lo que llega de un cliente
  (`_clean_name`, `_clean_look`, límites del chat) y nunca manda las fichas de
  un jugador a otro.
- El servidor solo manda órdenes del chat a quien dijo `sv_hello`; sigue ese
  patrón para cualquier función nueva que las versiones viejas no entiendan.

## Servidor (Docker/Render)

- La imagen copia solo `project.godot`, `scenes/`, `scripts/` y `emoji/`, e
  importa los recursos al construirse. **Si un script que carga el servidor
  (`net.gd` y lo que precarga: `chat.gd`, `avatar.gd`, `domino_*`) hace
  `preload` de un recurso nuevo, añade su carpeta al `Dockerfile` y al
  `.dockerignore`.** Si no, el servidor no compila.
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
