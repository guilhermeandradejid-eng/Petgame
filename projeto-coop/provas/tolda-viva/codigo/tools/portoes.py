# Portões da checagem interna sobre o quadro de estresse: cinza, borrão, miniatura 320x180, daltonismo
# (deuteranopia e protanopia, Machado 2009), separação entre os 4 jogadores e folha visual.
# Uso: python3 portoes.py estresse.png mascara.png aneis.png saida_prefixo
import sys, json, itertools
import numpy as np
from PIL import Image, ImageFilter, ImageDraw

M = {
    'protanopia': np.array([[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]]),
    'deuteranopia': np.array([[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]]),
}
def s2l(c): return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
def l2s(c): c = np.clip(c, 0, 1); return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)
def oklab(rgb):
    l = s2l(rgb)
    lms = l @ np.array([[0.4122214708, 0.5363325363, 0.0514459929], [0.2119034982, 0.6806995451, 0.1073969566], [0.0883024619, 0.2817188376, 0.6299787005]]).T
    lms = np.cbrt(np.maximum(lms, 0))
    return lms @ np.array([[0.2104542553, 0.7936177850, -0.0040720468], [1.9779984951, -2.4285922050, 0.4505937099], [0.0259040371, 0.7827717662, -0.8086757660]]).T
def cvd(rgb, k): return l2s(s2l(rgb) @ M[k].T)
def load(p): return np.asarray(Image.open(p).convert('RGB')).astype(np.float32) / 255
def to_im(a): return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
def blur(a, r): return np.asarray(to_im(a).filter(ImageFilter.GaussianBlur(r))).astype(np.float32) / 255
def dilate(b, r): return np.asarray(Image.fromarray((b * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(2 * r + 1))) > 127

img_p, mask_p, ring_p, out = sys.argv[1:5]
img = load(img_p); mask = (load(mask_p) * 255).round().astype(int)
H, W = img.shape[:2]
hero_m = (mask[..., 0] > 180) & (mask[..., 1] < 80)
en_m = (mask[..., 1] > 180) & (mask[..., 0] < 80)
anym = hero_m | en_m
# identificação pelo canal azul (vizinho mais próximo dos IDs gravados)
hid = [16, 60, 100, 140]; eid = [4, 16, 28, 39, 49, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160, 170, 180, 190, 200]
chars = {}
b = mask[..., 2]
for i, v in enumerate(hid):
    sel = hero_m & (np.abs(b - v) <= 3)
    if sel.sum() > 20: chars[f'h{i}'] = sel
for j, v in enumerate(eid):
    sel = en_m & (np.abs(b - v) <= 2)
    if sel.sum() > 20: chars[f'e{j}'] = sel

def contrast(im, r=6):
    L = oklab(im)[..., 0]
    res = {}
    for k, sel in chars.items():
        ring = dilate(sel, r) & ~anym
        if ring.sum() < 5: continue
        res[k] = float(abs(np.median(L[sel]) - np.median(L[ring])))
    return res
def summ(d, pref):
    v = np.array([x for k, x in d.items() if k[0] == pref])
    return dict(min=round(float(v.min()), 3), med=round(float(np.median(v)), 3), n=len(v), abaixo_0_12=int((v < 0.12).sum())) if len(v) else None

R = {}
R['personagens'] = dict(herois=sum(1 for k in chars if k[0] == 'h'), inimigos=sum(1 for k in chars if k[0] == 'e'))
c0 = contrast(img); R['cinza_dL'] = dict(herois=summ(c0, 'h'), inimigos=summ(c0, 'e'))
bl = blur(img, 4); c1 = contrast(bl); R['borrao4px_dL'] = dict(herois=summ(c1, 'h'), inimigos=summ(c1, 'e'))
# miniatura
th = np.asarray(to_im(img).resize((320, 180), Image.LANCZOS)).astype(np.float32) / 255
hts = {k: int(np.ptp(np.where(v.any(1))[0]) + 1) * 180 // H for k, v in chars.items()}
R['miniatura_altura_px'] = dict(herois=sorted(hts[k] for k in hts if k[0] == 'h'), inimigos_med=float(np.median([hts[k] for k in hts if k[0] == 'e'])))
R['altura_720p_herois'] = sorted(int(np.ptp(np.where(v.any(1))[0]) + 1) for k, v in chars.items() if k[0] == 'h')
# separação entre jogadores: cor média do anel (marcador) e do corpo, em visão normal e daltonismo
ring = load(ring_p)
rm = ring.sum(-1) > 0.12
ys, xs = np.nonzero(rm)
cent = {k: np.array([np.mean(np.nonzero(v)[1]), np.max(np.nonzero(v)[0])]) for k, v in chars.items() if k[0] == 'h'}
lab_of = {}
for kind in ['normal', 'deuteranopia', 'protanopia']:
    im = img if kind == 'normal' else cvd(img, kind)
    rg = ring if kind == 'normal' else cvd(ring, kind)
    labI = oklab(im); labR = oklab(rg)
    ringcol = {}
    for k, c in cent.items():
        d = np.hypot(xs - c[0], ys - c[1])
        sel = d < 110
        # atribui cada pixel do anel ao herói mais próximo
        ok = np.ones(len(xs), bool)
        for k2, c2 in cent.items():
            if k2 != k: ok &= d <= np.hypot(xs - c2[0], ys - c2[1])
        sel &= ok
        ringcol[k] = labR[ys[sel], xs[sel]].mean(0) if sel.sum() else None
    body = {k: labI[v].mean(0) for k, v in chars.items() if k[0] == 'h'}
    pr = [float(np.linalg.norm(ringcol[a] - ringcol[b])) for a, b in itertools.combinations(sorted(ringcol), 2) if ringcol[a] is not None and ringcol[b] is not None]
    pb = [float(np.linalg.norm(body[a] - body[b])) for a, b in itertools.combinations(sorted(body), 2)]
    cdl = contrast(im)
    R[f'{kind}'] = dict(anel_par_min_dE=round(min(pr), 3) if pr else None, corpo_par_min_dE=round(min(pb), 3), dL_herois=summ(cdl, 'h'), dL_inimigos=summ(cdl, 'e'))
R['passa'] = dict(borrao_herois=R['borrao4px_dL']['herois']['min'] >= 0.12, borrao_inimigos_med=R['borrao4px_dL']['inimigos']['med'] >= 0.12,
                  deut_aneis=R['deuteranopia']['anel_par_min_dE'] >= 0.05, prot_aneis=R['protanopia']['anel_par_min_dE'] >= 0.05,
                  miniatura_herois_px=min(R['miniatura_altura_px']['herois']) >= 20)
json.dump(R, open(out + '.json', 'w'), indent=1, ensure_ascii=False)
print(json.dumps(R, indent=1, ensure_ascii=False))
# folha visual: original, cinza, borrão, miniatura (ampliada), deuteranopia, protanopia
w2, h2 = 640, 360
def sm(a): return to_im(a).resize((w2, h2), Image.LANCZOS)
gray = oklab(img)[..., 0:1].repeat(3, -1)
tiles = [('original', sm(img)), ('cinza (claridade OKLab)', sm(np.clip(gray, 0, 1))), ('borrão 4 px', sm(bl)),
         ('miniatura 320x180 (ampliada)', to_im(th).resize((w2, h2), Image.NEAREST)), ('deuteranopia', sm(cvd(img, 'deuteranopia'))), ('protanopia', sm(cvd(img, 'protanopia')))]
S = Image.new('RGB', (w2 * 3, (h2 + 26) * 2), (24, 22, 28))
from PIL import ImageFont
FT = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 16)
dr = ImageDraw.Draw(S)
for i, (t, im) in enumerate(tiles):
    x, y = (i % 3) * w2, (i // 3) * (h2 + 26)
    S.paste(im, (x, y + 26)); dr.text((x + 8, y + 4), t, fill=(240, 230, 200), font=FT)
S.save(out + '_folha.png')
