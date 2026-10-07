# Poner el servidor en Render

Con esto el juego se puede jugar a distancia sin depender de este PC: el
servidor de salas queda en Render con una dirección fija.

Los archivos que Render necesita ya están en la raíz del proyecto:

- `Dockerfile`: cómo construir el servidor (descarga Godot para Linux y arranca
  el proyecto con `--server`).
- `render.yaml`: los datos del servicio (nombre, plan gratis, usar Docker).
- `.dockerignore`: la imagen solo lleva `project.godot`, `scenes/` y `scripts/`.
- `.gitignore`: qué no se sube a GitHub (el APK, la caché de Godot, las notas
  de voz originales).

## 1. Subir el proyecto a GitHub

Render toma el código de un repositorio de GitHub.

1. Entra en https://github.com/new y crea un repositorio. Ponlo **privado**:
   el proyecto lleva tus audios. No marques "Add a README".
2. Abre una terminal en la carpeta del proyecto y ejecuta, cambiando
   `TU_USUARIO` y `TU_REPO` por los tuyos:

       git init
       git add .
       git commit -m "Crazy Dominoes"
       git branch -M main
       git remote add origin https://github.com/TU_USUARIO/TU_REPO.git
       git push -u origin main

   La primera vez Git te pedirá iniciar sesión en GitHub.

## 2. Crear el servicio en Render

1. Entra en https://dashboard.render.com y crea la cuenta (puedes entrar con
   GitHub).
2. Pulsa **New → Blueprint**.
3. Conecta tu cuenta de GitHub y elige el repositorio. Si no aparece, pulsa
   "Configure account" y dale permiso a Render sobre ese repositorio.
4. Render lee `render.yaml` y propone un servicio llamado `crazy-dominoes`.
   Pulsa **Apply**.
5. Espera a que termine la construcción (unos minutos la primera vez). En los
   registros debe aparecer:

       [servidor] escuchando en el puerto 10000

6. Arriba de la página del servicio sale su dirección, del estilo
   `https://crazy-dominoes.onrender.com`. Si el nombre ya estaba cogido, Render
   le añade letras; usa la que te muestre.

## 3. Jugar

En el juego: **Jugar con amigos → A distancia**.

- En "Dirección del servidor" escribe la de Render, sin el `https://`:

      crazy-dominoes.onrender.com

- Uno pulsa **Crear sala** y le sale un código de 4 letras.
- Los demás escriben la misma dirección y ese código, y pulsan **Unirse**.

El juego recuerda la dirección para la próxima vez.

## Lo que hay que saber del plan gratis

- **Se duerme** tras unos 15 minutos sin uso. El primero que entre después
  espera cerca de un minuto; el juego reintenta solo durante ese rato y muestra
  "Conectando…".
- **Las salas no se guardan.** Si Render reinicia o duerme el servicio, las
  salas abiertas se pierden y hay que crear otra.
- Cada vez que hagas `git push`, Render vuelve a construir el servidor. Las
  salas abiertas en ese momento se cierran.

## Cuando cambies el juego

Servidor y teléfonos tienen que llevar la misma versión de las reglas y de la
red. Si cambias algo en `scripts/`:

1. Exporta el APK nuevo e instálalo en los teléfonos.
2. Sube los cambios para que Render actualice el servidor:

       git add .
       git commit -m "lo que cambiaste"
       git push

## Si algo falla

- **La construcción falla en Render**: abre los registros ("Logs") del
  despliegue; el error suele estar al final.
- **El despliegue se queda en "In progress" y acaba fallando por tiempo**:
  Render no ha detectado el puerto abierto. Comprueba en los registros que
  aparece la línea "escuchando en el puerto".
- **"No se pudo conectar" en el juego**: revisa que la dirección esté bien
  escrita y prueba otra vez; si el servidor estaba dormido puede necesitar un
  segundo intento.
- En los registros verás de vez en cuando `Missing or invalid header 'upgrade'`.
  Es normal: son visitas que no vienen del juego (por ejemplo, abrir la
  dirección en un navegador) y el servidor las rechaza.

## Probar la imagen en este PC (opcional)

Con Docker Desktop abierto, desde la carpeta del proyecto:

    docker build -t crazy-dominoes-server .
    docker run --rm -p 10000:10000 crazy-dominoes-server

En el juego, la dirección sería la IP de este PC seguida de `:10000`.
