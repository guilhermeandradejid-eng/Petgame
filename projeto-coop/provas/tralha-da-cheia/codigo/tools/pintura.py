# Pintura à mão por numpy, faceta por faceta (Tralha da Cheia).
# Cada faceta plana ganha uma ilha própria no atlas (projeção no plano dela), e cada texel sabe a sua posição 3D
# na pose de repouso. Assim os padrões (bolinhas, listras, escamas, folhas, faixas) são avaliados em 3D e
# continuam de uma faceta para a outra, como tinta passada depois do corte. Depois vêm:
#   - tremor de pincel (padrões com borda ondulada e estrias da cerda);
#   - tinta que falha nas arestas convexas mais expostas (distância real em metros até a aresta), mostrando o
#     miolo cru do miriti com poros;
#   - tinta estufada e descascada nos inimigos;
#   - alfa = distância até qualquer aresta da faceta (o shader usa para rachar a arma pelas facetas na Despedida).
import math
import numpy as np
from PIL import Image
import paleta as PAL

def C(name):
    return np.array(PAL.f(name), np.float32)

# ------------------------------------------------------------------ ruído 3D com semente
def _h(ix, iy, iz, seed):
    h = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (seed * 2654435761)
    h = (h ^ (h >> 13)) * 1274126177
    h = h ^ (h >> 16)
    return (h & 0xFFFFFF).astype(np.float32) / float(0xFFFFFF)

def vnoise(P, freq, seed=0):
    Q = P * freq
    i = np.floor(Q).astype(np.int64)
    f = Q - i
    f = f * f * (3 - 2 * f)
    out = 0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (f[:, 0] if dx else 1 - f[:, 0]) * (f[:, 1] if dy else 1 - f[:, 1]) * (f[:, 2] if dz else 1 - f[:, 2])
                out = out + w * _h(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz, seed)
    return out

def fbm(P, freq, seed=0, oct=3):
    a, s, t = 0.5, 0.0, 0.0
    for k in range(oct):
        s += a * vnoise(P, freq * (2 ** k), seed + 17 * k)
        t += a
        a *= 0.5
    return s / t

def cellhash(ci, seed, k=0):
    return _h(ci[:, 0], ci[:, 1], ci[:, 2], seed * 7 + k * 131)

# ------------------------------------------------------------------ padrões (devolvem máscara 0/1 por texel)
def pat_bolinhas(P, sp, seed):
    s = sp.get('s', 0.05)
    r = sp.get('r', 0.30)
    off = np.array(sp.get('off', (0.0, 0.0, 0.0)), np.float32)
    Q = (P - off) / s
    best = np.full(len(P), 9.0, np.float32)
    ci0 = np.floor(Q).astype(np.int64)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            for dz in (-1, 0, 1):
                ci = ci0 + np.array([dx, dy, dz])
                keep = cellhash(ci, seed, 9) < sp.get('dens', 0.55)
                j = np.stack([cellhash(ci, seed, 1), cellhash(ci, seed, 2), cellhash(ci, seed, 3)], -1) - 0.5
                c = ci + 0.5 + j * 0.5
                d = np.linalg.norm(Q - c, axis=1)
                rr = r * (0.8 + 0.4 * cellhash(ci, seed, 4))
                d = d / rr
                best = np.where(keep, np.minimum(best, d), best)
    trem = 0.10 * (vnoise(P, 90.0 / max(s, 0.01) * 0.05, seed + 5) - 0.5)
    return (best + trem < 1.0).astype(np.float32)

def pat_listras(P, sp, seed):
    s = sp.get('s', 0.05)
    a = np.array(sp.get('axis', (0, 0, 1)), np.float32)
    a = a / np.linalg.norm(a)
    w = sp.get('w', 0.45)
    t = P @ a / s + 0.18 * (vnoise(P, 6.0, seed) - 0.5) + 0.06 * (vnoise(P, 40.0, seed + 3) - 0.5)
    fr = t - np.floor(t)
    return (fr < w).astype(np.float32)

def pat_faixas(P, sp, seed):
    a = np.array(sp.get('axis', (0, 0, 1)), np.float32)
    a = a / np.linalg.norm(a)
    t = P @ a + 0.006 * (vnoise(P, 30.0, seed) - 0.5) * 2
    m = np.zeros(len(P), np.float32)
    for (h0, h1) in sp['bands']:
        m = np.maximum(m, ((t > h0) & (t < h1)).astype(np.float32))
    return m

