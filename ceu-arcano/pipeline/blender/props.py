"""Procedural prop generators (bmesh / curves).  All sizes in art pixels.

Coordinates passed in are Blender coords: X right, Y depth (away from the
camera), Z up.  Use px(x, y, depth) to convert from layer pixel space.
"""
import math

import bpy  # noqa: F401  (must be imported before bmesh)
import bmesh
from mathutils import Matrix, Vector, noise

from bl_util import (bm_box, bm_cyl, bm_ico, bm_merge, bm_uvsphere, curve_obj, fbm,
                     obj_from_bm, rng)


def px(x, y, depth=0.0):
    """layer/world pixel coords (y down) -> Blender coords."""
    return Vector((x, depth, -y))


# ----------------------------------------------------------------------------
# floating island
# ----------------------------------------------------------------------------
def island(name, center, rx, ry, top_h, under_h, mats, coll, seed=0, subdiv=4,
           spike=0.45, lumpy=0.12, tilt=0.0, flat_top=True):
    """Floating rock with a flattish grassy top and a jagged conical underside.
    center = Blender coords of the top-surface centre.  mats = [rock_mat]."""
    r = rng(seed)
    o = Vector((r.uniform(-50, 50), r.uniform(-50, 50), r.uniform(-50, 50)))
    bm = bm_ico(1.0, subdiv)
    lobes = r.randint(3, 6)
    ph = r.uniform(0, 6.28)
    for v in bm.verts:
        d = v.co.normalized()
        lat = math.asin(max(-1.0, min(1.0, d.z)))
        ang = math.atan2(d.y, d.x)
        n = fbm(d * 1.7 + o, 4)
        if lat >= 0:
            rad = (math.cos(lat) ** 0.22) * (1.0 + lumpy * n)
            z = top_h * (math.sin(lat) ** (0.35 if flat_top else 0.8))
            z += top_h * 0.25 * fbm(d * 3.0 + o * 2, 2)
        else:
            s = abs(math.sin(lat))
            rad = (math.cos(lat) ** 1.35) * (1.0 + lumpy * 1.3 * n)
            lob = 0.5 + 0.5 * math.cos(ang * lobes + ph + 1.3 * noise.noise(d * 2 + o))
            jag = abs(noise.noise(Vector((ang * 2.2, s * 3.0, 0.0)) + o))
            depth = under_h * (s ** 0.75) * (0.55 + spike * (0.6 * lob + 1.2 * jag))
            z = -depth
        v.co = Vector((d.x / max(1e-6, math.hypot(d.x, d.y)) * rad * rx if (d.x or d.y) else 0.0,
                       d.y / max(1e-6, math.hypot(d.x, d.y)) * rad * ry if (d.x or d.y) else 0.0,
                       z))
    # light 3D roughening
    for v in bm.verts:
        p = v.co
        n3 = Vector((fbm(p * 0.045 + o, 3), fbm(p * 0.045 + o + Vector((9, 0, 0)), 3),
                     fbm(p * 0.045 + o + Vector((0, 9, 0)), 3)))
        v.co = p + n3 * (min(rx, under_h) * 0.07)
    if tilt:
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(tilt, 3, 'Y'))
    ob = obj_from_bm(name, bm, mats, coll, smooth=False, loc=center)
    return ob


def island_bottom_points(ob, count, seed=0, min_drop=0.3):
    """Random points on the underside of an island (world coords)."""
    r = rng(seed)
    me = ob.data
    loc = ob.location.copy()          # matrix_world is stale until a depsgraph update
    zs = [v.co.z for v in me.vertices]
    zmin = min(zs)
    cands = [loc + v.co for v in me.vertices if v.co.z < zmin * min_drop and v.co.y < 0.25 * abs(zmin) + 5]
    r.shuffle(cands)
    return cands[:count]


def hanging_root(name, start, length, mat, coll, seed=0, thick=1.6):
    r = rng(seed)
    pts, rads = [], []
    n = 8
    sway = r.uniform(-0.35, 0.35)
    for i in range(n + 1):
        t = i / n
        x = start.x + sway * length * t * t + r.uniform(-1.0, 1.0) * t * 2
        z = start.z - length * t
        pts.append(Vector((x, start.y - 2, z)))
        rads.append(max(0.25, (1.0 - t) ** 0.8))
    return curve_obj(name, pts, rads, mat, coll, bevel=thick, res=1, kind='NURBS')


