"""Scene builders for every parallax layer of "Jardim das Lanternas Suspensas".

Each builder creates a Layer: its own collection of objects, the layer camera
framing (origin/size/tilt), and metadata (glowing lanterns, waterfalls and
1-px strings) that is projected through the layer camera after rendering.

World/layer coordinates are art pixels, Godot style (y down).  Layer.p(x, y,
depth) gives the Blender position that projects to world (x, y) when the
camera is at the reference position C0 with zoom 1.
"""
import math

import bpy  # noqa: F401
import bmesh
from mathutils import Matrix, Vector

import bl_util as U
import materials as MT
import palette as P
import props as PR

GROUND_TILT = 24.0
_TH = math.radians(GROUND_TILT)
FLOOR_BACK = 30.0 / math.sin(_TH)      # depth of the back edge   (screen y = -30)
FLOOR_FRONT = -60.0 / math.sin(_TH)    # depth of the front edge  (screen y = +60)


class Layer:
    def __init__(self, name, origin, size, parallax, z, tilt=0.0, front=False, samples=32):
        self.name = name
        self.origin = origin
        self.size = size
        self.parallax = parallax
        self.z = z
        self.tilt = tilt
        self.front = front
        self.samples = samples
        self.coll = U.collection(name)
        th = math.radians(tilt)
        self.fwd = Vector((0.0, math.cos(th), -math.sin(th)))
        self.up = Vector((0.0, math.sin(th), math.cos(th)))
        self.lights = []        # (blender pos, radius px, hex colour, kind)
        self.waterfalls = []    # (blender top, blender bottom, width px)
        self.strings = []       # ([blender pts], palette colour name)
        self.light_colls = ['lights']
        self.world = ('#6a5aa8', 0.6)

    def p(self, x, y, depth=0.0):
        return Vector((x, 0.0, 0.0)) + self.up * (-y) + self.fwd * depth


# ----------------------------------------------------------------------------
# materials
# ----------------------------------------------------------------------------
def make_materials():
    M = {}
    M['rock'] = MT.stone('rock', strata=0.16, lip=2.5, lip_var=5.0)
    M['rock_nolip'] = MT.stone('rock_nolip', strata=0.16)
    M['rock_float'] = MT.stone('rock_float', moss_thresh=0.82, strata=0.2)
    M['rock_bare'] = MT.stone('rock_bare', moss=False, strata=0.12)
    M['under'] = MT.stone('under', cls=P.UNDER, moss=False, strata=0.12, bump=0.15)
    M['ruin'] = MT.stone('ruin', moss=True, moss_thresh=0.75, crack_scale=0.09, noise_scale=0.08)
    M['far_a'] = MT.stone('far_a', cls=P.FAR_A, moss_cls=P.FAR_C, lip=2.0, lip_var=3.0, bump=0.15)
    M['far_b'] = MT.stone('far_b', cls=P.FAR_B, moss_cls=P.FAR_C, lip=1.5, lip_var=2.0, bump=0.1)
    M['far_c'] = MT.stone('far_c', cls=P.FAR_C, moss=False, bump=0.05)
    M['far_tree'] = MT.flat('far_tree', P.FAR_C)
    M['trim'] = MT.flat('trim', P.TRIM, var=0.15)
    M['bark'] = MT.flat('bark', P.BARK, var=0.25)
    M['root'] = MT.flat('root', P.ROOT)
    M['blossom'] = MT.foliage('blossom', P.BLOSSOM)
    M['blossom_s'] = MT.foliage('blossom_s', P.BLOSSOM, var_scale=0.22)
    M['leaf'] = MT.foliage('leaf', P.LEAF)
    M['leaf_s'] = MT.foliage('leaf_s', P.LEAF, var_scale=0.22)
    M['paper'] = MT.emissive('paper', P.LANTERN, '#ffa850', strength=7.0)
    M['paper_s'] = MT.emissive('paper_s', P.LANTERN, '#ffb860', strength=5.0, core=0.4)
    M['gold'] = MT.flat('gold', P.GOLD)
    M['water'] = MT.water('water')
    M['water_far'] = MT.water('water_far')
    M['cloud'] = MT.flat('cloud', P.CLOUD)
    M['cloud_b'] = MT.flat('cloud_b', P.CLOUD_B)
    M['cloud_t'] = MT.flat('cloud_t', P.CLOUD_B, off=-1)
    M['grass'] = MT.flat('grass', P.GRASS, var=0.2)
    M['moss'] = MT.flat('moss', P.MOSS, var=0.12, bump=0.6, bump_scale=0.3)
    M['flower_w'] = MT.flat('flower_w', P.FLOWER_W)
    M['flower_p'] = MT.flat('flower_p', P.FLOWER_P)
    M['stem'] = MT.flat('stem', P.GRASS, off=-1)
    M['shroom_stem'] = MT.flat('shroom_stem', P.TRIM)
    M['glowcap'] = MT.emissive('glowcap', P.GLOWCAP, '#90f0e0', strength=4.0, core=0.8)
    M['rune'] = MT.emissive('rune', P.RUNE, '#90f0e0', strength=3.0, core=0.3)
    M['flag'] = MT.flagstone('flag', front_y=FLOOR_FRONT + 40)
    M['flag_ring'] = MT.flagstone('flag_ring', front_y=FLOOR_FRONT + 40, var=False)
    M['inlay'] = MT.flat('inlay', P.INLAY)
    M['moon'] = MT.moon('moon')
    return M