def _cyl(P, sp):
    a = np.array(sp.get('axis', (0, 0, 1)), np.float32)
    a = a / np.linalg.norm(a)
    c = np.array(sp.get('center', (0, 0, 0)), np.float32)
    ref = np.array((1, 0, 0), np.float32) if abs(a[0]) < 0.9 else np.array((0, 1, 0), np.float32)
    e1 = np.cross(a, ref); e1 /= np.linalg.norm(e1)
    e2 = np.cross(a, e1)
    d = P - c
    th = np.arctan2(d @ e2, d @ e1)
    R = sp.get('R', 0.15)
    return th * R, d @ a

def pat_zigue(P, sp, seed):
    s = sp.get('s', 0.08)
    u, v = _cyl(P, sp)
    zs = sp.get('zs', 0.05)
    x = u / zs
    tri = np.abs(x - np.floor(x) - 0.5) * 2
    t = v / s + sp.get('amp', 0.35) * tri + 0.05 * (vnoise(P, 30.0, seed) - 0.5)
    fr = t - np.floor(t)
    return (fr < sp.get('w', 0.3)).astype(np.float32)

def pat_escamas(P, sp, seed):
    s = sp.get('s', 0.04)
    u, v = _cyl(P, sp)
    v = v / s + 0.08 * (vnoise(P, 30.0, seed) - 0.5)
    row = np.floor(v)
    u = u / s + 0.5 * (row % 2)
    fu = u - np.floor(u) - 0.5
    fv = v - row
    d = np.sqrt(fu * fu + (fv - 1.0) ** 2)   # arco em U voltado para baixo
    line = np.abs(d - 0.62) < sp.get('lw', 0.07)
    return (line & (fv < 0.98)).astype(np.float32)

def pat_folhas(P, sp, seed):
    s = sp.get('s', 0.08)
    u, v = _cyl(P, sp)
    U, V = u / s, v / s
    best = np.zeros(len(P), np.float32)
    mid = np.zeros(len(P), np.float32)
    i0, j0 = np.floor(U).astype(np.int64), np.floor(V).astype(np.int64)
    for di in (-1, 0, 1):
        for dj in (-1, 0, 1):
            ci = np.stack([i0 + di, j0 + dj, np.zeros_like(i0)], -1)
            cx = ci[:, 0] + 0.5 + 0.5 * (cellhash(ci, seed, 1) - 0.5)
            cy = ci[:, 1] + 0.5 + 0.5 * (cellhash(ci, seed, 2) - 0.5)
            an = cellhash(ci, seed, 3) * math.pi
            dx, dy = U - cx, V - cy
            x = dx * np.cos(an) + dy * np.sin(an)
            y = -dx * np.sin(an) + dy * np.cos(an)
            L = 0.55
            inside = (np.abs(x) < L) & (np.abs(y) < 0.2 * (1 - (x / L) ** 2) + 1e-4)
            best = np.maximum(best, inside.astype(np.float32))
            mid = np.maximum(mid, (inside & (np.abs(y) < 0.025)).astype(np.float32))
    return best, mid

def seg_dist3(P, a, b):
    a = np.array(a, np.float32); b = np.array(b, np.float32)
    ab = b - a
    t = np.clip(((P - a) @ ab) / max(1e-9, ab @ ab), 0, 1)
    return np.linalg.norm(P - (a + t[:, None] * ab), axis=1)

def apply_marks(col, P, marks, seed):
    for mk in marks:
        kind = mk[0]
        if kind == 'traco':  # polilinha 3D com largura (boca, sobrancelha, número, risco)
            pts, w, cname = mk[1], mk[2], mk[3]
            d = np.full(len(P), 9.0, np.float32)
            for a, b in zip(pts[:-1], pts[1:]):
                d = np.minimum(d, seg_dist3(P, a, b))
            d = d + 0.25 * w * (vnoise(P, 200.0, seed) - 0.5)
            m = d < w
            col[m] = C(cname)
        elif kind == 'disco':
            c, r, cname = mk[1], mk[2], mk[3]
            d = np.linalg.norm(P - np.array(c, np.float32), axis=1)
            d = d + 0.12 * r * (vnoise(P, 150.0, seed + 1) - 0.5)
            m = d < r
            col[m] = C(cname)
    return col

