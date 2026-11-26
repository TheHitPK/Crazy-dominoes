"""Genera la marca del estudio Catatumbo Games en marca_estudio/ (Python 3 + Pillow + numpy).

    python tools/generar_estudio.py

El estudio firma todos los juegos, no solo el dominó, así que la marca no
lleva fichas: es el relámpago del Catatumbo cayendo sobre el lago de
Maracaibo, con el puente en el horizonte.

- logo_512.png: icono del desarrollador en Google Play Console (512x512).
- logo_1080.png: foto de perfil para redes (Instagram, TikTok...).
- logo_transparente.png: rayo y nombre sobre fondo transparente (web, vídeos).
- banner_4096x2304.png: imagen de cabecera de la página del desarrollador en
  Google Play.
- firma.png: "Catatumbo Games" pequeño, para la pantalla de carga de cada
  juego (la usa tools/generar_marca.py).

marca_estudio/ lleva un .gdignore: Godot no importa esas imágenes ni las mete
en el juego.
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "marca_estudio")
BLACK = r"C:\Windows\Fonts\seguibl.ttf"
SEMI = r"C:\Windows\Fonts\seguisb.ttf"

SKY_TOP = (10, 10, 32)
SKY_MID = (46, 22, 78)
SKY_GLOW = (118, 58, 150)
LAKE = (8, 14, 30)
VIOLET = (178, 120, 255)
BOLT_TOP = (255, 255, 255)
BOLT_BOTTOM = (255, 214, 92)
OUTLINE = (20, 10, 40)

## Rayo de logo (polígono clásico), en una caja de 1x1.
BOLT = [(0.62, 0.00), (0.17, 0.57), (0.45, 0.57), (0.33, 1.00), (0.84, 0.39), (0.55, 0.39), (0.76, 0.00)]


def sky(w, h, horizon):
    """Cielo de noche que se aclara en violeta cerca del rayo, y lago oscuro debajo."""
    ys, xs = np.mgrid[0:h, 0:w].astype(float)
    t = np.clip(ys / max(horizon, 1), 0, 1)[..., None]
    col = np.array(SKY_TOP) * (1 - t) + np.array(SKY_MID) * t
    # Resplandor del rayo sobre el horizonte.
    d = np.sqrt(((xs - w * 0.5) / (w * 0.55)) ** 2 + ((ys - horizon * 0.62) / (h * 0.55)) ** 2)
    glow = np.clip(1 - d, 0, 1)[..., None] ** 2
    col = col + (np.array(SKY_GLOW) - col) * glow * 0.75
    lake_t = np.clip((ys - horizon) / max(h - horizon, 1), 0, 1)[..., None]
    lake = np.array(SKY_MID) * 0.55 * (1 - lake_t) + np.array(LAKE) * lake_t
    col = np.where(ys[..., None] >= horizon, lake, col)
    # Estrellas.
    rng = np.random.default_rng(7)
    img = Image.fromarray(np.concatenate([col, np.full((h, w, 1), 255.0)], axis=2).clip(0, 255).astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(img)
    for _ in range(int(w * h / 9000)):
        x, y = rng.uniform(0, w), rng.uniform(0, horizon * 0.8)
        r = rng.uniform(0.4, 1.4) * w / 1000
        a = int(rng.uniform(60, 200))
        d.ellipse((x - r, y - r, x + r, y + r), fill=(255, 255, 255, a))
    return img


def branches(size, origin, seed, count=5):
    """Ramas de relámpago finas y violetas detrás del rayo (dibujo libre)."""
    lay = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    rng = np.random.default_rng(seed)
    scale = size[0] / 1000

    def walk(p, ang, length, width, depth):
        pts = [p]
        steps = int(length / (14 * scale)) + 2
        for _ in range(steps):
            ang += rng.normal(0, 0.45)
            step = rng.uniform(10, 22) * scale
            p = (p[0] + math.cos(ang) * step, p[1] + math.sin(ang) * step)
            pts.append(p)
            if depth > 0 and rng.random() < 0.08:
                walk(p, ang + rng.choice([-1, 1]) * rng.uniform(0.4, 0.9), length * 0.45, width * 0.6, depth - 1)
        d.line(pts, fill=(226, 200, 255, 255), width=max(int(width), 1), joint="curve")

    for i in range(count):
        side = -1 if i % 2 == 0 else 1
        ang = math.pi / 2 + side * rng.uniform(0.7, 1.35)
        walk(origin[i % len(origin)], ang, rng.uniform(220, 380) * scale, 3.2 * scale, 2)
    glow = lay.filter(ImageFilter.GaussianBlur(9 * scale))
    tint = Image.new("RGBA", size, VIOLET + (0,))
    tint.putalpha(glow.getchannel("A"))
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    out.alpha_composite(tint)
    out.alpha_composite(tint)
    out.alpha_composite(lay)
    return out


def bolt(h, mono=False):
    """El rayo del logo: relleno blanco que pasa a amarillo, borde oscuro y halo violeta."""
    w = int(h * 0.62)
    pad = int(h * 0.22)
    W, H = w + pad * 2, h + pad * 2
    pts = [(pad + x * w, pad + y * h) for x, y in BOLT]
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    if mono:
        out.paste(Image.new("RGBA", (W, H), (255, 255, 255, 255)), (0, 0), mask)
        return out
    halo = mask.filter(ImageFilter.MaxFilter(int(h * 0.04) * 2 + 1)).filter(ImageFilter.GaussianBlur(h * 0.09))
    out.paste(Image.new("RGBA", (W, H), VIOLET + (255,)), (0, 0), halo)
    halo2 = mask.filter(ImageFilter.GaussianBlur(h * 0.03))
    out.alpha_composite(Image.merge("RGBA", (*Image.new("RGB", (W, H), (235, 215, 255)).split(), halo2)))
    edge = mask.filter(ImageFilter.MaxFilter(int(h * 0.025) * 2 + 1))
    out.paste(Image.new("RGBA", (W, H), OUTLINE + (255,)), (0, 0), edge)
    grad = np.clip((np.linspace(0, 1, H)[:, None, None] - 0.3) / 0.6, 0, 1)
    col = np.broadcast_to(np.array(BOLT_TOP) * (1 - grad) + np.array(BOLT_BOTTOM) * grad, (H, W, 3))
    fill = Image.fromarray(np.concatenate([col, np.full((H, W, 1), 255)], axis=2).astype(np.uint8), "RGBA")
    out.paste(fill, (0, 0), mask)
    # Brillo en la cara izquierda.
    shine = Image.new("L", (W, H), 0)
    sp = [pts[0], pts[1], (pts[1][0] + w * 0.09, pts[1][1] - h * 0.02), (pts[0][0] + w * 0.07, pts[0][1] + h * 0.02)]
    ImageDraw.Draw(shine).polygon(sp, fill=150)
    out.paste(Image.new("RGBA", (W, H), (255, 255, 255, 255)), (0, 0), shine.filter(ImageFilter.GaussianBlur(h * 0.006)))
    return out


def bridge(w, horizon, height, color=(6, 8, 20, 255)):
    """Silueta del puente sobre el lago: tablero largo, pilares y las torres atirantadas."""
    lay = Image.new("RGBA", (w, int(horizon) + 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    deck = horizon - height * 0.28
    th = max(height * 0.05, 1.5)
    d.rectangle((0, deck - th, w, deck), fill=color)
    n = 34
    for i in range(n + 1):
        x = i * w / n
        d.rectangle((x - th * 0.5, deck, x + th * 0.5, horizon), fill=color)
    # Las cinco torres centrales con sus tirantes.
    for k in range(5):
        cx = w * (0.3 + k * 0.1)
        top = deck - height * 0.72
        d.polygon([(cx - th * 1.4, deck), (cx - th * 0.4, top), (cx + th * 0.4, top), (cx + th * 1.4, deck)], fill=color)
        for s in (-1, 1):
            for j in range(1, 4):
                d.line([(cx, top + height * 0.08), (cx + s * w * 0.016 * j, deck)], fill=color, width=max(int(th * 0.45), 1))
    return lay


def reflect(base, layer, horizon, strength=0.4):
    """Reflejo del rayo en el lago: volteado, aplastado y con ondas."""
    part = layer.crop((0, 0, layer.width, int(horizon)))
    flip = part.transpose(Image.FLIP_TOP_BOTTOM)
    flip = flip.resize((flip.width, int(flip.height * 0.55)), Image.LANCZOS)
    arr = np.asarray(flip).copy()
    for y in range(arr.shape[0]):
        shift = int(math.sin(y * 0.18) * (2 + y * 0.03))
        arr[y] = np.roll(arr[y], shift, axis=0)
    fade = np.linspace(1, 0, arr.shape[0])[:, None] ** 1.5 * strength
    arr[..., 3] = (arr[..., 3] * fade).astype(np.uint8)
    img = Image.fromarray(arr, "RGBA").filter(ImageFilter.GaussianBlur(1.2))
    base.alpha_composite(img, (0, int(horizon)))


def text_img(text, font_path, size, fill, spacing=0, glow=None, outline=None):
    font = ImageFont.truetype(font_path, size)
    pad = int(size * 0.35)
    l, t, r, b = font.getbbox(text)
    w = int(sum(font.getlength(c) for c in text) + spacing * (len(text) - 1)) + pad * 2
    h = b - t + pad * 2
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    x = pad
    for c in text:
        d.text((x - l, pad - t), c, font=font, fill=255)
        x += font.getlength(c) + spacing
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    if glow:
        g = mask.filter(ImageFilter.GaussianBlur(size * 0.18))
        out.paste(Image.new("RGBA", (w, h), glow + (255,)), (0, 0), g)
    if outline:
        e = mask.filter(ImageFilter.MaxFilter(int(size * 0.06) * 2 + 1))
        out.paste(Image.new("RGBA", (w, h), outline + (255,)), (0, 0), e)
    out.paste(Image.new("RGBA", (w, h), fill + (255,)), (0, 0), mask)
    return out.crop(out.getbbox())


def wordmark(height, games_color=BOLT_BOTTOM):
    """"CATATUMBO" grande y "GAMES" espaciado debajo."""
    top = text_img("CATATUMBO", BLACK, height, (255, 255, 255), spacing=int(height * 0.02), glow=VIOLET,
                   outline=OUTLINE)
    games = text_img("GAMES", SEMI, int(height * 0.42), games_color, spacing=int(height * 0.38), outline=OUTLINE)
    w = max(top.width, games.width)
    out = Image.new("RGBA", (w, top.height + games.height + int(height * 0.02)), (0, 0, 0, 0))
    out.alpha_composite(top, ((w - top.width) // 2, 0))
    out.alpha_composite(games, ((w - games.width) // 2, top.height + int(height * 0.02)))
    return out


def scene(w, h, horizon, bolt_h, bolt_center, with_bridge=True):
    img = sky(w, h, horizon)
    s = min(w, h)
    b = bolt(int(bolt_h))
    bx = int(bolt_center[0] - b.width / 2)
    by = int(horizon - b.height + b.height * 0.17)
    tip = (bolt_center[0], horizon)
    sky_layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    org = [(bx + b.width * 0.5, by + b.height * 0.35), (bx + b.width * 0.42, by + b.height * 0.55),
           (bx + b.width * 0.56, by + b.height * 0.25)]
    sky_layer.alpha_composite(branches((w, h), org, seed=11, count=6))
    sky_layer.alpha_composite(b, (bx, by))
    img.alpha_composite(sky_layer)
    # Destello donde el rayo toca el agua.
    flash = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    r = s * 0.09
    ImageDraw.Draw(flash).ellipse((tip[0] - r * 2.2, tip[1] - r * 0.5, tip[0] + r * 2.2, tip[1] + r * 0.5),
                                  fill=(230, 210, 255, 160))
    img.alpha_composite(flash.filter(ImageFilter.GaussianBlur(r * 0.5)))
    reflect(img, sky_layer, horizon)
    if with_bridge:
        img.alpha_composite(bridge(w, horizon, s * 0.09), (0, 0))
    return img


def logo_square(size):
    horizon = size * 0.74
    img = scene(size, size, horizon, size * 0.62, (size * 0.5, 0))
    return img.convert("RGB")


def banner():
    w, h = 4096, 2304
    horizon = h * 0.72
    img = scene(w, h, horizon, h * 0.56, (w * 0.18, 0))
    wm = wordmark(310)
    cx = w * 0.64
    img.alpha_composite(wm, (int(cx - wm.width / 2), int(horizon * 0.46 - wm.height / 2)))
    tag = text_img("Juegos hechos en Maracaibo", SEMI, 96, (225, 210, 245), outline=OUTLINE)
    img.alpha_composite(tag, (int(cx - tag.width / 2), int(horizon * 0.46 + wm.height / 2 + 60)))
    return img.convert("RGB")


def logo_transparent():
    b = bolt(900)
    wm = wordmark(300)
    w = b.width + wm.width
    h = max(b.height, wm.height)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.alpha_composite(b, (0, (h - b.height) // 2))
    out.alpha_composite(wm, (int(b.width * 0.82), (h - wm.height) // 2))
    return out.crop(out.getbbox())


def firma(height=64):
    """Firma pequeña: rayo + "CATATUMBO GAMES" en una línea, fondo transparente."""
    b = bolt(int(height * 1.5))
    t = text_img("CATATUMBO GAMES", SEMI, height, (235, 225, 250), spacing=int(height * 0.12), outline=OUTLINE)
    w = int(b.width * 0.86) + t.width
    h = max(b.height, t.height)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.alpha_composite(b, (0, (h - b.height) // 2))
    out.alpha_composite(t, (int(b.width * 0.86), (h - t.height) // 2))
    return out.crop(out.getbbox())


def intro_layers(w=1080, h=1920):
    """Capas de la animación de entrada del juego (scripts/intro.gd), todas del
    mismo tamaño para montarlas una encima de otra:
    fondo (cielo, lago y puente, sin rayo: también es la pantalla de arranque),
    rayo, ramas, reflejo en el lago y el nombre del estudio aparte."""
    horizon = h * 0.6
    s = w
    b = bolt(int(h * 0.36))
    bx = int(w * 0.5 - b.width / 2)
    by = int(horizon - b.height + b.height * 0.17)
    tip = (w * 0.5, horizon)

    bg = sky(w, h, horizon)
    bg.alpha_composite(bridge(w, horizon, s * 0.09), (0, 0))

    rayo = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    rayo.alpha_composite(b, (bx, by))
    flash = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    r = s * 0.09
    ImageDraw.Draw(flash).ellipse((tip[0] - r * 2.2, tip[1] - r * 0.5, tip[0] + r * 2.2, tip[1] + r * 0.5),
                                  fill=(230, 210, 255, 170))
    rayo.alpha_composite(flash.filter(ImageFilter.GaussianBlur(r * 0.5)))

    org = [(bx + b.width * 0.5, by + b.height * 0.35), (bx + b.width * 0.42, by + b.height * 0.55),
           (bx + b.width * 0.56, by + b.height * 0.25)]
    ramas = branches((w, h), org, seed=11, count=7)

    both = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    both.alpha_composite(ramas)
    both.alpha_composite(rayo)
    reflejo = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    reflect(reflejo, both, horizon, strength=0.5)

    nombre = wordmark(150)
    return {"intro_fondo": bg.convert("RGB"), "intro_rayo": rayo, "intro_ramas": ramas,
            "intro_reflejo": reflejo, "intro_nombre": nombre}


def main():
    brand = os.path.join(ROOT, "assets", "brand")
    for name, img in intro_layers().items():
        img.save(os.path.join(brand, name + ".png"))
    os.makedirs(OUT, exist_ok=True)
    open(os.path.join(OUT, ".gdignore"), "w").close()
    big = logo_square(1080)
    big.save(os.path.join(OUT, "logo_1080.png"))
    big.resize((512, 512), Image.LANCZOS).save(os.path.join(OUT, "logo_512.png"))
    logo_transparent().save(os.path.join(OUT, "logo_transparente.png"))
    banner().save(os.path.join(OUT, "banner_4096x2304.png"))
    firma().save(os.path.join(OUT, "firma.png"))
    print("marca del estudio generada en", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
