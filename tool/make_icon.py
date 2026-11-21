#!/usr/bin/env python3
"""Dessine l'icône de Womp dans la DA de l'app (aplats, trait d'encre, ombre dure).

Usage : python3 tool/make_icon.py   puis   dart run flutter_launcher_icons
Sorties dans assets/icon/ : icon.png (iOS, sans transparence) et
icon_foreground.png (Android adaptatif, motif dans la zone sûre).
"""
from PIL import Image, ImageDraw

INK, SUN, TOMATO = (29, 36, 64), (255, 197, 49), (255, 90, 60)
SIZE, SS = 1024, 4  # dessin à 4 fois la taille, puis réduction : bords nets
TILT = 8  # degrés, comme la pastille du logo


def mark(scale: float) -> Image.Image:
    """La pastille « ! » sur fond transparent, centrée, inclinée."""
    n = SIZE * SS
    layer = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    def box(x0, y0, x1, y1):
        c = SIZE / 2
        return [((v - c) * scale + c) * SS for v in (x0, y0, x1, y1)]

    def px(v):
        return v * scale * SS

    # Ombre dure, sans flou, décalée vers le bas.
    d.rounded_rectangle(box(232, 252, 792, 852), radius=px(150), fill=INK)
    # Carte : trait d'encre puis aplat jaune.
    d.rounded_rectangle(box(232, 182, 792, 782), radius=px(150), fill=INK)
    d.rounded_rectangle(box(272, 222, 752, 742), radius=px(112), fill=SUN)
    # Point d'exclamation : une barre aux coins ronds qui s'affine vers le bas, et un point.
    c = SIZE / 2

    def pt(x, y):
        return (((x * scale) + c) * SS, ((y - c) * scale + c) * SS)

    r = 20
    corners = [pt(-50, 320), pt(50, 320), pt(26, 540), pt(-26, 540)]
    d.polygon(corners, fill=INK)
    d.line(corners + corners[:1], fill=INK, width=int(px(2 * r)), joint="curve")
    for x, y in corners:
        d.ellipse([x - px(r), y - px(r), x + px(r), y + px(r)], fill=INK)
    d.ellipse(box(c - 56, 612, c + 56, 724), fill=INK)

    layer = layer.rotate(-TILT, resample=Image.BICUBIC, center=(n / 2, n / 2))
    return layer.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    full = Image.new("RGBA", (SIZE, SIZE), TOMATO + (255,))
    full.alpha_composite(mark(1.0))
    # iOS refuse la transparence : image RGB, 8 bits par couche.
    full.convert("RGB").save("assets/icon/icon.png")
    # Android adaptatif : le système rogne les bords, le motif reste dans les 62 % du centre.
    mark(0.62).save("assets/icon/icon_foreground.png")


if __name__ == "__main__":
    main()