# ------------------------------------------------------------------ a tinta de uma peça
def paint(sp, P, d_wear, rng_seed):
    seed = sp.get('seed', 1) + rng_seed
    N = len(P)
    raw = C('miriti')
    # miolo cru: creme com poros finos e veio leve
    pore = vnoise(P, 520.0, seed + 11)
    grain = vnoise(P * np.array([1, 1, 0.12], np.float32), 160.0, seed + 12)
    rawc = raw[None, :] * (0.97 + 0.05 * grain[:, None])
    rawc = np.where((pore > 0.80)[:, None], rawc * 0.86, rawc)
    if sp.get('cru'):
        base = C(sp['base']) if sp['base'] != 'miriti' else raw
        col = base[None, :] * (0.95 + 0.07 * grain[:, None])
        col = np.where((pore > 0.80)[:, None], col * 0.88, col)
        return col
    col = np.repeat(C(sp['base'])[None, :], N, 0)
    # tinta antiga por baixo (descascado dos Inchados)
    if sp.get('descasca', 0) > 0:
        n = fbm(P, sp.get('desc_f', 7.0), seed + 21)
        thr = 1.0 - sp['descasca']
        under = C(sp.get('sob', 'miriti'))
        m = n > thr
        rim = (n > thr - 0.025) & ~m
        col = np.where(m[:, None], under[None, :] * (0.95 + 0.07 * grain[:, None]), col)
        col = np.where(rim[:, None], col * 0.72, col)
    pat = sp.get('pat')
    if pat:
        pats = pat if isinstance(pat, list) else [pat]
        subs = sp.get('pats', [sp]) if isinstance(pat, list) else [sp]
        for k, p in enumerate(pats):
            q = dict(sp); q.update(subs[k] if k < len(subs) else {})
            c1 = C(q.get('c1', 'miriti'))
            if p == 'bolinhas':
                m = pat_bolinhas(P, q, seed + k)
            elif p == 'listras':
                m = pat_listras(P, q, seed + k)
            elif p == 'faixas':
                m = pat_faixas(P, q, seed + k)
            elif p == 'zigue':
                m = pat_zigue(P, q, seed + k)
            elif p == 'escamas':
                m = pat_escamas(P, q, seed + k)
            elif p == 'folhas':
                m, mid = pat_folhas(P, q, seed + k)
                col = np.where(m[:, None] > 0, c1[None, :], col)
                m = mid
                c1 = C(q.get('c2', 'tinta'))
            else:
                m = np.zeros(N, np.float32)
            col = np.where(m[:, None] > 0, c1[None, :], col)
    if sp.get('marks'):
        col = apply_marks(col, P, sp['marks'], seed)
    # estrias da cerda: o pincel passou numa direção por peça
    bd = np.array(sp.get('brush', (0.3, 0.2, 0.93)), np.float32)
    bd /= np.linalg.norm(bd)
    ortho = P - (P @ bd)[:, None] * bd[None, :]
    st = vnoise(ortho, 220.0, seed + 31) * 0.6 + vnoise(P, 30.0, seed + 32) * 0.4
    col = col * (0.955 + 0.075 * st[:, None])
    # mancha de água e sujeira (cenário)
    if sp.get('mancha', 0) > 0:
        n = fbm(P, 5.0, seed + 41)
        col = col * (1 - sp['mancha'] * np.clip((n - 0.5) * 3, 0, 1)[:, None] * 0.3)
    # tinta que falha nas arestas expostas: mostra o miriti cru
    wear = sp.get('wear', 0.5)
    if wear > 0:
        wn = vnoise(P, 14.0, seed + 51) * 0.7 + vnoise(P, 60.0, seed + 52) * 0.3
        thr = wear * 0.024 * np.clip((wn - 0.5) / 0.5, 0, 1) ** 0.8 * sp.get('wear_w', 1.0)
        chip = d_wear < thr
        rim = (d_wear < thr + 0.0016) & ~chip & (thr > 0.002)
        col = np.where(rim[:, None], col * 0.78, col)
        col = np.where(chip[:, None], rawc, col)
    return col

# ------------------------------------------------------------------ atlas
def _seg_dist2(px, py, a, b):
    abx, aby = b[0] - a[0], b[1] - a[1]
    L2 = max(1e-12, abx * abx + aby * aby)
    t = np.clip(((px - a[0]) * abx + (py - a[1]) * aby) / L2, 0, 1)
    qx, qy = a[0] + t * abx - px, a[1] + t * aby - py
    return np.sqrt(qx * qx + qy * qy)