# ----------------------------------------------------------------------------
# trees
# ----------------------------------------------------------------------------
def canopy(name, center, radius, mat, coll, seed=0, clumps=7, squash=0.8, subdiv=3,
           spread=0.75):
    """A round canopy from overlapping displaced spheres ("clumps")."""
    r = rng(seed)
    bm = bmesh.new()
    pts = [(0.0, 0.0, 0.0, 1.0)]
    for i in range(clumps - 1):
        a = i / (clumps - 1) * math.tau + r.uniform(-0.3, 0.3)
        e = r.uniform(-0.35, 0.75)
        rr = r.uniform(0.45, 0.7)
        pts.append((math.cos(a) * math.cos(e) * spread, r.uniform(-0.3, 0.3),
                    math.sin(e) * spread * squash + 0.1, rr))
    o = Vector((r.uniform(-50, 50), r.uniform(-50, 50), 0))
    for (x, y, z, s) in pts:
        rr = radius * s * 0.62
        sd_ = subdiv if rr < 30 else subdiv + 1
        b = bm_ico(rr, sd_)
        leafy = 7.0 if rr > 12 else 4.0
        for v in b.verts:
            d = v.co.normalized()
            q = o + Vector((x, y, z)) * 3
            k = 1.0 + 0.12 * fbm(d * 2.5 + q, 3) + 0.09 * abs(noise.noise(d * leafy + q * 2.0))
            v.co = v.co * k
            v.co.z *= squash
        bmesh.ops.translate(b, vec=(x * radius, y * radius, z * radius), verts=b.verts)
        bm_merge(bm, b)
    return obj_from_bm(name, bm, [mat], coll, smooth=True, loc=center)


def trunk(name, base, height, mat, coll, seed=0, thick=5.0, lean=0.2, branches=3,
          canopy_r=40):
    """Curvy trunk with a few branches; returns (object, [branch tip points])."""
    r = rng(seed)
    objs = []
    pts, rads = [], []
    n = 7
    bend = r.uniform(-1, 1) * lean
    for i in range(n + 1):
        t = i / n
        x = base.x + height * (bend * t + 0.15 * math.sin(t * 3.0 + seed)) * t
        z = base.z + height * t
        pts.append(Vector((x, base.y, z)))
        rads.append(1.25 - 0.6 * t + (0.5 if i == 0 else 0))
    objs.append(curve_obj(name, pts, rads, mat, coll, bevel=thick, res=2, kind='NURBS'))
    tips = [pts[-1]]
    for b in range(branches):
        t0 = r.uniform(0.5, 0.85)
        i0 = int(t0 * n)
        p0 = pts[i0]
        side = -1 if b % 2 == 0 else 1
        ln = height * r.uniform(0.3, 0.45)
        p1 = p0 + Vector((side * ln * 0.8, r.uniform(-4, 4), ln * 0.55))
        p2 = p1 + Vector((side * ln * 0.25, 0, ln * 0.25))
        objs.append(curve_obj(f'{name}_br{b}', [p0, p1, p2], [0.7, 0.45, 0.3], mat, coll,
                              bevel=thick, res=1, kind='NURBS'))
        tips.append(p2)
    return objs, tips


def blossom_tree(name, base, height, trunk_mat, leaf_mats, coll, seed=0, size=1.0,
                 thick=4.0, lean=0.25):
    r = rng(seed)
    objs, tips = trunk(name + '_trunk', base, height, trunk_mat, coll, seed=seed,
                       thick=thick, lean=lean)
    cans = []
    top = tips[0]
    R = height * 0.55 * size
    cans.append(canopy(name + '_can0', top + Vector((0, -2, R * 0.15)), R, leaf_mats[0], coll,
                       seed=seed + 1, clumps=8))
    for i, tp in enumerate(tips[1:]):
        m = leaf_mats[(i + 1) % len(leaf_mats)]
        cans.append(canopy(f'{name}_can{i + 1}', tp + Vector((0, -4 - i, R * 0.1)), R * r.uniform(0.55, 0.7),
                           m, coll, seed=seed + 7 + i, clumps=6))
    return objs + cans


