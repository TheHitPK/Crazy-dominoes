"""Genera la marca de Crazy Dominoes en assets/brand/ (Python 3 + Pillow + numpy).

    python tools/generar_marca.py

- icon.png (1024): icono de la app (proyecto, web e iOS).
- icon_192.png: icono clásico de Android.
- adaptive_fg.png / adaptive_bg.png / adaptive_mono.png (432): icono adaptable
  de Android 8+ (el sistema lo recorta en círculo, gota o cuadrado, así que el
  dibujo va dentro de la zona segura: el 61 % central).
- splash.png (1080x1920): pantalla al abrir la app, en lugar del logo de Godot.

Los colores son los del menú: madera oscura, oro y fichas de marfil.
Las letras usan Segoe UI Black de Windows (solo para rasterizar la imagen;
la fuente no se incluye en el juego).
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "brand")
FONT = r"C:\Windows\Fonts\seguibl.ttf"
SS = 2

GOLD_TOP = (246, 211, 115)
GOLD_BOTTOM = (200, 146, 54)
OUTLINE = (43, 26, 14)
PIPS = {
    0: [], 1: [(0, 0)], 2: [(-1, -1), (1, 1)], 3: [(-1, -1), (0, 0), (1, 1)],
    4: [(-1, -1), (1, -1), (-1, 1), (1, 1)], 5: [(-1, -1), (1, -1), (0, 0), (-1, 1), (1, 1)],
    6: [(-1, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (1, 1)],
}


def radial_bg(w, h, inner, outer, center=(0.5, 0.42), grain=True):
    ys, xs = np.mgrid[0:h, 0:w]
    cx, cy = center[0] * w, center[1] * h
    d = np.sqrt(((xs - cx) / w) ** 2 + ((ys - cy) / h) ** 2) / 0.62
    d = np.clip(d, 0, 1)[..., None] ** 1.3
    img = np.array(inner) * (1 - d) + np.array(outer) * d
    if grain:
        # Vetas verticales de madera, suaves.
        rng = np.random.default_rng(3)
        streak = rng.normal(0, 1, (1, w // 6 + 1))
        streak = np.asarray(Image.fromarray(((streak * 30) + 128).clip(0, 255).astype(np.uint8)).resize((w, h), Image.BICUBIC), float)
        wave = np.sin(xs * 0.045 + np.sin(ys * 0.004) * 3) * 6
        img += ((streak - 128) / 30 * 7 + wave)[..., None] * np.array([1.0, 0.8, 0.6])
    a = np.full((h, w, 1), 255.0)
    return Image.fromarray(np.concatenate([img, a], axis=2).clip(0, 255).astype(np.uint8), "RGBA")


def tile(top, bottom, w, mono=False):
    """Ficha de dominó vertical de ancho w (alto 2w), con sombra aparte."""
    h = w * 2
    s = SS
    img = Image.new("RGBA", (w * s, h * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = int(w * 0.16 * s)
    if mono:
        d.rounded_rectangle((0, 0, w * s - 1, h * s - 1), radius=r, fill=(255, 255, 255, 255))
        hole = (0, 0, 0, 0)
    else:
        d.rounded_rectangle((0, 0, w * s - 1, h * s - 1), radius=r, fill=(42, 36, 32, 255))
        # Cara de marfil con degradado.
        face = Image.new("RGBA", img.size, (0, 0, 0, 0))
        grad = np.linspace(0, 1, h * s)[:, None, None]
        col = np.array([255, 252, 242]) * (1 - grad) + np.array([224, 214, 196]) * grad
        col = np.broadcast_to(col, (h * s, w * s, 3))
        face = Image.fromarray(np.concatenate([col, np.full((h * s, w * s, 1), 255)], axis=2).astype(np.uint8), "RGBA")
        m = Image.new("L", img.size, 0)
        b = int(w * 0.045 * s)
        ImageDraw.Draw(m).rounded_rectangle((b, b, w * s - 1 - b, h * s - 1 - b), radius=r - b, fill=255)
        img.paste(face, (0, 0), m)
        hole = (29, 26, 24, 255)
    # Raya del medio y pasador dorado.
    lw = max(int(w * 0.035 * s), 2)
    d.line((w * 0.14 * s, h * 0.5 * s, w * 0.86 * s, h * 0.5 * s), fill=hole, width=lw)
    if not mono:
        pr = w * 0.07 * s
        d.ellipse((w * 0.5 * s - pr, h * 0.5 * s - pr, w * 0.5 * s + pr, h * 0.5 * s + pr), fill=(214, 168, 70, 255),
                  outline=(140, 98, 30, 255), width=max(lw // 2, 1))
    for half, value in ((0, top), (1, bottom)):
        cy = (h * 0.25 + half * h * 0.5) * s
        for px, py in PIPS[value]:
            x = w * 0.5 * s + px * w * 0.25 * s
            y = cy + py * w * 0.25 * s
            pr = w * 0.085 * s
            d.ellipse((x - pr, y - pr, x + pr, y + pr), fill=hole)
    return img.resize((w, h), Image.LANCZOS)


def paste_rotated(base, img, center, angle, shadow=True):
    rot = img.rotate(angle, expand=True, resample=Image.BICUBIC)
    x = int(center[0] - rot.width / 2)
    y = int(center[1] - rot.height / 2)
    if shadow:
        sh = Image.new("RGBA", rot.size, (0, 0, 0, 0))
        sh.putalpha(rot.getchannel("A").point(lambda a: a * 0.55))
        sh = sh.filter(ImageFilter.GaussianBlur(rot.width * 0.03))
        off = int(rot.width * 0.04)
        base.alpha_composite(sh, (x + off // 2, y + off))
    base.alpha_composite(rot, (x, y))


def sparkle(base, center, size, color=(255, 236, 170, 255)):
    lay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    x, y, s = center[0], center[1], size
    d.polygon([(x, y - s), (x + s * 0.22, y - s * 0.22), (x + s, y), (x + s * 0.22, y + s * 0.22),
               (x, y + s), (x - s * 0.22, y + s * 0.22), (x - s, y), (x - s * 0.22, y - s * 0.22)], fill=color)
    glow = lay.filter(ImageFilter.GaussianBlur(s * 0.25))
    base.alpha_composite(glow)
    base.alpha_composite(lay)


def emblem(size, mono=False):
    """Las dos fichas cruzadas con destellos: el dibujo central de la marca."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    w = int(size * 0.3)
    paste_rotated(img, tile(5, 3, w, mono), (size * 0.6, size * 0.5), -24, shadow=not mono)
    paste_rotated(img, tile(6, 6, w, mono), (size * 0.4, size * 0.5), 18, shadow=not mono)
    if not mono:
        sparkle(img, (size * 0.83, size * 0.2), size * 0.07)
        sparkle(img, (size * 0.16, size * 0.8), size * 0.045)
        sparkle(img, (size * 0.86, size * 0.78), size * 0.03)
    return img


