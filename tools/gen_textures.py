# -*- coding: utf-8 -*-
"""Gera texturas procedurais: ruído (terreno/água), sombra circular, 9-patches de UI, ícones de UI e logo.
Uso: python3 tools/gen_textures.py
"""
import math
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
TEX = os.path.join(ROOT, "assets", "textures")
UI = os.path.join(ROOT, "assets", "ui")
ICONS = os.path.join(ROOT, "assets", "icons", "ui")
FONT = os.path.join(ROOT, "assets", "fonts", "Nunito.ttf")


# ------------------------------------------------------------------ ruído periódico (tileável)
def tile_noise(size, cells, seed, octaves=4):
    rng = np.random.default_rng(seed)
    out = np.zeros((size, size))
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        c = cells * (2 ** o)
        grid = rng.random((c, c))
        xs = np.arange(size) * c / size
        x0 = np.floor(xs).astype(int)
        t = xs - x0
        t = t * t * (3 - 2 * t)
        x1 = (x0 + 1) % c
        a = grid[np.ix_(x0, x0)]
        b = grid[np.ix_(x0, x1)]
        cc = grid[np.ix_(x1, x0)]
        d = grid[np.ix_(x1, x1)]
        ty = t[:, None]
        tx = t[None, :]
        v = (a * (1 - tx) + b * tx) * (1 - ty) + (cc * (1 - tx) + d * tx) * ty
        out += v * amp
        tot += amp
        amp *= 0.5
    out /= tot
    out = (out - out.min()) / (out.max() - out.min() + 1e-9)
    return out


def noise_tex():
    s = 512
    r = tile_noise(s, 4, 1, 4)  # baixa frequência (manchas grandes)
    g = tile_noise(s, 8, 2, 4)  # média
    b = tile_noise(s, 32, 3, 3)  # alta (micro detalhe)
    # A: células tipo voronoi (pedras/manchas)
    rng = np.random.default_rng(9)
    pts = rng.random((60, 2)) * s
    yy, xx = np.mgrid[0:s, 0:s]
    dmin = np.full((s, s), 1e9)
    for p in pts:
        for ox in (-s, 0, s):
            for oy in (-s, 0, s):
                d = np.hypot(xx - p[0] - ox, yy - p[1] - oy)
                dmin = np.minimum(dmin, d)
    a = np.clip(dmin / 40.0, 0, 1)
    img = np.stack([r, g, b, a], axis=-1)
    Image.fromarray((img * 255).astype(np.uint8), "RGBA").save(os.path.join(TEX, "noise.png"))


def blob_shadow():
    s = 128
    yy, xx = np.mgrid[0:s, 0:s]
    d = np.hypot(xx - s / 2 + 0.5, yy - s / 2 + 0.5) / (s / 2)
    a = np.clip(1 - d, 0, 1) ** 1.6
    img = np.zeros((s, s, 4), dtype=np.uint8)
    img[..., 3] = (a * 255).astype(np.uint8)
    Image.fromarray(img, "RGBA").save(os.path.join(TEX, "blob_shadow.png"))