# ----------------------------------------------------------------------------
# architecture
# ----------------------------------------------------------------------------
def pillar(name, base, height, radius, mat, coll, seed=0, broken=True, segs=10):
    """Ruined round pillar: plinth, shaft (optionally broken top), capital."""
    r = rng(seed)
    bm = bmesh.new()
    # plinth
    bm_merge(bm, bm_box(radius * 2.7, radius * 2.7, radius * 0.7, center=(0, 0, radius * 0.35),
                        bevel=0.8))
    bm_merge(bm, bm_box(radius * 2.3, radius * 2.3, radius * 0.4, center=(0, 0, radius * 0.9),
                        bevel=0.6))
    sh = bm_cyl(radius, radius * 0.9, height, segs=segs, center=(0, 0, radius * 1.1 + height / 2))
    if broken:
        top = max(v.co.z for v in sh.verts)
        o = r.uniform(0, 100)
        for v in sh.verts:
            if v.co.z > top - 0.1:
                a = math.atan2(v.co.y, v.co.x)
                v.co.z -= abs(noise.noise(Vector((a * 1.5 + o, 0, 0)))) * radius * 2.5 + \
                    (v.co.x / radius) * radius * 0.9
    bm_merge(bm, sh)
    if not broken:
        z0 = radius * 1.1 + height
        bm_merge(bm, bm_box(radius * 2.5, radius * 2.5, radius * 0.6, center=(0, 0, z0 + radius * 0.3),
                            bevel=0.8))
    return obj_from_bm(name, bm, [mat], coll, smooth=False, loc=base)


