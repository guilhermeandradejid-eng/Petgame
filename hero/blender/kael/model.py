"""Kael's body, face, hair, outfit and sword. Every part is an analytic loft written into a Builder.

Character space = Blender space: +Z up, the character faces -Y, +X is the character's left.
"""
from math import sin, cos, pi, radians, sqrt, exp, asin, degrees
from mathutils import Vector, Matrix, Quaternion
from .geo import Builder, Curve, catmull, tangents, hring, fring, sym_phis, ss, lerp
from . import facetex
from . import skel

EXTRA = []          # dynamic chains: dict(name, parent, points[list of Vector]) -> bones name1..nameN
NORMAL_FIX = {}     # part name -> fn(p, n) -> n


# ----------------------------------------------------------------------------
# helpers
# ----------------------------------------------------------------------------
def ellipsoid(b, c, r, mat, w, rot=None, M=12, rows=8, fn=None, tile=None):
    c = Vector(c)
    rot = rot or Matrix.Identity(3)
    rings = []
    for i in range(1, rows):
        th = pi * i / rows
        ring = []
        for j in range(M):
            ph = 2 * pi * j / M
            p = c + rot @ Vector((r[0] * sin(th) * cos(ph), r[1] * sin(th) * sin(ph), r[2] * cos(th)))
            ring.append(fn(p) if fn else p)
        rings.append(ring)
    g = b.loft(rings, mat, caps=(False, False), w=w, tile=tile, vs=[i / float(rows) for i in range(1, rows)])
    top, bot = c + rot @ Vector((0, 0, r[2])), c + rot @ Vector((0, 0, -r[2]))
    b.cap(g[0], mat, center=fn(top) if fn else top, w=w, uv=b.tile_uv(tile, 0.5, 0.0) if tile else None)
    b.cap(g[-1], mat, center=fn(bot) if fn else bot, w=w, uv=b.tile_uv(tile, 0.5, 1.0) if tile else None)
    return g


def chain_w(names, u):
    """Blend weights along a bone chain; u in [0,1] from chain root to tip."""
    n = len(names)
    x = max(0.0, min(n - 1.0, u * n - 0.5))
    i = min(int(x), n - 2) if n > 1 else 0
    if n == 1:
        return {names[0]: 1.0}
    t = ss(0.2, 0.8, x - i)
    w = {}
    if t < 0.999:
        w[names[i]] = 1.0 - t
    if t > 0.001:
        w[names[i + 1]] = t
    return w


def mixw(a, b, t):
    """Blend two weight dicts."""
    out = {}
    for k, v in a.items():
        out[k] = out.get(k, 0.0) + v * (1 - t)
    for k, v in b.items():
        out[k] = out.get(k, 0.0) + v * t
    return {k: v for k, v in out.items() if v > 1e-4}


def add_chain(name, parent, pts):
    """Register a spring chain of len(pts)-1 bones."""
    EXTRA.append(dict(name=name, parent=parent, pts=[Vector(p) for p in pts]))
    return ["%s%d" % (name, i + 1) for i in range(len(pts) - 1)]


def tube(b, path, radii, mat, w=None, M=10, squash=1.0, up=Vector((0, 0, 1)), caps=(True, True), wfn=None, n=2.0,
         tile=None, umap=None):
    """Round tube along a path; radii: list or fn(s). wfn(s, p) -> weights. tile: unwrap (u around, v along)."""
    T = tangents(path)
    k = len(path) - 1
    prev_u = None
    grid, rows = [], []
    for i, (p, t) in enumerate(zip(path, T)):
        s = i / k
        ref = up if prev_u is None else prev_u
        u = (ref - t * ref.dot(t))
        if u.length < 1e-5:
            u = t.orthogonal()
        u.normalize()
        v = t.cross(u).normalized()
        prev_u = u
        r = radii(s) if callable(radii) else radii[i]
        pts = fring(p, u, v, r, r * squash, n=n, M=M)
        ww = wfn(s, p) if wfn else w
        grid.append(b.ring(pts, ww))
        if tile:
            rows.append([b.tile_uv(tile, umap(j / float(M)) if umap else j / float(M), s) for j in range(M + 1)])
    for i, (a, c) in enumerate(zip(grid, grid[1:])):
        b.strip(a, c, mat, uv0=rows[i] if tile else None, uv1=rows[i + 1] if tile else None)
    if caps[0]:
        b.cap(grid[0], mat, uv=rows[0][0] if tile else None)
    if caps[1]:
        b.cap(grid[-1], mat, uv=rows[-1][0] if tile else None)
    return grid


# ----------------------------------------------------------------------------
# head
# ----------------------------------------------------------------------------
PHIS = sym_phis([0, 4, 9, 16, 25, 36, 48, 61, 75, 90, 105, 120, 135, 150, 165, 180])
#               z       a      y_front  y_back  nf    nb
HEAD = Curve([
    (1.3550, 0.0100, -0.0820, -0.0620, 2.0, 2.0),
    (1.3590, 0.0210, -0.0875, -0.0460, 2.0, 2.0),
    (1.3660, 0.0335, -0.0895, -0.0200, 2.0, 2.0),
    (1.3760, 0.0465, -0.0900, 0.0180, 2.0, 2.0),
    (1.3880, 0.0590, -0.0910, 0.0520, 2.1, 2.0),
    (1.4020, 0.0705, -0.0920, 0.0800, 2.25, 2.0),
    (1.4200, 0.0810, -0.0918, 0.0990, 2.45, 2.0),
    (1.4400, 0.0890, -0.0910, 0.1110, 2.6, 2.0),
    (1.4600, 0.0940, -0.0902, 0.1190, 2.6, 2.0),
    (1.4800, 0.0965, -0.0900, 0.1220, 2.5, 2.0),
    (1.5000, 0.0975, -0.0890, 0.1230, 2.35, 2.0),
    (1.5200, 0.0965, -0.0860, 0.1200, 2.2, 2.0),
    (1.5400, 0.0920, -0.0800, 0.1130, 2.1, 2.0),
    (1.5600, 0.0830, -0.0690, 0.1000, 2.0, 2.0),
    (1.5780, 0.0680, -0.0520, 0.0800, 2.0, 2.0),
    (1.5920, 0.0450, -0.0290, 0.0520, 2.0, 2.0),
    (1.5985, 0.0200, -0.0050, 0.0260, 2.0, 2.0),
])
HEAD_Z = [1.355, 1.357, 1.360, 1.364, 1.369, 1.375, 1.381, 1.387, 1.393, 1.399, 1.404, 1.408, 1.411, 1.4135, 1.416,
          1.420, 1.425, 1.431, 1.438, 1.446, 1.455, 1.465, 1.476, 1.488, 1.500, 1.512, 1.524, 1.536, 1.548, 1.560,
          1.571, 1.581, 1.589, 1.595, 1.5985]
