#!/usr/bin/env python3
"""3D -> pixel VFX strips for Ceu Arcano (Blender 5.x as module, Cycles CPU).

    python3 build_vfx.py

Outputs (game/assets/vfx/):
  star_spin.png    16 frames 24x24  golden faceted 5-point star spinning about Y (tilted)
  lantern_spin.png 16 frames 24x32  paper lantern with gold caps spinning, glowing body
  rock_chunks.png  8x8 grid of 12x12: 8 rocks (rows) x 8 tumbling rotations (columns)
  + <name>.json sidecars {"frame_w", "frame_h", "frames", "cols", "rows"}

Every frame is an instance placed in a grid and the whole sheet is rendered in
one go through the same id/light pass pipeline as the stage, then quantised to
the stage palette with a 1-px dark outline around each sprite.
"""
import json
import math
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402,F401
import bmesh  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Euler, Matrix, Vector  # noqa: E402

import bl_util as U  # noqa: E402
import palette as P  # noqa: E402
import pixelize as PX  # noqa: E402
import props as PR  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(ROOT, 'game', 'assets', 'vfx')
CACHE = os.path.join(HERE, '.cache', 'vfx')


def setup():
    U.reset_scene()
    lc = U.collection('vfx_lights')
    U.add_sun('k', '#fff0d8', 3.2, (0.55, 0.65, -0.55), lc)       # warm key, top-left front
    U.add_sun('r', '#ffb070', 2.5, (-0.6, -0.5, -0.35), lc)       # rim from behind right
    U.add_sun('f', '#8c7fd0', 0.8, (-0.4, 0.7, 0.4), lc)          # cool fill from below
    return lc


def sheet_camera(cols, rows, fw, fh):
    cam = U.ortho_camera('vfx_cam', U.collection('vfx_cam'))
    W, H = cols * fw, rows * fh
    U.setup_layer_camera(cam, (0, 0), (W, H))
    return cam


def cell_center(c, r, fw, fh, dy=0.0):
    """Blender position of the centre of grid cell (c, r) (layer coords, y down)."""
    return Vector((c * fw + fw / 2.0, 0.0, -(r * fh + fh / 2.0 + dy)))