def lights_rig():
    L = U.collection('lights')
    U.add_sun('key', '#ffb070', 3.0, (0.6, 0.3, -0.75), L)
    U.add_sun('rim', '#ff9a6a', 5.0, (-0.55, -0.75, -0.25), L)
    U.add_sun('bounce', '#d0608a', 0.7, (0.1, 0.2, 1.0), L)
    return L


# ----------------------------------------------------------------------------
# helpers
# ----------------------------------------------------------------------------
def add_roots(L, isl, count, mat, seed, lmin=12, lmax=40, thick=1.4):
    r = U.rng(seed)
    for i, p in enumerate(PR.island_bottom_points(isl, count, seed=seed)):
        PR.hanging_root(f'{isl.name}_root{i}', p + Vector((0, -2, 2)), r.uniform(lmin, lmax), mat,
                        L.coll, seed=seed + i, thick=thick)


def top_z(isl, dx, dy=0.0):
    """Approximate height of the island top surface at local (dx, dy)."""
    best = None
    for v in isl.data.vertices:
        if v.co.z > 0 and abs(v.co.x - dx) < 12 and abs(v.co.y - dy) < 12:
            best = v.co.z if best is None else max(best, v.co.z)
    return best if best is not None else 0.0


def string_with_lanterns(L, a, b, sag, n_lan, mats, lan_h, color='s2', seed=0, small=False,
                         drop=(3, 7), glow_r=None, glow_col='#ffc46a'):
    """Catenary from a to b (Blender coords) with n_lan lanterns hanging."""
    r = U.rng(seed)
    pts = U.catenary(a, b, sag, n=40)
    L.strings.append((pts, color))
    for i in range(n_lan):
        t = (i + 0.5 + r.uniform(-0.15, 0.15)) / n_lan
        k = int(t * (len(pts) - 1))
        p = pts[k]
        d = r.uniform(*drop)
        top = p + Vector((0, -0.5, 0))
        c = p + Vector((0, -1.0, -d - lan_h / 2))
        if small:
            bm = U.bm_uvsphere(1.0, 8, 6)
            for v in bm.verts:
                v.co = Vector((v.co.x * lan_h * 0.42, v.co.y * lan_h * 0.42, v.co.z * lan_h / 2))
            U.obj_from_bm(f'{L.name}_slan{seed}_{i}', bm, [mats['paper_s']], L.coll, smooth=True, loc=c)
        else:
            PR.paper_lantern(f'{L.name}_lan{seed}_{i}', c, lan_h, mats['paper'], mats['gold'], L.coll)
        L.strings.append(([top, c + Vector((0, 0, lan_h / 2))], color))
        L.lights.append((c, glow_r or lan_h * 1.6, glow_col, 'lantern_small' if small else 'lantern'))


def floating_rock(L, name, pos, s, mat, seed):
    bm = U.bm_ico(s, 2)
    o = Vector((seed * 5.0, 2.0, 1.0))
    for v in bm.verts:
        v.co *= 1 + 0.28 * U.fbm(v.co * (1.4 / s) + o, 2)
        v.co.z *= 0.75 if v.co.z > 0 else 1.35
    return U.obj_from_bm(name, bm, [mat], L.coll, loc=pos)


def cloud_mound(bm, c, R, seed, subdiv=3):
    """Billowing cumulus mound: big dome + smaller side puffs + top bump."""
    r = U.rng(seed)
    puffs = [(0.0, 0.0, R)]
    for i in range(r.randint(2, 4)):
        side = -1 if i % 2 == 0 else 1
        puffs.append((side * R * r.uniform(0.55, 1.05), -R * r.uniform(0.15, 0.45),
                      R * r.uniform(0.5, 0.75)))
    puffs.append((R * r.uniform(-0.35, 0.35), R * r.uniform(0.35, 0.55), R * r.uniform(0.38, 0.55)))
    for k, (dx, dz, rr) in enumerate(puffs):
        PR.cloud_puff(bm, c + Vector((dx, -k * 0.7, dz)), rr * 1.2, rr * 0.82, ry=rr * 0.8,
                      seed=seed * 7 + k, subdiv=subdiv)