FACE_C = Vector((0.0, 0.03, 1.455))


def nose_amp(z):
    if z >= 1.4135:
        return 0.0125 * ss(1.460, 1.4135, z) ** 1.25
    return 0.0125 * ss(1.4035, 1.4135, z)


def head(b):
    b.begin("head", outline=0.5)
    rings = []
    for z in HEAD_Z:
        a, yf, yb, nf, nb = HEAD(z)
        cy = (yf + yb) * 0.5
        pts = hring(z, a, cy - yf, yb - cy, cy, nf, nb, phis=PHIS)
        for p in pts:
            if p.y < cy:
                p.y -= nose_amp(z) * exp(-(p.x / 0.0085) ** 2)                       # small sharp nose
                p.y += 0.0040 * exp(-((abs(p.x) - 0.042) / 0.024) ** 2 - ((z - 1.449) / 0.022) ** 2)   # eye sockets
                p.y -= 0.0018 * exp(-(p.x / 0.016) ** 2 - ((z - 1.386) / 0.007) ** 2)  # lips
        rings.append(pts)

    def mat(i, j):
        a, c = PHIS[j], PHIS[(j + 1) % len(PHIS)]
        front = (a <= 75 or a >= 285) and (c <= 75 or c >= 285)
        return "face" if front and HEAD_Z[i] < 1.565 else "skin"

    b.loft(rings, mat, w={"head": 1.0}, uvfn=lambda i, j, p: facetex.face_uv(p.x, p.z))
    # ears
    for sx in (1, -1):
        R = Matrix.Rotation(radians(-18 * sx), 3, "Z") @ Matrix.Rotation(radians(8 * sx), 3, "Y")
        ellipsoid(b, (0.0965 * sx, 0.022, 1.449), (0.0075, 0.017, 0.027), "skin", {"head": 1.0}, R, M=10, rows=6)
    b.end()

    def fix(p, n):
        if p.y > 0.06:
            return n
        s = (p - FACE_C)
        s.z *= 0.45
        s.normalize()
        k = 0.82 * ss(0.06, 0.0, p.y)
        return (n * (1 - k) + s * k).normalized()
    NORMAL_FIX["head"] = fix

    b.begin("neck", outline=0.7)
    rings = [hring(z, r, r, r * 1.05, cy, M=14) for z, r, cy in
             ((1.255, 0.046, 0.010), (1.29, 0.041, 0.011), (1.33, 0.038, 0.012), (1.37, 0.037, 0.013), (1.41, 0.038, 0.014))]
    b.loft(rings, "skin", caps=(False, False))
    b.end(skel.w_torso)


# ----------------------------------------------------------------------------
# hair: locks that run over the scalp from the crown and hang free past the hairline
# ----------------------------------------------------------------------------
HC = Vector((0.0, 0.016, 1.492))
HR = Vector((0.110, 0.120, 0.122))


def sdir(az, el):
    a, e = radians(az), radians(el)
    return Vector((cos(e) * sin(a), -cos(e) * cos(a), sin(e)))


def on_shell(d, r=1.0):
    return HC + Vector((HR.x * d.x, HR.y * d.y, HR.z * d.z)) * r


def sh(az, el, r=1.0):
    return on_shell(sdir(az, el), r)


CLUMP_SECTION = [(-1.0, 0.0), (-0.62, 0.60), (0.0, 0.86), (0.62, 0.60), (1.0, 0.0), (0.55, -0.26), (0.0, -0.34),
                 (-0.55, -0.26)]
CLUMP_U = [0.04 + 0.42 * (x + 1.0) for x, y in CLUMP_SECTION[:5]] + [0.955, 0.955, 0.955, 0.955]


def clump(b, exit_azel, tip, w, bulge=0.012, roll=0.0, r_off=0.0, lift=0.03, n=16, thick=0.24, crown=(180.0, 80.0),
          start=0.16, mid=None, wfn=None, taper=0.35, mat="hair", tip_pow=1.35):
    """A lock of hair: runs over the scalp from the crown to the hairline, then hangs free down to `tip`."""
    dK, dE = sdir(*crown), sdir(*exit_azel)
    ctrl = []
    for s in (start, 0.42, 0.68, 0.88, 1.0):
        d = dK.slerp(dE, s)
        ctrl.append(on_shell(d, 1.0 + r_off + lift * sin(pi * s)))
    E, T = ctrl[-1], Vector(tip)
    if mid is None:
        m = E.lerp(T, 0.5)
        o = m - HC
        o.z = 0.0
        m = m + o.normalized() * bulge
    else:
        m = Vector(mid)
    ctrl += [m, T]
    seg = [0.0]
    for p, q in zip(ctrl, ctrl[1:]):
        seg.append(seg[-1] + (q - p).length)
    s_exit = seg[4] / seg[-1]
    path = catmull(ctrl, n)
    T_ = tangents(path)
    grid, rows = [], []
    out_prev = None
    for i, (p, t) in enumerate(zip(path, T_)):
        s = i / n
        out = p - HC
        out -= t * out.dot(t)
        if out.length < 1e-4:
            out = out_prev.copy()
        out.normalize()
        out_prev = out
        B = t.cross(out).normalized()
        N = B.cross(t).normalized()
        if roll:
            R = Matrix.Rotation(radians(roll) * ss(0.0, 0.6, s), 3, t)
            B, N = R @ B, R @ N
        st = s_exit + taper * (1 - s_exit)
        if s <= st:
            f = lerp(0.55, 1.0, ss(0.0, max(s_exit * 0.7, 0.05), s))
        else:
            u = (s - st) / (1 - st)
            f = max(1.0 - u ** tip_pow, 0.0)
        hw = max(w * 0.5 * f, 0.0009)
        hh = max(w * 0.5 * thick * f ** 0.6, 0.0008)
        pts = [p + B * (x * hw) + N * (y * hh) for x, y in CLUMP_SECTION]
        ww = wfn(s, s_exit, p) if wfn else {"head": 1.0}
        grid.append(b.ring(pts, ww))
        rows.append([b.tile_uv("hair", u, s) for u in CLUMP_U])
    for i, (a, c) in enumerate(zip(grid, grid[1:])):
        b.strip(a, c, mat, uv0=rows[i], uv1=rows[i + 1])
    b.cap(grid[0], mat, uv=rows[0][2])
    b.cap(grid[-1], mat, uv=rows[-1][2])
    for a, c in zip(grid, grid[1:]):
        b.mark_sharp(a[0], c[0])
        b.mark_sharp(a[4], c[4])
    return path, s_exit