def ring_slab(name, center, R, r_in, thick, mat, coll, a0=0.0, a1=math.tau, segs=48,
              seed=0, jag=0.0, rot_y=0.0):
    """Annulus (ring with square cross-section) in the XZ plane, thickness
    along Y.  a0..a1 angular span (radians, 0 = +X, CCW) for ruins; jag
    roughens the broken ends."""
    r = rng(seed)
    bm = bmesh.new()
    full = abs(a1 - a0) >= math.tau - 1e-6
    n = segs if full else max(3, int(segs * abs(a1 - a0) / math.tau))
    rows = []
    for i in range(n + (0 if full else 1)):
        a = a0 + (a1 - a0) * i / n
        ca, sa = math.cos(a), math.sin(a)
        ro, ri = R, r_in
        if not full and (i == 0 or i == n) and jag:
            ro *= 1 - r.uniform(0, jag)
        vs = [bm.verts.new((ca * ri, -thick / 2, sa * ri)), bm.verts.new((ca * ro, -thick / 2, sa * ro)),
              bm.verts.new((ca * ro, thick / 2, sa * ro)), bm.verts.new((ca * ri, thick / 2, sa * ri))]
        rows.append(vs)
    m = len(rows)
    for i in range(m if full else m - 1):
        A, B = rows[i], rows[(i + 1) % m]
        for k in range(4):
            bm.faces.new((A[k], A[(k + 1) % 4], B[(k + 1) % 4], B[k]))
    if not full:
        bm.faces.new(rows[0][::-1])
        bm.faces.new(rows[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if rot_y:
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(rot_y, 3, 'Y'))
    return obj_from_bm(name, bm, [mat], coll, smooth=False, loc=center)


# ----------------------------------------------------------------------------
# lanterns
# ----------------------------------------------------------------------------
def paper_lantern(name, center, h, mat_paper, mat_gold, coll, w=None, segs=10, ribs=True):
    """Round paper lantern (squashed sphere) with gold caps; center = Blender
    coords of the body centre.  Returns [objects]."""
    w = w or h * 0.8
    b = bm_uvsphere(1.0, segs, 8)
    for v in b.verts:
        v.co.x *= w / 2
        v.co.y *= w / 2
        v.co.z *= h / 2
    o1 = obj_from_bm(name, b, [mat_paper], coll, smooth=True, loc=center)
    cap_r = w * 0.28
    cap_h = max(1.2, h * 0.12)
    bm = bmesh.new()
    bm_merge(bm, bm_cyl(cap_r, cap_r * 0.8, cap_h, segs=8, center=(0, 0, h / 2 + cap_h * 0.3)))
    bm_merge(bm, bm_cyl(cap_r * 0.8, cap_r, cap_h, segs=8, center=(0, 0, -h / 2 - cap_h * 0.3)))
    o2 = obj_from_bm(name + '_caps', bm, [mat_gold], coll, smooth=False, loc=center)
    return [o1, o2]


# ----------------------------------------------------------------------------
# water, clouds
# ----------------------------------------------------------------------------
def waterfall(name, top, length, width, mat, coll, lip=4.0, seed=0):
    """Thin falling sheet: short outward lip then straight down (towards -Z).
    top = Blender coords of the lip start.  Returns object."""
    bm = bmesh.new()
    n = 10
    rows = []
    for i in range(n + 1):
        t = i / n
        z = -length * t
        y = -lip * min(1.0, t * 6)            # bulge towards camera at the lip
        w = width * (1.0 + 0.35 * t)
        rows.append([bm.verts.new((-w / 2, y - 1.0, z)), bm.verts.new((w / 2, y - 1.0, z)),
                     bm.verts.new((w / 2, y + 1.0, z)), bm.verts.new((-w / 2, y + 1.0, z))])
    for a, b in zip(rows[:-1], rows[1:]):
        for k in range(4):
            bm.faces.new((a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]))
    bm.faces.new(rows[0][::-1])
    bm.faces.new(rows[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return obj_from_bm(name, bm, [mat], coll, smooth=False, loc=top)


def cloud_puff(bm, center, rx, rz, ry=None, seed=0, subdiv=3):
    r = rng(seed)
    ry = ry or rx * 0.7
    b = bm_ico(1.0, subdiv)
    o = Vector((r.uniform(-50, 50), r.uniform(-50, 50), r.uniform(-50, 50)))
    for v in b.verts:
        d = v.co.normalized()
        k = 1.0 + 0.05 * fbm(d * 1.8 + o, 2)
        z = d.z * rz * k
        if z < 0:
            z *= 0.6                        # flatter bottoms
        v.co = Vector((d.x * rx * k, d.y * ry * k, z))
    bmesh.ops.translate(b, vec=center, verts=b.verts)
    return bm_merge(bm, b)


# ----------------------------------------------------------------------------
# small plants
# ----------------------------------------------------------------------------
def grass_tuft(bm, base, height, seed=0, blades=7, width=1.2, spread=1.0):
    r = rng(seed)
    for i in range(blades):
        h = height * r.uniform(0.55, 1.0)
        b = bmesh.new()
        bmesh.ops.create_cone(b, cap_ends=False, segments=3, radius1=width * r.uniform(0.8, 1.2),
                              radius2=0.05, depth=h)
        bmesh.ops.translate(b, vec=(0, 0, h / 2), verts=b.verts)
        ang = (i / max(1, blades - 1) - 0.5) * 1.1 * spread + r.uniform(-0.15, 0.15)
        bmesh.ops.rotate(b, verts=b.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(ang, 3, 'Y'))
        bmesh.ops.translate(b, vec=base + Vector((r.uniform(-1.5, 1.5) * spread, r.uniform(-1, 1), 0)),
                            verts=b.verts)
        bm_merge(bm, b)
    return bm


def flower(bm_stem, bm_head, base, height, head_r=1.6, seed=0, lean=0.0):
    b = bm_cyl(0.45, 0.35, height, segs=4, center=(0, 0, height / 2))
    bmesh.ops.rotate(b, verts=b.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(lean, 3, 'Y'))
    bmesh.ops.translate(b, vec=base, verts=b.verts)
    bm_merge(bm_stem, b)
    tip = base + Matrix.Rotation(lean, 3, 'Y') @ Vector((0, 0, height))
    h = bm_ico(head_r, 1)
    bmesh.ops.translate(h, vec=tip, verts=h.verts)
    bm_merge(bm_head, h)
    return tip


def mushroom(bm_stem, bm_cap, base, height, cap_r, lean=0.0):
    b = bm_cyl(cap_r * 0.3, cap_r * 0.22, height, segs=6, center=(0, 0, height / 2))
    bmesh.ops.rotate(b, verts=b.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(lean, 3, 'Y'))
    bmesh.ops.translate(b, vec=base, verts=b.verts)
    bm_merge(bm_stem, b)
    tip = base + Matrix.Rotation(lean, 3, 'Y') @ Vector((0, 0, height))
    c = bm_uvsphere(1.0, 12, 6)
    for v in c.verts:
        if v.co.z < 0:
            v.co.z *= 0.15
        v.co = Vector((v.co.x * cap_r, v.co.y * cap_r, v.co.z * cap_r * 0.62))
    bmesh.ops.rotate(c, verts=c.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(lean * 1.3, 3, 'Y'))
    bmesh.ops.translate(c, vec=tip, verts=c.verts)
    bm_merge(bm_cap, c)
    return tip


# ----------------------------------------------------------------------------
# moon gate, posts, balustrade, flagstones
# ----------------------------------------------------------------------------
def moon_gate(name, center, R, mats, coll, seed=0, missing=(), thick=24.0, base_w=None,
              rune_pts=None):
    """Circular stone gate built from voussoir blocks.
    mats = dict(stone=, trim=, rune=)
    center = Blender coords of the ring centre.  missing = block indices left out.
    Returns list of objects and list of rune world positions."""
    r = rng(seed)
    objs = []
    n = 16
    r_in = R * 0.68
    gap = 0.012
    bm = bmesh.new()
    for i in range(n):
        if i in missing:
            continue
        a0 = math.tau * i / n + gap - math.pi / 2 + math.pi / n
        a1 = math.tau * (i + 1) / n - gap - math.pi / 2 + math.pi / n
        b = _ring_bm(R * (1 + r.uniform(-0.015, 0.02)), r_in, thick + r.uniform(-1.5, 1.5), a0, a1, 3)
        bmesh.ops.translate(b, vec=(0, r.uniform(-1.5, 1.5), 0), verts=b.verts)
        bm_merge(bm, b)
    objs.append(obj_from_bm(name + '_ring', bm, [mats['stone']], coll, loc=center))
    # carved inner moulding ring + outer thin ring (front)
    bm = bmesh.new()
    segs = 48
    for i in range(segs):
        blk = int(((i + 0.5) / segs) * n) % n
        if blk in missing:
            continue
        a0 = math.tau * i / segs - math.pi / 2 + math.pi / n
        a1 = math.tau * (i + 1) / segs - math.pi / 2 + math.pi / n
        bm_merge(bm, _ring_bm(r_in + R * 0.06, r_in - R * 0.02, thick + 4, a0, a1, 1))
        bm_merge(bm, _ring_bm(R * 0.9, R * 0.85, thick + 3, a0, a1, 1))
    objs.append(obj_from_bm(name + '_trim', bm, [mats['trim']], coll, loc=center))
    runes = []
    if 'rune' in mats:
        bm = bmesh.new()
        for i in range(n):
            if i in missing or i % 2:
                continue
            a = math.tau * (i + 0.5) / n - math.pi / 2 + math.pi / n
            rr = (R * 0.85 + r_in + R * 0.06) / 2
            p = Vector((math.cos(a) * rr, -thick / 2 - 1.0, math.sin(a) * rr))
            g = bm_box(2.2, 1.0, 3.2)
            bmesh.ops.rotate(g, verts=g.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(-a + math.pi / 2, 3, 'Y'))
            bmesh.ops.translate(g, vec=p, verts=g.verts)
            bm_merge(bm, g)
            runes.append(center + p)
        objs.append(obj_from_bm(name + '_runes', bm, [mats['rune']], coll, loc=center))
    # base: two plinths + step slab
    bw = base_w or R * 2.5
    bm = bmesh.new()
    zb = -R - 2
    bm_merge(bm, bm_box(R * 0.55, thick + 10, 14, center=(-R * 0.62, 0, zb - 4), bevel=1.2))
    bm_merge(bm, bm_box(R * 0.55, thick + 10, 14, center=(R * 0.62, 0, zb - 4), bevel=1.2))
    bm_merge(bm, bm_box(bw, thick + 26, 10, center=(0, 0, zb - 15), bevel=1.5))
    objs.append(obj_from_bm(name + '_base', bm, [mats['stone']], coll, loc=center))
    return objs, runes


def _ring_bm(R, r_in, thick, a0, a1, n):
    bm = bmesh.new()
    rows = []
    for i in range(n + 1):
        a = a0 + (a1 - a0) * i / n
        ca, sa = math.cos(a), math.sin(a)
        rows.append([bm.verts.new((ca * r_in, -thick / 2, sa * r_in)), bm.verts.new((ca * R, -thick / 2, sa * R)),
                     bm.verts.new((ca * R, thick / 2, sa * R)), bm.verts.new((ca * r_in, thick / 2, sa * r_in))])
    for A, B in zip(rows[:-1], rows[1:]):
        for k in range(4):
            bm.faces.new((A[k], A[(k + 1) % 4], B[(k + 1) % 4], B[k]))
    bm.faces.new(rows[0][::-1])
    bm.faces.new(rows[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def crescent_hook(bm, center, R, thickness=1.6, a0=0.6, a1=5.4, width=None):
    """Crescent-moon shaped metal hook in the XZ plane."""
    width = width or R * 0.45
    b = bmesh.new()
    n = 14
    rows = []
    for i in range(n + 1):
        t = i / n
        a = a0 + (a1 - a0) * t
        w = width * math.sin(math.pi * t) + 0.6
        ro, ri = R, R - w
        ca, sa = math.cos(a), math.sin(a)
        rows.append([b.verts.new((ca * ri, -thickness / 2, sa * ri)), b.verts.new((ca * ro, -thickness / 2, sa * ro)),
                     b.verts.new((ca * ro, thickness / 2, sa * ro)), b.verts.new((ca * ri, thickness / 2, sa * ri))])
    for A, B in zip(rows[:-1], rows[1:]):
        for k in range(4):
            b.faces.new((A[k], A[(k + 1) % 4], B[(k + 1) % 4], B[k]))
    bmesh.ops.recalc_face_normals(b, faces=b.faces)
    bmesh.ops.translate(b, vec=center, verts=b.verts)
    return bm_merge(bm, b)


def lantern_post(name, base, height, mats, coll, seed=0, hook_side=1, lantern_h=12.0):
    """Slender carved stone post topped by a crescent hook holding a paper
    lantern.  Returns (objects, lantern_center)."""
    bm = bmesh.new()
    w = max(5.0, height * 0.075)
    bm_merge(bm, bm_box(w * 2.0, w * 2.0, w * 0.9, center=(0, 0, w * 0.45), bevel=0.8))
    bm_merge(bm, bm_box(w * 1.5, w * 1.5, w * 0.5, center=(0, 0, w * 1.15), bevel=0.5))
    bm_merge(bm, bm_box(w, w, height, center=(0, 0, w * 1.4 + height / 2), bevel=0.6))
    top = w * 1.4 + height
    bm_merge(bm, bm_box(w * 1.6, w * 1.6, w * 0.5, center=(0, 0, top + w * 0.25), bevel=0.5))
    bm_merge(bm, bm_box(w * 1.1, w * 1.1, w * 0.9, center=(0, 0, top + w * 0.95), bevel=0.4))
    objs = [obj_from_bm(name, bm, [mats['stone']], coll, loc=base)]
    # crescent hook rising from the top, opening to the side
    hb = bmesh.new()
    R = w * 1.7
    hc = Vector((hook_side * R * 0.55, 0, top + w * 1.4 + R))
    crescent_hook(hb, hc, R, a0=(0.9 if hook_side > 0 else 2.24) + math.pi, a1=(0.9 if hook_side > 0 else 2.24) + math.pi + 4.2,
                  width=R * 0.55)
    objs.append(obj_from_bm(name + '_hook', hb, [mats['gold']], coll, loc=base))
    tip = base + Vector((hook_side * (R * 0.55 + R * 0.95), -1, top + w * 1.4 + R * 0.9))
    lc = tip + Vector((0, -1.0, -lantern_h * 0.5 - 4))
    objs += paper_lantern(name + '_lan', lc, lantern_h, mats['paper'], mats['gold'], coll)
    return objs, lc, tip


def baluster_bm(bm, base, h, r):
    """Vase-shaped baluster from stacked cones."""
    parts = [(r * 0.8, r * 0.8, 0.12), (r * 0.6, r * 1.0, 0.3), (r * 1.0, r * 0.5, 0.3),
             (r * 0.55, r * 0.9, 0.16), (r * 0.9, r * 0.9, 0.12)]
    z = 0.0
    for r1, r2, f in parts:
        d = h * f
        bm_merge(bm, bm_cyl(r1, r2, d, segs=8, center=(base.x, base.y, base.z + z + d / 2)))
        z += d
    return bm
