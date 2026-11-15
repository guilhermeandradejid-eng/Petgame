"""en_base.py: ajudantes compartilhados pelos inimigos (formas, cor, olhos, esqueleto em
Python puro, molas assadas na animacao, encaixe no chao).

Os inimigos usam so canais crus do anim.py: '<osso>' = (rx, ry, rz) em graus nos eixos da
armature, '<osso>.pos' = (esquerda, frente, cima) e '<osso>.scale'. Todos os ossos apontam
para +Z com roll zero, entao os eixos do osso coincidem com os da armature.
"""
import math
import random

import bpy  # noqa: F401  (precisa vir antes do mathutils)
from mathutils import Matrix, Quaternion, Vector

import anim
import lp
from lp import Geo, hexc, mixc

FPS = 30
I3 = Matrix.Identity(3)
ZUP = Vector((0, 0, 1))

# luz "lumen" compartilhada por todos os inimigos
LUMEN = hexc('#6ff2ff')
LUMEN_HOT = hexc('#d9fffb')
LUMEN_DEEP = hexc('#2f9fe0')
GLOW_LO = (0.05, 0.42, 0.62)    # cores para o material 'glow' (o shader multiplica por ~2,2)
GLOW_HI = (0.30, 0.80, 0.80)
DARK = hexc('#2a1f3a')      # olhos / bocas
SHADE = (0.60, 0.54, 0.80)  # multiplicador de sombra (frio/roxo)


def C(h):
    return hexc(h)


def cool(c, k=0.6):
    """Versao sombreada de uma cor: escurece puxando para o roxo."""
    return (c[0] * k * 0.92, c[1] * k * 0.84, min(1.0, c[2] * k * 1.16 + 0.02))


def warm(c, k=1.15):
    return (min(1.0, c[0] * k * 1.04), min(1.0, c[1] * k), min(1.0, c[2] * k * 0.92))


# --------------------------------------------------------------------------- cor
def paint(g, lo, hi, c_lo, c_hi, axis='z', power=1.0):
    """Gradiente absoluto (substitui a cor) ao longo de um eixo."""
    ai = 'xyz'.index(axis)

    def fn(p, _c):
        t = 0.0 if hi == lo else max(0.0, min(1.0, (p[ai] - lo) / (hi - lo)))
        return mixc(c_lo, c_hi, t ** power)
    return g.tint(fn)


def paint3(g, stops, axis='z'):
    """Gradiente absoluto com varias paradas [(valor, cor), ...]."""
    ai = 'xyz'.index(axis)

    def fn(p, _c):
        x = p[ai]
        if x <= stops[0][0]:
            return stops[0][1]
        for (a, ca), (b, cb) in zip(stops, stops[1:]):
            if x <= b:
                t = (x - a) / (b - a) if b > a else 1.0
                t = t * t * (3 - 2 * t)
                return mixc(ca, cb, t)
        return stops[-1][1]
    return g.tint(fn)


def under_shade(g, amount=1.0, c_lo=SHADE, bias=0.0):
    """Escurece (frio) o que olha para baixo: da volume mesmo sem luz."""
    ns = lp._vertex_normals(g)
    out = []
    for n, c in zip(ns, g.c):
        t = max(0.0, min(1.0, 0.5 - 0.5 * n.z + bias))
        t = t * t * (3 - 2 * t) * amount
        k = mixc((1, 1, 1), c_lo, t)
        out.append((c[0] * k[0], c[1] * k[1], c[2] * k[2]))
    g.c = out
    return g


def top_tint(g, color, thresh=0.55, soft=0.25, amount=1.0, noise=None):
    """Tinge o que olha para cima (musgo, poeira, luz)."""
    ns = lp._vertex_normals(g)
    out = []
    for p, n, c in zip(g.v, ns, g.c):
        t = (n.z - thresh) / soft
        if noise:
            t += noise(p)
        t = max(0.0, min(1.0, t)) * amount
        out.append(mixc(c, color, t))
    g.c = out
    return g


def speckle(g, amount=0.06, seed=0):
    """Variacao leve de valor por vertice (pintura a mao)."""
    rnd = random.Random(seed)
    out = []
    for c in g.c:
        k = 1.0 + rnd.uniform(-amount, amount)
        out.append((min(1, c[0] * k), min(1, c[1] * k), min(1, c[2] * k)))
    g.c = out
    return g