def hair(b):
    b.begin("hair", outline=0.8)
    # scalp cap
    M, rows = 32, 9

    def elmin(az):
        a = abs(((az + 180) % 360) - 180)
        return Curve([(0, 31), (40, 28), (70, 12), (90, 2), (110, -10), (140, -24), (180, -30)])(a)[0]

    rings = []
    for i in range(1, rows + 1):
        t = i / rows
        rings.append([on_shell(sdir(360.0 * j / M, 90 - t * (90 - elmin(360.0 * j / M))), 0.965) for j in range(M)])
    g = b.loft(rings, "hair", caps=(False, False), w={"head": 1.0}, tile="haircap", vs=[i / float(rows) for i in range(1, rows + 1)])
    b.cap(g[0], "hair", center=on_shell(Vector((0, 0, 1)), 0.965), w={"head": 1.0}, uv=b.tile_uv("haircap", 0.5, 0.0))

    def dyn(bone, k=0.85):
        return lambda s, se, p: mixw({"head": 1.0}, {bone: 1.0}, k * ss(se, 1.0, s))

    # fringe: parted over the left eye and swept across the forehead; eyes and brows stay readable
    fr = [
        # exit (az, el)  tip (x, y, z)              width  roll  bone      mid (x, y, z) or None
        ((28, 38), (-0.050, -0.1030, 1.4800), 0.060, 10, "bang.C", (-0.008, -0.1190, 1.5060)),
        ((15, 37), (-0.016, -0.1085, 1.4600), 0.044, 8, "bang.C", (0.006, -0.1175, 1.4990)),
        ((-22, 37), (-0.083, -0.0810, 1.4700), 0.052, 12, "bang.R", (-0.062, -0.1065, 1.5070)),
        ((-52, 30), (-0.1010, -0.0500, 1.4440), 0.042, 12, "bang.R", None),
        ((41, 36), (0.071, -0.0920, 1.4900), 0.048, -10, "bang.L", (0.060, -0.1045, 1.5160)),
        ((60, 28), (0.0985, -0.0560, 1.4560), 0.042, -12, "bang.L", None),
        ((24, 39), (0.011, -0.1125, 1.4380), 0.020, 0, "bang.C", (0.020, -0.1205, 1.4950)),
        ((-6, 39), (-0.038, -0.1100, 1.4930), 0.018, 0, "bang.R", (-0.026, -0.1200, 1.5180)),
    ]
    add_chain("bang.C", "head", [sh(22, 37), Vector(fr[1][1])])
    add_chain("bang.L", "head", [sh(48, 32), Vector(fr[4][1])])
    add_chain("bang.R", "head", [sh(-37, 33), Vector(fr[2][1])])
    for k, (ex, tip, w, roll, bone, mid) in enumerate(fr):
        clump(b, ex, tip, w, bulge=0.010, roll=roll, r_off=0.004 * (k % 3) + (0.012 if w < 0.03 else 0.0),
              wfn=dyn(bone + "1"), mid=mid, taper=0.05, tip_pow=1.15 if w < 0.03 else 1.35)
    # face-framing locks in front of the ears (spring chains); the left one is longer and carries a clip
    for sx, name, zt, wd in ((1, "lock.L", 1.362, 0.036), (-1, "lock.R", 1.388, 0.034)):
        ex = (79 * sx, 12)
        tip = (0.086 * sx, -0.058, zt)
        E = sh(*ex)
        mid = Vector((0.1045 * sx, -0.042, 1.432))
        bones = add_chain(name, "head", [E, mid, Vector(tip)])

        def wl(s, se, p, bones=bones):
            u = (s - se) / (1 - se)
            return {"head": 1.0} if u <= 0 else mixw({"head": 1.0}, chain_w(bones, u), ss(0.0, 0.25, u))
        clump(b, ex, tip, wd, mid=mid, roll=-14 * sx, r_off=0.008, wfn=wl, taper=0.1)
        clump(b, (92 * sx, 8), (0.1010 * sx, -0.012, 1.405), 0.022, bulge=0.010, roll=-8 * sx, r_off=0.014, taper=0.05,
              tip_pow=1.1)
        clump(b, (102 * sx, 2), (0.1035 * sx, 0.036, 1.388), 0.046, bulge=0.012, roll=10 * sx, r_off=0.002)
    # back of the head: two rows of spiky layered ends
    for k, (ex, taz, tel, tr) in enumerate([((122, 14), 129, -13, 1.17), ((150, 16), 155, -19, 1.20),
                                            ((180, 18), 182, -24, 1.22), ((210, 16), 205, -19, 1.20),
                                            ((238, 14), 231, -13, 1.17)]):
        clump(b, ex, sh(taz, tel, tr), 0.060, bulge=0.012, roll=(9 if k % 2 else -9), r_off=0.010, taper=0.15)
    back = [((126, -10), (0.097, 0.086, 1.368)), ((149, -18), (0.068, 0.134, 1.348)),
            ((169, -22), (0.027, 0.154, 1.334)), ((191, -22), (-0.023, 0.155, 1.339)),
            ((213, -18), (-0.066, 0.135, 1.353)), ((236, -10), (-0.097, 0.089, 1.373))]
    for k, (ex, tip) in enumerate(back):
        clump(b, ex, tip, 0.058, bulge=0.016, roll=(8 if k % 2 else -8), r_off=0.004 * (k % 2), taper=0.25)
    # crown layer tufts break the dome; thin flyaways break the outline
    for k, (ex, taz, tel, tr) in enumerate([((32, 58), 20, 44, 1.10), ((-38, 56), -52, 40, 1.10),
                                            ((112, 42), 122, 18, 1.12), ((-116, 42), -130, 16, 1.12),
                                            ((172, 36), 178, 8, 1.13), ((75, 50), 86, 30, 1.11),
                                            ((-78, 50), -90, 28, 1.11), ((-5, 60), -8, 46, 1.09),
                                            ((148, 30), 152, 2, 1.12), ((-150, 30), -156, 0, 1.12)]):
        clump(b, ex, sh(taz, tel, tr), 0.050, bulge=0.004, r_off=0.012, lift=0.045, n=12, taper=0.1)
    for ex, taz, tel, tr in (((178, 50), 182, 28, 1.26), ((100, 30), 113, 4, 1.20), ((-104, 30), -118, 2, 1.21),
                             ((140, 20), 150, -8, 1.24), ((-142, 20), -152, -10, 1.25)):
        clump(b, ex, sh(taz, tel, tr), 0.016, bulge=0.002, r_off=0.02, lift=0.05, n=10, taper=0.0, tip_pow=1.0, thick=0.5)
    # a few bigger spikes lift off the crown towards the back, so the top is not a smooth dome
    for k, (ex, taz, tel, tr) in enumerate([((165, 62), 172, 40, 1.24), ((-170, 60), -176, 36, 1.27),
                                            ((128, 56), 140, 34, 1.22), ((-132, 56), -146, 32, 1.23),
                                            ((60, 64), 74, 46, 1.15), ((-56, 64), -72, 46, 1.15)]):
        clump(b, ex, sh(taz, tel, tr), 0.046, bulge=0.003, r_off=0.016, lift=0.06, n=12, taper=0.05, tip_pow=1.15)
    # ahoge
    K = sh(180, 84, 1.0)
    ah = [K + Vector((0.0, -0.006, 0.004)), K + Vector((0.003, -0.022, 0.022)), K + Vector((0.009, -0.046, 0.026)),
          K + Vector((0.014, -0.062, 0.014))]
    add_chain("ahoge", "head", [ah[0], ah[-1]])
    tri = lambda t: 0.04 + 0.84 * (1.0 - abs(2.0 * t - 1.0))
    tube(b, catmull(ah, 10), lambda s: 0.0052 * (1 - s * s) ** 0.6 + 0.0005, "hair", M=6, squash=0.55,
         wfn=lambda s, p: mixw({"head": 1.0}, {"ahoge1": 1.0}, ss(0.0, 0.5, s)), tile="hair", umap=tri)
    # low ponytail tied with a crimson ribbon
    pp = [Vector((0.0, 0.126, 1.418)), Vector((0.0, 0.150, 1.362)), Vector((0.003, 0.166, 1.292)),
          Vector((0.006, 0.170, 1.212))]
    bones = add_chain("pony", "head", pp)
    tube(b, catmull(pp, 18), lambda s: 0.0215 * (ss(-0.25, 0.2, s)) * max(1 - s ** 1.7, 0.0) ** 0.7 + 0.001, "hair",
         M=8, squash=0.8, up=Vector((1, 0, 0)), wfn=lambda s, p: mixw({"head": 1.0}, chain_w(bones, s), ss(0.0, 0.1, s)),
         tile="hair", umap=tri)
    b.end()
    b.begin("ribbon", outline=0.7)
    ellipsoid(b, (0.0, 0.129, 1.405), (0.021, 0.016, 0.011), "crimson", {"head": 1.0}, M=10, rows=6)
    for sx in (1, -1):
        R = Matrix.Rotation(radians(-25 * sx), 3, "Y")
        ellipsoid(b, (0.026 * sx, 0.136, 1.411), (0.026, 0.006, 0.014), "crimson", {"head": 1.0}, R, M=8, rows=6)
        tube(b, catmull([Vector((0.010 * sx, 0.136, 1.400)), Vector((0.030 * sx, 0.150, 1.350)),
                         Vector((0.038 * sx, 0.156, 1.300))], 6), lambda s: 0.010 * (1 - 0.5 * s), "crimson",
             w={"head": 0.5, "pony1": 0.5}, M=6, squash=0.25, up=Vector((0, 1, 0)))
    # hair clip on the long lock
    cp = sh(79, 12).lerp(Vector((0.1045, -0.042, 1.432)), 0.45) + Vector((0.006, -0.004, 0.0))
    Rc = Matrix.Rotation(radians(-12), 3, "Y")
    ellipsoid(b, cp, (0.007, 0.013, 0.021), "gold", {"head": 1.0}, Rc, M=8, rows=6)
    ellipsoid(b, cp + Vector((0.005, -0.004, 0.0)), (0.005, 0.006, 0.008), "glow", {"head": 1.0}, Rc, M=8, rows=5)
    b.end()