# ----------------------------------------------------------------------------
# FAR  (parallax 0.12)
# ----------------------------------------------------------------------------
def build_far(M):
    L = Layer('far', (-512, -410), (1024, 560), 0.12, -40, tilt=0.0, samples=24)
    r = U.rng(101)
    # towering hazy cumulus on the horizon (faint shapes)
    bm = bmesh.new()
    for i, (x, y, R) in enumerate([(-400, -92, 44), (-330, -84, 30), (360, -96, 50), (440, -82, 32),
                                   (40, -76, 26)]):
        cloud_mound(bm, L.p(x, y, 1200), R, 900 + i)
    U.obj_from_bm('cloud_towers', bm, [M['cloud_t']], L.coll, smooth=True)
    # sea of clouds: rows of billowing mounds receding to the horizon
    rows = [(-58, 7, 12, 1000, 'cloud_b'), (-47, 9, 16, 850, 'cloud_b'), (-32, 13, 22, 700, 'cloud_b'),
            (-10, 18, 30, 550, 'cloud'), (22, 26, 40, 400, 'cloud'), (68, 34, 54, 250, 'cloud'),
            (128, 44, 70, 100, 'cloud')]
    for ri, (yc, rmin, rmax, depth, mk) in enumerate(rows):
        bm = bmesh.new()
        x = -600 + r.uniform(0, 30)
        k = 0
        while x < 600:
            R = r.uniform(rmin, rmax)
            cloud_mound(bm, L.p(x, yc + r.uniform(-3, 3), depth + r.uniform(-15, 15)), R,
                        ri * 1000 + k, subdiv=3 if R > 14 else 2)
            x += R * r.uniform(1.1, 1.75)
            k += 1
        U.bm_merge(bm, U.bm_box(1300, 20, 260, center=L.p(0, yc + rmin * 0.5 + 130, depth + 60)))
        U.obj_from_bm(f'cloudrow{ri}', bm, [M[mk]], L.coll, smooth=True)
    # distant floating islands
    isl = [  # x, y_top, rx, under, mat, seed, waterfall_dx, trees
        (-360, -170, 54, 60, 'far_a', 11, 30, 2),
        (-120, -246, 28, 34, 'far_b', 12, None, 1),
        (64, -156, 20, 24, 'far_b', 13, None, 0),
        (262, -204, 56, 70, 'far_a', 14, -34, 2),
        (452, -150, 32, 38, 'far_b', 15, None, 1),
        (-466, -284, 24, 28, 'far_b', 16, None, 1),
        (-246, -108, 14, 16, 'far_b', 17, None, 0),
    ]
    for i, (x, yt, rx, und, mk, sd, wdx, nt) in enumerate(isl):
        c = L.p(x, yt, 60)
        PR.island(f'far_isl{i}', c, rx, rx * 0.5, max(3, rx * 0.12), und, [M[mk]], L.coll,
                  seed=sd, subdiv=3, spike=0.55)
        for t in range(nt):
            dx = (t - (nt - 1) / 2) * rx * 0.7 + r.uniform(-5, 5)
            rr = rx * r.uniform(0.2, 0.28)
            PR.canopy(f'far_tree{i}_{t}', c + Vector((dx, -4, rr * 1.3)), rr, M['far_tree'], L.coll,
                      seed=170 + i * 3 + t, clumps=4, subdiv=2)
            U.obj_from_bm(f'far_trunk{i}_{t}', U.bm_box(1.2, 1.2, rr * 1.5, center=(0, 0, rr * 0.7)),
                          [M['far_b']], L.coll, loc=c + Vector((dx, -3, 0)))
        if wdx is not None:
            top = c + Vector((wdx, -rx * 0.45, -1.5))
            ln = und * 1.25
            PR.waterfall(f'far_wf{i}', top, ln, 2.5, M['water_far'], L.coll, lip=1.5)
            L.waterfalls.append((top, top + Vector((0, 0, -ln)), 3.0))
    return L


# ----------------------------------------------------------------------------
# MID  (parallax 0.35)
# ----------------------------------------------------------------------------
def build_mid(M):
    L = Layer('mid', (-570, -440), (1140, 560), 0.35, -30, tilt=12.0, samples=32)
    specs = [  # name, x, y_top, rx, ry, top_h, under, seed
        ('A', -338, -112, 104, 56, 10, 122, 21),
        ('B', 322, -176, 84, 46, 9, 100, 22),
        ('C', -128, -236, 40, 24, 6, 50, 23),
        ('D', 150, -84, 52, 30, 7, 62, 24),
        ('E', 22, -302, 16, 11, 4, 20, 25),
        ('F', -486, -300, 26, 16, 4, 30, 26),
        ('G', 486, -338, 30, 18, 4, 36, 27),
    ]
    isl = {}
    for name, x, yt, rx, ry, th, und, sd in specs:
        c = L.p(x, yt, 0)
        ob = PR.island(f'mid_{name}', c, rx, ry, th, und, [M['rock']], L.coll, seed=sd, subdiv=4)
        isl[name] = (ob, c, rx, ry)
        add_roots(L, ob, max(2, int(rx / 12)), M['root'], sd, lmin=und * 0.2, lmax=und * 0.5,
                  thick=1.2 if rx > 50 else 0.9)

    def tree(iname, dx, dy, h, mats, sd, size=1.0, thick=3.0):
        ob, c, rx, ry = isl[iname]
        base = c + Vector((dx, dy, top_z(ob, dx, dy) - 2))
        PR.blossom_tree(f'mid_tree_{iname}{sd}', base, h, M['bark'], mats, L.coll, seed=sd,
                        size=size, thick=thick)
    tree('A', -46, 8, 58, [M['blossom'], M['blossom']], 31, 1.0, 3.4)
    tree('A', 26, -4, 42, [M['leaf'], M['leaf']], 32, 0.95, 3.0)
    tree('B', 16, 4, 64, [M['leaf'], M['blossom']], 33, 1.0, 3.6)
    tree('C', -6, 2, 36, [M['blossom_s'], M['blossom_s']], 34, 1.0, 2.4)
    tree('D', -24, 0, 32, [M['leaf_s'], M['leaf_s']], 35, 0.95, 2.2)
    tree('G', 2, 0, 22, [M['blossom_s'], M['blossom_s']], 36, 1.0, 1.8)

    def ruin_pillar(iname, dx, dy, h, rad, sd, broken=True):
        ob, c, rx, ry = isl[iname]
        base = c + Vector((dx, dy, top_z(ob, dx, dy) - 3))
        PR.pillar(f'mid_pil_{iname}{sd}', base, h, rad, M['ruin'], L.coll, seed=sd, broken=broken)
        return base + Vector((0, 0, h + rad * 1.4))
    ruin_pillar('A', 58, -10, 34, 4.5, 41)
    ruin_pillar('A', 74, -2, 20, 4.5, 42)
    a_post = ruin_pillar('A', 90, -16, 40, 3.2, 43, broken=False)
    ruin_pillar('B', -46, -6, 32, 4.0, 44)
    b_post = ruin_pillar('B', -64, -14, 38, 3.0, 45, broken=False)
    d_post = ruin_pillar('D', 30, -6, 26, 3.0, 46, broken=False)
    c_post = ruin_pillar('C', 24, -4, 20, 2.4, 48, broken=False)

    def wf(iname, dx, length, width, sd):
        ob, c, rx, ry = isl[iname]
        top = c + Vector((dx, -ry * 0.55, top_z(ob, dx, -ry * 0.5) - 3))
        PR.waterfall(f'mid_wf_{iname}{sd}', top, length, width, M['water'], L.coll, lip=3, seed=sd)
        L.waterfalls.append((top, top + Vector((0, -3, -length)), width * 1.35 + 2))
    wf('A', 78, 150, 5, 51)
    wf('A', -88, 112, 3, 52)
    wf('B', -58, 140, 4, 53)
    wf('D', 34, 72, 3, 54)
    # lantern strings between islands (kept to the sides of the playfield)
    string_with_lanterns(L, a_post + Vector((0, -2, 0)), c_post + Vector((0, -2, 0)), 26, 6, M, 3.2,
                         color='s3', seed=61, small=True, drop=(2, 4), glow_r=7)
    string_with_lanterns(L, d_post + Vector((0, -2, 0)), b_post + Vector((0, -2, 0)), 30, 6, M, 3.2,
                         color='s3', seed=63, small=True, drop=(2, 4), glow_r=7)
    for i, (x, y, s) in enumerate([(-250, -190, 7), (80, -206, 5), (240, -268, 8), (-40, -150, 4),
                                   (-536, -200, 6), (420, -60, 5)]):
        floating_rock(L, f'mid_rock{i}', L.p(x, y, 10), s, M['rock_float'], i)
    return L


