# Ícone do Smash na Areia: pá de beach tennis + bola verde-limão num pôr do sol de gibi.
# Uso: python3 tools/make_icon.py godot   (gera icon.png, icon_192.png, icon_bg/fg.png e icon.ico)
import math, sys
from PIL import Image, ImageDraw, ImageFilter, ImageChops
S = 2048
INK = (22, 12, 36, 255)
OUT = sys.argv[1]

def lerp(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))

def background(size):
    img = Image.new("RGB", (size, size))   # RGB: o Draw "RGBA" mistura a transparência
    px = img.load()
    top, mid, hor = (86, 34, 140), (255, 92, 120), (255, 196, 90)
    for y in range(size):
        t = y / size
        c = lerp(top, mid, min(t / 0.5, 1.0)) if t < 0.5 else lerp(mid, hor, min((t - 0.5) / 0.22, 1.0))
        for x in range(size):
            px[x, y] = c
    d = ImageDraw.Draw(img, "RGBA")
    sx, sy = size * 0.5, size * 0.70
    # raios de gibi saindo do sol
    for i in range(18):
        a0 = i / 18 * math.tau
        a1 = a0 + math.tau / 36
        R = size * 1.2
        d.polygon([(sx, sy), (sx + math.cos(a0) * R, sy + math.sin(a0) * R), (sx + math.cos(a1) * R, sy + math.sin(a1) * R)],
                  fill=(255, 225, 170, 60))
    # sol com halo
    for r, a in [(0.36, 40), (0.30, 70)]:
        rr = size * r
        d.ellipse([sx - rr, sy - rr, sx + rr, sy + rr], fill=(255, 220, 120, a))
    rr = size * 0.25
    d.ellipse([sx - rr, sy - rr, sx + rr, sy + rr], fill=(255, 213, 79, 255), outline=(232, 110, 50, 255), width=int(size * 0.012))
    rr2 = size * 0.19
    d.ellipse([sx - rr2, sy - rr2, sx + rr2, sy + rr2], fill=(255, 238, 160, 255))
    # mar com faixas de onda
    sea_y = size * 0.74
    d.rectangle([0, sea_y, size, size], fill=(25, 170, 210, 255))
    for k, (yy, w) in enumerate([(0.775, 0.010), (0.805, 0.008)]):
        y0 = size * yy
        pts = []
        for x in range(0, size + 40, 40):
            pts.append((x, y0 + math.sin(x / size * 14 + k) * size * 0.006))
        d.line(pts, fill=(200, 245, 255, 220), width=int(size * w))
    # areia em primeiro plano (curva)
    d.ellipse([-size * 0.3, size * 0.83, size * 1.3, size * 1.6], fill=(255, 214, 140, 255))
    d.arc([-size * 0.3, size * 0.83, size * 1.3, size * 1.6], 180, 360, fill=(255, 245, 225, 255), width=int(size * 0.014))
    # retícula de pontos no céu (meio-tom de gibi)
    dots = Image.new("L", (size, size), 0)
    dd = ImageDraw.Draw(dots)
    step = size // 46
    for y in range(0, int(size * 0.45), step):
        for x in range(0, size, step):
            off = step / 2 if (y // step) % 2 else 0
            r = step * 0.28 * (1 - y / (size * 0.45))
            if r > 0.5:
                dd.ellipse([x + off - r, y - r, x + off + r, y + r], fill=60)
    img.paste((255, 255, 255), (0, 0), dots)
    return img.convert("RGBA")

def paddle(size):
    """Pá de beach tennis desenhada na vertical e depois girada."""
    L = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(L)
    cx = size * 0.5
    fw, fh = size * 0.42, size * 0.50          # face
    fy = size * 0.10
    o = int(size * 0.022)
    # cabo
    hw, hh = size * 0.085, size * 0.30
    hy = fy + fh - size * 0.04
    d.rounded_rectangle([cx - hw / 2 - o, hy - o, cx + hw / 2 + o, hy + hh + o], radius=int(hw * 0.4), fill=INK)
    d.rounded_rectangle([cx - hw / 2, hy, cx + hw / 2, hy + hh], radius=int(hw * 0.35), fill=(40, 40, 60, 255))
    for k in range(7):  # fita do grip
        yy = hy + size * 0.05 + k * size * 0.034
        d.line([(cx - hw / 2, yy), (cx + hw / 2, yy + size * 0.02)], fill=(255, 79, 139, 255), width=int(size * 0.012))
    d.rounded_rectangle([cx - hw / 2 - o * 0.4, hy + hh - size * 0.03, cx + hw / 2 + o * 0.4, hy + hh + size * 0.008],
                        radius=int(hw * 0.3), fill=(255, 210, 63, 255), outline=INK, width=int(o * 0.6))
    # pescoço (garganta) em V
    d.polygon([(cx - fw * 0.30, fy + fh * 0.80), (cx + fw * 0.30, fy + fh * 0.80), (cx + hw * 0.55, hy + size * 0.03),
               (cx - hw * 0.55, hy + size * 0.03)], fill=INK)
    d.polygon([(cx - fw * 0.24, fy + fh * 0.80), (cx + fw * 0.24, fy + fh * 0.80), (cx + hw * 0.4, hy + size * 0.02),
               (cx - hw * 0.4, hy + size * 0.02)], fill=(255, 79, 139, 255))
    # face: contorno, aro e miolo
    d.ellipse([cx - fw / 2 - o, fy - o, cx + fw / 2 + o, fy + fh + o], fill=INK)
    d.ellipse([cx - fw / 2, fy, cx + fw / 2, fy + fh], fill=(255, 79, 139, 255))
    m = size * 0.03
    d.ellipse([cx - fw / 2 + m, fy + m, cx + fw / 2 - m, fy + fh - m], fill=(255, 250, 240, 255))
    # faixa colorida diagonal na face
    face = Image.new("L", (size, size), 0)
    ImageDraw.Draw(face).ellipse([cx - fw / 2 + m, fy + m, cx + fw / 2 - m, fy + fh - m], fill=255)
    band = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bd = ImageDraw.Draw(band)
    bd.polygon([(cx - fw, fy + fh * 0.55), (cx + fw, fy + fh * 0.15), (cx + fw, fy + fh * 0.36), (cx - fw, fy + fh * 0.76)],
               fill=(47, 140, 255, 255))
    bd.polygon([(cx - fw, fy + fh * 0.79), (cx + fw, fy + fh * 0.39), (cx + fw, fy + fh * 0.45), (cx - fw, fy + fh * 0.85)],
               fill=(255, 210, 63, 255))
    L.paste(band, (0, 0), ImageChops.multiply(face, band.split()[3]))
    # furinhos
    r = size * 0.013
    for row in range(-5, 6):
        for col in range(-4, 5):
            x = cx + col * size * 0.042 + (size * 0.021 if row % 2 else 0)
            y = fy + fh * 0.46 + row * size * 0.036
            if ((x - cx) / (fw / 2 - m * 1.6)) ** 2 + ((y - (fy + fh / 2)) / (fh / 2 - m * 1.6)) ** 2 < 1:
                d.ellipse([x - r, y - r, x + r, y + r], fill=(60, 40, 70, 200))
    # brilho
    d.arc([cx - fw / 2 + m * 1.6, fy + m * 1.6, cx + fw / 2 - m * 1.6, fy + fh - m * 1.6], 200, 250, fill=(255, 255, 255, 230),
          width=int(size * 0.016))
    return L

def ball_layer(size, c, r):
    L = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(L)
    x, y = c
    # linhas de velocidade
    for k, (dy, ln) in enumerate([(-0.75, 0.9), (-0.2, 1.25), (0.35, 0.8)]):
        w = int(r * 0.22)
        x0, y0 = x - r * 0.95 + r * dy * 0.6, y + r * dy + r * 0.25
        x1, y1 = x0 - r * ln * 0.8, y0 + r * ln * 0.55
        d.line([(x0, y0), (x1, y1)], fill=INK, width=w + int(r * 0.12))
        d.line([(x0, y0), (x1, y1)], fill=(255, 255, 255, 255), width=w)
    o = r * 0.14
    d.ellipse([x - r - o, y - r - o, x + r + o, y + r + o], fill=INK)
    d.ellipse([x - r, y - r, x + r, y + r], fill=(216, 255, 62, 255))
    d.ellipse([x - r * 0.85, y - r * 0.35, x + r * 0.95, y + r * 0.95], fill=(170, 222, 30, 255))
    d.ellipse([x - r * 0.8, y - r * 0.85, x + r * 0.75, y + r * 0.55], fill=(216, 255, 62, 255))
    d.arc([x - r * 1.5, y - r * 0.4, x + r * 0.4, y + r * 1.7], 270, 350, fill=(255, 255, 255, 255), width=int(r * 0.16))
    d.ellipse([x - r * 0.55, y - r * 0.62, x - r * 0.2, y - r * 0.3], fill=(255, 255, 255, 235))
    return L

def burst(size, c, r, col):
    L = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(L)
    pts, pts2 = [], []
    n = 14
    for i in range(n * 2):
        a = i / (n * 2) * math.tau + 0.2
        k = 1.0 if i % 2 == 0 else 0.62
        pts.append((c[0] + math.cos(a) * r * k, c[1] + math.sin(a) * r * k))
        pts2.append((c[0] + math.cos(a) * (r * k + r * 0.08), c[1] + math.sin(a) * (r * k + r * 0.08)))
    d.polygon(pts2, fill=INK)
    d.polygon(pts, fill=col)
    return L

def compose(size, with_bg=True, scale=1.0):
    img = background(size) if with_bg else Image.new("RGBA", (size, size), (0, 0, 0, 0))
    fg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bc = (size * 0.5 + size * 0.17 * scale, size * 0.5 - size * 0.2 * scale)
    fg.alpha_composite(burst(size, bc, size * 0.2 * scale, (255, 255, 255, 255)))
    p = paddle(int(size * 0.9 * scale)).rotate(-32, resample=Image.BICUBIC, expand=False)
    # sombra suave da pá
    sh = Image.new("RGBA", p.size, (22, 12, 36, 0))
    sh.putalpha(p.split()[3].point(lambda v: int(v * 0.35)))
    sh = sh.filter(ImageFilter.GaussianBlur(size * 0.01))
    ox = int(size * 0.5 - p.size[0] * 0.5 - size * 0.06 * scale)
    oy = int(size * 0.5 - p.size[1] * 0.5 + size * 0.05 * scale)
    fg.alpha_composite(sh, (ox + int(size * 0.02), oy + int(size * 0.025)))
    fg.alpha_composite(p, (ox, oy))
    fg.alpha_composite(ball_layer(size, bc, size * 0.105 * scale))
    img.alpha_composite(fg)
    return img, fg

def rounded(img, rad):
    m = Image.new("L", img.size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, img.size[0] - 1, img.size[1] - 1], radius=rad, fill=255)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), m)
    return out

full, _ = compose(S)
full_rgb = full.convert("RGB")
full_rgb.resize((512, 512), Image.LANCZOS).save(OUT + "/icon.png")
full_rgb.resize((192, 192), Image.LANCZOS).save(OUT + "/icon_192.png")
rounded(full, S // 5).resize((512, 512), Image.LANCZOS).save(OUT + "/icon_rounded.png")
# Android adaptativo: fundo (cenário) e frente (pá + bola) dentro da zona segura (66%)
bg = background(S).convert("RGB")
bg.resize((432, 432), Image.LANCZOS).save(OUT + "/icon_bg.png")
_, fg = compose(S, with_bg=False, scale=0.72)
fg.resize((432, 432), Image.LANCZOS).save(OUT + "/icon_fg.png")
# .ico do Windows (várias resoluções)
r = rounded(full, S // 5)
r.resize((256, 256), Image.LANCZOS).save(OUT + "/icon.ico", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
print("ok")
