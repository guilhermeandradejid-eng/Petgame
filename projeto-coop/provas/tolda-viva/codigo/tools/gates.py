# Portões do contrato anti-slop sobre as capturas: cinza, miniatura 320x180, borrão, daltonismo,
# orçamento de valor/saturação, paleta e paridade entre renderers. Uso: python3 gates.py CAPDIR
import sys, os, json, itertools
import numpy as np
from PIL import Image, ImageFilter

C = sys.argv[1]
M = {  # Machado et al. 2009, severidade 1.0 (tabela do colour-science, colour/blindness/datasets/machado2010.py)
    'protanopia': np.array([[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]]),
    'deuteranopia': np.array([[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]]),
    'tritanopia': np.array([[1.255528, -0.076749, -0.178779], [-0.078411, 0.930809, 0.147602], [0.004733, 0.691367, 0.303900]]),
}
def s2l(c): return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
def l2s(c): c = np.clip(c, 0, 1); return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)
def oklab(rgb):  # rgb sRGB 0..1
    l = s2l(rgb)
    lms = l @ np.array([[0.4122214708, 0.5363325363, 0.0514459929], [0.2119034982, 0.6806995451, 0.1073969566], [0.0883024619, 0.2817188376, 0.6299787005]]).T
    lms = np.cbrt(lms)
    return lms @ np.array([[0.2104542553, 0.7936177850, -0.0040720468], [1.9779984951, -2.4285922050, 0.4505937099], [0.0259040371, 0.7827717662, -0.8086757660]]).T
def cvd(rgb, kind): return l2s(s2l(rgb) @ M[kind].T)
def load(p): return np.asarray(Image.open(p).convert('RGB')).astype(np.float32) / 255

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
    im = Image.fromarray((b * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(2 * r + 1))
    return np.asarray(im) > 127

def contrast(img, chars, anym, r):
    L = oklab(img)[..., 0]
    res = {}
    for k, sel in chars.items():
        if sel.sum() < 3: continue
        ring = dilate(sel, r) & ~anym
        if ring.sum() < 3: continue
        res[k] = float(abs(np.median(L[sel]) - np.median(L[ring])))
    return res

def hsv_stats(img, sel):
    mx = img.max(-1); mn = img.min(-1)
    v = mx[sel]; s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)[sel]
    return dict(V_med=round(float(np.median(v)) * 100), V_p10=round(float(np.percentile(v, 10)) * 100), V_p90=round(float(np.percentile(v, 90)) * 100),
                S_med=round(float(np.median(s)) * 100), S_p90=round(float(np.percentile(s, 90)) * 100))

def summarize(d):
    if not d: return None
    v = np.array(list(d.values()))
    return dict(min=round(float(v.min()), 3), med=round(float(np.median(v)), 3), n=len(v), n_below_0_10=int((v < 0.10).sum()))