# ----------------------------------------------------------------------------
# NEAR  (parallax 0.65)
# ----------------------------------------------------------------------------
def build_near(M):
    L = Layer('near', (-700, -540), (1400, 640), 0.65, -20, tilt=10.0, samples=32)
    r = U.rng(303)
    gm = dict(stone=M['ruin'], trim=M['trim'], rune=M['rune'])
    gates = [(-318, -150, 92, (3, 4, 5), 71), (334, -168, 98, (), 72)]
    gate_tops = []
    for gi, (x, yc, R, missing, sd) in enumerate(gates):
        c = L.p(x, yc, 40)
        objs, runes = PR.moon_gate(f'gate{gi}', c, R, gm, L.coll, seed=sd, missing=missing)
        for rp in runes:
            L.lights.append((rp, 5, '#9fe8e0', 'rune'))
        base_c = c + Vector((0, 0, -R - 22))
        isl = PR.island(f'gate_rock{gi}', base_c, R * 1.4, 46, 6, 62, [M['rock']], L.coll,
                        seed=sd + 5, subdiv=4, spike=0.5)
        add_roots(L, isl, 7, M['root'], sd, lmin=14, lmax=34, thick=1.6)
        gate_tops.append(c + Vector((0, -6, R)))
    # fallen voussoirs drifting out of the ruined gate's gap
    gx, gy, gR = gates[0][0], gates[0][1], gates[0][2]
    gc = L.p(gx, gy, 40)
    for i, (blk, dist, rot, dz) in enumerate([(4, 16, 0.22, 4), (3, 34, -0.38, -10)]):
        a0 = math.tau * blk / 16 + 0.02 - math.pi / 2 + math.pi / 16
        a1 = math.tau * (blk + 1) / 16 - 0.02 - math.pi / 2 + math.pi / 16
        b = PR._ring_bm(gR, gR * 0.68, 22, a0, a1, 3)
        am = (a0 + a1) / 2
        cen = Vector((math.cos(am), 0, math.sin(am))) * gR * 0.84
        bmesh.ops.rotate(b, verts=b.verts, cent=cen, matrix=Matrix.Rotation(rot, 3, 'Y'))
        off = Vector((math.cos(am), 0, math.sin(am))) * dist + Vector((0, -3, dz))
        U.obj_from_bm(f'gate_chunk{i}', b, [M['ruin']], L.coll, loc=gc + off)
    # big blossom tree on the left, rooted on its own rock, leaning over the gate
    tb = L.p(-548, -40, 80)
    isl = PR.island('tree_rock', tb + Vector((0, 0, -4)), 92, 50, 8, 62, [M['rock']], L.coll, seed=81)
    add_roots(L, isl, 6, M['root'], 81, lmin=14, lmax=34, thick=1.8)
    objs, tips = PR.trunk('bigtree', tb, 220, M['bark'], L.coll, seed=82, thick=10.0, lean=0.3,
                          branches=4)
    for i, tp in enumerate(tips):
        R = 88 if i == 0 else r.uniform(50, 62)
        PR.canopy(f'bigtree_can{i}', tp + Vector((0, -6 - i * 2, R * 0.12)), R,
                  M['blossom'], L.coll, seed=90 + i, clumps=12 if i == 0 else 7, spread=0.85)
    # ruined tall column on a rock at the right
    col_base = L.p(600, -70, 60)
    isl = PR.island('col_rock', col_base + Vector((0, 0, -6)), 56, 34, 6, 56, [M['rock']], L.coll,
                    seed=83)
    add_roots(L, isl, 4, M['root'], 83, lmin=14, lmax=30)
    PR.pillar('near_col', col_base, 190, 11, M['ruin'], L.coll, seed=84, broken=True, segs=14)
    col_top = col_base + Vector((-6, -10, 176))
    # strings of paper lanterns (sides), plus a high one revealed when flying
    tree_anchor = tips[1] + Vector((10, -20, -10)) if len(tips) > 1 else tips[0]
    string_with_lanterns(L, tree_anchor, gate_tops[0] + Vector((-34, 0, -8)), 34, 3, M, 13,
                         color='s1', seed=91, drop=(4, 10))
    string_with_lanterns(L, gate_tops[1] + Vector((26, 0, -8)), col_top, 40, 3, M, 13,
                         color='s1', seed=92, drop=(4, 10))
    ra = floating_rock(L, 'near_hrock0', L.p(-150, -436, 0), 14, M['rock_float'], 11)
    rb = floating_rock(L, 'near_hrock1', L.p(210, -470, 0), 18, M['rock_float'], 12)
    string_with_lanterns(L, ra.location + Vector((6, -16, -6)), rb.location + Vector((-8, -18, -8)),
                         44, 4, M, 11, color='s1', seed=93, drop=(3, 8))
    for i, (x, y, s, d) in enumerate([(-640, -330, 10, 20), (-110, -70, 7, 0), (130, -36, 6, 0),
                                      (470, -330, 12, 0), (-60, -250, 5, 0)]):
        floating_rock(L, f'near_rock{i}', L.p(x, y, d), s, M['rock_float'], 20 + i)
    return L


