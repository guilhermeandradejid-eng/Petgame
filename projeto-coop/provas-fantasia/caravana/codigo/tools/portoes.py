# Portões automáticos sobre uma captura: cinza, borrão, miniatura 320x180 e daltonismo (deuteranopia e protanopia,
# matrizes de Machado 2009). Usa uma máscara renderizada na mesma pose (heróis em vermelho, inimigos em verde,
# identidade no azul). Uso: python3 portoes.py captura.png mascara.png saida_prefixo [borrao_px]
import sys, json
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

img_p, mask_p, out = sys.argv[1:4]
BR = float(sys.argv[4]) if len(sys.argv) > 4 else 4.0
img = load(img_p); mask = (load(mask_p) * 255).round().astype(int)
H, W = img.shape[:2]
hero_m = (mask[..., 0] > 150) & (mask[..., 1] < 90)
en_m = (mask[..., 1] > 150) & (mask[..., 0] < 90)
anym = hero_m | en_m
chars = {}
b = mask[..., 2]
for i, v in enumerate([60, 110, 160, 210]):
    sel = hero_m & (np.abs(b - v) <= 6)
    if sel.sum() > 15: chars['h%d' % i] = sel
for j in range(24):
    v = 40 + j * 9
    sel = en_m & (np.abs(b - v) <= 3)
    if sel.sum() > 15: chars['e%02d' % j] = sel

def contraste(im, r=5):
    L = oklab(im)[..., 0]
    res = {}
    for k, sel in chars.items():
        ring = dilate(sel, r) & ~dilate(anym, 1)
        if ring.sum() < 5: continue
        res[k] = float(abs(np.median(L[sel]) - np.median(L[ring])))
    return res
def resumo(d, pref):
    v = np.array([x for k, x in d.items() if k[0] == pref])
    return dict(min=round(float(v.min()), 3), med=round(float(np.median(v)), 3), n=len(v), abaixo_0_10=int((v < 0.10).sum())) if len(v) else None

R = {}
R['personagens'] = dict(herois=sum(1 for k in chars if k[0] == 'h'), inimigos=sum(1 for k in chars if k[0] == 'e'))
c0 = contraste(img); R['cinza_dL'] = dict(herois=resumo(c0, 'h'), inimigos=resumo(c0, 'e'))
bl = blur(img, BR * H / 720); c1 = contraste(bl); R['borrao_%dpx_dL' % BR] = dict(herois=resumo(c1, 'h'), inimigos=resumo(c1, 'e'))
R['por_personagem'] = {k: dict(cinza=round(c0[k], 3), borrao=round(c1.get(k, 0), 3)) for k in sorted(c0)}
hts = {k: (int(np.ptp(np.where(v.any(1))[0])) + 1) * 180.0 / H for k, v in chars.items()}
R['miniatura_altura_px'] = dict(herois=sorted(round(hts[k], 1) for k in hts if k[0] == 'h'),
                                inimigos_min=round(min([hts[k] for k in hts if k[0] == 'e'] or [0]), 1))
# cores-chave: jogadores, perigo e Labareda, sob daltonismo
cores = {'carmim': '#E0503C', 'ouro': '#E8C34A', 'celeste': '#5CB8EE', 'lilas': '#B07BE6', 'acido': '#C6EE3A', 'ambar': '#E8A24A'}
rgb = {k: np.array([int(v[i:i + 2], 16) for i in (1, 3, 5)]) / 255 for k, v in cores.items()}
R['daltonismo_dE'] = {}
for kind in ['normal', 'deuteranopia', 'protanopia']:
    lab = {k: oklab(c if kind == 'normal' else cvd(c[None], kind)[0]) for k, c in rgb.items()}
    jog = ['carmim', 'ouro', 'celeste', 'lilas']
    pares = [(a, b) for i, a in enumerate(jog) for b in jog[i + 1:]]
    dj = min(float(np.linalg.norm(lab[a] - lab[b])) for a, b in pares)
    pior = min(pares, key=lambda p: np.linalg.norm(lab[p[0]] - lab[p[1]]))
    da = min(float(np.linalg.norm(lab['acido'] - lab[k])) for k in jog + ['ambar'])
    R['daltonismo_dE'][kind] = dict(jogadores_min=round(dj, 3), par=pior, acido_vs_resto_min=round(da, 3))
json.dump(R, open(out + '.json', 'w'), indent=1, ensure_ascii=False)
print(json.dumps(R, ensure_ascii=False)[:1800])
# folha visual: original, cinza, borrão, miniatura (ampliada), deuteranopia, protanopia
th = to_im(img).resize((320, 180), Image.LANCZOS)
g = np.repeat(oklab(img)[..., :1], 3, -1); g = g / max(g.max(), 1e-3)
tiles = [('original', to_im(img)), ('cinza (OKLab L)', to_im(g)), ('borrao %d px' % BR, to_im(bl)),
         ('miniatura 320x180', th.resize((W, H), Image.NEAREST)), ('deuteranopia', to_im(cvd(img, 'deuteranopia'))), ('protanopia', to_im(cvd(img, 'protanopia')))]
tw, tht = W // 2, H // 2
sheet = Image.new('RGB', (tw * 3, (tht + 26) * 2), (20, 20, 26))
d = ImageDraw.Draw(sheet)
for i, (nm, im) in enumerate(tiles):
    x, y = (i % 3) * tw, (i // 3) * (tht + 26)
    sheet.paste(im.resize((tw, tht), Image.LANCZOS), (x, y + 26))
    d.text((x + 8, y + 6), nm, fill=(235, 225, 200))
sheet.save(out + '.png')
