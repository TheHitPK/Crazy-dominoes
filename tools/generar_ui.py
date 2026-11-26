"""Genera las texturas del menú en assets/ui/ (Python 3 + Pillow + numpy).

    python tools/generar_ui.py [imagen_de_referencia.jpg]

Todo se dibuja por código salvo la moneda, que se recorta de la imagen de
referencia (si se pasa) con una máscara redonda suavizada. Si no se pasa, se
conserva la coin_domino.png que ya haya.

Cada textura se genera al doble del tamaño con el que se ve en el lienzo de
720x1280 (los botones de 290x104 salen de 580x208), para que en teléfonos de
1080 o más de ancho no se vea borrosa. Como cada pieza tiene un tamaño fijo en
el menú, se estira entera (sin 9-slice): con 9-slice las esquinas de una
textura al doble se verían al doble de grandes. La barra de experiencia sí es
9-slice porque cambia de ancho; esa va a tamaño real.

Después de generar: godot --headless --path . --import
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui")
SS = 3  # sobremuestreo para que los bordes salgan suavizados
RNG = np.random.default_rng(7)


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])


# ------------------------------------------------------------------ utilidades

class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = np.zeros((h * SS, w * SS, 4))

    def rr(self, box, r, corners=None):
        """Máscara de un rectángulo redondeado (coordenadas de la textura final)."""
        m = Image.new("L", (self.w * SS, self.h * SS), 0)
        x0, y0, x1, y1 = [v * SS for v in box]
        ImageDraw.Draw(m).rounded_rectangle((x0, y0, x1 - 1, y1 - 1), radius=r * SS, fill=255, corners=corners)
        return np.asarray(m, float) / 255

    def ellipse(self, box):
        m = Image.new("L", (self.w * SS, self.h * SS), 0)
        ImageDraw.Draw(m).ellipse([v * SS for v in box], fill=255)
        return np.asarray(m, float) / 255

    def ys(self):
        return (np.arange(self.h * SS) / SS)[:, None] * np.ones((1, self.w * SS))

    def xs(self):
        return np.ones((self.h * SS, 1)) * (np.arange(self.w * SS) / SS)[None, :]

    def grad(self, stops, y0, y1):
        """Degradado vertical entre y0 e y1 con paradas [(t, color), ...]."""
        t = np.clip((self.ys() - y0) / max(y1 - y0, 1), 0, 1)
        out = np.zeros((self.h * SS, self.w * SS, 3))
        for (ta, ca), (tb, cb) in zip(stops, stops[1:]):
            sel = (t >= ta) & (t <= tb)
            k = ((t - ta) / max(tb - ta, 1e-6))[..., None]
            out[sel] = (ca * (1 - k) + cb * k)[sel]
        return out

    def paint(self, mask, rgb, alpha=1.0):
        a = (mask * alpha)[..., None]
        if np.ndim(rgb) == 1:
            rgb = np.broadcast_to(rgb, self.px[..., :3].shape)
        ca = self.px[..., 3:4]
        out_a = a + ca * (1 - a)
        safe = np.where(out_a > 0, out_a, 1)
        self.px[..., :3] = (rgb * a + self.px[..., :3] * ca * (1 - a)) / safe
        self.px[..., 3:4] = out_a

    def layer(self, img, alpha=1.0):
        """Pega una capa RGBA de Pillow dibujada al tamaño sobremuestreado."""
        arr = np.asarray(img, float) / 255
        self.paint(arr[..., 3], arr[..., :3], alpha)

    def blank(self):
        return Image.new("RGBA", (self.w * SS, self.h * SS), (0, 0, 0, 0))

    def noise(self, mask, amount, streak=1):
        """Grano de la textura. Con streak > 1 se alarga en horizontal (cepillado o veta)."""
        h, w = self.h * SS, self.w * SS
        n = RNG.normal(0, 1, (h, max(w // streak, 1)))
        n = np.asarray(Image.fromarray(((n * 40) + 128).clip(0, 255).astype(np.uint8)).resize((w, h), Image.BILINEAR), float)
        n = (n - 128) / 40 * amount
        self.px[..., :3] = np.clip(self.px[..., :3] + (n * mask)[..., None], 0, 1)

    def save(self, name):
        img = Image.fromarray((self.px.clip(0, 1) * 255).astype(np.uint8), "RGBA")
        img = img.resize((self.w, self.h), Image.LANCZOS)
        img.save(os.path.join(OUT, name))
        print("  ", name, img.size)


# ------------------------------------------------------------------ botones

def button(name, w, h, rim, face, gloss=False, icon=None, r=28):
    """Botón con borde biselado (rim) y cara (face), cada uno [(t, color), ...]."""
    c = Canvas(w, h)
    c.paint(c.rr((0, 4, w, h), r), np.zeros(3), 0.55)  # sombra de apoyo
    c.paint(c.rr((0, 0, w, h - 4), r), hexc("#140d08"))
    c.paint(c.rr((3, 3, w - 3, h - 7), r - 3), c.grad(rim, 3, h - 7))
    inner = c.rr((11, 11, w - 11, h - 15), r - 10)
    c.paint(inner, c.grad(face, 11, h - 15))
    c.noise(inner, 0.025 if gloss else 0.045)
    # Luz arriba y sombra abajo dentro de la cara.
    ys = c.ys()
    top = np.clip(1 - (ys - 11) / ((h - 26) * 0.5), 0, 1)
    if gloss:
        # Brillo especular con corte marcado a media altura, como un cristal.
        band = np.where(ys < 11 + (h - 26) * 0.48, 0.26 * top + 0.06, 0)
        c.paint(inner * band, np.ones(3))
    else:
        c.paint(inner * top ** 2, np.ones(3), 0.16)
    c.paint(inner * np.clip((ys - (h - 40)) / 25, 0, 1), np.zeros(3), 0.3)
    # Filo claro bajo el borde superior.
    c.paint(inner - c.rr((11, 14, w - 11, h - 15), r - 10), np.ones(3), 0.35)
    if icon:
        icon(c, w, h)
    c.save(name)


def gear_icon(c, w, h):
    lay = c.blank()
    d = ImageDraw.Draw(lay)
    cx, cy, r = (w - 46) * SS, (h - 46) * SS, 26 * SS
    pts = []
    for i in range(32):
        a = i / 32 * math.tau
        rr = r if (i // 2) % 2 == 0 else r * 0.76
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    d.polygon(pts, fill=(20, 40, 20, 140))
    d.ellipse((cx - r * 0.34, cy - r * 0.34, cx + r * 0.34, cy + r * 0.34), fill=(0, 0, 0, 0))
    # Silueta de jugador detrás del engranaje.
    px, py = cx - 34 * SS, cy - 30 * SS
    d.ellipse((px - 13 * SS, py - 13 * SS, px + 13 * SS, py + 13 * SS), fill=(20, 40, 20, 110))
    d.pieslice((px - 28 * SS, py + 14 * SS, px + 28 * SS, py + 66 * SS), 180, 360, fill=(20, 40, 20, 110))
    c.layer(lay)


def globe_icon(c, w, h):
    lay = c.blank()
    d = ImageDraw.Draw(lay)
    cx, cy, r = (w - 66) * SS, (h / 2 - 2) * SS, 42 * SS
    col, lw = (255, 255, 255, 120), 4 * SS
    d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=col, width=lw)
    for k in (0.35, 0.75):
        d.ellipse((cx - r * k, cy - r, cx + r * k, cy + r), outline=col, width=lw)
    d.line((cx, cy - r, cx, cy + r), fill=col, width=lw)
    for k in (-0.5, 0.0, 0.5):
        half = r * math.sqrt(1 - k * k)
        d.line((cx - half, cy + r * k, cx + half, cy + r * k), fill=col, width=lw)
    c.layer(lay)


def domino_icon(c, w, h):
    # Pequeña y pegada al borde derecho: el texto del botón va a su izquierda,
    # sin pisarla (ver TEXT_ROOM en scripts/ui_skin.gd).
    k = 0.62
    tw, th = int(60 * k), int(110 * k)
    tile = Image.new("RGBA", (tw * SS, th * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(tile)
    d.rounded_rectangle((0, 0, tw * SS - 1, th * SS - 1), radius=int(10 * k * SS), fill=(255, 235, 240, 70),
                        outline=(255, 200, 230, 130), width=3 * SS)
    d.line((5 * SS, th * SS // 2, (tw - 5) * SS, th * SS // 2), fill=(255, 200, 230, 130), width=3 * SS)
    for x, y in ((18, 18), (42, 38), (30, 28), (18, 72), (42, 92)):
        x, y, s = x * k, y * k, 6 * k
        d.ellipse(((x - s) * SS, (y - s) * SS, (x + s) * SS, (y + s) * SS), fill=(255, 220, 240, 150))
    tile = tile.rotate(-24, expand=True, resample=Image.BICUBIC)
    lay = c.blank()
    lay.alpha_composite(tile, (w * SS - tile.width - 24 * SS, (h - 4) * SS // 2 - tile.height // 2))
    d = ImageDraw.Draw(lay)
    for x, y, s in ((w - 92, 44, 6), (w - 28, 124, 4), (w - 30, 36, 4)):
        x, y, s = x * SS, y * SS, s * SS
        d.polygon([(x, y - s * 2), (x + s * 0.5, y - s * 0.5), (x + s * 2, y), (x + s * 0.5, y + s * 0.5),
                   (x, y + s * 2), (x - s * 0.5, y + s * 0.5), (x - s * 2, y), (x - s * 0.5, y - s * 0.5)],
                  fill=(255, 230, 250, 170))
    c.layer(lay)


def metal(light, mid, dark):
    return [(0, hexc(light)), (0.45, hexc(mid)), (1, hexc(dark))]


# ------------------------------------------------------------------ tarjeta y placa

def card_frame():
    w, h, head = 1000, 940, 168
    c = Canvas(w, h)
    c.paint(c.rr((0, 0, w, h), 50), hexc("#1a0f07"))
    gold = [(0, hexc("#f6e3a6")), (0.18, hexc("#c9a35a")), (0.5, hexc("#a87a2e")), (0.82, hexc("#d8b56a")),
            (1, hexc("#8a6224"))]
    ring = c.rr((4, 4, w - 4, h - 4), 46)
    c.paint(ring, c.grad(gold, 4, h - 4))
    c.noise(ring, 0.03, streak=8)
    c.paint(c.rr((17, 17, w - 17, h - 17), 34), hexc("#3a2410"))
    c.paint(c.rr((20, 20, w - 20, h - 20), 31), hexc("#f0d58a"))
    inner = c.rr((24, 24, w - 24, h - 24), 28)
    c.paint(inner, c.grad([(0, hexc("#2c1d14")), (1, hexc("#22160f"))], 24, h - 24))
    c.noise(inner, 0.02, streak=12)
    # Cabecera de madera: vetas horizontales.
    hm = inner * (c.ys() < 24 + head)
    ys, xs = c.ys(), c.xs()
    grain = (np.sin(ys * 0.9 + np.sin(xs * 0.012) * 4) * 0.5 + 0.5) * 0.08
    wood = c.grad([(0, hexc("#7a5130")), (1, hexc("#4e321c"))], 24, 24 + head) - grain[..., None]
    c.paint(hm, wood)
    c.noise(hm, 0.06, streak=40)
    c.paint(hm * np.clip(1 - (ys - 24) / 30, 0, 1), np.ones(3), 0.18)
    # Moldura dorada bajo la cabecera.
    line = inner * ((ys >= 24 + head) & (ys < 24 + head + 6))
    c.paint(line, hexc("#d9b768"))
    c.paint(inner * ((ys >= 24 + head + 6) & (ys < 24 + head + 12)), np.zeros(3), 0.45)
    c.save("card_frame.png")


def plaque():
    w, h = 600, 116
    c = Canvas(w, h)
    c.paint(c.rr((0, 4, w, h), 28), np.zeros(3), 0.5)
    c.paint(c.rr((0, 0, w, h - 4), 28), hexc("#1c1c1c"))
    c.paint(c.rr((3, 3, w - 3, h - 7), 25), c.grad(metal("#f2f2f0", "#a9a9a6", "#6a6a68"), 3, h - 7))
    face = c.rr((10, 10, w - 10, h - 14), 18)
    c.paint(face, c.grad([(0, hexc("#9b978f")), (1, hexc("#5f5c57"))], 10, h - 14))
    c.noise(face, 0.05, streak=60)
    c.paint(face * np.clip(1 - (c.ys() - 10) / 40, 0, 1), np.ones(3), 0.18)
    for x in (34, w - 34):
        cy = (h - 4) / 2
        c.paint(c.ellipse((x - 11, cy - 9, x + 11, cy + 13)), np.zeros(3), 0.5)
        c.paint(c.ellipse((x - 10, cy - 10, x + 10, cy + 10)), c.grad(metal("#ffffff", "#b5b5b2", "#5a5a58"), cy - 10, cy + 10))
    c.save("plaque_meta.png")


def arrow(name, left):
    w, h = 88, 220
    c = Canvas(w, h)
    corners = (False, True, True, False) if left else (True, False, False, True)
    box = (-30, 0, w, h) if left else (0, 0, w + 30, h)
    c.paint(c.rr(box, 30, corners), hexc("#140d08"))
    b2 = (box[0] + 4, 4, box[2] - 4, h - 4)
    b3 = (box[0] + 11, 11, box[2] - 11, h - 11)
    if left:
        c.paint(c.rr(b2, 26), c.grad(metal("#fbe7a6", "#d2a24e", "#8e6322"), 4, h - 4))
        face = c.rr(b3, 19)
        c.paint(face, c.grad([(0, hexc("#f0cd7c")), (1, hexc("#b8873a"))], 11, h - 11))
        col = (58, 34, 12, 255)
    else:
        c.paint(c.rr(b2, 26), c.grad(metal("#ffffff", "#b9c2cc", "#6a7480"), 4, h - 4))
        face = c.rr(b3, 19)
        c.paint(face, c.grad([(0, hexc("#4b80cf")), (1, hexc("#1d3a78"))], 11, h - 11))
        col = (235, 242, 255, 255)
    c.paint(face * np.clip(1 - (c.ys() - 11) / 70, 0, 1), np.ones(3), 0.25)
    lay = c.blank()
    d = ImageDraw.Draw(lay)
    cx, cy, s = w / 2 * SS, h / 2 * SS, 22 * SS
    tip = -1 if left else 1
    pts = [(cx - tip * s * 0.5, cy - s), (cx + tip * s * 0.6, cy), (cx - tip * s * 0.5, cy + s)]
    d.line(pts, fill=col, width=9 * SS, joint="curve")
    c.layer(lay)
    c.save(name)


def level_badge():
    s = 128
    c = Canvas(s, s)
    c.paint(c.ellipse((0, 3, s, s)), np.zeros(3), 0.5)
    c.paint(c.ellipse((0, 0, s, s - 3)), hexc("#1e1209"))
    c.paint(c.ellipse((4, 4, s - 4, s - 7)), c.grad(metal("#f3d4a0", "#b0793f", "#6a4220"), 4, s - 7))
    face = c.ellipse((16, 16, s - 16, s - 19))
    c.paint(c.ellipse((14, 14, s - 14, s - 17)), hexc("#3a220f"))
    c.paint(face, c.grad([(0, hexc("#8f5e32")), (1, hexc("#4a2c14"))], 16, s - 19))
    c.paint(face * np.clip(1 - (c.ys() - 16) / 40, 0, 1), np.ones(3), 0.2)
    c.save("level_badge.png")


def xp_fill():
    """A tamaño real (9-slice horizontal): 40x18 con 9 de margen a cada lado."""
    w, h = 40, 18
    c = Canvas(w, h)
    m = c.rr((0, 0, w, h), 9)
    c.paint(m, c.grad([(0, hexc("#7ff59a")), (0.35, hexc("#4cd964")), (1, hexc("#2e8b57"))], 0, h))
    c.paint(m * (c.ys() < 6) * (c.ys() > 2), np.ones(3), 0.35)
    c.save("xp_fill.png")


def mini_tile():
    w, h = 40, 68
    c = Canvas(w, h)
    c.paint(c.rr((0, 0, w, h), 8), hexc("#2a2420"))
    c.paint(c.rr((3, 3, w - 3, h - 3), 6), c.grad([(0, hexc("#ffffff")), (1, hexc("#d9d2c4"))], 3, h - 3))
    c.paint(c.rr((8, h / 2 - 1.5, w - 8, h / 2 + 1.5), 1), hexc("#3a3430"))
    for x, y in ((13, 12), (27, 24), (20, 46)):
        c.paint(c.ellipse((x - 4, y - 4, x + 4, y + 4)), hexc("#1d1a18"))
    c.save("mini_tile.png")


# ------------------------------------------------------------------ moneda

def coin(ref):
    """Recorta la moneda de la barra de arriba de la referencia (arriba a la derecha)."""
    im = Image.open(ref).convert("RGB")
    W, H = im.size
    region = (int(W * 0.55), 0, int(W * 0.8), int(H * 0.09))
    arr = np.asarray(im.crop(region), float)
    r, g, b = arr[..., 0], arr[..., 1], arr[..., 2]
    gold = (r > 150) & (g > 100) & (b < 120) & (r - b > 70)
    ys, xs = np.nonzero(gold)
    x0, x1 = xs.min() + region[0], xs.max() + region[0] + 1
    y0, y1 = ys.min() + region[1], ys.max() + region[1] + 1
    pad = 2
    box = (x0 - pad, y0 - pad, x1 + pad, y1 + pad)
    big = 8
    crop = im.crop(box).resize(((box[2] - box[0]) * big, (box[3] - box[1]) * big), Image.LANCZOS).convert("RGBA")
    mask = Image.new("L", crop.size, 0)
    # Máscara elíptica (la moneda tiene canto abajo) un poco por dentro del borde dorado.
    inset = (pad + 0.6) * big
    ImageDraw.Draw(mask).ellipse((inset, inset, crop.size[0] - inset, crop.size[1] - inset), fill=255)
    crop.putalpha(mask)
    side = max(crop.size)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.alpha_composite(crop, ((side - crop.size[0]) // 2, (side - crop.size[1]) // 2))
    sq.resize((128, 128), Image.LANCZOS).save(os.path.join(OUT, "coin_domino.png"))
    print("   coin_domino.png desde", box)


def main():
    os.makedirs(OUT, exist_ok=True)
    if len(sys.argv) > 1:
        coin(sys.argv[1])
    button("btn_green_cpu.png", 580, 208, metal("#c9dcc0", "#7f9c78", "#3d5638"),
           [(0, hexc("#6a9168")), (1, hexc("#3f5c3f"))], icon=gear_icon)
    button("btn_blue_online.png", 580, 208, metal("#ffffff", "#b8c6d4", "#5d6e80"),
           [(0, hexc("#6b97c0")), (0.5, hexc("#466d8e")), (1, hexc("#2c4a66"))], gloss=True, icon=globe_icon)
    button("btn_silver_rules.png", 380, 176, metal("#ffffff", "#b3b6ba", "#5b5e62"),
           [(0, hexc("#9a9da0")), (1, hexc("#5f6265"))])
    button("btn_purple_custom.png", 380, 176, metal("#e7a6cf", "#a65a8a", "#5a2448"),
           [(0, hexc("#7a3c66")), (1, hexc("#45203b"))], icon=domino_icon)
    button("btn_dark_exit.png", 380, 176, metal("#b5aa9c", "#6e665c", "#38332e"),
           [(0, hexc("#48484a")), (1, hexc("#262628"))])
    card_frame()
    plaque()
    arrow("arrow_nav_left.png", True)
    arrow("arrow_nav_right.png", False)
    level_badge()
    xp_fill()
    mini_tile()


if __name__ == "__main__":
    main()
