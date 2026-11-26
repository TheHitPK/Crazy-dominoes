"""Recorta los dibujos de la tienda de las imágenes de referencia
(tools/fuentes/tienda_gemas.jpg y tienda_monedas.jpg) y les quita el fondo
oscuro de la tarjeta (Python 3 + Pillow + numpy).

    python tools/recortar_tienda.py

- gem.png: la gema suelta (la del saldo de arriba).
- shop_gems_1..4.png: puñado, bolsa, cofre y tesoro, con su cantidad (80, 500,
  1.100 y 3.000) incluida, porque en la imagen va dibujada encima del paquete.
  Si cambian las cantidades de Store.PRODUCTS, hay que cambiar la imagen.
- shop_coins_1..4.png: puñado, bolsa, cofre y tesoro de monedas. Aquí la
  imagen no trae la cantidad: la escribe el juego encima (shop.gd, _art).

Cómo se quita el fondo: el color de la tarjeta se mide en el borde de cada
recorte; lo que está unido al borde y se parece a ese color se vuelve
transparente, con un degradado suave (así se conserva el brillo de las gemas
y las partes oscuras de dentro de los cofres no se borran).
"""
import os
from collections import deque

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..")
GEMS_SRC = os.path.join(ROOT, "tools", "fuentes", "tienda_gemas.jpg")
COINS_SRC = os.path.join(ROOT, "tools", "fuentes", "tienda_monedas.jpg")
OUT = os.path.join(ROOT, "assets", "ui")

# (imagen, nombre, caja en la imagen de referencia, escala de salida)
CROPS = [
    (GEMS_SRC, "gem", (156, 118, 214, 163), 2),
    (GEMS_SRC, "shop_gems_1", (146, 486, 432, 616), 2),
    (GEMS_SRC, "shop_gems_2", (462, 486, 752, 616), 2),
    (GEMS_SRC, "shop_gems_3", (146, 760, 432, 898), 2),
    (GEMS_SRC, "shop_gems_4", (462, 760, 752, 898), 2),
    (COINS_SRC, "shop_coins_1", (142, 428, 404, 562), 2),
    (COINS_SRC, "shop_coins_2", (432, 428, 694, 562), 2),
    (COINS_SRC, "shop_coins_3", (142, 698, 404, 836), 2),
    (COINS_SRC, "shop_coins_4", (432, 694, 694, 838), 2),
]
## Distancia de color al fondo: por debajo de NEAR es fondo, por encima de FAR es dibujo.
NEAR = 16.0
FAR = 46.0


def cut(img):
    a = np.asarray(img, dtype=float)
    h, w, _ = a.shape
    border = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    bg = np.median(border, axis=0)
    dist = np.sqrt(((a - bg) ** 2).sum(axis=2))
    # Fondo = lo parecido al color de la tarjeta y unido al borde del recorte.
    soft = dist < FAR
    seen = np.zeros((h, w), bool)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if soft[y, x]:
                q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if soft[y, x]:
                q.append((y, x))
    while q:
        y, x = q.popleft()
        if seen[y, x] or not soft[y, x]:
            continue
        seen[y, x] = True
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not seen[ny, nx] and soft[ny, nx]:
                q.append((ny, nx))
    alpha = np.ones((h, w))
    ramp = np.clip((dist - NEAR) / (FAR - NEAR), 0, 1)
    alpha[seen] = ramp[seen]
    # Quita el tinte del fondo de los bordes semitransparentes.
    k = np.clip(alpha, 0.05, 1)[..., None]
    rgb = np.clip((a - (1 - k) * bg) / k, 0, 255)
    out = Image.fromarray(np.concatenate([rgb, alpha[..., None] * 255], axis=2).astype(np.uint8), "RGBA")
    # Borde del recorte siempre transparente, por si el dibujo lo tocaba.
    m = Image.fromarray((alpha * 255).astype(np.uint8))
    fade = Image.new("L", (w, h), 0)
    fade.paste(255, (3, 3, w - 3, h - 3))
    fade = fade.filter(ImageFilter.GaussianBlur(2))
    out.putalpha(Image.fromarray(np.minimum(np.asarray(m), np.asarray(fade)).astype(np.uint8)))
    return out


def main():
    for path, name, box, scale in CROPS:
        piece = cut(Image.open(path).convert("RGB").crop(box))
        piece = piece.resize((piece.width * scale, piece.height * scale), Image.LANCZOS)
        piece.save(os.path.join(OUT, name + ".png"))
        print(name, piece.size)


if __name__ == "__main__":
    main()