# --------------------------------------------------------------------------- formas
def outward(g, center=None):
    """Corrige a orientacao das faces de uma peca convexa (normal para fora do centro)."""
    if center is None:
        b0, b1 = g.bounds()
        center = Vector(((b0[0] + b1[0]) / 2, (b0[1] + b1[1]) / 2, (b0[2] + b1[2]) / 2))
    center = Vector(center)
    nf = []
    for f in g.f:
        cen = sum((g.v[i] for i in f), Vector()) / len(f)
        nrm = Vector()
        for i in range(len(f)):
            a, b = g.v[f[i]], g.v[f[(i + 1) % len(f)]]
            nrm += a.cross(b)
        nf.append(tuple(reversed(f)) if nrm.dot(cen - center) < 0 else f)
    g.f = nf
    return g


def cbox(sx, sy, sz, bevel=0.03, center=(0, 0, 0), taper=1.0, taper_y=None, mat='vcol'):
    """Caixa chanfrada (24 vertices), facetada. taper: escala do topo (x e y)."""
    hx, hy, hz = sx / 2, sy / 2, sz / 2
    b = min(bevel, hx * 0.45, hy * 0.45, hz * 0.45)
    g = Geo()
    idx = {}
    for sx_ in (-1, 1):
        for sy_ in (-1, 1):
            for sz_ in (-1, 1):
                idx[(sx_, sy_, sz_, 'x')] = g.add_vert((sx_ * hx, sy_ * (hy - b), sz_ * (hz - b)))
                idx[(sx_, sy_, sz_, 'y')] = g.add_vert((sx_ * (hx - b), sy_ * hy, sz_ * (hz - b)))
                idx[(sx_, sy_, sz_, 'z')] = g.add_vert((sx_ * (hx - b), sy_ * (hy - b), sz_ * hz))
    sq = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    for s in (-1, 1):
        g.add_face([idx[(s, a, c, 'x')] for a, c in sq], mat, False)
        g.add_face([idx[(a, s, c, 'y')] for a, c in sq], mat, False)
        g.add_face([idx[(a, c, s, 'z')] for a, c in sq], mat, False)
    for sa in (-1, 1):
        for sb in (-1, 1):
            g.add_face([idx[(sa, sb, -1, 'x')], idx[(sa, sb, 1, 'x')], idx[(sa, sb, 1, 'y')], idx[(sa, sb, -1, 'y')]],
                       mat, False)
            g.add_face([idx[(sa, -1, sb, 'x')], idx[(sa, 1, sb, 'x')], idx[(sa, 1, sb, 'z')], idx[(sa, -1, sb, 'z')]],
                       mat, False)
            g.add_face([idx[(-1, sa, sb, 'y')], idx[(1, sa, sb, 'y')], idx[(1, sa, sb, 'z')], idx[(-1, sa, sb, 'z')]],
                       mat, False)
    for sx_ in (-1, 1):
        for sy_ in (-1, 1):
            for sz_ in (-1, 1):
                g.add_face([idx[(sx_, sy_, sz_, 'x')], idx[(sx_, sy_, sz_, 'y')], idx[(sx_, sy_, sz_, 'z')]], mat, False)
    outward(g, (0, 0, 0))
    ty = taper if taper_y is None else taper_y
    if taper != 1.0 or ty != 1.0:
        def tw(p):
            t = (p.z + hz) / (2 * hz)
            return Vector((p.x * (1 + (taper - 1) * t), p.y * (1 + (ty - 1) * t), p.z))
        g.warp(tw)
    g.move(*center)
    return g


