"""Dibujos de la tienda: la gema y los paquetes de gemas y de monedas
(Python 3 + Pillow + numpy). Salen en assets/ui/ con fondo transparente.

    python tools/generar_tienda.py

- shop_coins_1..4.png (400x260): puñado, bolsa, cofre y tesoro de monedas
  (usa coin_domino.png).

La gema y los paquetes de gemas NO salen de aquí: son recortes de la imagen
de referencia (tools/recortar_tienda.py). Las funciones de gemas se quedan por
si hacen falta, pero main() no las guarda.

Todo se dibuja a 4 veces el tamaño final y se reduce, para que los bordes
salgan suaves. Las semillas son fijas: siempre salen los mismos dibujos.
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui")
SS = 4
ART = (400, 260)

OUTLINE = (10, 22, 70, 255)
GEM_SHADES = {
    "hi": (205, 242, 255), "light": (120, 205, 255), "mid": (55, 150, 245), "deep": (25, 85, 210),
    "dark": (14, 45, 150), "night": (8, 28, 100),
}


# ------------------------------------------------------------------ gema

def gem(size, angle=0.0, glow=True):
    """Brillante de frente: corona con mesa arriba y pabellón en punta."""
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def p(x, y):
        return (x * s, y * s)

    t = [p(0.3, 0.2), p(0.5, 0.2), p(0.7, 0.2)]
    g = [p(x, 0.4) for x in (0.06, 0.22, 0.38, 0.5, 0.62, 0.78, 0.94)]
    c = p(0.5, 0.94)
    outer = [t[0], t[2], g[6], c, g[0]]
    # Contorno grueso.
    d.polygon(outer, fill=OUTLINE)
    shrink = [(x + (s * 0.5 - x) * 0.07, y + (s * 0.55 - y) * 0.07) for x, y in outer]
    inner = Image.new("L", (s, s), 0)
    ImageDraw.Draw(inner).polygon(shrink, fill=255)
    face = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    f = ImageDraw.Draw(face)
    sh = GEM_SHADES
    crown = [
        ((g[0], t[0], g[1]), sh["light"]), ((t[0], g[2], g[1]), sh["hi"]), ((t[0], t[1], g[2]), sh["light"]),
        ((t[1], g[3], g[2]), sh["mid"]), ((t[1], g[4], g[3]), sh["light"]), ((t[1], t[2], g[4]), sh["mid"]),
        ((t[2], g[5], g[4]), sh["deep"]), ((t[2], g[6], g[5]), sh["mid"]),
    ]
    for tri, col in crown:
        f.polygon(tri, fill=col + (255,))
    pav = [sh["light"], sh["mid"], sh["deep"], sh["mid"], sh["dark"], sh["deep"]]
    for i in range(6):
        f.polygon([g[i], g[i + 1], c], fill=pav[i] + (255,))
    # Facetas largas del pabellón.
    f.polygon([g[1], p(0.42, 0.62), c], fill=sh["hi"] + (110,))
    f.polygon([g[5], p(0.6, 0.6), c], fill=sh["night"] + (120,))
    # Mesa de arriba, más clara.
    f.polygon([t[0], t[2], p(0.62, 0.27), p(0.38, 0.27)], fill=sh["hi"] + (160,))
    # Aristas finas.
    lw = max(1, int(s * 0.008))
    for a, b in [(g[0], g[6]), (t[0], g[2]), (t[1], g[2]), (t[1], g[4]), (t[2], g[4]), (t[0], g[1]), (t[2], g[5])]:
        f.line([a, b], fill=(10, 30, 90, 120), width=lw)
    for x in g[1:-1]:
        f.line([x, c], fill=(10, 30, 90, 90), width=lw)
    img.paste(face, (0, 0), Image.composite(face, Image.new("RGBA", (s, s)), inner).getchannel("A"))
    # Reflejo blanco y destello.
    shine = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(shine).polygon([p(0.2, 0.36), p(0.32, 0.23), p(0.36, 0.25), p(0.26, 0.38)], fill=(255, 255, 255, 200))
    img.alpha_composite(shine.filter(ImageFilter.GaussianBlur(s * 0.006)))
    star(img, p(0.3, 0.24), s * 0.13)
    if glow:
        halo = img.getchannel("A").filter(ImageFilter.GaussianBlur(s * 0.05))
        out = Image.new("RGBA", (s, s), (90, 190, 255, 0))
        out.putalpha(halo.point(lambda a: a * 0.45))
        out.alpha_composite(img)
        img = out
    if angle:
        img = img.rotate(angle, resample=Image.BICUBIC, expand=True)
    return img


def star(img, center, r):
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    x, y = center
    pts = []
    for i in range(8):
        a = -math.pi / 2 + i * math.pi / 4
        rr = r if i % 2 == 0 else r * 0.18
        pts.append((x + math.cos(a) * rr, y + math.sin(a) * rr))
    d.polygon(pts, fill=(255, 255, 255, 255))
    img.alpha_composite(lay.filter(ImageFilter.GaussianBlur(r * 0.12)))
    img.alpha_composite(lay)


# ------------------------------------------------------------------ monedas

def coin_face(size):
    return Image.open(os.path.join(OUT, "coin_domino.png")).convert("RGBA").resize((size * SS, size * SS), Image.LANCZOS)


def coin_stack(size, n):
    """Columna de n monedas vistas un poco desde arriba."""
    s = size * SS
    th = int(s * 0.11)
    h = int(s * 0.42)
    img = Image.new("RGBA", (s, h + th * n + 4), (0, 0, 0, 0))
    top = coin_face(size).resize((s, h), Image.LANCZOS)
    d = ImageDraw.Draw(img)
    for i in range(n):
        y = (n - 1 - i) * th
        d.ellipse((0, y + th, s - 1, y + th + h), fill=(120, 72, 10, 255))
        d.rectangle((0, y + h // 2, s - 1, y + h // 2 + th), fill=(196, 132, 28, 255))
        d.ellipse((0, y + th - 2, s - 1, y + th + h - 2), fill=(150, 95, 15, 255))
        for k in range(0, s, max(4, s // 24)):
            d.line((k, y + h // 2 + 2, k, y + h // 2 + th - 2), fill=(150, 98, 18, 255), width=max(1, s // 120))
        img.alpha_composite(top, (0, y))
    return img


# ------------------------------------------------------------------ montón, bolsa y cofres

def canvas():
    return Image.new("RGBA", (ART[0] * SS, ART[1] * SS), (0, 0, 0, 0))


def put(img, piece, cx, cy):
    """Pega `piece` centrada en (cx, cy), en unidades del tamaño final."""
    img.alpha_composite(piece, (int(cx * SS - piece.width / 2), int(cy * SS - piece.height / 2)))


def pile(img, kind, cx, cy, w, h, n, seed, big=60):
    """Montón: piezas de atrás adelante, las de abajo más grandes."""
    rng = np.random.default_rng(seed)
    pieces = []
    for _ in range(n):
        x = cx + rng.uniform(-w / 2, w / 2)
        ny = rng.uniform(0, 1)
        y = cy - h / 2 + ny * h
        # Forma de montaña: más estrecho arriba.
        x = cx + (x - cx) * (0.35 + 0.65 * ny)
        pieces.append((y, x, rng.uniform(0.6, 1.0) * big, rng.uniform(-35, 35)))
    for y, x, size, ang in sorted(pieces):
        if kind == "gem":
            put(img, gem(int(size), ang, glow=False), x, y)
        else:
            c = coin_face(int(size * 0.9))
            c = c.resize((c.width, int(c.height * rng.uniform(0.55, 1.0))), Image.LANCZOS).rotate(ang * 0.5,
                                                                                               resample=Image.BICUBIC,
                                                                                               expand=True)
            put(img, c, x, y)


def shadow(img, cx, cy, w, h):
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(lay).ellipse(((cx - w / 2) * SS, (cy - h / 2) * SS, (cx + w / 2) * SS, (cy + h / 2) * SS),
                                fill=(0, 0, 0, 120))
    img.alpha_composite(lay.filter(ImageFilter.GaussianBlur(10 * SS / 4)))


def shade(mask, top, bottom, light=None):
    """Relleno con degradado vertical (y un brillo a la izquierda) dentro de `mask`."""
    w, h = mask.size
    t = np.linspace(0, 1, h)[:, None, None]
    col = np.array(top) * (1 - t) + np.array(bottom) * t
    col = np.broadcast_to(col, (h, w, 3)).copy()
    if light is not None:
        xs = np.linspace(0, 1, w)[None, :, None]
        col = col + (1 - np.abs(xs - light) * 2.2).clip(0, 1) * 28
    out = Image.fromarray(np.concatenate([col.clip(0, 255), np.full((h, w, 1), 255.0)], axis=2).astype(np.uint8))
    out.putalpha(mask)
    return out


def bag(img, contents, seed):
    """Saco de tela atado con cuerda, abierto arriba con el contenido asomando."""
    cx, base = ART[0] / 2, 238
    shadow(img, cx, base, 220, 30)
    m = Image.new("L", img.size, 0)
    d = ImageDraw.Draw(m)
    k = SS
    d.ellipse(((cx - 105) * k, 90 * k, (cx + 105) * k, (base + 2) * k), fill=255)
    d.polygon([((cx - 55) * k, 70 * k), ((cx + 55) * k, 70 * k), ((cx + 85) * k, 120 * k), ((cx - 85) * k, 120 * k)],
              fill=255)
    d.ellipse(((cx - 75) * k, 40 * k, (cx + 75) * k, 85 * k), fill=255)
    outline = m.filter(ImageFilter.MaxFilter(9))
    img.paste(Image.new("RGBA", img.size, (40, 22, 8, 255)), (0, 0), outline)
    body = shade(m, (176, 120, 70), (96, 58, 28), light=0.35)
    img.alpha_composite(body)
    dd = ImageDraw.Draw(img)
    # Pliegues.
    for x0, x1 in ((cx - 40, cx - 60), (cx + 30, cx + 55), (cx - 5, cx + 5)):
        dd.line([(x0 * k, 95 * k), (x1 * k, 200 * k)], fill=(80, 46, 20, 160), width=3 * k)
    # Boca abierta con el contenido.
    dd.ellipse(((cx - 66) * k, 44 * k, (cx + 66) * k, 78 * k), fill=(48, 26, 10, 255))
    pile(img, contents, cx, 44, 130, 44, 16, seed, 52)
    # Cuerda.
    dd.rounded_rectangle(((cx - 62) * k, 82 * k, (cx + 62) * k, 98 * k), radius=8 * k, fill=(214, 172, 100, 255),
                         outline=(90, 60, 25, 255), width=2 * k)
    for x in range(int(cx - 58), int(cx + 58), 9):
        dd.line([(x * k, 84 * k), ((x + 6) * k, 96 * k)], fill=(150, 112, 55, 255), width=2 * k)
    dd.ellipse(((cx + 40) * k, 86 * k, (cx + 58) * k, 104 * k), fill=(214, 172, 100, 255), outline=(90, 60, 25, 255),
               width=2 * k)
    dd.line([((cx + 50) * k, 102 * k), ((cx + 62) * k, 135 * k)], fill=(214, 172, 100, 255), width=5 * k)
    dd.line([((cx + 46) * k, 102 * k), ((cx + 40) * k, 132 * k)], fill=(214, 172, 100, 255), width=5 * k)
    # Unas cuantas sueltas al pie del saco.
    rng = np.random.default_rng(seed + 3)
    for x in (cx - 112, cx - 84, cx + 92, cx + 118):
        if contents == "gem":
            put(img, gem(int(rng.uniform(36, 46)), rng.uniform(-30, 30), glow=False), x, base - 10)
        else:
            put(img, coin_stack(int(rng.uniform(32, 40)), int(rng.integers(1, 4))), x, base - 16)


def chest(img, contents, seed, overflow=False):
    """Cofre de madera abierto con refuerzos de metal y el contenido dentro."""
    cx = ART[0] / 2
    k = SS
    shadow(img, cx, 240, 300 if overflow else 250, 30)
    left, right = cx - (130 if overflow else 112), cx + (130 if overflow else 112)
    top, base = 128, 238
    d = ImageDraw.Draw(img)
    # Tapa abierta, inclinada hacia atrás.
    lid = [(left + 8, top - 8), (right - 8, top - 8), (right - 22, 38), (left + 22, 38)]
    d.polygon([(x * k, y * k) for x, y in lid], fill=(38, 20, 8, 255))
    inner = [(left + 18, top - 10), (right - 18, top - 10), (right - 30, 50), (left + 30, 50)]
    d.polygon([(x * k, y * k) for x, y in inner], fill=(70, 38, 16, 255))
    d.line([(x * k, y * k) for x, y in lid + lid[:1]], fill=(150, 156, 168, 255), width=5 * k)
    # Contenido: montón que asoma por encima del borde.
    pile(img, contents, cx, top - (30 if overflow else 20), (right - left) * 0.95, 80 if overflow else 56,
         34 if overflow else 24, seed, 60 if overflow else 54)
    # Caja de tablas.
    m = Image.new("L", img.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((left * k, top * k, right * k, base * k), radius=10 * k, fill=255)
    outline = m.filter(ImageFilter.MaxFilter(9))
    img.paste(Image.new("RGBA", img.size, (32, 16, 6, 255)), (0, 0), outline)
    img.alpha_composite(shade(m, (150, 88, 40), (90, 48, 20), light=0.3))
    d = ImageDraw.Draw(img)
    for y in range(top + 28, base, 28):
        d.line([(left * k, y * k), (right * k, y * k)], fill=(60, 30, 10, 200), width=2 * k)
    # Refuerzos de metal y cerradura.
    steel = (170, 176, 188, 255)
    dark_steel = (90, 94, 106, 255)
    d.rectangle((left * k, top * k, right * k, (top + 14) * k), fill=steel, outline=dark_steel, width=2 * k)
    for x in (left + 18, right - 32):
        d.rectangle((x * k, top * k, (x + 14) * k, base * k), fill=steel, outline=dark_steel, width=2 * k)
        for y in (top + 30, top + 70, base - 18):
            d.ellipse(((x + 4) * k, y * k, (x + 10) * k, (y + 6) * k), fill=dark_steel)
    d.rounded_rectangle(((cx - 20) * k, (top + 6) * k, (cx + 20) * k, (top + 56) * k), radius=6 * k, fill=steel,
                        outline=dark_steel, width=2 * k)
    d.ellipse(((cx - 6) * k, (top + 22) * k, (cx + 6) * k, (top + 34) * k), fill=(30, 30, 36, 255))
    d.polygon([((cx - 3) * k, (top + 30) * k), ((cx + 3) * k, (top + 30) * k), ((cx + 2) * k, (top + 46) * k),
               ((cx - 2) * k, (top + 46) * k)], fill=(30, 30, 36, 255))
    if overflow:
        # Se sale: piezas sueltas por el suelo, a los lados.
        rng = np.random.default_rng(seed + 9)
        for x in (left - 6, left + 30, right - 30, right + 6, cx - 70, cx + 70):
            y = base - rng.uniform(0, 16)
            if contents == "gem":
                put(img, gem(int(rng.uniform(34, 46)), rng.uniform(-30, 30), glow=False), x, y)
            else:
                put(img, coin_stack(int(rng.uniform(30, 40)), int(rng.integers(2, 5))), x, y - 6)
        # Y unas monedas también en el tesoro de gemas.
        if contents == "gem":
            for x in (left + 4, right - 4):
                put(img, coin_stack(34, 3), x, base - 30)


def gem_set(level, seed):
    img = canvas()
    if level == 1:
        # Puñado: una gema grande delante y las pequeñas alrededor.
        cx = ART[0] / 2
        shadow(img, cx, 222, 250, 30)
        for x, y, size, ang in ((-80, 186, 54, -28), (78, 190, 50, 24), (-40, 152, 62, -12), (44, 150, 60, 14),
                                (-112, 206, 40, -35), (112, 208, 38, 30), (0, 168, 118, 0), (-58, 206, 46, 18),
                                (60, 210, 44, -16)):
            put(img, gem(size, ang, glow=False), cx + x, y)
    elif level == 2:
        bag(img, "gem", seed)
    elif level == 3:
        chest(img, "gem", seed)
    else:
        chest(img, "gem", seed, overflow=True)
    return img


def coin_set(level, seed):
    img = canvas()
    if level == 1:
        shadow(img, ART[0] / 2, 228, 220, 26)
        for x, n in ((-70, 3), (0, 5), (70, 2)):
            put(img, coin_stack(70, n), ART[0] / 2 + x, 200 - n * 4)
        put(img, coin_face(64), ART[0] / 2 + 40, 206)
    elif level == 2:
        bag(img, "coin", seed)
    elif level == 3:
        chest(img, "coin", seed)
    else:
        chest(img, "coin", seed, overflow=True)
    return img


def finish(img, size):
    # Brillo general de la pieza (las gemas lo llevan en el color).
    return img.resize(size, Image.LANCZOS)


def main():
    # Ya no se guarda nada: la gema y los paquetes de gemas y monedas son
    # recortes de las imágenes de referencia (tools/recortar_tienda.py).
    # Para volver a los dibujos generados, guardar gem_set / coin_set aquí.
    print("nada que generar: ver tools/recortar_tienda.py")
    print("dibujos de la tienda en", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
