#!/usr/bin/env python3
"""Build the "Jardim das Lanternas Suspensas" stage art (Blender 5.x as module).

    python3 build_stage.py              # build scene, render all layers, post, export
    python3 build_stage.py --only mid   # re-render a subset (others from cache)
    python3 build_stage.py --post-only  # re-run pixel post-processing from cache
    python3 build_stage.py --no-vfx     # skip the VFX strips (build_vfx.py)

Outputs (game/assets/stage/): far.png mid.png near.png ground.png fg.png
moon.png stage.json preview.png.   Raw passes are cached in ./.cache/.
Deterministic: fixed seeds everywhere, fixed Cycles seed / thread count.
"""
import argparse
import json
import math
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import numpy as np  # noqa: E402
from PIL import Image  # noqa: E402

import palette as PAL  # noqa: E402
import pixelize as PX  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(ROOT, 'game', 'assets', 'stage')
CACHE = os.path.join(HERE, '.cache')
LAYERS = ['moon', 'far', 'mid', 'near', 'ground', 'fg']
REF_CAMERA = (0, -110)
VIEW = (640, 360)

# sky gradient used for the preview (world y at the reference camera)
SKY_STOPS = [(-760, PAL.SKY['top']), (-560, PAL.SKY['high']), (-330, PAL.SKY['mid']),
             (-175, PAL.SKY['low']), (-75, PAL.SKY['horizon']), (-25, PAL.SKY['glow'])]


# ----------------------------------------------------------------------------
# render (bpy)
# ----------------------------------------------------------------------------
def render_layers(which):
    import bl_util as U
    import stage_scene as S
    t0 = time.time()
    U.reset_scene()
    M = S.make_materials()
    S.lights_rig()
    builders = dict(moon=S.build_moon, far=S.build_far, mid=S.build_mid, near=S.build_near,
                    ground=S.build_ground, fg=S.build_fg)
    layers = {}
    for name in LAYERS:
        layers[name] = builders[name](M)
    cam = U.ortho_camera('layer_cam', U.collection('cameras'))
    print(f'[stage] scene built in {time.time() - t0:.1f}s')
    os.makedirs(CACHE, exist_ok=True)
    for name in which:
        L = layers[name]
        t1 = time.time()
        U.only_collections([name, 'cameras'] + L.light_colls)
        U.setup_layer_camera(cam, L.origin, L.size, tilt_deg=L.tilt)
        ida, la = U.render_passes(os.path.join(CACHE, 'exr'), name, samples=L.samples, world=L.world)
        meta = dict(
            name=name, origin=list(L.origin), size=list(L.size), parallax=L.parallax, z=L.z,
            front=L.front, tilt=L.tilt,
            lights=[dict(p=U.project(cam, p), r=rad, color=col, kind=kind) for p, rad, col, kind in L.lights],
            waterfalls=[dict(top=U.project(cam, a), bot=U.project(cam, b), w=w) for a, b, w in L.waterfalls],
            strings=[dict(pts=[U.project(cam, q) for q in pts], color=col) for pts, col in L.strings],
        )
        np.savez_compressed(os.path.join(CACHE, f'{name}.npz'), ida=ida, la=la)
        with open(os.path.join(CACHE, f'{name}.json'), 'w') as f:
            json.dump(meta, f)
        print(f'[stage] rendered {name} {L.size} in {time.time() - t1:.1f}s')


# ----------------------------------------------------------------------------
# post (numpy)
# ----------------------------------------------------------------------------
def layer_cfg(name):
    import importlib
    S = importlib.import_module('stage_cfg')
    return S.CFG[name]


def fade_waterfalls(P, ramp_id, meta):
    """Dissolve the lower part of each waterfall into mist (ordered dither)."""
    H, W = P.shape
    for wf in meta['waterfalls']:
        (x0, y0), (x1, y1) = wf['top'], wf['bot']
        yt, yb = int(min(y0, y1)), int(max(y0, y1))
        xc = (x0 + x1) / 2
        hw = wf['w'] / 2 + 3
        xa, xb = max(0, int(xc - hw - 2)), min(W, int(xc + hw + 3))
        for y in range(max(0, yt), min(H, yb + 4)):
            t = (y - yt) / max(1, (yb - yt))
            if t < 0.55:
                continue
            k = (t - 0.55) / 0.45
            for x in range(xa, xb):
                if ramp_id[y, x] == PAL.WATER and P[y, x] >= 0:
                    if PX.BAYER4[y % 4, x % 4] < k * 1.05:
                        P[y, x] = -1
    return P


