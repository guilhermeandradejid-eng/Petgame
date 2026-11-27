# Portões de legibilidade da captura de estresse (seção 11.8) e teste de paleta (11.7.7).
# Uso: python3 portoes.py stress.png mascara.png saida_prefixo
import sys, json
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

PAL = ["#231C17", "#E9DFC9", "#E3C99A", "#8E97A3", "#A8834F", "#7D8A5A", "#6E4A33", "#6F8894", "#C9A55A", "#5E8F7E",
       "#E2672B", "#F4F1E8", "#7FA3E0", "#F2E6C2", "#D9472B", "#E8B23A", "#3F62C8", "#9B3FA8", "#A8D82A",
       "#2F4677", "#6B2A63", "#B5301F"]
JOG = {"vermelhao": "#D9472B", "ouro": "#E8B23A", "ultramar": "#3F62C8", "murice": "#9B3FA8"}

def hexrgb(h): return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], float) / 255
def lin(c): return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
def unlin(c): return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.clip(c, 0, None) ** (1 / 2.4) - 0.055)
def oklab(rgb):
    l = lin(rgb)
    M1 = np.array([[0.4122214708, 0.5363325363, 0.0514459929], [0.2119034982, 0.6806995451, 0.1073969566], [0.0883024619, 0.2817188376, 0.6299787005]])
    lms = np.cbrt(np.clip(l @ M1.T, 0, None))
    M2 = np.array([[0.2104542553, 0.7936177850, -0.0040720468], [1.9779984951, -2.4285922050, 0.4505937099], [0.0259040371, 0.7827717662, -0.8086757660]])
    return lms @ M2.T
# Machado 2009, severidade 1.0
DEU = np.array([[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]])
PRO = np.array([[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]])
def cvd(rgb, M): return unlin(np.clip(lin(rgb) @ M.T, 0, 1))

img = np.asarray(Image.open(sys.argv[1]).convert('RGB')).astype(float) / 255
mask = np.asarray(Image.open(sys.argv[2]).convert('L')).astype(float) / 255
out = sys.argv[3]
H, W = mask.shape
her = mask > 0.8
ini = (mask > 0.3) & (mask < 0.7)

def contraste(L, sel, nome):
    lab, n = ndimage.label(ndimage.binary_opening(sel, iterations=1))
    res = []
    for i in range(1, n + 1):
        b = lab == i
        if b.sum() < 150: continue
        ring = ndimage.binary_dilation(b, iterations=6) & ~ndimage.binary_dilation(b, iterations=2) & ~her & ~ini
        if ring.sum() < 20: continue
        res.append(abs(np.median(L[b]) - np.median(L[ring])))
    return res