def crystal(r, h, n=6, tip=0.32, base=0.7, c_base=LUMEN_DEEP, c_tip=LUMEN_HOT, seed=0, skew=0.0,
            flat=0.8, glow_tip=False, mat='vcol', facet=0.22):
    """Cristal facetado ao longo de +Z (base em z=0), cada faceta com seu proprio tom."""
    rnd = random.Random(seed)
    g = Geo()
    zs = h * (1.0 - tip)
    ph = rnd.uniform(0, 1)
    ring0 = [(x * base, y * base * flat, 0.0) for x, y in lp.ring_pts(n, r, r, 0.0, ph)]
    ring1 = [(x + skew * 0.5, y * flat, zs * (1 + rnd.uniform(-0.06, 0.06))) for x, y in lp.ring_pts(n, r, r, 0.0, ph)]
    apex = (skew, rnd.uniform(-0.15, 0.15) * r, h)
    light = Vector((0.5, -0.6, 0.6)).normalized()
    c_mid = mixc(c_base, c_tip, 0.55)
    for i in range(n):
        j = (i + 1) % n
        a0, a1, b0, b1 = Vector(ring0[i]), Vector(ring0[j]), Vector(ring1[i]), Vector(ring1[j])
        nrm = (a1 - a0).cross(b0 - a0).normalized()
        k = 1.0 + facet * (nrm.dot(light)) + rnd.uniform(-0.07, 0.07)
        q = [g.add_vert(a0, c=lp.mulc(c_base, k)), g.add_vert(a1, c=lp.mulc(c_base, k)),
             g.add_vert(b1, c=lp.mulc(c_mid, k)), g.add_vert(b0, c=lp.mulc(c_mid, k))]
        g.add_face(q, mat, False)
        ap = Vector(apex)
        nrm2 = (b1 - b0).cross(ap - b0).normalized()
        k2 = 1.0 + facet * (nrm2.dot(light)) + rnd.uniform(-0.07, 0.07)
        tm = 'glow' if glow_tip else mat
        kk = 0.62 if glow_tip else 1.0
        t = [g.add_vert(b0, c=lp.mulc(c_mid, k2 * kk)), g.add_vert(b1, c=lp.mulc(c_mid, k2 * kk)),
             g.add_vert(ap, c=lp.mulc(c_tip, k2 * kk))]
        g.add_face(t, tm, False)
    # tampa de baixo (normalmente enterrada)
    ci = g.add_vert((0, 0, 0), c=c_base)
    ids = [g.add_vert(p, c=c_base) for p in ring0]
    for i in range(n):
        g.add_face((ci, ids[(i + 1) % n], ids[i]), mat, False)
    return g


def aim(g, direction, pos=(0, 0, 0), roll=0.0):
    """Gira a Geo para o eixo +Z apontar em `direction` e move para `pos`."""
    d = Vector(direction).normalized()
    q = ZUP.rotation_difference(d)
    m = q.to_matrix().to_4x4()
    if roll:
        m = m @ Matrix.Rotation(math.radians(roll), 4, 'Z')
    g.xf(Matrix.Translation(Vector(pos)) @ m)
    return g


def face_frame(normal, pos=(0, 0, 0), tilt=0.0):
    """Matriz que leva o -Y local para `normal` (Z local o mais para cima possivel)."""
    n = Vector(normal).normalized()
    up = ZUP - n * ZUP.dot(n)
    if up.length < 1e-4:
        up = Vector((0, -1, 0)) - n * Vector((0, -1, 0)).dot(n)
    up.normalize()
    x = (-n).cross(up)
    m = Matrix(((x.x, -n.x, up.x), (x.y, -n.y, up.y), (x.z, -n.z, up.z))).to_4x4()
    if tilt:
        m = m @ Matrix.Rotation(math.radians(tilt), 4, 'Y')
    return Matrix.Translation(Vector(pos)) @ m


def eye(pos, normal, rx, rz, depth=None, color=DARK, hl=(-0.3, 0.38, 0.30), hl2=None, tilt=0.0, n=10,
        hl_color=lp.WHITE, mat='vcol', cut_top=None):
    """Olho em relevo: cupula escura achatada com brilho branco.
    hl = (dx, dz, raio) em fracoes de rx/rz. cut_top: (altura_frac, inclinacao) corta o topo reto."""
    depth = depth or min(rx, rz) * 0.42
    g = lp.ellipsoid(rx, depth, rz, n=n, rings=6, mat=mat)
    g.keep_faces(lambda c: c.y < depth * 0.35)
    if cut_top is not None:
        hfrac, slope = cut_top

        def cut(p):
            lim = rz * hfrac + p.x * slope
            return Vector((p.x, p.y, min(p.z, lim)))
        g.warp(cut)
    g.color(color)
    paint_rim = cool(color, 1.5)
    g.tint(lambda p, c: mixc(c, paint_rim, max(0.0, min(1.0, (p.z / rz) * 0.5 + 0.15))))
    for h in (hl, hl2):
        if not h:
            continue
        hr = h[2]
        y = -depth * math.sqrt(max(0.0, 1.0 - h[0] ** 2 - h[1] ** 2)) - depth * 0.10
        s = lp.ellipsoid(rx * hr, depth * 0.35, rz * hr * (rx / rz) ** 0.5, n=8, rings=3, mat=mat,
                         center=(h[0] * rx, y, h[1] * rz))
        s.color(hl_color)
        g.add(s)
    g.xf(face_frame(normal, pos, tilt))
    return g