# ------------------------------------------------------------------ 9-patches de UI
def panel(name, top, bottom, border, radius=28, size=128, inner_hl=0.12, border_w=3):
    K = 4
    S = size * K
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    grad = Image.new("RGBA", (S, S))
    gd = ImageDraw.Draw(grad)
    for y in range(S):
        t = y / (S - 1)
        c = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(4))
        gd.line([(0, y), (S, y)], fill=c)
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=radius * K, fill=255)
    img.paste(grad, (0, 0), mask)
    d = ImageDraw.Draw(img)
    # brilho interno superior
    if inner_hl > 0:
        hl = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        hd = ImageDraw.Draw(hl)
        hd.rounded_rectangle([border_w * K, border_w * K, S - 1 - border_w * K, S * 0.45], radius=(radius - 2) * K,
                             fill=(255, 255, 255, int(255 * inner_hl)))
        hl = hl.filter(ImageFilter.GaussianBlur(6 * K))
        hm = Image.new("L", (S, S), 0)
        ImageDraw.Draw(hm).rounded_rectangle([0, 0, S - 1, S - 1], radius=radius * K, fill=255)
        img.paste(Image.alpha_composite(img, hl), (0, 0), hm)
        d = ImageDraw.Draw(img)
    d.rounded_rectangle([border_w * K // 2, border_w * K // 2, S - 1 - border_w * K // 2, S - 1 - border_w * K // 2],
                        radius=radius * K, outline=border, width=border_w * K)
    img = img.resize((size, size), Image.LANCZOS)
    img.save(os.path.join(UI, name + ".png"))


def circle_btn(name, c1, c2, size=192):
    K = 4
    S = size * K
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    # sombra
    sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse([S * 0.06, S * 0.1, S * 0.94, S * 0.98], fill=(0, 0, 0, 120))
    sh = sh.filter(ImageFilter.GaussianBlur(6 * K))
    img.alpha_composite(sh)
    grad = Image.new("RGBA", (S, S))
    gd = ImageDraw.Draw(grad)
    for y in range(S):
        t = y / S
        gd.line([(0, y), (S, y)], fill=tuple(int(c1[i] * (1 - t) + c2[i] * t) for i in range(3)) + (255,))
    m = Image.new("L", (S, S), 0)
    ImageDraw.Draw(m).ellipse([S * 0.06, S * 0.04, S * 0.94, S * 0.92], fill=255)
    img.paste(grad, (0, 0), m)
    d = ImageDraw.Draw(img)
    hl = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(hl).ellipse([S * 0.18, S * 0.08, S * 0.82, S * 0.46], fill=(255, 255, 255, 70))
    hl = hl.filter(ImageFilter.GaussianBlur(4 * K))
    img.alpha_composite(hl)
    d.ellipse([S * 0.06, S * 0.04, S * 0.94, S * 0.92], outline=(255, 255, 255, 150), width=4 * K)
    img.resize((size, size), Image.LANCZOS).save(os.path.join(UI, name + ".png"))


# ------------------------------------------------------------------ ícones de UI (brancos com contorno)
def ui_icon(name, draw_fn, size=128):
    K = 4
    S = size * K
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    draw_fn(d, S)
    # contorno escuro
    alpha = img.split()[3]
    outline = alpha.filter(ImageFilter.MaxFilter(4 * K + 1))
    base = Image.new("RGBA", (S, S), (20, 18, 30, 0))
    base.putalpha(outline.point(lambda v: int(v * 0.85)))
    base.alpha_composite(img)
    base.resize((size, size), Image.LANCZOS).save(os.path.join(ICONS, name + ".png"))


W = (255, 255, 255, 255)


def p(S, pts):
    return [(x * S, y * S) for x, y in pts]


def ic_sword(d, S):
    d.polygon(p(S, [(0.22, 0.70), (0.66, 0.16), (0.80, 0.12), (0.76, 0.26), (0.30, 0.76)]), fill=W)
    d.polygon(p(S, [(0.16, 0.62), (0.36, 0.84), (0.30, 0.88), (0.10, 0.68)]), fill=W)
    d.ellipse(p(S, [(0.08, 0.80), (0.2, 0.92)]), fill=W)


def ic_hand(d, S):
    d.rounded_rectangle(p(S, [(0.28, 0.40), (0.74, 0.86)]), radius=0.12 * S, fill=W)
    for i, x in enumerate([0.30, 0.42, 0.54, 0.66]):
        d.rounded_rectangle(p(S, [(x, 0.16 + (i % 2) * 0.04), (x + 0.09, 0.52)]), radius=0.05 * S, fill=W)
    d.rounded_rectangle(p(S, [(0.12, 0.44), (0.32, 0.56)]), radius=0.05 * S, fill=W)


def ic_jump(d, S):
    d.polygon(p(S, [(0.5, 0.12), (0.82, 0.48), (0.62, 0.48), (0.62, 0.82), (0.38, 0.82), (0.38, 0.48), (0.18, 0.48)]), fill=W)


def ic_sphere(d, S):
    # rede de captura: aro + malha
    d.ellipse(p(S, [(0.12, 0.12), (0.88, 0.88)]), outline=W, width=int(0.09 * S))
    for i in range(-2, 3):
        x = 0.5 + i * 0.12
        d.line(p(S, [(x - 0.22, 0.2), (x + 0.22, 0.8)]), fill=W, width=int(0.045 * S))
        d.line(p(S, [(x + 0.22, 0.2), (x - 0.22, 0.8)]), fill=W, width=int(0.045 * S))
    m = Image.new("L", (S, S), 0)
    ImageDraw.Draw(m).ellipse(p(S, [(0.12, 0.12), (0.88, 0.88)]), fill=255)
    # recorta a malha no círculo
    base = d._image
    cut = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    cut.paste(base, (0, 0), m)
    base.paste((0, 0, 0, 0), (0, 0, S, S))
    base.alpha_composite(cut)
    d2 = ImageDraw.Draw(base)
    d2.ellipse(p(S, [(0.12, 0.12), (0.88, 0.88)]), outline=W, width=int(0.09 * S))


def ic_hammer(d, S):
    d.polygon(p(S, [(0.22, 0.86), (0.58, 0.40), (0.66, 0.46), (0.30, 0.92)]), fill=W)
    d.polygon(p(S, [(0.40, 0.26), (0.62, 0.10), (0.88, 0.36), (0.72, 0.54)]), fill=W)


def ic_bag(d, S):
    d.rounded_rectangle(p(S, [(0.18, 0.30), (0.82, 0.88)]), radius=0.14 * S, fill=W)
    d.arc(p(S, [(0.32, 0.10), (0.68, 0.46)]), 180, 360, fill=W, width=int(0.07 * S))


def ic_gift(d, S):
    d.rectangle(p(S, [(0.16, 0.42), (0.84, 0.88)]), fill=W)
    d.rectangle(p(S, [(0.10, 0.30), (0.90, 0.44)]), fill=W)
    d.ellipse(p(S, [(0.26, 0.10), (0.50, 0.32)]), outline=W, width=int(0.06 * S))
    d.ellipse(p(S, [(0.50, 0.10), (0.74, 0.32)]), outline=W, width=int(0.06 * S))


def ic_gem(d, S):
    d.polygon(p(S, [(0.28, 0.18), (0.72, 0.18), (0.90, 0.40), (0.50, 0.88), (0.10, 0.40)]), fill=W)


def ic_coin(d, S):
    d.ellipse(p(S, [(0.14, 0.14), (0.86, 0.86)]), fill=W)


def ic_heart(d, S):
    d.ellipse(p(S, [(0.10, 0.16), (0.52, 0.56)]), fill=W)
    d.ellipse(p(S, [(0.48, 0.16), (0.90, 0.56)]), fill=W)
    d.polygon(p(S, [(0.12, 0.44), (0.88, 0.44), (0.5, 0.88)]), fill=W)


def ic_food(d, S):
    d.ellipse(p(S, [(0.16, 0.12), (0.68, 0.62)]), fill=W)
    d.polygon(p(S, [(0.46, 0.52), (0.58, 0.40), (0.82, 0.70), (0.72, 0.80)]), fill=W)
    d.ellipse(p(S, [(0.70, 0.66), (0.90, 0.86)]), fill=W)


def ic_star(d, S):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = 0.42 if i % 2 == 0 else 0.18
        pts.append((0.5 + math.cos(a) * r, 0.53 + math.sin(a) * r))
    d.polygon(p(S, pts), fill=W)


def ic_close(d, S):
    d.line(p(S, [(0.22, 0.22), (0.78, 0.78)]), fill=W, width=int(0.14 * S))
    d.line(p(S, [(0.78, 0.22), (0.22, 0.78)]), fill=W, width=int(0.14 * S))


def ic_rotate(d, S):
    d.arc(p(S, [(0.16, 0.16), (0.84, 0.84)]), 30, 320, fill=W, width=int(0.1 * S))
    d.polygon(p(S, [(0.70, 0.08), (0.92, 0.34), (0.62, 0.38)]), fill=W)


def ic_swap(d, S):
    d.polygon(p(S, [(0.12, 0.36), (0.42, 0.12), (0.42, 0.28), (0.86, 0.28), (0.86, 0.44), (0.42, 0.44), (0.42, 0.60)]), fill=W)
    d.polygon(p(S, [(0.88, 0.64), (0.58, 0.40), (0.58, 0.56), (0.14, 0.56), (0.14, 0.72), (0.58, 0.72), (0.58, 0.88)]), fill=W)


def ic_paw(d, S):
    d.ellipse(p(S, [(0.28, 0.46), (0.72, 0.86)]), fill=W)
    for (x, y) in [(0.16, 0.36), (0.34, 0.16), (0.56, 0.16), (0.74, 0.36)]:
        d.ellipse(p(S, [(x, y), (x + 0.16, y + 0.2)]), fill=W)


def ic_scroll(d, S):
    d.rounded_rectangle(p(S, [(0.22, 0.14), (0.78, 0.86)]), radius=0.06 * S, fill=W)
    for y in [0.32, 0.46, 0.60]:
        d.line(p(S, [(0.32, y), (0.68, y)]), fill=(0, 0, 0, 0), width=int(0.05 * S))


def ic_book(d, S):
    d.polygon(p(S, [(0.10, 0.22), (0.48, 0.30), (0.48, 0.86), (0.10, 0.78)]), fill=W)
    d.polygon(p(S, [(0.90, 0.22), (0.52, 0.30), (0.52, 0.86), (0.90, 0.78)]), fill=W)


def ic_crystal(d, S):
    d.polygon(p(S, [(0.5, 0.08), (0.74, 0.40), (0.5, 0.92), (0.26, 0.40)]), fill=W)


def ic_map(d, S):
    d.polygon(p(S, [(0.10, 0.22), (0.36, 0.12), (0.64, 0.22), (0.90, 0.12), (0.90, 0.78), (0.64, 0.88), (0.36, 0.78), (0.10, 0.88)]), fill=W)


def ic_gear(d, S):
    for i in range(8):
        a = i * math.pi / 4
        d.line(p(S, [(0.5, 0.5), (0.5 + math.cos(a) * 0.4, 0.5 + math.sin(a) * 0.4)]), fill=W, width=int(0.14 * S))
    d.ellipse(p(S, [(0.22, 0.22), (0.78, 0.78)]), fill=W)


def ic_anvil(d, S):
    d.polygon(p(S, [(0.10, 0.30), (0.86, 0.30), (0.86, 0.46), (0.66, 0.54), (0.66, 0.70), (0.80, 0.86), (0.20, 0.86), (0.34, 0.70), (0.34, 0.54), (0.10, 0.44)]), fill=W)


def ic_auto(d, S):
    d.polygon(p(S, [(0.56, 0.08), (0.22, 0.56), (0.46, 0.56), (0.40, 0.92), (0.78, 0.40), (0.52, 0.40)]), fill=W)


ICON_SET = {"sword": ic_sword, "hand": ic_hand, "jump": ic_jump, "sphere": ic_sphere, "hammer": ic_hammer, "bag": ic_bag,
            "gift": ic_gift, "gem": ic_gem, "coin": ic_coin, "heart": ic_heart, "food": ic_food, "star": ic_star,
            "close": ic_close, "rotate": ic_rotate, "swap": ic_swap, "paw": ic_paw, "scroll": ic_scroll, "book": ic_book,
            "crystal": ic_crystal, "map": ic_map, "gear": ic_gear, "anvil": ic_anvil, "auto": ic_auto}


# ------------------------------------------------------------------ logo
def logo(sub="DESPERTAR", out="logo.png"):
    w, h = 1400, 420
    K = 2
    img = Image.new("RGBA", (w * K, h * K), (0, 0, 0, 0))
    f = ImageFont.truetype(FONT, 230 * K)
    f.set_variation_by_axes([1000])
    text = "ECOTERRA"
    d = ImageDraw.Draw(img)
    bbox = d.textbbox((0, 0), text, font=f, stroke_width=0)
    tw = bbox[2] - bbox[0]
    x = (w * K - tw) // 2
    y = 30 * K
    # brilho
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).text((x, y), text, font=f, fill=(120, 255, 220, 200), stroke_width=30 * K, stroke_fill=(120, 255, 220, 200))
    glow = glow.filter(ImageFilter.GaussianBlur(24 * K))
    img.alpha_composite(glow)
    # contorno grosso
    ImageDraw.Draw(img).text((x, y), text, font=f, fill=(15, 30, 35, 255), stroke_width=18 * K, stroke_fill=(15, 30, 35, 255))
    # preenchimento com gradiente
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).text((x, y), text, font=f, fill=255)
    grad = Image.new("RGBA", img.size)
    gd = ImageDraw.Draw(grad)
    for yy in range(img.size[1]):
        t = np.clip((yy - y) / (240 * K), 0, 1)
        c = (int(250 - 90 * t), int(255 - 40 * t), int(200 - 120 * t), 255)
        gd.line([(0, yy), (img.size[0], yy)], fill=c)
    img.paste(grad, (0, 0), mask)
    # faixa de brilho
    shine = Image.new("L", img.size, 0)
    ImageDraw.Draw(shine).rectangle([0, y + 40 * K, img.size[0], y + 95 * K], fill=90)
    shine = Image.composite(shine, Image.new("L", img.size, 0), mask)
    white = Image.new("RGBA", img.size, (255, 255, 255, 255))
    img.paste(white, (0, 0), shine)
    # folhas decorativas
    d = ImageDraw.Draw(img)
    for i, (lx, ly, ang) in enumerate([(x - 70 * K, y + 30 * K, -30), (x + tw + 50 * K, y + 30 * K, 30)]):
        leaf = Image.new("RGBA", (160 * K, 90 * K), (0, 0, 0, 0))
        ld = ImageDraw.Draw(leaf)
        ld.ellipse([0, 0, 160 * K, 90 * K], fill=(110, 210, 90, 255), outline=(15, 30, 35, 255), width=8 * K)
        ld.line([(10 * K, 45 * K), (150 * K, 45 * K)], fill=(60, 140, 50, 255), width=6 * K)
        leaf = leaf.rotate(ang, expand=True, resample=Image.BICUBIC)
        img.alpha_composite(leaf, (int(lx - leaf.size[0] / 2), int(ly)))
    # subtítulo
    f2 = ImageFont.truetype(FONT, 84 * K)
    f2.set_variation_by_axes([900])
    bb = d.textbbox((0, 0), sub, font=f2)
    sx = (w * K - (bb[2] - bb[0])) // 2
    d.text((sx, 285 * K), sub, font=f2, fill=(255, 205, 80, 255), stroke_width=10 * K, stroke_fill=(30, 20, 10, 255))
    img = img.resize((w, h), Image.LANCZOS)
    img.save(os.path.join(UI, out))


