# Portões de legibilidade sobre o quadro de estresse (Compatibility): cinza, borrão, miniatura
# 320x180, daltonismo (Machado 2009). Lê a imagem e a máscara de identificação (heróis em
# (255,0,20+40i), inimigos em (0,255,10+10j)). Uso: python3 gates.py stress.png mask.png OUTDIR
import sys, os, json, itertools
import numpy as np
from PIL import Image, ImageFilter, ImageDraw, ImageFont
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from paleta import P

IMG, MASK, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
M = {  # Machado et al. 2009, severidade 1.0
    'protanopia': np.array([[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]]),
    'deuteranopia': np.array([[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]]),
    'tritanopia': np.array([[1.255528, -0.076749, -0.178779], [-0.078411, 0.930809, 0.147602], [0.004733, 0.691367, 0.303900]]),
}
def s2l(c): return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
def l2s(c): c = np.clip(c, 0, 1); return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)
def oklab(rgb):
    l = s2l(rgb)
    lms = l @ np.array([[0.4122214708, 0.5363325363, 0.0514459929], [0.2119034982, 0.6806995451, 0.1073969566], [0.0883024619, 0.2817188376, 0.6299787005]]).T
    lms = np.cbrt(lms)
    return lms @ np.array([[0.2104542553, 0.7936177850, -0.0040720468], [1.9779984951, -2.4285922050, 0.4505937099], [0.0259040371, 0.7827717662, -0.8086757660]]).T
def cvd(rgb, kind): return l2s(s2l(rgb) @ M[kind].T)
def load(p): return np.asarray(Image.open(p).convert('RGB')).astype(np.float32) / 255
def gray(img): return np.repeat(oklab(img)[..., :1], 3, -1).clip(0, 1)

def ids(mask):
    m = (mask * 255).round().astype(int)
    out = {}
    hero = (m[..., 0] > 200) & (m[..., 1] < 60)
    en = (m[..., 1] > 200) & (m[..., 0] < 60)
    for i in range(4):
        sel = hero & (np.abs(m[..., 2] - (20 + 40 * i)) <= 8)
        if sel.sum() > 0: out[f'h{i}'] = sel
    for j in range(20):
        sel = en & (np.abs(m[..., 2] - (10 + 10 * j)) <= 3)
        if sel.sum() > 0: out[f'e{j}'] = sel
    return out, hero | en