def outer_outline(P_, fw, fh, color):
    """1-px outline outside the silhouette, never crossing frame borders."""
    H, W = P_.shape
    op = P_ >= 0
    out = P_.copy()
    ci = P.INDEX[color]
    yy, xx = np.mgrid[0:H, 0:W]
    for dy, dx in PX.OFFS4:
        nb = PX._shift(op, dy, dx, False)
        # neighbour must be in the same cell
        same = ((yy + dy) // fh == yy // fh) & ((xx + dx) // fw == xx // fw)
        out[(~op) & nb & same] = ci
    return out


def finish(name, ida, la, cfg, fw, fh, cols, rows, frames, outline='s0'):
    d = PX.decode(ida, la)
    Pm, ramp_id, idx = PX.process(d, cfg)
    Pm = outer_outline(Pm, fw, fh, outline)
    PX.save_png(PX.to_rgba(Pm), os.path.join(OUT, f'{name}.png'))
    with open(os.path.join(OUT, f'{name}.json'), 'w') as f:
        json.dump(dict(frame_w=fw, frame_h=fh, frames=frames, cols=cols, rows=rows), f)
    print(f'[vfx] {name}.png {cols * fw}x{rows * fh}')


# ----------------------------------------------------------------------------
def star_mesh(R=10.4, r=4.3, depth=3.4):
    bm = bmesh.new()
    rim = []
    for k in range(10):
        a = math.pi / 2 + math.tau * k / 10
        rr = R if k % 2 == 0 else r
        rim.append(bm.verts.new((math.cos(a) * rr, 0.0, math.sin(a) * rr)))
    f = bm.verts.new((0.0, -depth, 0.0))
    b = bm.verts.new((0.0, depth, 0.0))
    for k in range(10):
        a_, b_ = rim[k], rim[(k + 1) % 10]
        bm.faces.new((f, b_, a_))
        bm.faces.new((b, a_, b_))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def build_star():
    setup()
    coll = U.collection('star')
    mat = U.make_material('star_gold', P.GOLD, 0.0, None)
    fw = fh = 24
    n = 16
    for i in range(n):
        bm = star_mesh()
        rot = Matrix.Rotation(math.radians(-14), 3, 'X') @ Matrix.Rotation(math.tau * i / n, 3, 'Z')
        bmesh.ops.transform(bm, matrix=rot.to_4x4(), verts=bm.verts)
        U.obj_from_bm(f'star{i}', bm, [mat], coll, loc=cell_center(i, 0, fw, fh, dy=0.5))
    sheet_camera(n, 1, fw, fh)
    ida, la = U.render_passes(CACHE, 'star', samples=64, world=('#5a4a80', 0.4), denoise=False)
    cfg = dict(lum=(-2.6, 0.5), classes={
        P.GOLD: dict(ramp=['a1', 'a2', 'a3', 'a4', 'a5', 'a6'], keep=True),
    }, orphan_passes=0)
    finish('star_spin', ida, la, cfg, fw, fh, n, 1, n, outline='a0')


# ----------------------------------------------------------------------------
def build_lantern():
    setup()
    coll = U.collection('lantern')
    fw, fh = 24, 32
    n = 16

    def paper_off(nb):
        co = nb.coord('Object')
        x, y, z = nb.sep(co)
        ang = nb.math('ARCTAN2', y, x)
        rib = nb.lt(nb.math('FRACT', nb.math('MULTIPLY_ADD', ang, 8.0 / math.tau, 0.5)), 0.13)
        # crescent emblem on the +X side
        dx1 = nb.math('SUBTRACT', y, 0.0)
        r1 = nb.math('SQRT', nb.add(nb.mul(dx1, dx1), nb.mul(z, z)))
        dy2 = nb.math('SUBTRACT', y, 1.6)
        r2 = nb.math('SQRT', nb.add(nb.mul(dy2, dy2), nb.mul(nb.math('SUBTRACT', z, 0.8),
                                                               nb.math('SUBTRACT', z, 0.8))))
        front = nb.gt(x, 2.0)
        cres = nb.mul(nb.mul(nb.lt(r1, 4.2), nb.gt(r2, 3.6)), front)
        return nb.math('SUBTRACT', nb.mul(rib, -2.0), nb.mul(cres, 2.0))

    def paper_light(nb):
        f = nb.facing(0.4)
        s = nb.math('MULTIPLY_ADD', nb.math('POWER', nb.math('SUBTRACT', 1.0, f), 1.4), 5.0, 0.9)
        return nb.add_shader(nb.emission(U.hex_lin('#ffb060'), s), nb.diffuse((0.9, 0.7, 0.5)))
    paper = U.make_material('lan_paper', P.LANTERN, paper_off, paper_light)
    gold = U.make_material('lan_gold', P.GOLD, 0.0, None)
    for i in range(n):
        c = cell_center(i, 0, fw, fh, dy=0.5)
        rot = Matrix.Rotation(math.radians(-10), 3, 'X') @ Matrix.Rotation(math.tau * i / n, 3, 'Z')
        # body: ribbed squashed sphere
        bm = U.bm_uvsphere(1.0, 24, 12)
        for v in bm.verts:
            v.co = Vector((v.co.x * 8.6, v.co.y * 8.6, v.co.z * 8.0))
        ob = U.obj_from_bm(f'lan{i}', bm, [paper], coll, smooth=True, loc=c)
        ob.rotation_mode = 'QUATERNION'
        ob.rotation_quaternion = rot.to_quaternion()
        g = bmesh.new()
        U.bm_merge(g, U.bm_cyl(5.0, 4.0, 2.4, segs=10, center=(0, 0, 8.6)))
        U.bm_merge(g, U.bm_cyl(4.0, 5.0, 2.4, segs=10, center=(0, 0, -8.6)))
        U.bm_merge(g, U.bm_cyl(1.6, 1.6, 1.4, segs=8, center=(0, 0, 10.4)))
        U.bm_merge(g, U.bm_cyl(1.3, 0.6, 3.4, segs=6, center=(0, 0, -11.4)))
        PR.crescent_hook(g, Vector((0, 0, 12.6)), 1.8, thickness=1.0, a0=-0.5, a1=3.6, width=0.9)
        ob = U.obj_from_bm(f'lan_gold{i}', g, [gold], coll, smooth=False, loc=c)
        ob.rotation_mode = 'QUATERNION'
        ob.rotation_quaternion = rot.to_quaternion()
    sheet_camera(n, 1, fw, fh)
    ida, la = U.render_passes(CACHE, 'lantern', samples=64, world=('#5a4a80', 0.4), denoise=False)
    cfg = dict(lum=(-2.4, 1.2), classes={
        P.LANTERN: dict(ramp=['a1', 'a2', 'a3', 'a4', 'a5', 'a6'], keep=True, lum=(-0.8, 2.5)),
        P.GOLD: dict(ramp=['s1', 'a0', 'a1', 'a2', 'a3', 'a4'], keep=True),
    }, orphan_passes=0)
    finish('lantern_spin', ida, la, cfg, fw, fh, n, 1, n, outline='s0')


# ----------------------------------------------------------------------------
def build_rocks():
    setup()
    coll = U.collection('rocks')
    fw = fh = 12
    nr, nc = 8, 8

    def cls_fn(nb):
        n = nb.noise(0.32, 2.0, 0.5)
        return nb.lerp(float(P.STONE), float(P.MOSS), nb.gt(n, 0.63))

    def off_fn(nb):
        n = nb.noise(0.5, 2.0, 0.5)
        return nb.math('SUBTRACT', nb.gt(n, 0.66), nb.lt(n, 0.34))
    mat = U.make_material('chunk', cls_fn, off_fn, None)
    for rk in range(nr):
        r = U.rng(900 + rk)
        o = Vector((rk * 17.0, 3.0, 5.0))
        sx, sy, sz = r.uniform(0.75, 1.15), r.uniform(0.75, 1.1), r.uniform(0.6, 0.95)
        axis = Vector((r.uniform(-1, 1), r.uniform(-1, 1), r.uniform(-1, 1))).normalized()
        base = Euler((r.uniform(0, 6.3), r.uniform(0, 6.3), r.uniform(0, 6.3))).to_matrix()
        sub = 1 if rk % 2 else 2
        for c in range(nc):
            bm = U.bm_ico(1.0, sub)
            for v in bm.verts:
                d = v.co.normalized()
                k = 1.0 + 0.32 * U.fbm(d * 1.6 + o, 2)
                v.co = Vector((d.x * sx, d.y * sy, d.z * sz)) * k
            # normalise size to fit the cell
            ext = max(max(abs(v.co.x), abs(v.co.y), abs(v.co.z)) for v in bm.verts)
            s = 4.5 / ext
            bmesh.ops.scale(bm, vec=(s, s, s), verts=bm.verts)
            rot = Matrix.Rotation(math.tau * c / nc, 3, axis) @ base
            ob = U.obj_from_bm(f'rock{rk}_{c}', bm, [mat], coll, smooth=False, loc=cell_center(c, rk, fw, fh))
            ob.rotation_mode = 'QUATERNION'
            ob.rotation_quaternion = rot.to_quaternion()
    sheet_camera(nc, nr, fw, fh)
    ida, la = U.render_passes(CACHE, 'rocks', samples=64, world=('#5a4a80', 0.5), denoise=False)
    cfg = dict(lum=(-3.0, 0.0), classes={
        P.STONE: dict(ramp=['s1', 's2', 's3', 's4', 's5', 's6', 's7'], keep=True),
        P.MOSS: dict(ramp=['t1', 't2', 'm2', 'm3'], keep=True),
    }, orphan_passes=0)
    finish('rock_chunks', ida, la, cfg, fw, fh, nc, nr, nc * nr, outline='s0')


def main():
    t = time.time()
    os.makedirs(OUT, exist_ok=True)
    build_star()
    build_lantern()
    build_rocks()
    print(f'[vfx] done in {time.time() - t:.1f}s')


if __name__ == '__main__':
    main()
