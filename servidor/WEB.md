# Versión web

El mismo juego, para abrirlo en el navegador del teléfono o del PC sin instalar
nada. Los archivos ya exportados están en la carpeta `web/`.

## Qué cambia respecto al APK

- **No hay sala en la misma wifi**: un navegador no puede hacer de anfitrión.
  En la web solo aparece "En línea", que usa el servidor de Render.
- **Nivel difícil algo más flojo**: en el navegador la CPU piensa menos tiempo
  por jugada para no congelar la imagen.
- **No hay botón Salir**: se cierra la pestaña.
- **El sonido empieza tras el primer toque**: los navegadores no dejan sonar
  nada antes de que el usuario toque la página.
- Las dos gaitas comerciales NO van en la versión web (están excluidas en el
  perfil de exportación "Web"): una página pública no puede repartir música
  con derechos. La pista de jazz y los audios de pasar sí van.

Un jugador en la web y otro en el APK pueden estar en la misma sala.

## Publicarla en Render

`render.yaml` ya describe un segundo servicio, `crazy-dominoes-web`, que sirve
la carpeta `web/` como sitio estático (gratis y sin dormirse).

1. Sube los cambios a GitHub, incluida la carpeta `web/`.
2. En Render, entra en tu Blueprint y pulsa **Manual Sync** (o espera a que se
   sincronice solo). Aparecerá el servicio nuevo.
3. Su dirección será del estilo `https://crazy-dominoes-web.onrender.com`.

Si creaste el primer servicio a mano y no como Blueprint: **New → Static Site**,
elige el repositorio, deja vacío el comando de construcción y pon `web` como
carpeta a publicar.

## Probarla en este PC

Los navegadores no abren el juego haciendo doble clic en `index.html`: hace
falta servir la carpeta. Con Docker abierto:

    docker run --rm -p 8080:80 -v "%cd%\web:/usr/share/nginx/html:ro" nginx:alpine

y en el navegador: http://localhost:8080

## Regenerarla cuando cambie el juego

En Godot: `Proyecto → Exportar → Web → Exportar proyecto`, a `web/index.html`.
O por línea de comandos:

    godot --headless --path . --export-release "Web" web/index.html

Después, `git add web` y `git push` para que Render la publique.