# ----------------------------------------------------------------------------
# torso: cream tunic under an indigo jacket with gold trim
# ----------------------------------------------------------------------------
#                z      a      bf     bb     cy     n
TORSO = Curve([
    (0.860, 0.112, 0.078, 0.086, 0.004, 2.3),
    (0.900, 0.130, 0.086, 0.094, 0.005, 2.4),
    (0.950, 0.124, 0.082, 0.088, 0.005, 2.4),
    (1.000, 0.110, 0.074, 0.076, 0.004, 2.3),
    (1.060, 0.117, 0.079, 0.076, 0.002, 2.3),
    (1.120, 0.131, 0.087, 0.080, 0.000, 2.4),
    (1.180, 0.145, 0.093, 0.086, 0.000, 2.5),
    (1.230, 0.149, 0.090, 0.088, 0.002, 2.5),
    (1.270, 0.139, 0.078, 0.084, 0.005, 2.4),
    (1.300, 0.098, 0.062, 0.070, 0.008, 2.2),
    (1.320, 0.060, 0.050, 0.054, 0.010, 2.0),
    (1.345, 0.047, 0.045, 0.048, 0.011, 2.0),
])


def frange(a, b, n):
    return [a + (b - a) * i / n for i in range(n + 1)]


def torso(b):
    b.begin("tunic")
    zs = frange(0.860, 1.345, 30)
    rings = []
    for z in zs:
        a, bf, bb, cy, n = TORSO(z)
        rings.append(hring(z, a, bf, bb, cy, n, n, M=24))
    b.loft(rings, "cream", caps=(True, False), tile="tunic")
    b.end(skel.w_torso)

    # jacket: C-shaped shell, open down the front, flared hem, stand-up collar
    b.begin("jacket")
    open_x = Curve([(0.905, 0.020), (0.955, 0.005), (0.995, 0.005), (1.10, 0.022), (1.20, 0.044), (1.30, 0.050),
                    (1.340, 0.040)])
    zs = [0.905, 0.917] + frange(0.93, 1.30, 24) + [1.312, 1.326, 1.340]
    K = 26
    rings = []
    for z in zs:
        a, bf, bb, cy, n = TORSO(z)
        off = 0.009 + 0.016 * ss(0.955, 0.905, z) + 0.006 * ss(1.305, 1.34, z)
        ao = a + off
        x0 = open_x(z)[0]
        p0 = degrees(asin(min(1.0, (x0 / ao)) ** (n / 2)))
        p1 = degrees(asin(min(1.0, ((x0 + 0.013) / ao)) ** (n / 2)))
        angs = [p0, p1] + [p1 + (360 - 2 * p1) * k / (K - 3) for k in range(1, K - 3)] + [360 - p1, 360 - p0]
        outer = hring(z, ao, bf + off, bb + off, cy, n, n, phis=angs)
        inner = hring(z, ao - 0.007, bf + off - 0.007, bb + off - 0.007, cy, n, n, phis=angs)
        rings.append(outer + inner[::-1])
    nz = len(zs)

    def mat(i, j):
        if j >= K - 1:
            return "coat" if j in (K - 1, 2 * K - 1) else "crimson"
        if j in (0, K - 2) or i == 0 or i >= nz - 2:
            return "gold"
        return "coat"
    us = [0.5 * k / (K - 1.0) for k in range(K)] + [0.5 + 0.5 * m / (K - 1.0) for m in range(K)] + [1.0]
    g = b.loft(rings, mat, caps=(False, False), tile="coat", us=us, vs=[(z - 0.905) / 0.435 for z in zs],
               tile_mats=("coat", "crimson"))
    for row, m in ((g[0], "gold"), (g[-1], "gold")):
        for j in range(K - 1):
            b.face((row[j], row[j + 1], row[2 * K - 2 - j], row[2 * K - 1 - j]), m)
    b.end(skel.w_torso)

    # belt + buckle + hip gem
    b.begin("belt")
    rings = []
    for z, off in ((0.952, 0.010), (0.956, 0.019), (0.992, 0.019), (0.996, 0.010)):
        a, bf, bb, cy, n = TORSO(z)
        rings.append(hring(z, a + off + 0.009, bf + off + 0.009, bb + off + 0.009, cy, n, n, M=24))
    b.loft(rings, "leather", caps=(False, False), sharp_rings=(1, 2), tile="belt", vs=[0.0, 0.12, 0.88, 1.0])
    a, bf, bb, cy, n = TORSO(0.974)
    yb = cy - bf - 0.028
    for hw, hh, m, dy in ((0.030, 0.026, "gold", 0.0), (0.017, 0.014, "dark", -0.004), (0.010, 0.008, "glow", -0.007)):
        ellipsoid(b, (0.0, yb - 0.004 + dy, 0.974), (hw, 0.009, hh), m, None, M=10, rows=6)
    gc = Vector((0.108, -0.066, 0.962))
    R = Matrix.Rotation(radians(52), 3, "Z")
    ellipsoid(b, gc, (0.027, 0.011, 0.027), "gold", None, R, M=12, rows=6)
    ellipsoid(b, gc + R @ Vector((0, -0.006, 0)), (0.019, 0.011, 0.019), "glow", None, R, M=12, rows=6)
    R = Matrix.Rotation(radians(-150), 3, "Z")
    ellipsoid(b, (-0.085, 0.085, 0.94), (0.034, 0.02, 0.034), "leather", None, R, M=10, rows=6)
    ellipsoid(b, (-0.092, 0.097, 0.955), (0.03, 0.012, 0.016), "leather", None, R, M=8, rows=5)
    b.end(skel.w_torso)

    # scabbard on the left hip, slung back
    b.begin("scabbard")
    m0, d = Vector((0.128, 0.040, 0.962)), Vector((0.10, 0.60, -0.79)).normalized()
    path = [m0 + d * (0.84 * i / 16.0) for i in range(17)]
    tube(b, path, lambda s: (0.021 if s < 0.9 else 0.021 * max(1 - ((s - 0.9) / 0.1) ** 2, 0.05) ** 0.5) * (1 - 0.3 * s),
         "coat", w={"hips": 1.0}, M=10, squash=0.5, up=Vector((1, 0, 0.2)), tile="scabbard")
    for t in (0.03, 0.19):
        c = m0 + d * (0.84 * t)
        tube(b, [c + Vector((0, 0, 0.0)), c + Vector((-0.012, -0.022, 0.030)), c + Vector((-0.020, -0.036, 0.040))],
             [0.008, 0.007, 0.006], "leather", w={"hips": 1.0}, M=6, squash=0.5)
    b.end()


