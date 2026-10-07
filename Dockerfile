# Servidor de salas de Crazy Dominoes (para jugar a distancia).
#
# Es el mismo proyecto del juego arrancado sin pantalla con --server: solo
# usa las reglas, la IA y el código de red. No lleva gráficos ni audio.
#
# Probar en local:
#   docker build -t crazy-dominoes-server .
#   docker run --rm -p 10000:10000 crazy-dominoes-server
# y en el juego, como dirección: la IP de este PC seguida de :10000

FROM debian:bookworm-slim

ARG GODOT_VERSION=4.7.2-stable

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates libfontconfig1 wget unzip \
    && wget -q "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip" -O /tmp/godot.zip \
    && unzip -q /tmp/godot.zip -d /tmp \
    && mv "/tmp/Godot_v${GODOT_VERSION}_linux.x86_64" /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && rm /tmp/godot.zip \
    && apt-get purge -y wget unzip \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY project.godot ./
COPY scenes ./scenes
COPY scripts ./scripts

# No se ejecuta como root.
RUN useradd --create-home dominoes && chown -R dominoes /app
USER dominoes

# Render indica el puerto en la variable PORT; 10000 es su valor por defecto.
ENV PORT=10000
EXPOSE 10000

CMD ["godot", "--headless", "--path", "/app", "--", "--server"]