def ell_point(center, radii, x, z, front=True):
    """Ponto e normal na superficie de um elipsoide em (x, z)."""
    cx, cy, cz = center
    rx, ry, rz = radii
    u = (x - cx) / rx
    w = (z - cz) / rz
    k = max(0.0, 1.0 - u * u - w * w)
    y = ry * math.sqrt(k)
    p = Vector((x, cy - y if front else cy + y, z))
    nrm = Vector(((p.x - cx) / rx ** 2, (p.y - cy) / ry ** 2, (p.z - cz) / rz ** 2)).normalized()
    return p, nrm


def patch(pts3d, normal_off=0.0, color=lp.WHITE, mat='vcol', center=None):
    """Poligono em leque a partir de pontos 3D (com normais opcionais para afastar da superficie).
    pts3d: lista de Vector ou (Vector, normal)."""
    g = Geo()
    ps = []
    for it in pts3d:
        if isinstance(it, tuple) and len(it) == 2 and isinstance(it[1], Vector):
            ps.append(it[0] + it[1] * normal_off)
        else:
            ps.append(Vector(it))
    c = sum(ps, Vector()) / len(ps) if center is None else Vector(center)
    ci = g.add_vert(c, c=color)
    ids = [g.add_vert(p, c=color) for p in ps]
    for i in range(len(ids)):
        g.add_face((ci, ids[i], ids[(i + 1) % len(ids)]), mat)
    return g


def leaf(length, width, n=5, droop=40.0, fold=0.25, thickness=0.012, tip=0.12, base=0.25, belly=0.45,
         power=1.5):
    """Folha ao longo de +Z (nasce em z=0) que arqueia para -Y; a face de cima fica do lado +Y.
    Devolve (geo, pontos_da_nervura)."""
    rows = []
    spine = []
    p = Vector((0, 0, 0))
    seg = length / n
    for i in range(n + 1):
        t = i / n
        if t < belly:
            k = base + (1 - base) * math.sin(math.pi / 2 * t / belly)
        else:
            k = max(tip, math.cos((t - belly) / (1 - belly) * math.pi / 2) ** 0.8)
        w = width * 0.5 * k
        ang = math.radians(droop) * t ** power
        d = Vector((0, -math.sin(ang), math.cos(ang)))
        top = Vector((0, math.cos(ang), math.sin(ang)))
        lift = top * (w * fold)
        rows.append([p + Vector((w, 0, 0)) + lift, p.copy(), p + Vector((-w, 0, 0)) + lift])
        spine.append(p.copy())
        p = p + d * seg
    g = lp.sheet(rows, thickness=thickness)
    return g, spine


# --------------------------------------------------------------------------- esqueleto em Python
def B(name, parent, head, length=0.12):
    """Osso apontando para +Z (eixos alinhados com a armature)."""
    h = tuple(head)
    return (name, parent, h, (h[0], h[1], h[2] + length))


def is_r(name):
    return name.endswith('.R')


class Skel:
    """Cinematica direta igual a do Blender/Godot para os canais crus do anim.py."""

    def __init__(self, bones):
        self.order = [b[0] for b in bones]
        self.parent = {b[0]: b[1] for b in bones}
        self.head = {b[0]: Vector(b[2]) for b in bones}

    def vals(self, clip, frame):
        return {ch: clip.sample(ch, frame) for ch in clip.tracks}

    def fk(self, vals):
        """vals: {canal: (a, b, c)} -> {osso: matriz 4x4 de deformacao (pose @ rest^-1)}."""
        out = {}
        for b in self.order:
            h = self.head[b]
            m3 = anim.channel_quat(b, vals[b]).to_matrix() if b in vals else I3.copy()
            s = vals.get(b + '.scale')
            if s is not None:
                m3 = m3 @ Matrix.Diagonal(Vector(s))
            d = vals.get(b + '.pos')
            off = Vector((d[0], -d[1], d[2])) if d is not None else Vector()
            m = Matrix.Translation(h + off) @ m3.to_4x4() @ Matrix.Translation(-h)
            par = self.parent[b]
            out[b] = out[par] @ m if par else m
        return out

    def skin(self, g, mats):
        res = []
        for p, ws in zip(g.v, g.w):
            q = Vector()
            for b, w in ws.items():
                q += (mats[b] @ p) * w
            res.append(q)
        return res