# ----------------------------------------------------------------------------
# arms, hands
# ----------------------------------------------------------------------------
def axis_loft(b, origin, d, u, st, ts, mat, M=14, n=2.0, caps=(True, True), sharp_rings=(), flip=False, tile=None,
              tile_mats=None):
    v = d.cross(u).normalized()
    rings = []
    for t in ts:
        vals = st(t)
        r1 = vals[0]
        r2 = vals[1] if len(vals) > 1 else r1
        rings.append(fring(origin + d * t, u, v, r1, r2, n=n, M=M, flip=flip))
    vs = [(t - ts[0]) / (ts[-1] - ts[0]) for t in ts]
    return b.loft(rings, mat, caps=caps, sharp_rings=sharp_rings, tile=tile, vs=vs, tile_mats=tile_mats)


def arm(b, sx):
    S = "L" if sx > 0 else "R"
    sh_, d = skel.shoulder(sx), skel.arm_dir(sx)
    u = Vector((0, -1, 0))
    fl = sx < 0
    b.begin("sleeve." + S)
    st = Curve([(-0.040, 0.030), (-0.022, 0.050), (0.0, 0.0585), (0.05, 0.057), (0.12, 0.0495), (0.20, 0.0455),
                (0.255, 0.0445), (0.30, 0.0460), (0.345, 0.0485)])
    ts = [-0.040, -0.032, -0.022, -0.010] + frange(0.0, 0.345, 22)
    axis_loft(b, sh_, d, u, st, ts, "coat", M=16, caps=(True, False), flip=fl, tile="sleeve")
    cu = Curve([(0.300, 0.0465), (0.306, 0.0560), (0.348, 0.0590), (0.356, 0.0590), (0.362, 0.0545), (0.350, 0.0400)])
    tsc = [0.300, 0.306, 0.320, 0.334, 0.348, 0.356, 0.362]
    vv = d.cross(u).normalized()
    rings = [fring(sh_ + d * t, u, vv, cu(t)[0], cu(t)[0], M=16, flip=fl) for t in tsc]
    rings.append(fring(sh_ + d * 0.350, u, vv, 0.040, 0.040, M=16, flip=fl))
    b.loft(rings, lambda i, j: "gold" if i >= 4 and i < 6 else ("dark" if i >= 6 else "cream"), caps=(False, True),
           sharp_rings=(1, 4, 5))
    b.end(skel.w_arm(sx))

    b.begin("bracer." + S)
    st = Curve([(0.325, 0.0345), (0.36, 0.0375), (0.42, 0.0345), (0.47, 0.0300), (0.492, 0.0285)])
    ts = frange(0.325, 0.492, 12)
    axis_loft(b, sh_, d, u, st, ts, "leather", M=14, caps=(False, False), flip=fl, tile="bracer")
    for t in (0.395, 0.484):
        r = st(t)[0] + 0.0028
        rings = [fring(sh_ + d * (t + dt), u, vv, rr, rr, M=14, flip=fl)
                 for dt, rr in ((-0.008, r - 0.004), (-0.006, r), (0.006, r), (0.008, r - 0.004))]
        b.loft(rings, "gold", caps=(False, False))
    b.end(skel.w_arm(sx))
    hand(b, sx)


FINGERS = [  # base x, base y, radius, phalanges
    (0.086, 0.0265, 0.0088, (0.036, 0.023, 0.018)),
    (0.088, 0.0090, 0.0092, (0.040, 0.025, 0.019)),
    (0.085, -0.0085, 0.0088, (0.037, 0.023, 0.018)),
    (0.079, -0.0245, 0.0078, (0.029, 0.018, 0.016)),
]
CURL_RELAX = [(14, 26, 18), (20, 32, 22), (26, 38, 26), (30, 42, 28)]
CURL_GRIP = [(84, 86, 48), (85, 86, 50), (86, 86, 50), (88, 84, 48)]