def post_layer(name):
    z = np.load(os.path.join(CACHE, f'{name}.npz'))
    with open(os.path.join(CACHE, f'{name}.json')) as f:
        meta = json.load(f)
    cfg = layer_cfg(name)
    d = PX.decode(z['ida'], z['la'])
    P, ramp_id, idx = PX.process(d, cfg)
    if meta['waterfalls']:
        P = fade_waterfalls(P, ramp_id, meta)
    for s in meta['strings']:
        P = PX.draw_polyline(P, s['pts'], s['color'], behind=True)
    rgba = PX.to_rgba(P)
    PX.save_png(rgba, os.path.join(OUT, f'{name}.png'))
    return rgba, meta


def hex_to_rgb(h):
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32)


def sky_preview(h=VIEW[1], w=VIEW[0]):
    ys = np.arange(h) + REF_CAMERA[1] - h / 2
    cols = np.zeros((h, 3), np.float32)
    stops = SKY_STOPS
    for i, y in enumerate(ys):
        if y <= stops[0][0]:
            cols[i] = hex_to_rgb(stops[0][1])
        elif y >= stops[-1][0]:
            cols[i] = hex_to_rgb(stops[-1][1])
        else:
            for (ya, ca), (yb, cb) in zip(stops[:-1], stops[1:]):
                if ya <= y <= yb:
                    t = (y - ya) / (yb - ya)
                    cols[i] = hex_to_rgb(ca) * (1 - t) + hex_to_rgb(cb) * t
                    break
    img = np.repeat(cols[:, None, :], w, axis=1)
    return np.concatenate([img, np.full((h, w, 1), 255, np.float32)], -1).astype(np.uint8)


def paste(dst, src, ox, oy):
    """Alpha-paste src (binary alpha) at integer offset."""
    H, W = dst.shape[:2]
    h, w = src.shape[:2]
    x0, y0 = max(0, ox), max(0, oy)
    x1, y1 = min(W, ox + w), min(H, oy + h)
    if x1 <= x0 or y1 <= y0:
        return
    s = src[y0 - oy:y1 - oy, x0 - ox:x1 - ox]
    m = s[..., 3:4] > 127
    dst[y0:y1, x0:x1] = np.where(m, s, dst[y0:y1, x0:x1])