lab = oklab(img)
L = lab[..., 0]
r = {}
ch = contraste(L, her, 'her'); ci = contraste(L, ini, 'ini')
r['cinza_herois_lista'] = [round(x, 3) for x in ch]
r['cinza_herois_min'] = round(min(ch), 3) if ch else None
r['cinza_herois_mediana'] = round(float(np.median(ch)), 3) if ch else None
r['cinza_inimigos_mediana'] = round(float(np.median(ci)), 3) if ci else None
blur = np.asarray(Image.fromarray((img * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(4))).astype(float) / 255
Lb = oklab(blur)[..., 0]
bh = contraste(Lb, her, 'her'); bi = contraste(Lb, ini, 'ini')
r['borrao_herois_lista'] = [round(x, 3) for x in bh]
r['borrao_herois_min'] = round(min(bh), 3) if bh else None
r['borrao_inimigos_mediana'] = round(float(np.median(bi)), 3) if bi else None
# miniatura 320x180: altura de cada herói em px e quantos se distinguem
mm = np.asarray(Image.fromarray((her * 255).astype(np.uint8)).resize((320, 180), Image.BILINEAR)) > 100
labm, nm = ndimage.label(ndimage.binary_dilation(mm, iterations=1))
alts = sorted([int(s[0].stop - s[0].start) for s in ndimage.find_objects(labm)])
r['miniatura_herois_contados'] = int(nm)
r['miniatura_alturas_px'] = alts
# daltonismo: ΔE OKLab mínimo entre as 4 cores de jogador
cores = np.array([hexrgb(h) for h in JOG.values()])
def dmin(c):
    l = oklab(c); d = [np.linalg.norm(l[i] - l[j]) for i in range(4) for j in range(i + 1, 4)]
    return round(float(min(d)), 3)
r['jogadores_dE_normal'] = dmin(cores)
r['jogadores_dE_deuteranopia'] = dmin(cvd(cores, DEU))
r['jogadores_dE_protanopia'] = dmin(cvd(cores, PRO))
cv = cvd(cores, DEU)
r['par_vermelhao_ouro'] = {'normal': round(float(np.linalg.norm(oklab(cores[0]) - oklab(cores[1]))), 3),
                           'deut': round(float(np.linalg.norm(oklab(cv[0]) - oklab(cv[1]))), 3),
                           'dL_valor': round(float(abs(oklab(cores[0])[0] - oklab(cores[1])[0])), 3)}
# semântica de cor: perigo (vermelhão de perigo) x verde dos mortos x vermelhão do jogador 1
pg, vd, j1 = hexrgb("#B5301F"), hexrgb("#A8D82A"), hexrgb("#D9472B")
r['perigo_x_verde_dE'] = round(float(np.linalg.norm(oklab(pg) - oklab(vd))), 3)
r['perigo_x_jogador1_dE'] = round(float(np.linalg.norm(oklab(pg) - oklab(j1))), 3)
r['perigo_x_jogador1_dL'] = round(float(abs(oklab(pg)[0] - oklab(j1)[0])), 3)
# paleta: pixel "da paleta" = perto de uma cor da paleta, ou mistura dela com a tinta (borda de linha)
P = np.array([hexrgb(h) for h in PAL]); Pl = oklab(P)
flat = lab.reshape(-1, 3)
d = np.min(np.linalg.norm(flat[:, None, :] - Pl[None], axis=2), axis=1)
ink = Pl[0]
best = np.full(len(flat), 9.0)
for k in range(1, len(PAL)):
    dv = Pl[k] - ink
    a = np.clip(((flat - ink) @ dv) / (dv @ dv), 0, 1)
    best = np.minimum(best, np.linalg.norm(flat - (ink + a[:, None] * dv), axis=1))
fora = (d > 0.045) & (best > 0.03)
r['fora_da_paleta_pct'] = round(float(fora.mean() * 100), 2)
V = img.max(axis=2)
r['V_min_mundo_pct'] = round(float(np.percentile(V, 0.01) * 100), 1)
r['pixels_abaixo_V11_pct'] = round(float((V < 0.11).mean() * 100), 3)
json.dump(r, open(out + '.json', 'w'), indent=1, ensure_ascii=False)
print(json.dumps(r, ensure_ascii=False))
# painel
def im(a): return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
g = np.repeat(L[..., None] / max(L.max(), 1e-3), 3, 2)
mini = im(img).resize((320, 180), Image.LANCZOS).resize((W, H), Image.NEAREST)
de = cvd(img.reshape(-1, 3), DEU).reshape(img.shape); pr = cvd(img.reshape(-1, 3), PRO).reshape(img.shape)
fz = img.copy().reshape(-1, 3); fz[fora] = [1, 0, 1]; fz = fz.reshape(img.shape)
tiles = [im(img), im(g), im(blur), mini, im(de), im(pr), im(fz)]
names = ['original', 'cinza (L OKLab)', 'borrao 4 px', 'miniatura 320x180', 'deuteranopia', 'protanopia', 'fora da paleta (magenta)']
w2, h2 = W // 2, H // 2
pan = Image.new('RGB', (w2 * 4, h2 * 2), (35, 28, 23))
from PIL import ImageDraw
dr = ImageDraw.Draw(pan)
for i, t in enumerate(tiles):
    x, y = (i % 4) * w2, (i // 4) * h2
    pan.paste(t.resize((w2, h2), Image.LANCZOS), (x, y))
    dr.rectangle([x, y, x + 230, y + 18], fill=(35, 28, 23)); dr.text((x + 4, y + 3), names[i], fill=(233, 223, 201))
txt = '\n'.join(f'{k}: {v}' for k, v in r.items())
dr.text((3 * w2 + 10, h2 + 10), txt, fill=(233, 223, 201))
pan.save(out + '.png')