R = {}
for sc in ('duo', 'stress'):
    for cam in ('stage', 'iso', 'camarote'):
        key = f'{sc}_{cam}'
        if not os.path.exists(os.path.join(C, f'mask_{sc}_{cam}.png')): continue
        mask = load(os.path.join(C, f'mask_{sc}_{cam}.png'))
        chars, anym = ids(mask)
        heroes = {k: v for k, v in chars.items() if k[0] == 'h'}
        ens = {k: v for k, v in chars.items() if k[0] == 'e'}
        r = {}
        for var in ('compat', 'fplus', 'compat_preta', 'compat_pardo'):
            p = os.path.join(C, f'{sc}_{cam}_{var}.png')
            if not os.path.exists(p): continue
            img = load(p)
            rr = {}
            rr['cinza_dL_herois'] = summarize(contrast(img, heroes, anym, 6))
            rr['cinza_dL_inimigos'] = summarize(contrast(img, ens, anym, 6))
            bl = np.asarray(Image.fromarray((img * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(4))).astype(np.float32) / 255
            rr['borrao_dL_herois'] = summarize(contrast(bl, heroes, anym, 6))
            rr['borrao_dL_inimigos'] = summarize(contrast(bl, ens, anym, 6))
            th = np.asarray(Image.fromarray((img * 255).astype(np.uint8)).resize((320, 180), Image.LANCZOS)).astype(np.float32) / 255
            tm = np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).resize((320, 180), Image.NEAREST)).astype(np.float32) / 255
            tch, tany = ids(tm)
            hts = {k: int(np.ptp(np.where(v.any(1))[0]) + 1) for k, v in tch.items() if v.sum() > 0}
            rr['mini_altura_px_herois'] = sorted([hts[k] for k in hts if k[0] == 'h'])
            rr['mini_altura_px_inimigos_med'] = float(np.median([hts[k] for k in hts if k[0] == 'e'])) if any(k[0] == 'e' for k in hts) else None
            rr['mini_dL_herois'] = summarize(contrast(th, {k: v for k, v in tch.items() if k[0] == 'h'}, tany, 2))
            rr['mini_dL_inimigos'] = summarize(contrast(th, {k: v for k, v in tch.items() if k[0] == 'e'}, tany, 2))
            fullh = {k: int(np.ptp(np.where(v.any(1))[0]) + 1) for k, v in heroes.items()}
            rr['altura_px_herois_720p'] = sorted(fullh.values())
            rr['orcamento'] = dict(fundo=hsv_stats(img, ~anym), herois=hsv_stats(img, np.any(list(heroes.values()), 0)) if heroes else None,
                                   inimigos=hsv_stats(img, np.any(list(ens.values()), 0)) if ens else None)
            # daltonismo: separação entre jogadores (média OKLab) e entre classes
            lab = oklab(img)
            for kind in ['normal'] + list(M):
                labk = lab if kind == 'normal' else oklab(cvd(img, kind))
                hm = {k: labk[v].mean(0) for k, v in heroes.items()}
                pairs = [float(np.linalg.norm(hm[a] - hm[b])) for a, b in itertools.combinations(sorted(hm), 2)]
                em = labk[np.any(list(ens.values()), 0)].mean(0) if ens else None
                he = [float(np.linalg.norm(hm[a] - em)) for a in hm] if em is not None else []
                rr[f'cvd_{kind}'] = dict(herois_par_min=round(min(pairs), 3) if pairs else None, heroi_vs_inimigo_min=round(min(he), 3) if he else None,
                                         dL_herois=summarize(contrast(l2s(s2l(img) @ M[kind].T) if kind != 'normal' else img, heroes, anym, 6)))
            r[var] = rr
        a, b = os.path.join(C, f'{sc}_{cam}_compat.png'), os.path.join(C, f'{sc}_{cam}_fplus.png')
        if os.path.exists(a) and os.path.exists(b):
            d = np.abs(load(a) - load(b)) * 255
            r['paridade'] = dict(dif_media=round(float(d.mean()), 2), pct_px_dif_maior_8=round(float((d.max(-1) > 8).mean() * 100), 2))
        R[key] = r
json.dump(R, open(os.path.join(C, 'gates.json'), 'w'), indent=1)
for k, v in R.items():
    print('==', k, v.get('paridade'))
    for var, rr in v.items():
        if var == 'paridade': continue
        print('  ', var, 'cinza H', rr['cinza_dL_herois'], 'E', rr['cinza_dL_inimigos'])
        print('      mini H', rr['mini_altura_px_herois'], rr['mini_dL_herois'], 'E alt', rr['mini_altura_px_inimigos_med'], rr['mini_dL_inimigos'])
        print('      borrao H', rr['borrao_dL_herois'], ' alt720', rr['altura_px_herois_720p'])
        print('      orc', rr['orcamento'])
        for kind in ['normal'] + list(M):
            print('      ', kind, rr[f'cvd_{kind}'])
