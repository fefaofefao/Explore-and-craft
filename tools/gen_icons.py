# -*- coding: utf-8 -*-
"""Gera ícones de itens (assets/icons/items/<icone>.png) e o ícone do app em estilo vetorial com PIL.
Uso: python3 tools/gen_icons.py
"""
import json
import math
import os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "icons", "items")
S = 128  # tamanho final
K = 4  # supersampling
W = S * K


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c[:3]) + (c[3] if len(c) > 3 else 255,)


def P(x, y):
    return (x * K, y * K)


def poly(d, pts, fill, outline=(20, 16, 28, 255), w=4):
    pp = [P(x, y) for x, y in pts]
    d.polygon(pp, fill=fill)
    d.line(pp + [pp[0]], fill=outline, width=w * K // 2, joint="curve")


def ell(d, x0, y0, x1, y1, fill, outline=(20, 16, 28, 255), w=4):
    d.ellipse([P(x0, y0), P(x1, y1)], fill=fill, outline=outline, width=w * K // 2)


def rect(d, x0, y0, x1, y1, fill, r=6, outline=(20, 16, 28, 255), w=4):
    d.rounded_rectangle([P(x0, y0), P(x1, y1)], radius=r * K, fill=fill, outline=outline, width=w * K // 2)


def line(d, pts, fill, w=6):
    d.line([P(x, y) for x, y in pts], fill=fill, width=w * K, joint="curve")


def hl(d, x, y, r=5, a=255):
    d.ellipse([P(x - r, y - r), P(x + r, y + r)], fill=(255, 255, 255, a))


def draw_icon(icon, c):
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c2 = shade(c, 0.7)
    c3 = shade(c, 1.25)
    wood = hexc("#9a6a3a")
    if icon == "log":
        poly(d, [(20, 70), (90, 30), (108, 58), (38, 98)], wood)
        ell(d, 84, 26, 112, 62, hexc("#d8a868"))
        ell(d, 92, 36, 104, 52, hexc("#b08050"), w=2)
    elif icon == "rock":
        poly(d, [(18, 88), (30, 48), (60, 30), (96, 40), (112, 80), (90, 104), (40, 106)], c)
        poly(d, [(30, 48), (60, 30), (70, 58), (44, 70)], c3, w=2)
    elif icon == "fiber":
        for i, col in enumerate([c, c2, c3]):
            line(d, [(40 + i * 18, 108), (36 + i * 22, 60), (44 + i * 20, 20)], (20, 16, 28, 255), 9)
            line(d, [(40 + i * 18, 108), (36 + i * 22, 60), (44 + i * 20, 20)], col, 6)
        rect(d, 34, 70, 96, 82, hexc("#c8a060"), 4)
    elif icon == "berry":
        for (x, y) in [(46, 70), (78, 66), (62, 92), (60, 48)]:
            ell(d, x - 20, y - 20, x + 20, y + 20, c)
            hl(d, x - 7, y - 8)
        poly(d, [(56, 28), (70, 16), (80, 30), (66, 36)], hexc("#5fbf4a"), w=3)
    elif icon in ("ore", "coal"):
        poly(d, [(18, 88), (30, 48), (60, 30), (96, 40), (112, 80), (90, 104), (40, 106)], hexc("#8a847c"))
        for (x, y) in [(46, 58), (76, 74), (58, 88), (84, 50)]:
            poly(d, [(x - 10, y), (x, y - 12), (x + 11, y - 2), (x + 4, y + 10), (x - 8, y + 9)], c, w=3)
    elif icon == "crystal":
        poly(d, [(64, 10), (88, 50), (64, 118), (40, 50)], c)
        poly(d, [(64, 10), (88, 50), (64, 60)], c3, w=2)
        poly(d, [(30, 60), (44, 40), (52, 100), (34, 108)], c2, w=3)
        poly(d, [(98, 60), (84, 40), (76, 100), (94, 108)], c2, w=3)
    elif icon == "sand":
        poly(d, [(14, 100), (40, 56), (64, 44), (92, 58), (116, 100)], c)
        for (x, y) in [(50, 70), (70, 66), (60, 84), (84, 82), (40, 88)]:
            ell(d, x - 3, y - 3, x + 3, y + 3, shade(c, 0.8), w=1)
    elif icon == "ice":
        poly(d, [(24, 44), (64, 22), (104, 44), (104, 92), (64, 114), (24, 92)], c)
        poly(d, [(24, 44), (64, 22), (104, 44), (64, 66)], c3, w=3)
        line(d, [(64, 66), (64, 114)], (20, 16, 28, 255), 2)
    elif icon == "hide":
        poly(d, [(30, 30), (50, 20), (64, 30), (78, 20), (98, 30), (104, 70), (96, 106), (64, 96), (32, 106), (24, 70)], c)
        line(d, [(46, 50), (82, 50)], shade(c, 0.75), 3)
        line(d, [(42, 74), (86, 74)], shade(c, 0.75), 3)
    elif icon == "meat":
        ell(d, 26, 30, 96, 96, c)
        ell(d, 44, 46, 76, 76, shade(c, 1.15), w=2)
        rect(d, 84, 80, 112, 96, hexc("#f0e8d8"), 6)
        ell(d, 100, 72, 118, 90, hexc("#f0e8d8"))
    elif icon == "drop":
        poly(d, [(64, 14), (92, 66), (88, 92), (64, 110), (40, 92), (36, 66)], c)
        hl(d, 52, 70, 8)
    elif icon == "mushroom":
        rect(d, 52, 60, 76, 110, hexc("#f0e6d0"), 8)
        poly(d, [(16, 66), (30, 32), (64, 18), (98, 32), (112, 66)], c)
        for (x, y) in [(44, 40), (70, 34), (88, 50)]:
            ell(d, x - 6, y - 6, x + 6, y + 6, (255, 240, 230, 255), w=1)
    elif icon == "dust":
        for (x, y, r) in [(50, 60, 22), (80, 74, 18), (60, 90, 14), (86, 44, 12)]:
            ell(d, x - r, y - r, x + r, y + r, c, w=3)
            hl(d, x - r / 3, y - r / 3, r / 4)
    elif icon == "feather":
        poly(d, [(30, 110), (56, 60), (90, 18), (98, 26), (70, 74)], c)
        line(d, [(30, 110), (92, 22)], shade(c, 0.6), 3)
    elif icon == "ingot":
        poly(d, [(18, 82), (36, 52), (102, 52), (112, 82)], c)
        poly(d, [(36, 52), (102, 52), (92, 38), (46, 38)], c3, w=3)
        hl(d, 56, 46, 4)
    elif icon == "glass":
        rect(d, 28, 24, 100, 104, (190, 240, 255, 180), 10)
        line(d, [(42, 40), (60, 40)], (255, 255, 255, 220), 4)
    elif icon == "rope":
        for r in [40, 30, 20]:
            ell(d, 64 - r, 64 - r, 64 + r, 64 + r, (0, 0, 0, 0), outline=(20, 16, 28, 255), w=10)
            ell(d, 64 - r, 64 - r, 64 + r, 64 + r, (0, 0, 0, 0), outline=c + (255,) if len(c) == 3 else c, w=6)
    elif icon == "plank":
        for i in range(3):
            rect(d, 18, 26 + i * 26, 110, 46 + i * 26, shade(c, 1 - i * 0.08), 4)
    elif icon == "brick":
        for (x, y) in [(18, 70), (66, 70), (42, 44)]:
            rect(d, x, y, x + 44, y + 24, c, 4)
    elif icon == "chip":
        rect(d, 30, 30, 98, 98, hexc("#2a3a4a"), 8)
        rect(d, 46, 46, 82, 82, c, 4)
        for i in range(4):
            line(d, [(36 + i * 18, 18), (36 + i * 18, 30)], hexc("#c8ccd4"), 4)
            line(d, [(36 + i * 18, 98), (36 + i * 18, 110)], hexc("#c8ccd4"), 4)
    elif icon == "bowl":
        poly(d, [(16, 60), (112, 60), (96, 104), (32, 104)], hexc("#c88a50"))
        ell(d, 22, 48, 106, 72, c)
    elif icon == "bottle":
        rect(d, 52, 14, 76, 40, hexc("#a87a4a"), 4)
        poly(d, [(50, 40), (78, 40), (98, 70), (92, 112), (36, 112), (30, 70)], c)
        hl(d, 48, 72, 7)
    elif icon in ("axe", "pick", "sword", "spear", "torch", "crowbar", "glider", "rod"):
        if icon == "glider":
            poly(d, [(10, 70), (64, 24), (118, 70), (64, 58)], c)
            line(d, [(64, 58), (64, 110)], wood, 5)
        elif icon == "crowbar":
            line(d, [(30, 110), (90, 30), (106, 36)], (20, 16, 28, 255), 14)
            line(d, [(30, 110), (90, 30), (106, 36)], c, 9)
        elif icon == "rod":
            line(d, [(64, 112), (64, 30)], (20, 16, 28, 255), 12)
            line(d, [(64, 112), (64, 30)], c, 7)
            poly(d, [(64, 10), (74, 30), (66, 30), (72, 44), (56, 24), (64, 24)], hexc("#ffe14a"), w=3)
        else:
            line(d, [(28, 112), (92, 24)], (20, 16, 28, 255), 14)
            line(d, [(28, 112), (92, 24)], wood, 9)
            if icon == "axe":
                poly(d, [(76, 18), (110, 26), (104, 64), (82, 46)], c)
            elif icon == "pick":
                poly(d, [(46, 22), (90, 12), (118, 44), (92, 30), (60, 34)], c)
            elif icon == "sword":
                poly(d, [(54, 76), (98, 14), (110, 10), (106, 22), (64, 86)], c)
                line(d, [(42, 70), (70, 94)], hexc("#c8a060"), 7)
            elif icon == "spear":
                poly(d, [(84, 34), (104, 8), (100, 40)], c)
            elif icon == "torch":
                poly(d, [(86, 30), (98, 2), (112, 22), (104, 44)], hexc("#ffb02a"), w=3)
                poly(d, [(92, 30), (100, 14), (106, 28)], hexc("#fff0a0"), w=1)
    elif icon == "canteen":
        ell(d, 22, 30, 106, 114, c)
        rect(d, 54, 12, 74, 34, hexc("#6a4a2a"), 4)
        line(d, [(30, 50), (98, 50)], shade(c, 0.7), 4)
    elif icon == "coat":
        poly(d, [(36, 20), (92, 20), (114, 50), (100, 60), (96, 112), (32, 112), (28, 60), (14, 50)], c)
        line(d, [(64, 24), (64, 112)], shade(c, 0.7), 3)
    elif icon == "mask":
        ell(d, 22, 30, 106, 100, c)
        ell(d, 34, 46, 58, 66, (190, 240, 255, 255), w=3)
        ell(d, 70, 46, 94, 66, (190, 240, 255, 255), w=3)
        ell(d, 50, 76, 78, 104, shade(c, 0.6), w=3)
    elif icon == "orb":
        # Esfera de Vínculo: orbe de cristal com anel de folhas e núcleo brilhante
        ell(d, 18, 18, 110, 110, shade(c, 0.55))
        ell(d, 26, 22, 102, 98, c, w=0)
        ell(d, 46, 44, 82, 80, shade(c, 1.6), w=0)
        ell(d, 54, 52, 74, 72, (255, 255, 240, 255), w=0)
        d.ellipse([P(18, 18), P(110, 110)], outline=(20, 16, 28, 255), width=4 * K // 2)
        d.arc([P(10, 50), P(118, 78)], 0, 180, fill=(20, 16, 28, 255), width=9 * K)
        d.arc([P(10, 50), P(118, 78)], 0, 180, fill=hexc("#e8c070"), width=5 * K)
        for (x, y) in [(22, 66), (106, 66), (64, 78)]:
            poly(d, [(x - 6, y), (x, y - 7), (x + 6, y), (x, y + 7)], hexc("#7cd65a"), w=2)
        hl(d, 42, 38, 8)
    elif icon == "seed":
        poly(d, [(64, 14), (96, 60), (84, 106), (44, 106), (32, 60)], c)
        line(d, [(64, 30), (64, 98)], shade(c, 0.7), 3)
        hl(d, 52, 52, 7)
    elif icon in ("relic", "core", "lens"):
        glow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow)
        gd.ellipse([P(10, 10), P(118, 118)], fill=c[:3] + (150,))
        glow = glow.filter(ImageFilter.GaussianBlur(10 * K))
        img.alpha_composite(glow)
        d = ImageDraw.Draw(img)
        if icon == "lens":
            ell(d, 24, 24, 104, 104, hexc("#c8a060"))
            ell(d, 34, 34, 94, 94, (255, 240, 180, 255), w=3)
            hl(d, 52, 50, 10)
        elif icon == "core":
            poly(d, [(64, 12), (106, 40), (106, 88), (64, 116), (22, 88), (22, 40)], c)
            poly(d, [(64, 34), (86, 48), (86, 80), (64, 94), (42, 80), (42, 48)], c3, w=3)
        else:
            poly(d, [(64, 12), (96, 46), (84, 108), (44, 108), (32, 46)], c)
            poly(d, [(64, 12), (96, 46), (64, 60)], c3, w=2)
            hl(d, 52, 50, 8)
    else:
        ell(d, 22, 22, 106, 106, c)
    return img.resize((S, S), Image.LANCZOS)


def app_icon():
    N = 512 * 2
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # fundo: céu ao entardecer com colina
    for y in range(N):
        t = y / N
        c = (int(30 + 40 * t), int(110 + 60 * t), int(190 - 40 * t), 255)
        d.line([(0, y), (N, y)], fill=c)
    d.ellipse([-200, 640, 1220, 1500], fill=(80, 160, 70, 255))
    d.ellipse([-100, 700, 1100, 1500], fill=(100, 185, 80, 255))
    # sol/aurora
    glow = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([600, 100, 900, 400], fill=(255, 220, 120, 200))
    glow = glow.filter(ImageFilter.GaussianBlur(40))
    img.alpha_composite(glow)
    d = ImageDraw.Draw(img)
    # Eco (Folhito estilizado)
    ol = (25, 22, 35, 255)
    d.ellipse([250, 330, 780, 830], fill=(124, 214, 90, 255), outline=ol, width=22)
    d.ellipse([370, 560, 660, 800], fill=(63, 143, 46, 255))
    for x in (400, 560):
        d.ellipse([x, 470, x + 90, 590], fill=(255, 255, 255, 255), outline=ol, width=12)
        d.ellipse([x + 18, 500, x + 78, 580], fill=(26, 20, 32, 255))
        d.ellipse([x + 40, 505, x + 64, 530], fill=(255, 255, 255, 255))
    d.arc([470, 600, 570, 660], 20, 160, fill=ol, width=14)
    # broto
    d.line([(515, 340), (515, 230)], fill=(63, 143, 46, 255), width=26)
    d.ellipse([380, 170, 520, 250], fill=(124, 214, 90, 255), outline=ol, width=14)
    d.ellipse([510, 150, 660, 240], fill=(124, 214, 90, 255), outline=ol, width=14)
    # esfera
    d.ellipse([690, 690, 920, 920], fill=(245, 245, 245, 255), outline=ol, width=18)
    d.pieslice([690, 690, 920, 920], 180, 360, fill=(255, 90, 90, 255))
    d.ellipse([690, 690, 920, 920], outline=ol, width=18)
    d.line([(694, 805), (916, 805)], fill=ol, width=18)
    d.ellipse([770, 770, 840, 840], fill=(255, 255, 255, 255), outline=ol, width=12)
    img = img.resize((512, 512), Image.LANCZOS)
    mask = Image.new("L", (512, 512), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, 511, 511], radius=110, fill=255)
    out = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    out.save(os.path.join(ROOT, "assets", "icon.png"))
    img.save(os.path.join(ROOT, "assets", "icon_square.png"))  # para a Play Store (512x512 sem cantos)
    # adaptativo (frente e fundo, 432x432)
    fg = img.resize((432, 432), Image.LANCZOS)
    fg.save(os.path.join(ROOT, "assets", "icon_foreground.png"))
    Image.new("RGBA", (432, 432), (40, 140, 190, 255)).save(os.path.join(ROOT, "assets", "icon_background.png"))


def feature_graphic():
    """Arte de destaque da Play Store (1024x500)."""
    img = Image.open(os.path.join(ROOT, "docs", "screenshots", "04_base.png")).convert("RGBA") if os.path.exists(
        os.path.join(ROOT, "docs", "screenshots", "04_base.png")) else Image.new("RGBA", (1280, 720), (40, 120, 160, 255))
    img = img.resize((1024, 576)).crop((0, 38, 1024, 538))
    shade_l = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade_l)
    for x in range(1024):
        a = int(max(0, 200 - x * 0.45))
        sd.line([(x, 0), (x, 500)], fill=(5, 10, 20, a))
    img.alpha_composite(shade_l)
    icon = Image.open(os.path.join(ROOT, "assets", "icon.png")).resize((180, 180))
    img.alpha_composite(icon, (40, 40))
    try:
        from PIL import ImageFont
        f1 = ImageFont.truetype(os.path.join(ROOT, "assets", "fonts", "Nunito.ttf"), 92)
        f1.set_variation_by_axes([1000])
        f2 = ImageFont.truetype(os.path.join(ROOT, "assets", "fonts", "Nunito.ttf"), 44)
        f2.set_variation_by_axes([900])
        d = ImageDraw.Draw(img)
        d.text((40, 250), "ECOTERRA", font=f1, fill=(240, 255, 250, 255), stroke_width=6, stroke_fill=(10, 15, 25, 255))
        d.text((44, 360), "Despertar", font=f2, fill=(255, 201, 74, 255), stroke_width=4, stroke_fill=(10, 15, 25, 255))
    except Exception as e:  # noqa
        print("fonte:", e)
    img.convert("RGB").save(os.path.join(ROOT, "docs", "play_store", "feature_graphic.png"))


def main():
    os.makedirs(OUT, exist_ok=True)
    items = json.load(open(os.path.join(ROOT, "data", "items.json"), encoding="utf-8"))
    n = 0
    for iid, it in items.items():
        img = draw_icon(it["icon"], hexc(it["color"]))
        img.save(os.path.join(OUT, iid + ".png"))
        n += 1
    app_icon()
    os.makedirs(os.path.join(ROOT, "docs", "play_store"), exist_ok=True)
    feature_graphic()
    print(f"{n} ícones de itens + ícone do app + arte de destaque")


if __name__ == "__main__":
    main()