def make_preview(imgs, metas, path, cam=REF_CAMERA, zoom=1.0, fighters=False):
    """Composite as Godot would show it: camera `cam`, `zoom` (parallax layers
    scale with the camera zoom around the screen centre)."""
    W, H = int(round(VIEW[0] / zoom)), int(round(VIEW[1] / zoom))
    out = sky_preview(H, W) if zoom == 1.0 else _sky_zoomed(H, W, cam)

    def place(name):
        m = metas[name]
        par = m['parallax']
        ox = m['origin'][0] + (1 - par) * (cam[0] - REF_CAMERA[0]) - cam[0] + W // 2
        oy = m['origin'][1] + (1 - par) * (cam[1] - REF_CAMERA[1]) - cam[1] + H // 2
        paste(out, imgs[name], int(round(ox)), int(round(oy)))
    for name in ['moon', 'far', 'mid', 'near', 'ground']:
        place(name)
    if fighters:
        for fx in (-140, 140):
            sx, sy = int(fx - cam[0] + W // 2), int(0 - cam[1] + H // 2)
            out[sy - 56:sy, sx - 9:sx + 9, :3] = (20, 16, 40)
            out[sy - 70:sy - 56, sx - 6:sx + 6, :3] = (20, 16, 40)
    place('fg')
    im = Image.fromarray(out, 'RGBA').convert('RGB')
    if zoom != 1.0:
        im = im.resize(VIEW, Image.NEAREST)
    im.save(path)


def _sky_zoomed(H, W, cam):
    ys = np.arange(H) + cam[1] - H / 2
    cols = np.zeros((H, 3), np.float32)
    for i, y in enumerate(ys):
        st = SKY_STOPS
        if y <= st[0][0]:
            cols[i] = hex_to_rgb(st[0][1])
        elif y >= st[-1][0]:
            cols[i] = hex_to_rgb(st[-1][1])
        else:
            for (ya, ca), (yb, cb) in zip(st[:-1], st[1:]):
                if ya <= y <= yb:
                    t = (y - ya) / (yb - ya)
                    cols[i] = hex_to_rgb(ca) * (1 - t) + hex_to_rgb(cb) * t
                    break
    img = np.repeat(cols[:, None, :], W, axis=1)
    return np.concatenate([img, np.full((H, W, 1), 255, np.float32)], -1).astype(np.uint8)


def export_json(metas):
    layers = []
    lights = []
    waterfalls = []
    for name in ['far', 'mid', 'near', 'ground', 'fg']:
        m = metas[name]
        e = dict(name=name, file=f'{name}.png', parallax=m['parallax'],
                 origin=[int(m['origin'][0]), int(m['origin'][1])], size=m['size'], z=m['z'])
        if m['front']:
            e['front'] = True
        layers.append(e)
    for name in ['far', 'mid', 'near', 'ground', 'fg']:
        m = metas[name]
        for l in m['lights']:
            lights.append(dict(layer=name, x=int(round(l['p'][0])), y=int(round(l['p'][1])),
                               r=int(round(l['r'])), color=l['color'], kind=l['kind']))
        for w in m['waterfalls']:
            (x0, y0), (x1, y1) = w['top'], w['bot']
            ww = int(math.ceil(w['w']))
            waterfalls.append(dict(layer=name, x=int(round((x0 + x1) / 2 - ww / 2)), y=int(round(min(y0, y1))),
                                   w=ww, h=int(round(abs(y1 - y0)))))
    mm = metas['moon']
    doc = {
        'name': 'Jardim das Lanternas Suspensas',
        'ref_camera': list(REF_CAMERA),
        'floor_y': 0,
        'layers': layers,
        'moon': dict(file='moon.png', parallax=mm['parallax'],
                     origin=[int(mm['origin'][0]), int(mm['origin'][1])], size=mm['size']),
        'lights': lights,
        'waterfalls': waterfalls,
        'sky_preview_stops': [[y, c] for y, c in SKY_STOPS],
        'palette': [PAL.PALETTE[n] for n in PAL.NAMES],
        'notes': ('origin = world position of the image top-left with the camera at ref_camera, '
                  'zoom 1. lights/waterfalls are in pixels of the named layer image (x,y = light '
                  'centre; waterfall x,y = top-left of the strip). Fighter-safe: fg props inside '
                  '|x| < 640 stay below y = +46.'),
    }
    with open(os.path.join(OUT, 'stage.json'), 'w') as f:
        json.dump(doc, f, indent=1)


def post_all():
    os.makedirs(OUT, exist_ok=True)
    imgs, metas = {}, {}
    for name in LAYERS:
        t = time.time()
        imgs[name], metas[name] = post_layer(name)
        print(f'[stage] post {name} {imgs[name].shape[1]}x{imgs[name].shape[0]} in {time.time() - t:.1f}s')
    export_json(metas)
    make_preview(imgs, metas, os.path.join(OUT, 'preview.png'), fighters=False)
    if os.environ.get('STAGE_REVIEW_DIR'):
        d = os.environ['STAGE_REVIEW_DIR']
        for tag, cam, z in [('wide', (0, -110), 0.72), ('wide_right', (356, -110), 0.72),
                            ('high', (0, -380), 0.72), ('high_close', (-200, -380), 1.15),
                            ('fighters', (0, -110), 1.0)]:
            make_preview(imgs, metas, os.path.join(d, f'review_{tag}.png'), cam=cam, zoom=z,
                         fighters=True)
    return imgs, metas


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--only', default='', help='comma separated layers to (re)render')
    ap.add_argument('--post-only', action='store_true')
    ap.add_argument('--no-vfx', action='store_true')
    a = ap.parse_args()
    t0 = time.time()
    if not a.post_only:
        which = [s for s in a.only.split(',') if s] or LAYERS
        missing = [n for n in LAYERS if not os.path.exists(os.path.join(CACHE, f'{n}.npz'))]
        which = list(dict.fromkeys(which + missing))
        render_layers([n for n in LAYERS if n in which])
    post_all()
    if not a.no_vfx and not a.post_only:
        import subprocess
        subprocess.check_call([sys.executable, os.path.join(HERE, 'build_vfx.py')])
    print(f'[stage] done in {time.time() - t0:.1f}s')


if __name__ == '__main__':
    main()