def hand(b, sx):
    S = "L" if sx > 0 else "R"
    X, Y, Z = skel.hand_frame(sx)
    W = skel.wrist(sx)
    grip = sx < 0
    ct, st_ = cos(radians(skel.GRIP_TILT)), sin(radians(skel.GRIP_TILT))
    gx, gy = skel.GRIP_LOCAL[0], skel.GRIP_LOCAL[1]

    def P(x, y, z):
        if grip:        # fingers wrap the handle, which lies diagonally across the palm
            dx, dy = x - gx, y - gy
            x, y = gx + dx * ct + dy * st_, gy - dx * st_ + dy * ct
        return W + X * x + Y * y + Z * z

    def P0(x, y, z):
        return W + X * x + Y * y + Z * z

    b.begin("hand." + S, outline=0.75)
    w = {"hand." + S: 1.0}
    pal = Curve([(-0.016, 0.0190, 0.0150), (0.0, 0.0220, 0.0165), (0.022, 0.0290, 0.0165), (0.048, 0.0350, 0.0150),
                 (0.072, 0.0375, 0.0135), (0.088, 0.0360, 0.0115), (0.094, 0.0300, 0.0085)])
    rings = [fring(P0(x, 0.001, 0.0), Y, Z, pal(x)[0], pal(x)[1], n=3.0, M=14)
             for x in (-0.016, -0.006, 0.006, 0.022, 0.040, 0.058, 0.074, 0.086, 0.094)]
    b.loft(rings, "skin", w=w)
    curls = CURL_GRIP if grip else CURL_RELAX
    for (bx, by, r, ph), cu in zip(FINGERS, curls):
        p = Vector((bx - 0.004, by, 0.0))
        ctrl = [Vector((bx - 0.016, by, 0.0)), p.copy()]
        ang = 0.0
        splay = by * 0.10 * (0.2 if grip else 1.0)
        for L, c in zip(ph, cu):
            ang += radians(c)
            dirv = Vector((cos(ang), splay, -sin(ang)))
            mid = p + dirv * (L * 0.5)
            p = p + dirv * L
            ctrl += [mid, p.copy()]
        path = [P(*c) for c in catmull(ctrl, 14)]
        tube(b, path, lambda s, r=r: r * (1.0 - 0.22 * s) * (1.0 if s < 0.93 else 0.80), "skin", w=w, M=8, up=Z)
    if grip:
        tc = [(0.022, 0.024, -0.004), (0.046, 0.040, -0.014), (0.070, 0.037, -0.032), (0.074, 0.020, -0.044),
              (0.066, 0.004, -0.046)]
    else:
        tc = [(0.022, 0.024, -0.004), (0.046, 0.042, -0.010), (0.066, 0.050, -0.016), (0.082, 0.052, -0.024)]
    path = [P(*c) for c in catmull([Vector(c) for c in tc], 12)]
    tube(b, path, lambda s: 0.0108 * (1.0 - 0.22 * s) * (1.0 if s < 0.93 else 0.8), "skin", w=w, M=8, up=Z)
    b.end()


def pauldron(b):
    b.begin("pauldron")
    sh_, d = skel.shoulder(1), skel.arm_dir(1)
    w = {"clavicle.L": 0.45, "upper_arm.L": 0.55}
    up = Vector((d.z * -1, 0, d.x))          # perpendicular to the arm, pointing up/out
    R = Matrix((d, Vector((0, -1, 0)), up)).transposed()
    c = sh_ + d * 0.018 + up * 0.030
    ellipsoid(b, c, (0.082, 0.074, 0.040), "coat", w, R, M=14, rows=8, tile="pauldron")
    ellipsoid(b, c - up * 0.012, (0.0850, 0.0770, 0.020), "gold", w, R, M=14, rows=6)
    c2 = sh_ + d * 0.075 + up * 0.018
    ellipsoid(b, c2, (0.060, 0.066, 0.034), "coat", w, R, M=12, rows=8, tile="pauldron")
    ellipsoid(b, c2 - up * 0.011, (0.0630, 0.0690, 0.017), "gold", w, R, M=12, rows=6)
    ellipsoid(b, sh_ + d * 0.01 + up * 0.064, (0.016, 0.016, 0.012), "glow", w, R, M=10, rows=6)
    b.end()


# ----------------------------------------------------------------------------
# legs, boots
# ----------------------------------------------------------------------------
#               z      a      b      cx     cy
LEG = Curve([
    (0.910, 0.068, 0.082, 0.068, 0.004),
    (0.850, 0.0770, 0.089, 0.0790, 0.002),
    (0.780, 0.0750, 0.085, 0.0825, 0.000),
    (0.680, 0.0675, 0.076, 0.0840, -0.002),
    (0.580, 0.0600, 0.067, 0.0848, -0.003),
    (0.500, 0.0545, 0.060, 0.0850, -0.004),
    (0.470, 0.0530, 0.058, 0.0850, -0.006),
    (0.430, 0.0505, 0.056, 0.0860, -0.002),
    (0.350, 0.0470, 0.053, 0.0870, 0.004),
])
#                z      a      cy       yf      yb     nf   nb   (relative to the ankle at y=0.010)
BOOT = Curve([
    (0.010, 0.0440, -0.090, -0.200, 0.062, 2.2, 2.6),
    (0.030, 0.0462, -0.092, -0.203, 0.064, 2.2, 2.6),
    (0.048, 0.0445, -0.085, -0.193, 0.063, 2.2, 2.5),
    (0.062, 0.0415, -0.066, -0.162, 0.061, 2.1, 2.4),
    (0.078, 0.0395, -0.040, -0.118, 0.058, 2.0, 2.3),
    (0.095, 0.0385, -0.018, -0.080, 0.055, 2.0, 2.2),
    (0.115, 0.0385, -0.004, -0.058, 0.052, 2.0, 2.1),
    (0.140, 0.0390, 0.000, -0.049, 0.050, 2.0, 2.0),
    (0.200, 0.0410, 0.002, -0.046, 0.050, 2.0, 2.0),
    (0.280, 0.0465, 0.004, -0.049, 0.058, 2.0, 2.0),
    (0.350, 0.0495, 0.003, -0.053, 0.060, 2.0, 2.0),
    (0.405, 0.0520, 0.002, -0.057, 0.060, 2.0, 2.0),
])