def gold_ring(base, center, radius, width):
    lay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    x, y = center
    d.ellipse((x - radius - width, y - radius - width, x + radius + width, y + radius + width), fill=(26, 15, 7, 255))
    d.ellipse((x - radius, y - radius, x + radius, y + radius), fill=(214, 172, 86, 255))
    d.ellipse((x - radius + width * 0.35, y - radius + width * 0.35, x + radius - width * 0.35, y + radius - width * 0.35),
              fill=(246, 222, 150, 255))
    d.ellipse((x - radius + width * 0.6, y - radius + width * 0.6, x + radius - width * 0.6, y + radius - width * 0.6),
              fill=(0, 0, 0, 0))
    base.alpha_composite(lay)


def icon(size):
    bg = radial_bg(size, size, (122, 74, 38), (34, 19, 9))
    gold_ring(bg, (size / 2, size / 2), size * 0.44, size * 0.035)
    bg.alpha_composite(emblem(int(size * 0.86)), (int(size * 0.07), int(size * 0.07)))
    # Esquinas redondeadas como un icono de tienda.
    m = Image.new("L", (size * 2, size * 2), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size * 2 - 1, size * 2 - 1), radius=int(size * 0.22 * 2), fill=255)
    bg.putalpha(m.resize((size, size), Image.LANCZOS))
    return bg


def gold_text(text, font_size, spacing=6):
    font = ImageFont.truetype(FONT, font_size)
    pad = int(font_size * 0.25)
    l, t, r, b = font.getbbox(text)
    w = r - l + pad * 2 + spacing * len(text)
    h = b - t + pad * 2
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    x = pad
    for ch in text:
        d.text((x - l, pad - t), ch, font=font, fill=255)
        x += font.getlength(ch) + spacing
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    outline = mask.filter(ImageFilter.MaxFilter(int(font_size * 0.09) * 2 + 1))
    shadow = outline.filter(ImageFilter.GaussianBlur(font_size * 0.05))
    out.paste(Image.new("RGBA", (w, h), (0, 0, 0, 160)), (0, int(font_size * 0.07)), shadow)
    out.paste(Image.new("RGBA", (w, h), OUTLINE + (255,)), (0, 0), outline)
    grad = np.linspace(0, 1, h)[:, None, None]
    grad = np.clip((grad - 0.25) / 0.6, 0, 1)
    col = np.array(GOLD_TOP) * (1 - grad) + np.array(GOLD_BOTTOM) * grad
    col = np.broadcast_to(col, (h, w, 3))
    fill = Image.fromarray(np.concatenate([col, np.full((h, w, 1), 255)], axis=2).astype(np.uint8), "RGBA")
    out.paste(fill, (0, 0), mask)
    return out


def splash():
    w, h = 1080, 1920
    bg = radial_bg(w, h, (110, 66, 33), (24, 13, 6), center=(0.5, 0.4))
    em = emblem(620)
    bg.alpha_composite(em, ((w - 620) // 2, 430))
    for i, word in enumerate(("CRAZY", "DOMINOES")):
        t = gold_text(word, 150)
        bg.alpha_composite(t, ((w - t.width) // 2, 1060 + i * 170))
    # Firma del estudio abajo (la dibuja generar_estudio.py).
    from generar_estudio import firma
    f = firma(40)
    bg.alpha_composite(f, ((w - f.width) // 2, h - 150 - f.height))
    return bg.convert("RGB")


def main():
    os.makedirs(OUT, exist_ok=True)
    big = icon(1024)
    big.save(os.path.join(OUT, "icon.png"))
    big.resize((192, 192), Image.LANCZOS).save(os.path.join(OUT, "icon_192.png"))
    # Adaptable: fondo de madera entero y el dibujo dentro de la zona segura.
    radial_bg(432, 432, (122, 74, 38), (34, 19, 9)).save(os.path.join(OUT, "adaptive_bg.png"))
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    fg.alpha_composite(emblem(290), (71, 71))
    fg.save(os.path.join(OUT, "adaptive_fg.png"))
    mono = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    mono.alpha_composite(emblem(290, mono=True), (71, 71))
    mono.save(os.path.join(OUT, "adaptive_mono.png"))
    splash().save(os.path.join(OUT, "splash.png"))
    print("marca generada en", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