# ----------------------------------------------------------------------------
# GROUND  (parallax 1.0) -- the arena terrace, oblique view
# ----------------------------------------------------------------------------
def _paving(r, x0, x1, y0, y1):
    """Ashlar paving: rows of random depth, random widths per row, and some
    big slabs that span two rows (cutting the stones they overlap)."""
    rows = []
    y = y0
    while y < y1 - 8:
        d = min(r.uniform(16, 30), y1 - y)
        rows.append((y, y + d))
        y += d
    stones = [[] for _ in rows]
    for i, (ya, yb_) in enumerate(rows):
        x = x0 - r.uniform(0, 40)
        while x < x1:
            w = r.uniform(24, 58)
            stones[i].append([x, ya, x + w, yb_])
            x += w
    for i in range(len(rows) - 1):
        for st in stones[i]:
            if r.random() < 0.16 and st[2] - st[0] > 28:
                st[3] = rows[i + 1][1]
                keep = []
                for o in stones[i + 1]:
                    if o[2] <= st[0] or o[0] >= st[2]:
                        keep.append(o)
                        continue
                    if o[0] < st[0] - 10:
                        keep.append([o[0], o[1], st[0], o[3]])
                    if o[2] > st[2] + 10:
                        keep.append([st[2], o[1], o[2], o[3]])
                stones[i + 1] = keep
    return [tuple(s_) for row in stones for s_ in row]


def _ring_xy(R, r_in, h, a0, a1, n, z=0.0):
    b = PR._ring_bm(R, r_in, h, a0, a1, n)
    bmesh.ops.rotate(b, verts=b.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(-math.pi / 2, 3, 'X'))
    bmesh.ops.translate(b, vec=(0, 0, z), verts=b.verts)
    return b