def leg(b, sx):
    S = "L" if sx > 0 else "R"
    ph16 = [(sx * 360.0 * j / 16) % 360.0 for j in range(16)]      # mirrored unwrap: u = .25 is always the outer side
    ph18 = [(sx * 360.0 * j / 18) % 360.0 for j in range(18)]
    b.begin("leg." + S)
    zs = frange(0.910, 0.350, 30)
    rings = []
    for z in zs:
        a, bb, cx, cy = LEG(z)
        rings.append(hring(z, a, bb, bb, cy, 2.0, 2.0, cx=cx * sx, phis=ph16))
    b.loft(rings, "pants", caps=(True, True), tile="pants", vs=[(z - 0.35) / 0.56 for z in zs])
    if sx < 0:      # thigh strap + small pouch on the right leg
        srs = []
        for z, off in ((0.705, 0.002), (0.708, 0.008), (0.732, 0.008), (0.735, 0.002)):
            a, bb, cx, cy = LEG(z)
            srs.append(hring(z, a + off, bb + off, bb + off, cy, 2.0, 2.0, cx=cx * sx, M=16))
        b.loft(srs, "leather", caps=(False, False), sharp_rings=(1, 2))
        ellipsoid(b, (-0.150, 0.0, 0.705), (0.018, 0.032, 0.040), "leather", None, M=10, rows=6)
        ellipsoid(b, (-0.166, 0.0, 0.722), (0.006, 0.012, 0.012), "gold", None, M=8, rows=5)
    b.end(skel.w_leg(sx))

    b.begin("boot." + S)
    ax, ay = 0.088 * sx, 0.010
    zs = [0.010, 0.020, 0.030, 0.040, 0.048, 0.055, 0.062, 0.070, 0.078, 0.086, 0.095, 0.105, 0.115, 0.127, 0.140,
          0.165, 0.200, 0.24, 0.28, 0.315, 0.35, 0.38, 0.405]
    rings = []
    for z in zs:
        a, cy, yf, yb, nf, nb = BOOT(z)
        rings.append(hring(z, a, cy - yf, yb - cy, ay + cy, nf, nb, cx=ax, phis=ph18, ab=a * (0.80 if z < 0.07 else 1.0)))
    b.loft(rings, "leather", caps=(True, True), tile="boot", vs=[z / 0.405 for z in zs])
    a, cy, yf, yb, nf, nb = BOOT(0.010)
    srs = [hring(z, a + o, cy - yf + o, yb - cy + o, ay + cy, nf, nb, cx=ax, M=18, ab=(a + o) * 0.80)
           for z, o in ((0.0, 0.002), (0.004, 0.005), (0.013, 0.005), (0.016, 0.001))]
    b.loft(srs, "dark", caps=(True, True), sharp_rings=(1, 2))
    crs = []
    for z, o in ((0.372, 0.002), (0.378, 0.012), (0.428, 0.015), (0.436, 0.013), (0.440, 0.004), (0.425, -0.004)):
        a, cy, yf, yb, nf, nb = BOOT(min(z, 0.405))
        crs.append(hring(z, a + o, cy - yf + o, yb - cy + o, ay + cy, 2.0, 2.0, cx=ax, M=18))
    b.loft(crs, lambda i, j: "gold" if i >= 2 and i < 4 else ("dark" if i >= 4 else "cream"), caps=(False, True),
           sharp_rings=(1, 2, 3))
    for z0 in (0.150,):
        srs = []
        for z, o in ((z0, 0.001), (z0 + 0.003, 0.006), (z0 + 0.020, 0.006), (z0 + 0.023, 0.001)):
            a, cy, yf, yb, nf, nb = BOOT(z)
            srs.append(hring(z, a + o, cy - yf + o, yb - cy + o, ay + cy, 2.0, 2.0, cx=ax, M=18))
        b.loft(srs, "dark", caps=(False, False), sharp_rings=(1, 2))
        ellipsoid(b, (ax + 0.046 * sx, ay, z0 + 0.0115), (0.006, 0.013, 0.013), "gold", None, M=8, rows=5)
    b.end(skel.w_leg(sx))


# ----------------------------------------------------------------------------
# cloth: scarf and coat tails (spring chains)
# ----------------------------------------------------------------------------
def ribbon(b, path, width, thick, wide, mats, wfn, K=5, tile=None, tile_mats=None):
    """Flat strip with thickness. mats = (outer, inner, edge[, trim]). wide: preferred width axis.
    Unwrap: u 0..0.5 across the outer face, 0.5..1 across the inner face; v along."""
    T = tangents(path)
    n = len(path) - 1
    grid, rows = [], []
    us = [0.5 * k / (K - 1.0) for k in range(K)] + [0.5 + 0.5 * m / (K - 1.0) for m in range(K)] + [1.0]
    for i, (p, t) in enumerate(zip(path, T)):
        s = i / n
        Wd = wide - t * wide.dot(t)
        Wd.normalize()
        Nn = t.cross(Wd).normalized()
        hw = max(width(s) * 0.5, 0.0012)
        th = thick * (0.35 + 0.65 * min(1.0, hw / 0.02))
        pts = []
        for k in range(K):
            x = -1 + 2 * k / (K - 1)
            pts.append(p + Wd * (x * hw) + Nn * (th * 0.5 * (1 + 0.5 * (1 - x * x))))
        for k in reversed(range(K)):
            x = -1 + 2 * k / (K - 1)
            pts.append(p + Wd * (x * hw) - Nn * (th * 0.5))
        grid.append(b.ring(pts, wfn(s, p)))
        if tile:
            rows.append([b.tile_uv(tile, u, s) for u in us])

    def mat(j):
        if j < K - 1:
            return mats[2] if (len(mats) > 3 and j in (0, K - 2)) else mats[0]
        if j == K - 1 or j == 2 * K - 1:
            return mats[2]
        return mats[1]
    for i, (a, c) in enumerate(zip(grid, grid[1:])):
        b.strip(a, c, mat, uv0=rows[i] if tile else None, uv1=rows[i + 1] if tile else None, tile_mats=tile_mats)
    b.cap(grid[0], mats[0])
    b.cap(grid[-1], mats[2])
    return grid