def rotq(m):
    """Parte de rotacao (ortonormalizada) de uma matriz 4x4/3x3."""
    return m.to_3x3().normalized().to_quaternion() if abs(m.to_3x3().determinant()) > 1e-9 else Quaternion()


def q_to_raw(q, bone):
    """Quaternion (eixos da armature) -> valor (rx, ry, rz) do canal cru do osso."""
    e = q.to_euler('XYZ')
    m = -1.0 if is_r(bone) else 1.0
    return (math.degrees(e.x), m * math.degrees(e.y), m * math.degrees(e.z))


def set_track(clip, ch, values):
    clip.tracks[ch] = [(f, tuple(v), 'l') for f, v in enumerate(values)]


def add_fn(clip, ch, fn):
    """Soma fn(quadro) -> (a, b, c) ao canal (vira uma chave por quadro)."""
    base = (1.0, 1.0, 1.0) if ch.endswith('.scale') else (0.0, 0.0, 0.0)
    vals = []
    for f in range(clip.length + 1):
        v = clip.sample(ch, f) if ch in clip.tracks else base
        d = fn(f)
        vals.append((v[0] + d[0], v[1] + d[1], v[2] + d[2]))
    if clip.loop:
        vals[-1] = vals[0]
    set_track(clip, ch, vals)
    return clip


def shake(clip, ch, f0, f1, amp, freq=0.9, seed=0, grow=True):
    """Tremor aditivo entre os quadros f0 e f1 (cresce ate f1 se grow)."""
    rnd = random.Random(seed)
    ph = [rnd.uniform(0, math.tau) for _ in range(3)]

    def fn(f):
        if f <= f0 or f >= f1:
            return (0.0, 0.0, 0.0)
        t = (f - f0) / float(f1 - f0)
        env = (t if grow else math.sin(t * math.pi)) * min(1.0, (f1 - f) / 1.5)
        return tuple(amp[i] * env * math.sin(f * freq * math.tau / 2.0 * (1 + 0.13 * i) + ph[i]) for i in range(3))
    return add_fn(clip, ch, fn)


def spring(clip, sk, bone, tip, k=260.0, c=9.0, limit=65.0, wind=(0, 0, 0), settle=5, cycles=3, gain=1.0,
           floor=None):
    """Assa um atraso de mola no osso: a ponta `tip` (ponto no repouso, espaco da armature)
    segue com inercia o movimento que o resto do corpo ja tem. Para cadeias, chame da base
    para a ponta. wind: forca constante (esquerda, frente, cima) para folhas ao vento."""
    L = clip.length
    tipv = Vector(tip)
    head = sk.head[bone]
    par = sk.parent[bone]
    H, T, D, Q = [], [], [], []
    for f in range(L + 1):
        vals = sk.vals(clip, f)
        mats = sk.fk(vals)
        H.append(mats[bone] @ head)
        T.append(mats[bone] @ tipv)
        D.append(rotq(mats[par]) if par else Quaternion())
        Q.append(anim.channel_quat(bone, vals[bone]) if bone in vals else Quaternion())
    force = Vector((wind[0], -wind[1], wind[2]))
    seq = list(range(L + 1))
    if clip.loop:
        seq = list(range(L)) * cycles + [L]
    P = T[seq[0]].copy() + force / k
    V = Vector()
    sub = 4
    dt = 1.0 / FPS / sub
    res = {}
    prev = seq[0]
    for step, f in enumerate(seq):
        if step > 0:
            a, b = T[prev], T[f]
            if clip.loop and f == 0:
                a = T[L - 1]
            for s in range(1, sub + 1):
                tgt = a.lerp(b, s / sub)
                acc = (tgt - P) * k - V * c + force
                V += acc * dt
                P += V * dt
                if floor is not None and P.z < floor:
                    P.z = floor
                    V.z = max(V.z, 0.0)
                    V *= 0.9
        prev = f
        rigid = T[f] - H[f]
        want = P - H[f]
        if rigid.length < 1e-6 or want.length < 1e-6:
            w = Quaternion()
        else:
            w = rigid.rotation_difference(want)
            ang = w.angle * gain
            fade = 1.0
            if not clip.loop and settle and f > L - settle:
                fade = (L - f) / float(settle)
            ang = min(ang, math.radians(limit)) * fade
            w = Quaternion(w.axis, ang) if ang > 1e-6 else Quaternion()
        q = D[f].inverted() @ w @ D[f] @ Q[f]
        res[f] = q_to_raw(q, bone)
    vals = [res[f] for f in range(L + 1)]
    if clip.loop:
        vals[-1] = vals[0]
    set_track(clip, bone, vals)
    return clip