def vignette():
    s = 256
    yy, xx = np.mgrid[0:s, 0:s]
    d = np.hypot((xx - s / 2) / (s / 2), (yy - s / 2) / (s / 2))
    a = np.clip((d - 0.65) / 0.75, 0, 1) ** 1.8 * 0.55
    img = np.zeros((s, s, 4), dtype=np.uint8)
    img[..., 3] = (a * 255).astype(np.uint8)
    Image.fromarray(img, "RGBA").save(os.path.join(UI, "vignette.png"))


def main():
    for dd in (TEX, UI, ICONS):
        os.makedirs(dd, exist_ok=True)
    noise_tex()
    blob_shadow()
    panel("panel", (28, 36, 52, 235), (14, 18, 28, 240), (255, 255, 255, 40))
    panel("panel_light", (44, 56, 78, 245), (26, 32, 46, 245), (255, 255, 255, 55), radius=22)
    panel("panel_gold", (92, 70, 22, 245), (52, 36, 10, 245), (255, 210, 110, 160), radius=22)
    panel("panel_purple", (66, 44, 104, 245), (34, 22, 58, 245), (210, 160, 255, 140), radius=22)
    panel("btn", (64, 78, 104, 255), (36, 44, 62, 255), (255, 255, 255, 70), radius=22, inner_hl=0.18)
    panel("btn_accent", (70, 200, 186, 255), (26, 120, 112, 255), (190, 255, 245, 160), radius=22, inner_hl=0.22)
    panel("btn_gold", (255, 200, 80, 255), (196, 120, 20, 255), (255, 240, 180, 190), radius=22, inner_hl=0.25)
    panel("btn_green", (110, 210, 100, 255), (40, 130, 50, 255), (210, 255, 200, 170), radius=22, inner_hl=0.22)
    panel("btn_red", (240, 100, 90, 255), (160, 40, 40, 255), (255, 200, 190, 170), radius=22, inner_hl=0.22)
    panel("btn_purple", (160, 110, 230, 255), (90, 50, 160, 255), (230, 200, 255, 170), radius=22, inner_hl=0.22)
    panel("slot", (36, 44, 60, 230), (22, 27, 38, 230), (255, 255, 255, 30), radius=18, inner_hl=0.06, border_w=2)
    for name, c1, c2 in [("cb_red", (255, 130, 90), (200, 60, 40)), ("cb_blue", (110, 170, 255), (40, 90, 200)),
                         ("cb_green", (120, 220, 110), (40, 140, 60)), ("cb_pink", (255, 120, 140), (190, 50, 80)),
                         ("cb_teal", (90, 220, 200), (20, 120, 120)), ("cb_gray", (120, 125, 140), (60, 64, 76)),
                         ("cb_gold", (255, 210, 100), (210, 130, 30))]:
        circle_btn(name, c1, c2)
    for k, fn in ICON_SET.items():
        ui_icon(k, fn)
    logo()
    logo("AWAKENING", "logo_en.png")
    vignette()
    print("texturas, painéis, %d ícones de UI e logo" % len(ICON_SET))


if __name__ == "__main__":
    main()
