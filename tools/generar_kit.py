"""Genera el kit de interfaz común de toda la app en assets/ui/kit_*.png.

    python tools/generar_kit.py
    godot --headless --path . --import

Son piezas 9-slice que se estiran a cualquier tamaño (la guía de uso está en
DISEÑO.md y el código que las monta en scripts/ui_skin.gd):

  kit_panel       Marco de panel: borde dorado con adornos en las esquinas.
  kit_btn_body    Cara del botón en grises: se tiñe con el color del botón.
  kit_btn_frame   Aro dorado, brillo y sombra del botón (no se tiñe).
  kit_field       Campo hundido para valores y textos (a tamaño real).
  kit_orb_gloss   Brillo de los círculos de color.
  kit_orb_ring    Aro dorado del círculo elegido.
  kit_chev_l/r    Flechas doradas de los selectores.
  kit_icon_*      Iconos crema con sombra (96x96, 48 en pantalla).

Salvo kit_field, van al doble de tamaño y el juego las monta con un
NinePatchRect a escala 0,5 (UISkin.nine), para que las esquinas salgan nítidas
en teléfonos de 1080 o más de ancho sin verse al doble de grandes.
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from generar_ui import OUT, SS, Canvas, hexc, metal  # noqa: E402

GOLD = [(0, hexc("#fff0b8")), (0.2, hexc("#e2bd62")), (0.5, hexc("#b8862e")), (0.8, hexc("#e6c477")),
        (1, hexc("#8a6224"))]


# ------------------------------------------------------------------ panel

def panel():
    """240x240, márgenes 9-slice de 72 (36 en pantalla)."""
    s = 240
    c = Canvas(s, s)
    c.paint(c.rr((0, 0, s, s), 44), hexc("#120904"))
    ring = c.rr((5, 5, s - 5, s - 5), 40)
    c.paint(ring, c.grad(GOLD, 5, s - 5))
    c.noise(ring, 0.03, streak=6)
    c.paint(c.rr((15, 15, s - 15, s - 15), 30), hexc("#2a170a"))
    c.paint(c.rr((18, 18, s - 18, s - 18), 27), hexc("#d9b468"))
    inner = c.rr((21, 21, s - 21, s - 21), 24)
    # Fondo casi plano y de un marrón medio: con uno más oscuro y con grano los
    # paneles se veían sucios. Solo una sombra fina bajo el marco.
    c.paint(inner, c.grad([(0, hexc("#6a4528")), (1, hexc("#5e3c22"))], 21, s - 21))
    ys, xs = c.ys(), c.xs()
    edge = np.minimum(np.minimum(ys - 21, s - 21 - ys), np.minimum(xs - 21, s - 21 - xs))
    c.paint(inner * np.clip(1 - edge / 8, 0, 1), np.zeros(3), 0.3)

    # Adorno de una esquina; las otras tres son su reflejo.
    k = 4 * SS  # el adorno se dibuja a 4x sobre el sobremuestreo para suavizarlo
    big = 76
    orn = Image.new("RGBA", (big * k, big * k), (0, 0, 0, 0))
    d = ImageDraw.Draw(orn)

    def p(x, y):
        return (x * k, y * k)

    def scroll(d, fill, w):
        # Voluta: arco que abraza la esquina y termina en dos rizos.
        d.arc((p(10, 10), p(58, 58)), 180, 270, fill=fill, width=w)
        d.line((p(34, 10), p(66, 10)), fill=fill, width=w)
        d.line((p(10, 34), p(10, 66)), fill=fill, width=w)
        for cx, cy in ((66, 15), (15, 66)):
            d.arc((p(cx - 5, cy - 5), p(cx + 5, cy + 5)), 0, 300, fill=fill, width=w)
        # Hoja en la diagonal y dos puntos.
        d.polygon([p(20, 20), p(33, 25), p(40, 40), p(25, 33)], fill=fill)
        for cx, cy in ((46, 22), (22, 46)):
            d.ellipse((p(cx - 3, cy - 3), p(cx + 3, cy + 3)), fill=fill)

    shadow = Image.new("RGBA", orn.size, (0, 0, 0, 0))
    scroll(ImageDraw.Draw(shadow), (10, 5, 0, 200), 6 * k)
    orn.alpha_composite(shadow, (k, 2 * k))
    scroll(d, (255, 255, 255, 255), 4 * k)
    # Tiñe de oro con brillo arriba a la izquierda.
    arr = np.asarray(orn, float)
    yy, xx = np.mgrid[0:orn.size[1], 0:orn.size[0]] / k
    t = np.clip((xx + yy) / 110, 0, 1)[..., None]
    gold = hexc("#fff1bd") * (1 - t) + hexc("#b07f2c") * t
    white = arr[..., 3:4] / 255 * (arr[..., 0:1] > 128)
    arr[..., :3] = np.where(white > 0, gold * 255, arr[..., :3])
    orn = Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGBA").resize((big * SS, big * SS), Image.LANCZOS)

    lay = c.blank()
    for fx in (False, True):
        for fy in (False, True):
            o = orn
            if fx:
                o = o.transpose(Image.FLIP_LEFT_RIGHT)
            if fy:
                o = o.transpose(Image.FLIP_TOP_BOTTOM)
            lay.alpha_composite(o, ((s - big) * SS if fx else 0, (s - big) * SS if fy else 0))
    c.layer(lay)
    c.save("kit_panel.png")


# ------------------------------------------------------------------ botón

BW, BH, BR = 256, 176, 36


def btn_body():
    """Cara en grises (blanco arriba, gris abajo): el juego la tiñe con modulate."""
    c = Canvas(BW, BH)
    face = c.rr((12, 12, BW - 12, BH - 20), BR - 12)
    c.paint(face, c.grad([(0, np.ones(3)), (0.55, np.ones(3) * 0.9), (1, np.ones(3) * 0.74)], 12, BH - 20))
    c.noise(face, 0.02)
    c.save("kit_btn_body.png")


def btn_frame():
    """Lo que no se tiñe: sombra, contorno, aro dorado y brillo de cristal."""
    c = Canvas(BW, BH)
    c.paint(c.rr((2, 8, BW - 2, BH), BR), np.zeros(3), 0.5)
    outer = c.rr((0, 0, BW, BH - 6), BR)
    face = c.rr((12, 12, BW - 12, BH - 20), BR - 12)
    c.paint(outer * (1 - face), hexc("#160b04"))
    ring = c.rr((4, 4, BW - 4, BH - 10), BR - 4) * (1 - c.rr((11, 11, BW - 11, BH - 19), BR - 11))
    c.paint(ring, c.grad(GOLD, 4, BH - 10))
    ys = c.ys()
    # Brillo de cristal en la mitad de arriba, con corte suave.
    mid = 12 + (BH - 32) * 0.5
    band = np.clip((mid - ys) / 6, 0, 1) * np.clip(1 - (ys - 12) / (mid - 12) * 0.6, 0, 1)
    c.paint(face * band, np.ones(3), 0.36)
    c.paint(face * np.clip((ys - (BH - 44)) / 24, 0, 1), np.zeros(3), 0.16)
    c.paint(face - c.rr((12, 15, BW - 12, BH - 20), BR - 12), np.ones(3), 0.55)
    c.save("kit_btn_frame.png")


# ------------------------------------------------------------------ campo, círculos y flechas

def field():
    """A tamaño real: 48x48, márgenes 16."""
    s = 48
    c = Canvas(s, s)
    c.paint(c.rr((0, 0, s, s), 14), hexc("#4a2f1a"))
    inner = c.rr((2, 2, s - 2, s - 2), 12)
    c.paint(inner, c.grad([(0, hexc("#140b05")), (1, hexc("#22140b"))], 2, s - 2))
    c.paint(inner * np.clip(1 - (c.ys() - 2) / 8, 0, 1), np.zeros(3), 0.6)
    c.paint(c.rr((2, s - 3, s - 2, s - 1), 1), hexc("#e2bd62"), 0.35)
    c.save("kit_field.png")


def orb_gloss():
    s = 132
    c = Canvas(s, s)
    disc = c.ellipse((4, 4, s - 4, s - 4))
    ys, xs = c.ys(), c.xs()
    r = np.hypot(xs - s / 2, ys - s / 2) / (s / 2 - 4)
    c.paint(disc * np.clip((r - 0.55) / 0.45, 0, 1) ** 1.5, np.zeros(3), 0.55)
    c.paint(disc * np.clip((ys - s * 0.55) / (s * 0.45), 0, 1), np.zeros(3), 0.25)
    spec = c.ellipse((s * 0.24, s * 0.12, s * 0.62, s * 0.4))
    c.paint(spec * np.clip(1 - (ys - s * 0.12) / (s * 0.3), 0, 1), np.ones(3), 0.75)
    ring = disc - c.ellipse((7, 7, s - 7, s - 7))
    c.paint(ring, hexc("#140a04"), 0.8)
    c.save("kit_orb_gloss.png")


def orb_ring():
    s = 156
    c = Canvas(s, s)
    ys, xs = c.ys(), c.xs()
    r = np.hypot(xs - s / 2, ys - s / 2)
    c.paint(np.clip(1 - np.abs(r - 70) / 9, 0, 1), hexc("#ffe08a"), 0.5)  # resplandor
    ring = c.ellipse((6, 6, s - 6, s - 6)) - c.ellipse((13, 13, s - 13, s - 13))
    c.paint(ring, c.grad(GOLD, 6, s - 6))
    c.save("kit_orb_ring.png")


def chevron(name, left):
    s = 64
    c = Canvas(s, s)
    lay = c.blank()
    d = ImageDraw.Draw(lay)
    tip = -1 if left else 1
    cx, cy, h = s / 2 * SS, s / 2 * SS, 18 * SS
    pts = [(cx - tip * h * 0.55, cy - h), (cx + tip * h * 0.55, cy), (cx - tip * h * 0.55, cy + h)]
    d.line([(x, y + 3 * SS) for x, y in pts], fill=(25, 12, 2, 200), width=15 * SS, joint="curve")
    d.line(pts, fill=(255, 255, 255, 255), width=11 * SS, joint="curve")
    arr = np.asarray(lay, float) / 255
    white = (arr[..., 0] > 0.5)[..., None]
    gold = c.grad([(0, hexc("#fff3c4")), (0.5, hexc("#f2c75a")), (1, hexc("#b9801f"))], s / 2 - 18, s / 2 + 18)
    rgb = np.where(white, gold, arr[..., :3])
    c.paint(arr[..., 3], rgb)
    c.save(name)


# ------------------------------------------------------------------ iconos

IK = 384  # se dibujan a 384 y se reducen a 96 (48 en pantalla) para suavizar


def _icon(name, draw):
    """Icono crema con sombra oscura. `draw(d)` pinta en blanco sobre un lienzo de IK."""
    mask = Image.new("L", (IK, IK), 0)
    draw(ImageDraw.Draw(mask))
    out = Image.new("RGBA", (IK, IK), (0, 0, 0, 0))
    shadow = Image.new("RGBA", (IK, IK), (30, 14, 4, 0))
    shadow.putalpha(mask.point(lambda v: v * 0.75))
    out.alpha_composite(shadow, (0, 12))
    # Relleno con un degradado vertical suave de crema a dorado claro.
    grad = Image.new("RGBA", (IK, IK))
    gp = grad.load()
    for y in range(IK):
        t = y / IK
        col = (255, int(250 - 30 * t), int(232 - 90 * t), 255)
        for x in range(IK):
            gp[x, y] = col
    grad.putalpha(mask)
    out.alpha_composite(grad)
    out.resize((96, 96), Image.LANCZOS).save(os.path.join(OUT, "kit_icon_%s.png" % name))
    print("   kit_icon_%s.png" % name)


def _ring(d, box, w):
    d.ellipse(box, outline=255, width=w)


def icon_cpu(d):
    # Cabeza de robot: la CPU.
    d.rounded_rectangle((70, 110, 314, 300), radius=48, fill=255)
    d.rectangle((182, 50, 202, 110), fill=255)
    d.ellipse((168, 30, 216, 78), fill=255)
    d.rounded_rectangle((40, 170, 70, 240), radius=12, fill=255)
    d.rounded_rectangle((314, 170, 344, 240), radius=12, fill=255)
    for cx in (140, 244):
        d.ellipse((cx - 30, 160, cx + 30, 220), fill=0)
    d.rounded_rectangle((130, 246, 254, 270), radius=10, fill=0)


def icon_globe(d):
    _ring(d, (50, 50, 334, 334), 26)
    d.ellipse((132, 50, 252, 334), outline=255, width=22)
    d.line((192, 50, 192, 334), fill=255, width=22)
    for y, half in ((120, 125), (192, 142), (264, 125)):
        d.line((192 - half, y, 192 + half, y), fill=255, width=22)


def icon_book(d):
    # Libro abierto.
    d.polygon([(192, 110), (40, 80), (40, 300), (192, 330)], fill=255)
    d.polygon([(192, 110), (344, 80), (344, 300), (192, 330)], fill=255)
    d.line((192, 110, 192, 330), fill=0, width=14)
    for k in range(3):
        y = 150 + k * 48
        d.line((76, y - 6, 166, y + 12), fill=0, width=12)
        d.line((218, y + 12, 308, y - 6), fill=0, width=12)


def icon_exit(d):
    # Puerta con flecha saliendo.
    d.rounded_rectangle((60, 50, 220, 334), radius=14, outline=255, width=26)
    d.ellipse((168, 182, 194, 208), fill=255)
    d.line((170, 192, 320, 192), fill=255, width=34)
    d.polygon([(358, 192), (290, 124), (290, 260)], fill=255)


def icon_brush(d):
    # Pincel en diagonal con una gota de pintura: personalizar.
    d.polygon([(250, 60), (320, 130), (170, 280), (100, 210)], fill=255)
    d.polygon([(100, 210), (170, 280), (110, 340), (40, 340), (40, 270)], fill=255)
    d.line((250, 60, 100, 210), fill=0, width=10)


def icon_cart(d):
    d.line((30, 70, 90, 70, 130, 250, 310, 250), fill=255, width=28, joint="curve")
    d.polygon([(100, 110), (350, 110), (320, 220), (124, 220)], fill=255)
    for cx in (150, 290):
        d.ellipse((cx - 30, 270, cx + 30, 330), fill=255)


def icon_trophy(d):
    d.pieslice((90, -40, 294, 230), 0, 180, fill=255)
    d.rectangle((90, 40, 294, 96), fill=255)
    _ring(d, (30, 60, 140, 180), 22)
    _ring(d, (244, 60, 354, 180), 22)
    d.rectangle((170, 220, 214, 290), fill=255)
    d.rounded_rectangle((110, 286, 274, 340), radius=12, fill=255)


def icon_shield(d):
    # Escudo con estrella: ranked.
    d.polygon([(192, 30), (340, 80), (320, 230), (192, 350), (64, 230), (44, 80)], fill=255)
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = 92 if i % 2 == 0 else 40
        pts.append((192 + math.cos(a) * r, 180 + math.sin(a) * r))
    d.polygon(pts, fill=0)


def icon_calendar(d):
    d.rounded_rectangle((40, 70, 344, 340), radius=30, fill=255)
    d.rectangle((40, 150, 344, 160), fill=0)
    for x in (110, 274):
        d.rounded_rectangle((x - 16, 36, x + 16, 110), radius=12, fill=255)
    # Estrella dentro: el desafío del día.
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = 70 if i % 2 == 0 else 30
        pts.append((192 + math.cos(a) * r, 252 + math.sin(a) * r))
    d.polygon(pts, fill=0)


def icon_chart(d):
    for i, h in enumerate((120, 200, 280)):
        x = 60 + i * 100
        d.rounded_rectangle((x, 340 - h, x + 72, 340), radius=12, fill=255)


def icon_bulb(d):
    d.ellipse((92, 30, 292, 230), fill=255)
    d.polygon([(130, 200), (254, 200), (234, 270), (150, 270)], fill=255)
    d.rounded_rectangle((146, 282, 238, 306), radius=10, fill=255)
    d.rounded_rectangle((160, 318, 224, 342), radius=10, fill=255)


def icon_share(d):
    # Globo de mensaje con flecha: invitar.
    d.rounded_rectangle((30, 50, 354, 270), radius=60, fill=255)
    d.polygon([(90, 250), (70, 350), (170, 262)], fill=255)
    d.line((120, 160, 250, 160), fill=0, width=26)
    d.polygon([(290, 160), (230, 104), (230, 216)], fill=0)


def icon_video(d):
    # Pantalla con "play": ver anuncio.
    d.rounded_rectangle((30, 70, 354, 314), radius=40, fill=255)
    d.polygon([(150, 130), (150, 254), (260, 192)], fill=0)


def icon_smile(d):
    d.ellipse((40, 40, 344, 344), fill=255)
    for cx in (140, 244):
        d.ellipse((cx - 22, 130, cx + 22, 182), fill=0)
    d.arc((110, 150, 274, 290), 20, 160, fill=0, width=24)


def icon_bolt(d):
    d.polygon([(220, 20), (70, 220), (180, 220), (150, 364), (314, 150), (200, 150)], fill=255)


def icon_gift(d):
    d.rounded_rectangle((50, 150, 334, 340), radius=18, fill=255)
    d.rounded_rectangle((30, 100, 354, 170), radius=18, fill=255)
    d.rectangle((172, 100, 212, 340), fill=0)
    d.ellipse((100, 30, 190, 110), outline=255, width=24)
    d.ellipse((194, 30, 284, 110), outline=255, width=24)


def icon_gear(d):
    # Engranaje de 8 dientes con agujero: ajustes.
    c = 192
    for i in range(8):
        a = i * math.pi / 4
        pts = []
        for da, r in ((-0.2, 120), (-0.15, 168), (0.15, 168), (0.2, 120)):
            pts.append((c + math.cos(a + da) * r, c + math.sin(a + da) * r))
        d.polygon(pts, fill=255)
    d.ellipse((c - 128, c - 128, c + 128, c + 128), fill=255)
    d.ellipse((c - 54, c - 54, c + 54, c + 54), fill=0)


ICONS = {
    "cpu": icon_cpu, "globe": icon_globe, "book": icon_book, "exit": icon_exit, "brush": icon_brush,
    "cart": icon_cart, "trophy": icon_trophy, "shield": icon_shield, "calendar": icon_calendar,
    "chart": icon_chart, "bulb": icon_bulb, "share": icon_share, "video": icon_video, "smile": icon_smile,
    "bolt": icon_bolt, "gift": icon_gift, "gear": icon_gear,
}


def main():
    os.makedirs(OUT, exist_ok=True)
    panel()
    btn_body()
    btn_frame()
    field()
    orb_gloss()
    orb_ring()
    chevron("kit_chev_l.png", True)
    chevron("kit_chev_r.png", False)
    for name, fn in ICONS.items():
        _icon(name, fn)


if __name__ == "__main__":
    main()