def place(sk, pose, bone, pivot, target, rot=(0, 0, 0)):
    """Ajusta pose[bone] e pose[bone+'.pos'] para o ponto `pivot` (repouso) do osso ir parar em
    `target` (espaco da armature, x esquerda / y tras / z cima) com rotacao absoluta `rot` (graus XYZ).
    Os pais precisam estar ja definidos em `pose`."""
    mats = sk.fk({ch: anim.as3(v) for ch, v in pose.items() if ch != bone and ch != bone + '.pos'})
    par = sk.parent[bone]
    dp = mats[par] if par else Matrix.Identity(4)
    rp = rotq(dp)
    qt = Quaternion(Vector((0, 0, 1)), math.radians(rot[2])) @ Quaternion(Vector((0, 1, 0)), math.radians(rot[1])) @ \
        Quaternion(Vector((1, 0, 0)), math.radians(rot[0]))
    q = rp.inverted() @ qt
    head = sk.head[bone]
    loc = dp.inverted() @ Vector(target)
    d = loc - head - q.to_matrix() @ (Vector(pivot) - head)
    pose[bone] = q_to_raw(q, bone)
    pose[bone + '.pos'] = (d.x, -d.y, d.z)
    return pose


def ground_fit(clip, sk, soles, bone='body', margin=0.0, only_up=False):
    """Sobe/desce `bone` (filho direto da raiz) quadro a quadro para o ponto de apoio mais baixo
    encostar no chao. soles: [(osso, ponto_no_repouso), ...]. O canal 'lift' soma altura."""
    ch = bone + '.pos'
    vals = []
    for f in range(clip.length + 1):
        v = sk.vals(clip, f)
        mats = sk.fk(v)
        low = min((mats[b] @ Vector(p)).z for b, p in soles)
        lift = clip.sample('lift', f)[0] if 'lift' in clip.tracks else 0.0
        cur = v.get(ch, (0.0, 0.0, 0.0))
        dz = -low + margin + lift
        if only_up and dz < 0:
            dz = 0.0
        vals.append((cur[0], cur[1], cur[2] + dz))
    if clip.loop:
        vals[-1] = vals[0]
    set_track(clip, ch, vals)
    return clip


# --------------------------------------------------------------------------- clipes
def clip(name, length, keys, loop=False, base=None):
    """Clip cru (ground=False). Todo canal usado ganha uma chave neutra no quadro 0."""
    b = {}
    for k in keys:
        for ch in k[1]:
            b[ch] = (1.0, 1.0, 1.0) if ch.endswith('.scale') else (0.0, 0.0, 0.0)
    if base:
        b.update(base)
    norm = []
    for k in keys:
        norm.append((k[0], dict(k[1]), k[2] if len(k) > 2 else 'io'))
    return anim.Clip(name, length, norm, loop=loop, base=b, ground=False)


def sym(pose):
    """Copia canais .L para .R (posicoes com x espelhado; rotacoes o anim.py ja espelha)."""
    out = dict(pose)
    for ch, v in pose.items():
        base, _, suf = ch.partition('.L')
        if '.L' in ch and (suf == '' or suf.startswith('.')):
            rch = base + '.R' + suf
            if rch in pose:
                continue
            if suf in ('.pos', '.ik', '.pole'):
                v = anim.as3(v)
                v = (-v[0], v[1], v[2])
            out[rch] = v
    return out


def mg(*dicts):
    out = {}
    for d in dicts:
        out.update(d)
    return out


def cyc(length, poses, ease='io'):
    """Chaves de um ciclo: [(quadro, pose)] -> lista de chaves (a ultima fecha sozinha no Clip)."""
    return [(f, p, ease) for f, p in poses]


def wave(f, period, amp, phase=0.0):
    return amp * math.sin(math.tau * (f / float(period) + phase))