def build_ground(M):
    L = Layer('ground', (-800, -260), (1600, 460), 1.0, -10, tilt=GROUND_TILT, samples=32)
    r = U.rng(404)
    yb, yf = FLOOR_BACK, FLOOR_FRONT
    X0, X1 = -840.0, 840.0
    # --- moss bed under the paving
    U.obj_from_bm('floor_bed', U.bm_box(X1 - X0, yb - yf + 4, 6, center=(0, (yb + yf) / 2, -3.2)),
                  [M['moss']], L.coll)
    # --- central medallion (circular paving with a star inlay): fighters' centre
    mc = Vector((0.0, -14.0 / math.sin(_TH), 0.0))
    MR = 98.0
    bm = bmesh.new()
    rings = [(0, 22, 1), (23.5, 48, 8), (49.5, 74, 12), (75.5, 88, 20)]
    for ri, (a, b, n) in enumerate(rings):
        for k in range(n):
            if a == 0:
                g = U.bm_cyl(b, b, 2.6, segs=24, center=(0, 0, -0.3))
            else:
                a0 = math.tau * k / n + 0.012 + ri * 0.2
                a1 = math.tau * (k + 1) / n - 0.012 + ri * 0.2
                g = _ring_xy(b, a, 2.6, a0, a1, max(2, int(24 / n * 3)), z=-0.3)
            U.bm_merge(bm, g)
    bmesh.ops.translate(bm, vec=mc, verts=bm.verts)
    U.obj_from_bm('medallion', bm, [M['flag_ring']], L.coll)
    bm = bmesh.new()
    U.bm_merge(bm, _ring_xy(MR, 89.5, 3.4, 0, math.tau, 64, z=-0.2))
    bmesh.ops.translate(bm, vec=mc, verts=bm.verts)
    U.obj_from_bm('medallion_rim', bm, [M['trim']], L.coll)
    # 8-point star inlay + crescent
    bm = bmesh.new()
    pts = []
    for k in range(16):
        a = math.tau * k / 16 + math.pi / 2
        rr = 19.0 if k % 2 == 0 else 7.5
        pts.append(bm.verts.new((math.cos(a) * rr, math.sin(a) * rr, -1.0)))
    bm.faces.new(pts)
    ext = bmesh.ops.extrude_face_region(bm, geom=list(bm.faces))
    new_verts = [e for e in ext['geom'] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, vec=(0, 0, 2.6), verts=new_verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for k in range(8):
        a = math.tau * k / 8 + math.pi / 8
        g = U.bm_cyl(1.8, 1.8, 2.4, segs=8, center=(math.cos(a) * 61, math.sin(a) * 61, 0.6))
        U.bm_merge(bm, g)
    bmesh.ops.translate(bm, vec=mc, verts=bm.verts)
    U.obj_from_bm('medallion_star', bm, [M['inlay']], L.coll)
    # --- irregular flagstones around it
    rects = _paving(r, X0, X1, yf + 8, yb - 3)
    bm = bmesh.new()
    for (x0, y0, x1, y1) in rects:
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        qx = max(abs(cx - mc.x) - (x1 - x0) / 2, 0)
        qy = max(abs(cy - mc.y) - (y1 - y0) / 2, 0)
        if math.hypot(qx, qy) < MR + 3:
            # cut the stone into small fitted pieces around the medallion
            nx = max(1, int((x1 - x0) / 13))
            ny = max(1, int((y1 - y0) / 11))
            for i in range(nx):
                for j in range(ny):
                    a0, a1 = x0 + (x1 - x0) * i / nx, x0 + (x1 - x0) * (i + 1) / nx
                    b0, b1 = y0 + (y1 - y0) * j / ny, y0 + (y1 - y0) * (j + 1) / ny
                    fx = max(abs(a0 - mc.x), abs(a1 - mc.x))
                    fy = max(abs(b0 - mc.y), abs(b1 - mc.y))
                    if math.hypot(fx, fy) > MR + 1.5 and \
                            math.hypot(max(a0 - mc.x, 0, mc.x - a1), max(b0 - mc.y, 0, mc.y - b1)) > MR + 1.5 and r.random() > 0.08:
                        h = r.uniform(2.0, 3.0)
                        U.bm_merge(bm, U.bm_box(a1 - a0 - 1.8, b1 - b0 - 1.8, h,
                                                center=((a0 + a1) / 2, (b0 + b1) / 2, h / 2 - 1.5), bevel=0.7))
            continue
        if r.random() < 0.035:
            continue                                   # missing stone -> moss
        h = r.uniform(2.2, 3.4)
        b = U.bm_box(x1 - x0 - 2.0, y1 - y0 - 2.0, h, center=(cx, cy, h / 2 - 1.5), bevel=0.9)
        rot = Matrix.Rotation(r.uniform(-0.03, 0.03), 3, 'Y') @ Matrix.Rotation(r.uniform(-0.03, 0.03), 3, 'X')
        bmesh.ops.rotate(b, verts=b.verts, cent=(cx, cy, 0), matrix=rot)
        U.bm_merge(bm, b)
    U.obj_from_bm('flagstones', bm, [M['flag']], L.coll)
    # --- front coping + masonry face
    bm = bmesh.new()
    x = X0
    while x < X1:
        w = r.uniform(44, 70)
        U.bm_merge(bm, U.bm_box(w - 1.6, 14, 9, center=(x + w / 2, yf + 4, -2.5), bevel=1.4))
        x += w
    U.obj_from_bm('coping', bm, [M['ruin']], L.coll)
    bm = bmesh.new()
    for k, (z0, hh) in enumerate([(-7, 20), (-27.5, 20)]):
        x = X0 - r.uniform(0, 30)
        while x < X1:
            w = r.uniform(34, 62)
            U.bm_merge(bm, U.bm_box(w - 1.8, 10, hh - 1.6,
                                    center=(x + w / 2, yf + 4 + k * 2, z0 - hh / 2 + 0.5), bevel=1.2))
            x += w
    U.obj_from_bm('masonry', bm, [M['rock_nolip']], L.coll)
    # --- rocky underside: jagged lobes hanging below the masonry
    for i, (x, rx, und, sd) in enumerate([(-610, 230, 90, 1), (-210, 210, 130, 2), (220, 240, 115, 3),
                                          (640, 220, 85, 4)]):
        c = Vector((x, yf + 26, -40))
        isl = PR.island(f'under{i}', c, rx, 36, 2, und, [M['under']], L.coll,
                        seed=440 + sd, subdiv=4, spike=0.8, lumpy=0.1)
        add_roots(L, isl, 9, M['root'], 450 + sd, lmin=16, lmax=50, thick=1.8)
    for i in range(16):
        x = r.uniform(X0 + 20, X1 - 20)
        p0 = Vector((x, yf - 2, 1))
        ln = r.uniform(16, 46)
        pts = [p0 + Vector((r.uniform(-2, 2) * t / 6, -1 - 0.5 * t / 6, -ln * t / 6)) for t in range(7)]
        U.curve_obj(f'vine{i}', pts, [1.0 - 0.1 * t for t in range(7)], M['moss'], L.coll, bevel=1.3,
                    res=1, kind='NURBS')
    # --- back balustrade, open in the centre (ruined), rubble in the gaps
    bm_rail = bmesh.new()
    bm_bal = bmesh.new()
    gaps = [(-196, 196), (420, 480), (-560, -520)]
    yb_rail = yb + 4
    x = X0
    seg = 64.0
    posts = []
    while x < X1:
        mid = x + seg / 2
        in_gap = any(a < mid < b for a, b in gaps)
        if not in_gap:
            posts += [x, x + seg]
            U.bm_merge(bm_rail, U.bm_box(seg, 9, 4, center=(mid, yb_rail, 2), bevel=0.8))
            U.bm_merge(bm_rail, U.bm_box(seg, 8, 3.2, center=(mid, yb_rail, 23), bevel=0.8))
            for k in range(5):
                PR.baluster_bm(bm_bal, Vector((x + (k + 1) * seg / 6, yb_rail, 4)), 17.5, 2.0)
        else:
            for k in range(r.randint(1, 3)):
                b = U.bm_box(r.uniform(6, 12), r.uniform(5, 8), r.uniform(3, 6),
                             center=(x + r.uniform(5, seg - 5), yb_rail + r.uniform(-6, 2), 2), bevel=1.0)
                U.bm_merge(bm_rail, b)
        x += seg
    for px_ in sorted(set(round(p, 3) for p in posts)):
        hb = 28 if r.random() < 0.8 else r.uniform(14, 22)       # some broken posts
        U.bm_merge(bm_rail, U.bm_box(9, 10, hb, center=(px_, yb_rail, hb / 2), bevel=0.9))
        if hb >= 28:
            U.bm_merge(bm_rail, U.bm_box(11, 12, 3, center=(px_, yb_rail, 29), bevel=0.8))
    U.obj_from_bm('balustrade', bm_rail, [M['ruin']], L.coll).visible_shadow = False
    U.obj_from_bm('balusters', bm_bal, [M['trim']], L.coll).visible_shadow = False
    # --- lantern posts at the back (two flank the open centre)
    pm = dict(stone=M['ruin'], gold=M['gold'], paper=M['paper'])
    for i, (x, h, side) in enumerate([(-700, 92, 1), (-212, 80, -1), (212, 80, 1), (700, 92, -1)]):
        objs, lc, tip = PR.lantern_post(f'lpost{i}', Vector((x, yb + 12, 0)), h, pm, L.coll, seed=i,
                                        hook_side=side, lantern_h=13)
        for ob in objs:
            ob.visible_shadow = False
        L.lights.append((lc, 22, '#ffc46a', 'lantern'))
        L.strings.append(([tip, lc + Vector((0, 0, 6.5))], 's0'))
    # --- grass tufts & flowers along the back edge, a few at the front
    bm_g, bm_s, bm_fw, bm_fp = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    for i in range(170):
        x = r.uniform(X0, X1)
        y = yb - r.uniform(-2, 12)
        PR.grass_tuft(bm_g, Vector((x, y, 0)), r.uniform(6, 13), seed=1000 + i, blades=r.randint(5, 9),
                      width=1.4)
        if r.random() < 0.5:
            for k in range(r.randint(1, 3)):
                PR.flower(bm_s, bm_fw if r.random() < 0.55 else bm_fp,
                          Vector((x + r.uniform(-5, 5), y - r.uniform(0, 4), 0)), r.uniform(6, 13),
                          head_r=r.uniform(1.3, 2.0), lean=r.uniform(-0.3, 0.3))
    for i in range(50):
        x = r.uniform(X0, X1)
        y = yf + r.uniform(4, 12)
        PR.grass_tuft(bm_g, Vector((x, y, 0.5)), r.uniform(3, 7), seed=2000 + i, blades=r.randint(3, 6))
    for i in range(36):                         # sparse tufts in the paving joints
        x = r.uniform(X0, X1)
        y = r.uniform(yf + 15, yb - 15)
        if math.hypot(x - mc.x, (y - mc.y)) < MR + 4:
            continue
        PR.grass_tuft(bm_g, Vector((x, y, 0.3)), r.uniform(2.5, 4.5), seed=3000 + i, blades=r.randint(3, 5),
                      spread=1.4)
    for ob in (U.obj_from_bm('grass', bm_g, [M['grass']], L.coll),
               U.obj_from_bm('stems', bm_s, [M['stem']], L.coll),
               U.obj_from_bm('flowers_w', bm_fw, [M['flower_w']], L.coll),
               U.obj_from_bm('flowers_p', bm_fp, [M['flower_p']], L.coll)):
        ob.visible_shadow = False
    # --- planters with small blossom shrubs at the far ends
    for i, x in enumerate([-560, 560]):
        U.obj_from_bm(f'planter{i}', U.bm_box(44, 30, 16, center=(0, 0, 8), bevel=1.5), [M['ruin']], L.coll,
                      loc=Vector((x, yb - 22, 0)))
        PR.canopy(f'shrub{i}', Vector((x, yb - 22, 30)), 26, M['blossom_s'], L.coll, seed=470 + i,
                  clumps=6, squash=0.8)
    return L


# ----------------------------------------------------------------------------
# FG  (parallax 1.25) -- sparse dark silhouettes along the bottom
# ----------------------------------------------------------------------------
def build_fg(M):
    L = Layer('fg', (-1000, -90), (2000, 290), 1.25, 20, tilt=0.0, front=True, samples=24)
    r = U.rng(505)
    bm_g, bm_s, bm_f, bm_ms, bm_mc, bm_rock = (bmesh.new() for _ in range(6))
    # clumps: a low dark mound rising from below the frame + tall grass + flowers
    clumps = [(-930, 76, 1.3), (-760, 86, 1.0), (-560, 94, 0.8), (-330, 96, 0.75), (-80, 100, 0.6),
              (160, 98, 0.65), (400, 96, 0.8), (610, 92, 0.9), (790, 80, 1.15), (950, 74, 1.3)]
    for ci, (cx, top, s) in enumerate(clumps):
        lane = abs(cx) < 640
        w = r.uniform(80, 120) * s
        for k in range(2):
            rx = w * r.uniform(0.6, 0.75)
            rz = 58.0
            b = U.bm_uvsphere(1.0, 24, 12)
            o = Vector((ci * 3.0, k * 2.0, 0))
            for v in b.verts:
                d = v.co.copy()
                v.co = Vector((d.x * rx, d.y * 30, d.z * rz)) * (1 + 0.05 * U.fbm(d * 2.0 + o, 2))
            cxk = cx + (k - 0.5) * w * 0.5 + r.uniform(-8, 8)
            ctop = top + (0 if k == 0 else r.uniform(4, 12))
            bmesh.ops.translate(b, vec=L.p(cxk, ctop + rz, 8 + k * 4), verts=b.verts)
            U.bm_merge(bm_rock, b)
            # grass fringe along the mound's crest
            for j in range(int(rx / 9)):
                u = r.uniform(-0.85, 0.85)
                gy = ctop + rz * (1 - math.sqrt(1 - u * u)) + 2
                hh = min(r.uniform(8, 18), gy - (47 if lane else -30))
                if hh > 4:
                    PR.grass_tuft(bm_g, L.p(cxk + u * rx, gy, 4 + k * 4 - 6), hh, seed=7000 + ci * 50 + k * 20 + j,
                                  blades=r.randint(5, 8), width=1.8, spread=2.0)
        top_lim = 47 if lane else -30
        for k in range(r.randint(5, 8)):
            gx = cx + r.uniform(-0.55, 0.55) * w
            gy = top + r.uniform(3, 12)
            h = min(r.uniform(30, 56) * (1.3 if not lane else 1.0), gy - top_lim - r.uniform(0, 8))
            if h < 8:
                continue
            PR.grass_tuft(bm_g, L.p(gx, gy, 0), h, seed=5000 + ci * 10 + k, blades=r.randint(8, 12),
                          width=2.0, spread=1.3)
            if r.random() < 0.5:
                fh = min(h * r.uniform(0.85, 1.2), gy - top_lim - 2)
                PR.flower(bm_s, bm_f, L.p(gx + r.uniform(-6, 6), gy, -2), fh, head_r=2.6,
                          lean=r.uniform(-0.25, 0.25))
    # glowing mushroom clusters on the outer clumps
    for i in range(8):
        xx = 790 + r.uniform(-40, 40)
        PR.mushroom(bm_ms, bm_mc, L.p(xx, 86 + r.uniform(0, 8), -12 - i), r.uniform(14, 40),
                    r.uniform(7, 14), lean=r.uniform(-0.3, 0.3))
    for i in range(5):
        xx = -760 + r.uniform(-30, 30)
        PR.mushroom(bm_ms, bm_mc, L.p(xx, 94 + r.uniform(0, 6), -12 - i), r.uniform(10, 24), r.uniform(6, 10),
                    lean=r.uniform(-0.3, 0.3))
    U.obj_from_bm('fg_grass', bm_g, [M['grass']], L.coll)
    U.obj_from_bm('fg_stems', bm_s, [M['stem']], L.coll)
    U.obj_from_bm('fg_flowers', bm_f, [M['flower_p']], L.coll)
    U.obj_from_bm('fg_rock', bm_rock, [M['rock_bare']], L.coll, smooth=True)
    U.obj_from_bm('fg_shroom_stem', bm_ms, [M['shroom_stem']], L.coll, smooth=True)
    U.obj_from_bm('fg_shroom_cap', bm_mc, [M['glowcap']], L.coll, smooth=True)
    L.lights.append((L.p(790, 62, 0), 48, '#90f0e0', 'mushroom'))
    L.lights.append((L.p(-760, 76, 0), 34, '#90f0e0', 'mushroom'))
    # lantern post silhouette at the far left
    pm = dict(stone=M['rock_bare'], gold=M['gold'], paper=M['paper'])
    objs, lc, tip = PR.lantern_post('fg_post', L.p(-905, 84, 0), 130, pm, L.coll, hook_side=1,
                                    lantern_h=18)
    L.lights.append((lc, 34, '#ffc46a', 'lantern'))
    L.strings.append(([tip, lc + Vector((0, 0, 9))], 's0'))
    return L


# ----------------------------------------------------------------------------
# MOON
# ----------------------------------------------------------------------------
def build_moon(M):
    L = Layer('moon', (130, -282), (144, 144), 0.03, -50, tilt=0.0, samples=48)
    bm = U.bm_ico(68, 5)
    r = U.rng(606)
    craters = [(Vector((r.uniform(-1, 1), -1.0, r.uniform(-1, 1))).normalized(), r.uniform(0.07, 0.2))
               for _ in range(22)]
    for v in bm.verts:
        d = v.co.normalized()
        h = 0.0
        for cd, cr in craters:
            a = d.angle(cd)
            if a < cr * 1.35:
                t = a / cr
                h += (-0.05 * (1 - t * t) if t < 1 else 0.02 * (1.35 - t) / 0.35) * cr * 4
        h += 0.008 * U.fbm(d * 4.0, 3)
        v.co = d * 68 * (1 + h)
    U.obj_from_bm('moon', bm, [M['moon']], L.coll, smooth=True, loc=L.p(202, -210, 0))
    lc = U.collection('moonlight')
    U.add_sun('moon_key', '#fff4f0', 3.2, (0.45, 0.8, -0.35), lc, angle_deg=4)
    L.light_colls = ['moonlight']
    L.world = ('#8070c0', 0.5)
    return L