def scarf(b):
    b.begin("scarf")
    w0 = {"chest": 0.55, "neck": 0.45}
    nc = Vector((0.0, 0.012, 1.326))
    M, Mc = 24, 10
    rings, rows = [], []
    for k in range(M):
        th = 2 * pi * k / M
        rad = Vector((sin(th), -cos(th), 0.0))
        c = nc + Vector((0.064 * rad.x, 0.070 * rad.y, -0.026 * cos(th)))
        rr = 0.027 + 0.004 * sin(3 * th + 1.0) + 0.006 * max(cos(th), 0.0)
        rz = 0.034 + 0.010 * max(cos(th), 0.0) + 0.003 * sin(2 * th)
        rings.append(b.ring(fring(c, rad, Vector((0, 0, 1)), rr, rz, M=Mc), w0))
    for k in range(M + 1):
        rows.append([b.tile_uv("scarfwrap", j / float(Mc), k / float(M)) for j in range(Mc + 1)])
    for k in range(M):
        b.strip(rings[k], rings[(k + 1) % M], "crimson", uv0=rows[k], uv1=rows[k + 1])
    knot = Vector((0.052, 0.090, 1.352))
    ellipsoid(b, knot, (0.030, 0.026, 0.028), "crimson", w0, M=10, rows=6)
    # brooch at the front
    bc, bn = Vector((0.041, -0.082, 1.304)), Vector((0.42, -0.90, 0.10)).normalized()
    Rb = bn.to_track_quat("Y", "Z").to_matrix()
    ellipsoid(b, bc, (0.016, 0.006, 0.016), "gold", w0, Rb, M=10, rows=6)
    ellipsoid(b, bc + bn * 0.004, (0.009, 0.006, 0.009), "glow", w0, Rb, M=8, rows=5)
    for name, x0, x1, top, length, wd, nb in (("scarfA", 0.060, 0.086, 1.345, 0.62, 0.072, 5),
                                              ("scarfB", 0.040, 0.030, 1.340, 0.44, 0.062, 4)):
        pts = [knot + Vector((x0 - 0.052, 0.012, top - 1.352)),
               Vector((lerp(x0, x1, 0.3), 0.128, top - 0.07)),
               Vector((x1, 0.140, top - length * 0.55)), Vector((x1, 0.140, top - length))]
        path = catmull(pts, nb * 4)
        joints = [path[i * 4] for i in range(nb + 1)]
        bones = add_chain(name, "chest", joints)
        ribbon(b, path, lambda s, wd=wd: wd * (0.55 + 0.45 * ss(0.0, 0.12, s)) * (1.0 if s < 0.90 else max(1 - ((s - 0.90) / 0.10) ** 1.6, 0.0)),
               0.008, Vector((-1, 0, 0)), ("crimson", "crimson", "crimson"),
               lambda s, p, bones=bones: mixw(w0, chain_w(bones, s), ss(0.0, 0.08, s)), K=5, tile="scarftail")
    b.end()

    b.begin("tails")
    for S, sx in (("L", 1), ("R", -1)):
        pts = [Vector((0.060 * sx, 0.092, 0.945)), Vector((0.066 * sx, 0.104, 0.80)), Vector((0.072 * sx, 0.112, 0.64)),
               Vector((0.076 * sx, 0.118, 0.47))]
        path = catmull(pts, 18)
        joints = [path[i * 6] for i in range(4)]
        bones = add_chain("tail." + S, "hips", joints)
        ribbon(b, path, lambda s: 0.110 * (0.9 + 0.2 * s) * (1.0 if s < 0.80 else max(1 - ((s - 0.80) / 0.20) ** 1.5, 0.0)),
               0.008, Vector((-1, 0, 0)), ("coat", "crimson", "gold", "trim"),
               lambda s, p, bones=bones: mixw({"hips": 1.0}, chain_w(bones, s), ss(0.0, 0.10, s)), K=7, tile="tail",
               tile_mats=("coat", "crimson"))
    b.end()


# ----------------------------------------------------------------------------
# sword (rigid on the weapon bone)
# ----------------------------------------------------------------------------
def sword(b):
    A, T, N = skel.blade_axes(-1)               # across the blade (edge), along the blade, flat normal
    G = skel.grip_point()
    w = {"weapon": 1.0}
    R3 = Matrix((A, T, N)).transposed()

    def P(a, t, n=0.0):
        return G + A * a + T * t + N * n

    b.begin("sword", outline=0.8)
    hs = ((-0.128, 0.008), (-0.122, 0.0130), (-0.06, 0.0122), (0.0, 0.0125), (0.052, 0.0135), (0.056, 0.009))
    rings = [fring(P(0, t), A, N, r, r * 0.86, M=10) for t, r in hs]
    b.loft(rings, "dark", w=w, tile="grip", vs=[(t + 0.128) / 0.184 for t, r in hs])
    for t in (-0.092, -0.046, 0.0, 0.044):
        rr = [fring(P(0, t + dt), A, N, r, r * 0.86, M=10) for dt, r in ((-0.004, 0.012), (-0.003, 0.0148),
                                                                        (0.003, 0.0148), (0.004, 0.012))]
        b.loft(rr, "gold", caps=(False, False), w=w)
    ellipsoid(b, P(0, -0.142), (0.020, 0.017, 0.015), "gold", w, R3, M=10, rows=6)
    ellipsoid(b, P(0, -0.142), (0.0105, 0.0105, 0.017), "glow", w, R3, M=8, rows=6)
    gp = [P(-0.078, 0.098), P(-0.054, 0.074), P(-0.026, 0.063), P(0.0, 0.061), P(0.026, 0.063), P(0.054, 0.074),
          P(0.078, 0.098)]
    tube(b, catmull(gp, 20), lambda s: 0.0088 * (1 - (2 * s - 1) ** 2) ** 0.45 + 0.0020, "gold", w=w, M=8, squash=0.8, up=N)
    ellipsoid(b, P(0, 0.064), (0.019, 0.021, 0.0150), "gold", w, R3, M=10, rows=6)
    ellipsoid(b, P(0, 0.064), (0.0100, 0.0120, 0.0178), "glow", w, R3, M=10, rows=6)
    st = [(0.072, 0.0250, 0.0050), (0.090, 0.0300, 0.0062), (0.50, 0.0265, 0.0056), (0.78, 0.0225, 0.0048),
          (0.86, 0.0150, 0.0036), (0.915, 0.0010, 0.0008)]
    rings = [[P(-hw, t), P(0, t, hn), P(hw, t), P(0, t, -hn)] for t, hw, hn in st]
    b.loft(rings, "steel", w=w, sharp_cols=(0, 1, 2, 3), tile="blade", vs=[(t - 0.072) / 0.843 for t, hw, hn in st])
    for sgn in (1, -1):
        fr = [[P(-hw, t, sgn * (hn + 0.0004)), P(0, t, sgn * (hn + 0.0022)), P(hw, t, sgn * (hn + 0.0004)),
               P(0, t, sgn * (hn - 0.002))]
              for t, hw, hn in ((0.094, 0.0015, 0.0052), (0.11, 0.0058, 0.0052), (0.40, 0.0050, 0.0048),
                                (0.58, 0.0030, 0.0042), (0.66, 0.0006, 0.0040))]
        b.loft(fr, "glow", w=w)
    b.end()


def build(b, only=None):
    del EXTRA[:]
    parts = [head, hair, torso, lambda b: arm(b, 1), lambda b: arm(b, -1), pauldron, lambda b: leg(b, 1),
             lambda b: leg(b, -1), scarf, sword]
    names = ["head", "hair", "torso", "armL", "armR", "pauldron", "legL", "legR", "scarf", "sword"]
    for fn, nm in zip(parts, names):
        if only and nm not in only.split(","):
            continue
        fn(b)