def about(sk, bone, pivot, rot, extra=(0, 0, 0)):
    """Rotacao de um osso central em torno de `pivot` (ponto no repouso) em vez da cabeca do osso:
    devolve {osso: rot, osso.pos: compensacao + extra}. Vale para ossos cujo pai nao esta girado."""
    q = anim.channel_quat(bone, anim.as3(rot)).to_matrix()
    r = Vector(pivot) - sk.head[bone]
    d = r - q @ r
    return {bone: tuple(rot), bone + '.pos': (d.x + extra[0], -d.y + extra[1], d.z + extra[2])}


def mesh_low(sk, g, clip, frame, bones=None):
    """z mais baixo da malha deformada no quadro (bones: so vertices presos a esses ossos)."""
    mats = sk.fk(sk.vals(clip, frame))
    low = 1e9
    for p, ws in zip(g.v, g.w):
        if bones is not None and not any(b in bones for b in ws):
            continue
        z = 0.0
        for b, w in ws.items():
            z += (mats[b] @ p).z * w
        low = min(low, z)
    return low


def floor_fit(clip, sk, g, bone='body', f0=0, f1=None, mode='up', blend=0, bones=None):
    """Encosta a malha no chao entre os quadros f0..f1. mode 'up' so levanta o que afundou;
    'fit' cola o ponto mais baixo no chao. blend: quadros de entrada suave antes de f0."""
    f1 = clip.length if f1 is None else f1
    ch = bone + '.pos'
    vals = []
    dzs = {}
    for f in range(clip.length + 1):
        cur = clip.sample(ch, f) if ch in clip.tracks else (0.0, 0.0, 0.0)
        dz = 0.0
        if f0 <= f <= f1:
            low = mesh_low(sk, g, clip, f, bones)
            dz = -low if (mode == 'fit' or low < 0) else 0.0
        dzs[f] = dz
        vals.append(cur)
    if blend:
        for i in range(1, blend + 1):
            f = f0 - i
            if f >= 0:
                dzs[f] = dzs[f0] * (1.0 - i / float(blend + 1))
    vals = [(v[0], v[1], v[2] + dzs[f]) for f, v in enumerate(vals)]
    if clip.loop:
        vals[-1] = vals[0]
    set_track(clip, ch, vals)
    return clip


def lfu(p):
    """Ponto no espaco da armature -> (esquerda, frente, cima), a convencao dos canais .pos/.ik."""
    return (p[0], -p[1], p[2])


def ik_bake(clip, sk, upper, lower, end, space='world', pole=None, end_world=False, end_point=None):
    """IK de dois ossos assado quadro a quadro. O alvo da cabeca do osso `end` vem do canal
    '<end>.ik' = (esquerda, frente, cima): no espaco da armature (space='world') ou no espaco de
    repouso do pai de `upper` (space='parent'). pole: para onde o cotovelo/joelho aponta, dado para
    o lado esquerdo (espelhado em .R); o canal '<end>.pole' troca por chave.
    end_world: o osso `end` mantem a rotacao absoluta do canal '<end>.wrot' (ou reta)."""
    tch, pch, wch = end + '.ik', end + '.pole', end + '.wrot'
    if tch not in clip.tracks:
        return clip
    S, E = sk.head[upper], sk.head[lower]
    W = Vector(end_point) if end_point is not None else sk.head[end]
    l1, l2 = (E - S).length, (W - E).length
    par = sk.parent[upper]
    side = -1.0 if is_r(end) else 1.0
    ups, los, ends = [], [], []
    for f in range(clip.length + 1):
        vals = sk.vals(clip, f)
        t = vals[tch]
        T = Vector((t[0], -t[1], t[2]))
        if pch in vals:
            p = vals[pch]
            P = Vector((p[0], -p[1], p[2]))
        elif pole is not None:
            P = Vector((pole[0] * side, -pole[1], pole[2]))
        else:
            P = None
        dp = sk.fk(vals)[par] if par else Matrix.Identity(4)
        if space == 'world':
            T = dp.inverted() @ T
            if P is not None:
                P = dp.to_3x3().inverted() @ P
        if P is None:
            P = E - S       # mesma dobra do repouso
        v = T - S
        d = max(abs(l1 - l2) * 1.001 + 1e-4, min((l1 + l2) * 0.999, v.length))
        dirv = v.normalized() if v.length > 1e-6 else Vector((0, 0, -1))
        a = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
        h = math.sqrt(max(0.0, l1 * l1 - a * a))
        pp = P - dirv * P.dot(dirv)
        if pp.length < 1e-5:
            pp = dirv.orthogonal()
        pp.normalize()
        e2 = S + dirv * a + pp * h
        w2 = S + dirv * d
        q1 = (E - S).rotation_difference(e2 - S)
        q2 = (q1 @ (W - E)).rotation_difference(w2 - e2)
        qc = q1.inverted() @ q2 @ q1
        ups.append(q_to_raw(q1, upper))
        los.append(q_to_raw(qc, lower))
        if end_world:
            tot = rotq(dp) @ q1 @ qc
            qw = anim.channel_quat(end, vals[wch]) if wch in vals else Quaternion()
            ends.append(q_to_raw(tot.inverted() @ qw, end))
    if clip.loop:
        ups[-1], los[-1] = ups[0], los[0]
        if ends:
            ends[-1] = ends[0]
    set_track(clip, upper, ups)
    set_track(clip, lower, los)
    if ends:
        set_track(clip, end, ends)
    return clip