def dilate(b, r):
    return np.asarray(Image.fromarray((b * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(2 * r + 1))) > 127

def contrast(img, chars, anym, r):
    L = oklab(img)[..., 0]
    res = {}
    for k, sel in chars.items():
        if sel.sum() < 3: continue
        ring = dilate(sel, r) & ~anym
        if ring.sum() < 3: continue
        res[k] = float(abs(np.median(L[sel]) - np.median(L[ring])))
    return res

def summ(d):
    if not d: return None
    v = np.array(list(d.values()))
    return dict(min=round(float(v.min()), 3), med=round(float(np.median(v)), 3), n=len(v), abaixo_0_10=int((v < 0.10).sum()))

img = load(IMG); mask = load(MASK)
chars, anym = ids(mask)
H = {k: v for k, v in chars.items() if k[0] == 'h'}
E = {k: v for k, v in chars.items() if k[0] == 'e'}
R = {}
R['cinza_herois'] = summ(contrast(img, H, anym, 6)); R['cinza_inimigos'] = summ(contrast(img, E, anym, 6))
R['cinza_por_heroi'] = {k: round(v, 3) for k, v in contrast(img, H, anym, 6).items()}
bl = np.asarray(Image.fromarray((img * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(4))).astype(np.float32) / 255
R['borrao_herois'] = summ(contrast(bl, H, anym, 6)); R['borrao_inimigos'] = summ(contrast(bl, E, anym, 6))
R['borrao_por_heroi'] = {k: round(v, 3) for k, v in contrast(bl, H, anym, 6).items()}
th = np.asarray(Image.fromarray((img * 255).astype(np.uint8)).resize((320, 180), Image.LANCZOS)).astype(np.float32) / 255
tm = np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).resize((320, 180), Image.NEAREST)).astype(np.float32) / 255
tch, tany = ids(tm)
hts = {k: int(np.ptp(np.where(v.any(1))[0]) + 1) for k, v in tch.items() if v.sum() > 0}
R['mini_altura_herois_px'] = {k: hts[k] for k in hts if k[0] == 'h'}
R['mini_altura_inimigos_med_px'] = float(np.median([hts[k] for k in hts if k[0] == 'e']))
R['mini_herois'] = summ(contrast(th, {k: v for k, v in tch.items() if k[0] == 'h'}, tany, 2))
R['mini_inimigos'] = summ(contrast(th, {k: v for k, v in tch.items() if k[0] == 'e'}, tany, 2))
R['altura_herois_720p'] = {k: int(np.ptp(np.where(v.any(1))[0]) + 1) for k, v in H.items()}
# identidade do jogador: cor do anel (o símbolo é a garantia em daltonismo)
rings = {'P1 magenta/quadrado': P['p_magenta'], 'P2 ciano/triângulo': P['p_ciano'], 'P3 lilás/círculo': P['p_lilas'], 'P4 lima/losango': P['p_lima']}
rc = {k: np.array([int(v[i:i + 2], 16) for i in (1, 3, 5)], np.float32) / 255 for k, v in rings.items()}
for kind in ['normal'] + list(M):
    lab = {k: oklab((v if kind == 'normal' else cvd(v[None], kind)[0])[None])[0] for k, v in rc.items()}
    pairs = {f'{a} x {b}': round(float(np.linalg.norm(lab[a] - lab[b])), 3) for a, b in itertools.combinations(lab, 2)}
    R[f'aneis_{kind}'] = dict(min=min(pairs.values()), pares=pairs)
    labi = oklab(img if kind == 'normal' else cvd(img, kind))
    hm = {k: labi[v].mean(0) for k, v in H.items()}
    em = labi[np.any(list(E.values()), 0)].mean(0)
    R[f'classe_{kind}_heroi_x_inimigo_min'] = round(min(float(np.linalg.norm(hm[a] - em)) for a in hm), 3)
    R[f'cinza_herois_{kind}'] = summ(contrast(img if kind == 'normal' else cvd(img, kind), H, anym, 6))
json.dump(R, open(os.path.join(OUT, 'portoes.json'), 'w'), indent=1, ensure_ascii=False)
for k, v in R.items():
    print(k, v)

# folha dos portões: original, cinza, borrão, miniatura, deuteranopia, protanopia
W, Hh = 640, 360
tiles = [('original', img), ('cinza (OKLab L)', gray(img)), ('borrão gaussiano 4 px', bl),
         ('miniatura 320x180 (ampliada)', np.asarray(Image.fromarray((th * 255).astype(np.uint8)).resize((1280, 720), Image.NEAREST)).astype(np.float32) / 255),
         ('deuteranopia', cvd(img, 'deuteranopia')), ('protanopia', cvd(img, 'protanopia'))]
sheet = Image.new('RGB', (W * 3 + 40, (Hh + 34) * 2 + 20), (24, 26, 40))
try:
    font = ImageFont.truetype('/usr/share/fonts/opentype/inter/Inter-Medium.otf', 20)
except Exception:
    font = ImageFont.load_default()
dr = ImageDraw.Draw(sheet)
for i, (name, a) in enumerate(tiles):
    r, c = divmod(i, 3)
    x, y = 10 + c * (W + 10), 10 + r * (Hh + 34)
    sheet.paste(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).resize((W, Hh), Image.LANCZOS), (x, y + 30))
    dr.text((x, y + 4), name, fill=(235, 232, 220), font=font)
sheet.save(os.path.join(OUT, 'portoes.png'))
