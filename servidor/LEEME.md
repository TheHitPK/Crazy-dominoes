# Servidor para jugar a distancia

Para jugar en la **misma wifi** no hace falta nada de esto: un teléfono crea la
sala y hace de servidor.

Para jugar **a distancia** (cada uno en su casa o con datos móviles) hace falta
un servidor encendido en internet al que todos se conecten. Es el mismo juego
arrancado sin ventana, con `--server`.

La forma preparada para tenerlo en internet es **Render**: los pasos están en
[RENDER.md](RENDER.md).

## Probarlo en este PC

Ejecuta `iniciar_servidor.bat`. Deja la ventana abierta: ahí verás las salas que
se crean y cómo va cada mano.

En el teléfono, en **Jugar con amigos → A distancia**, escribe como dirección la
IP de este PC (por ejemplo `192.168.1.20`) y pulsa **Crear sala**. Sale un código
de 4 letras; los demás escriben la misma dirección y ese código.

Así solo funciona dentro de tu red. Para que entre gente de fuera hay que subir
el servidor a internet.

## Subirlo a internet

Hace falta una máquina Linux con IP pública (un VPS de los baratos sobra: el
dominó manda mensajes mínimos).

1. En Godot: `Proyecto → Exportar → Añadir → Linux`, activa **Exportar como
   servidor dedicado** y exporta. Salen un ejecutable y un `.pck`.
2. Sube los dos archivos al servidor y arráncalo:

       ./crazy_dominoes.x86_64 --headless -- --server --port=8910

3. Abre el puerto **8910 TCP** en el cortafuegos del servidor.
4. En el juego, la dirección del servidor es su IP o dominio, por ejemplo
   `midominio.com`.

Conviene dejarlo como servicio (systemd o similar) para que se reinicie solo.

## Conexión cifrada (necesaria para publicar en iPhone)

Tal cual, la conexión va sin cifrar (`ws://`). Para cifrarla (`wss://`) se pone
delante un proxy con certificado, por ejemplo Caddy o nginx, que reciba en el
443 y reenvíe al 8910. Entonces en el juego se escribe la dirección completa:

    wss://midominio.com

Cómo interpreta el juego lo que se escribe como dirección:

- una IP (`192.168.1.20`): conexión directa sin cifrar, puerto 8910;
- una IP con puerto (`192.168.1.20:10000`): igual, con ese puerto;
- un nombre de dominio (`midominio.com`): conexión cifrada (`wss://`);
- algo con `://`: se usa tal cual.

## Qué hace el servidor

- Guarda las salas (código de 4 letras) y quién ocupa cada asiento.
- Reparte, valida cada jugada y manda a cada jugador solo sus fichas.
- Mueve las CPU de los asientos vacíos.
- Si alguien se desconecta, una CPU sigue jugando por él.
- Cuando se va el último jugador, la sala se cierra.

No guarda cuentas ni partidas: al reiniciarlo se pierden las salas abiertas.