def brow_eye(p, n, sx, rx, rz, depth, cut=(0.5, 0.5), brow=None, hl=(-0.22, 0.02, 0.30), hl2=(0.22, -0.42, 0.14),
             eye_bone='eye', face_bone='body', color=DARK):
    """Olho bravo: cupula escura com o topo cortado em diagonal + sobrancelha grossa.
    p, n: ponto e normal na superficie; sx: +1 esquerdo, -1 direito.
    brow = (comprimento, espessura, cor, angulo_graus) ou None."""
    e = eye((0, 0, 0), (0, -1, 0), rx, rz, depth=depth, hl=hl, hl2=hl2, cut_top=(cut[0], cut[1] * sx), color=color)
    e.bind(eye_bone + ('.L' if sx > 0 else '.R'))
    if brow:
        ln, th, col, ang = brow
        bw = cbox(ln, th * 1.1, th, th * 0.28, center=(-0.05 * ln * sx, 0.0, rz * cut[0] + th * 0.52))
        bw.rot('Y', -ang * sx, (0, 0, rz * cut[0]))
        paint(bw, rz * cut[0] - th, rz * cut[0] + th * 1.5, cool(col, 0.85), warm(col, 1.1))
        bw.bind(face_bone)
        e.add(bw)
    e.xf(face_frame(n, Vector(p) - Vector(n) * 0.004))
    return e


def bind_chain(g, pts, bones, blend=0.3):
    """Pesos de um membro: pts = juntas (n+1 pontos), bones = n ossos. Mistura perto das juntas."""
    pts = [Vector(p) for p in pts]

    def fn(p):
        best = None
        for i in range(len(bones)):
            a, b = pts[i], pts[i + 1]
            ab = b - a
            t = (p - a).dot(ab) / ab.length_squared
            tc = max(0.0, min(1.0, t))
            d = (p - (a + ab * tc)).length
            if best is None or d < best[0]:
                best = (d, i, t)
        _, i, t = best
        ws = {bones[i]: 1.0}
        if t > 1.0 - blend and i + 1 < len(bones):
            k = min(1.0, (t - (1.0 - blend)) / blend) * 0.5
            ws = {bones[i]: 1.0 - k, bones[i + 1]: k}
        elif t < blend and i > 0:
            k = min(1.0, (blend - t) / blend) * 0.5
            ws = {bones[i]: 1.0 - k, bones[i - 1]: k}
        return ws
    return g.bind_fn(fn)


def gait(clip, ch, rest, phase, stride=0.3, lift=0.08, duty=0.5, side=0.0):
    """Trilha de um pe num ciclo de andar parado no lugar: apoio (desliza para tras) e passada
    (levanta e volta para a frente). rest = (esq, frente, cima) do pe; phase 0..1."""
    L = clip.length
    vals = []
    for f in range(L + 1):
        p = (f / float(L) + phase) % 1.0
        if p < duty:
            u = p / duty
            dy, dz = stride * (0.5 - u), 0.0
        else:
            u = (p - duty) / (1.0 - duty)
            s = u * u * (3 - 2 * u)
            dy, dz = stride * (-0.5 + s), lift * math.sin(math.pi * u)
        vals.append((rest[0] + side * dz * 0.3, rest[1] + dy, rest[2] + dz))
    vals[-1] = vals[0]
    set_track(clip, ch, vals)
    return clip