def bake(B, out_png, dens=600.0, W=2048, maxH=4096, pad=3, crease=30.0, seed=0):
    """Pinta todas as facetas de B (Builder) num atlas e grava as UVs. Devolve (densidade usada, tamanho)."""
    bm = B.bm
    pcl = B.pc
    bm.faces.ensure_lookup_table()
    bm.normal_update()
    faces = [f for f in bm.faces if f[pcl] >= 0]
    cos_cr = math.cos(math.radians(crease))
    info = []
    for f in faces:
        n = f.normal.copy()
        vs = [v.co.copy() for v in f.verts]
        # aresta mais longa como eixo u
        best, L = 0, -1
        for i in range(len(vs)):
            l = (vs[(i + 1) % len(vs)] - vs[i]).length
            if l > L:
                L, best = l, i
        t1 = (vs[(best + 1) % len(vs)] - vs[best]).normalized()
        t2 = n.cross(t1).normalized()
        o = vs[0]
        p2 = [((v - o).dot(t1), (v - o).dot(t2)) for v in vs]
        flags = []
        cen = f.calc_center_median()
        for lo in f.loops:
            e = lo.edge
            others = [g for g in e.link_faces if g is not f and g[pcl] == f[pcl]]
            if not others:
                flags.append(True)
            else:
                g = others[0]
                convex = (g.calc_center_median() - cen).dot(n) < -1e-6
                flags.append(bool(convex and n.dot(g.normal) < cos_cr))
        xs = [p[0] for p in p2]; ys = [p[1] for p in p2]
        info.append((f, o, t1, t2, p2, flags, min(xs), min(ys), max(xs), max(ys)))
    while True:
        rects = []
        for k, it in enumerate(info):
            w = int(math.ceil((it[8] - it[6]) * dens)) + 2 * pad
            h = int(math.ceil((it[9] - it[7]) * dens)) + 2 * pad
            rects.append((h, w, k))
        rects.sort(reverse=True)
        pos = {}
        x = y = rowh = 0
        for h, w, k in rects:
            if x + w > W:
                x = 0; y += rowh; rowh = 0
            pos[k] = (x, y)
            x += w; rowh = max(rowh, h)
        H = y + rowh
        if H <= maxH:
            break
        dens *= 0.85
    H = int(2 ** math.ceil(math.log2(max(H, 64))))
    img = np.zeros((H, W, 4), np.float32)
    img[..., :3] = C('miriti')
    uv = B.uv
    for k, (f, o, t1, t2, p2, flags, x0, y0, x1, y1) in enumerate(info):
        sp = B.specs[f[pcl]]
        ox, oy = pos[k]
        w = int(math.ceil((x1 - x0) * dens)) + 2 * pad
        h = int(math.ceil((y1 - y0) * dens)) + 2 * pad
        cx = x0 + (np.arange(w, dtype=np.float32) - pad + 0.5) / dens
        cy = y0 + (np.arange(h, dtype=np.float32) - pad + 0.5) / dens
        gx, gy = np.meshgrid(cx, cy)
        gx = gx.ravel(); gy = gy.ravel()
        O = np.array(o, np.float32); T1 = np.array(t1, np.float32); T2 = np.array(t2, np.float32)
        P = O[None, :] + gx[:, None] * T1[None, :] + gy[:, None] * T2[None, :]
        dw = np.full(len(gx), 9.0, np.float32)
        da = np.full(len(gx), 9.0, np.float32)
        n = len(p2)
        for i in range(n):
            d = _seg_dist2(gx, gy, p2[i], p2[(i + 1) % n])
            da = np.minimum(da, d)
            if flags[i]:
                dw = np.minimum(dw, d)
        col = paint(sp, P, dw, seed)
        a = np.clip(da / 0.03, 0, 1)
        img[oy:oy + h, ox:ox + w, :3] = col.reshape(h, w, 3)
        img[oy:oy + h, ox:ox + w, 3] = a.reshape(h, w)
        for i, lo in enumerate(f.loops):
            u = (ox + pad + (p2[i][0] - x0) * dens) / W
            v = (oy + pad + (p2[i][1] - y0) * dens) / H
            lo[uv].uv = (u, 1.0 - v)
    Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8), 'RGBA').save(out_png)
    return dens, (W, H)
