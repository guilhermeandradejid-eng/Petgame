"""Post-processing: (id pass, light pass) -> palette-locked pixel art.

Pure numpy / Pillow (no bpy), so it can be re-run from cached passes with
`python3 build_stage.py --post-only`.

Per pixel the id pass gives the material class, a ramp offset (procedural
cracks, strata, moss patches ...) and the camera depth; the light pass gives
the lighting of a white material.  Each layer config maps
class -> ramp (palette names, dark -> light) and turns log-luminance into a
ramp index.  Then: orphan clean-up, selective outline, inner depth outlines,
optional ordered dither (far, soft gradients only).
"""
import numpy as np
from PIL import Image

import palette as pal

CLS_SCALE = 64.0
OFF_SCALE = 16.0

BAYER4 = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]],
                   np.float32) + 0.5) / 16.0


def decode(ida, la):
    alpha = ida[..., 3] > 0.5
    cls = np.where(alpha, np.rint(ida[..., 0] * CLS_SCALE), 0).astype(np.int32)
    off = np.where(alpha, np.rint((ida[..., 1] - 0.5) * OFF_SCALE), 0).astype(np.int32)
    depth = np.where(alpha, ida[..., 2], np.inf).astype(np.float32)
    a = np.maximum(la[..., 3:4], 1e-3)
    rgb = la[..., :3] / a
    lum = 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]
    warm = (rgb[..., 0] + 1e-4) / (rgb[..., 2] + 1e-4)
    return dict(alpha=alpha, cls=cls, off=off, depth=depth, lum=np.maximum(lum, 1e-5),
                warm=warm)


def shade(d, cfg):
    """Returns (ramp_id map, idx map, t map). ramp_id = -1 transparent."""
    H, W = d['cls'].shape
    lo, hi = cfg['lum']
    classes = cfg['classes']
    ramp_id = np.full((H, W), -1, np.int32)
    idx = np.zeros((H, W), np.int32)
    tmap = np.zeros((H, W), np.float32)
    ll = np.log2(d['lum'])
    yy, xx = np.mgrid[0:H, 0:W]
    bay = BAYER4[yy % 4, xx % 4]
    for c, spec in classes.items():
        m = d['alpha'] & (d['cls'] == c)
        if not m.any():
            continue
        clo, chi = spec.get('lum', (lo, hi))
        t = np.clip((ll[m] - clo) / (chi - clo), 0.0, 1.0)
        t = t ** spec.get('gamma', 1.0) + spec.get('bias', 0.0)
        n = len(spec['ramp'])
        f = t * n
        if spec.get('dither', 0.0) > 0:
            f = f + (bay[m] - 0.5) * spec['dither']
        k = np.floor(f).astype(np.int32)
        k = k + d['off'][m] * spec.get('off_mul', 1)
        k = np.clip(k, spec.get('min', 0), n - 1)
        ramp_id[m] = c
        idx[m] = k
        tmap[m] = np.clip(t, 0, 1)
    # classes not configured -> leave transparent but warn
    unknown = d['alpha'] & (ramp_id < 0)
    if unknown.any():
        vals, cnt = np.unique(d['cls'][unknown], return_counts=True)
        print(f"   [pixelize] unconfigured classes {dict(zip(vals.tolist(), cnt.tolist()))}")
    return ramp_id, idx, tmap


def _neighbors4(a, fill):
    up = np.vstack([np.full((1, a.shape[1]), fill, a.dtype), a[:-1]])
    dn = np.vstack([a[1:], np.full((1, a.shape[1]), fill, a.dtype)])
    lf = np.hstack([np.full((a.shape[0], 1), fill, a.dtype), a[:, :-1]])
    rt = np.hstack([a[:, 1:], np.full((a.shape[0], 1), fill, a.dtype)])
    return up, dn, lf, rt


def _shift(a, dy, dx, fill):
    out = np.full_like(a, fill)
    H, W = a.shape
    ys = slice(max(dy, 0), H + min(dy, 0))
    yd = slice(max(-dy, 0), H + min(-dy, 0))
    xs = slice(max(dx, 0), W + min(dx, 0))
    xd = slice(max(-dx, 0), W + min(-dx, 0))
    out[ys, xs] = a[yd, xd]
    return out


OFFS8 = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]
OFFS4 = [(-1, 0), (1, 0), (0, -1), (0, 1)]


def to_colors(ramp_id, idx, classes):
    """Palette index map (-1 transparent)."""
    H, W = ramp_id.shape
    P = np.full((H, W), -1, np.int32)
    for c, spec in classes.items():
        m = ramp_id == c
        if not m.any():
            continue
        lut = np.array([pal.INDEX[n] for n in spec['ramp']], np.int32)
        P[m] = lut[np.clip(idx[m], 0, len(lut) - 1)]
    return P


def clean_orphans(P, keep_mask=None, passes=2):
    """Replace pixels that share their colour with none of their 8 neighbours
    by the most common colour of their 4 opaque neighbours."""
    for _ in range(passes):
        same = np.zeros(P.shape, np.int32)
        for dy, dx in OFFS8:
            same += (_shift(P, dy, dx, -2) == P)
        cand = (P >= 0) & (same == 0)
        if keep_mask is not None:
            cand &= ~keep_mask
        if not cand.any():
            break
        nbs = np.stack([_shift(P, dy, dx, -1) for dy, dx in OFFS4], 0)  # 4,H,W
        ys, xs = np.nonzero(cand)
        newv = P[ys, xs].copy()
        for i, (y, x) in enumerate(zip(ys, xs)):
            v = nbs[:, y, x]
            v = v[v >= 0]
            if len(v):
                vals, cnt = np.unique(v, return_counts=True)
                newv[i] = vals[np.argmax(cnt)]
        P[ys, xs] = newv
    return P


def clean_alpha(P):
    """Remove isolated opaque pixels, fill single-pixel holes."""
    op = P >= 0
    n8 = np.zeros(P.shape, np.int32)
    for dy, dx in OFFS8:
        n8 += _shift(op, dy, dx, False)
    P[op & (n8 == 0)] = -1
    op = P >= 0
    n4 = np.zeros(P.shape, np.int32)
    for dy, dx in OFFS4:
        n4 += _shift(op, dy, dx, False)
    holes = (~op) & (n4 == 4)
    if holes.any():
        P[holes] = _shift(P, 0, -1, -1)[holes]
    return P


def outline(P, ramp_id, idx, tmap, classes, rim_t=0.62, inner_depth=None, depth=None,
            inner_steps=2):
    """Selective outline: silhouette pixels on the shadow side become the
    class outline colour; lit rims keep their (bright) colour.
    Inner outlines: where a pixel sits right behind a closer surface (depth
    jump) it is darkened `inner_steps` along its own ramp."""
    op = P >= 0
    edge = np.zeros(P.shape, bool)
    for dy, dx in OFFS4:
        edge |= ~_shift(op, dy, dx, False)
    edge &= op
    out = P.copy()
    for c, spec in classes.items():
        oc = spec.get('outline')
        if oc is None:
            continue
        m = edge & (ramp_id == c) & (tmap < spec.get('rim_t', rim_t))
        out[m] = pal.INDEX[oc]
    if inner_depth is not None and depth is not None:
        dz = np.zeros(P.shape, bool)
        for dy, dx in OFFS4:
            nd = _shift(depth, dy, dx, np.inf)
            dz |= (nd < depth - inner_depth)
        dz &= op & ~edge
        for c, spec in classes.items():
            if spec.get('no_inner'):
                continue
            m = dz & (ramp_id == c)
            if not m.any():
                continue
            lut = np.array([pal.INDEX[n] for n in spec['ramp']], np.int32)
            k = np.clip(idx[m] - inner_steps, 0, len(lut) - 1)
            out[m] = lut[k]
    return out


def draw_polyline(P, pts, color_idx, behind=True, depth_mask=None):
    """1-px Bresenham polyline in palette index space.
    behind=True: only draws on transparent pixels (string passes behind)."""
    H, W = P.shape
    ci = pal.INDEX[color_idx] if isinstance(color_idx, str) else color_idx
    for (x0, y0), (x1, y1) in zip(pts[:-1], pts[1:]):
        x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            if 0 <= x0 < W and 0 <= y0 < H:
                if (not behind) or P[y0, x0] < 0:
                    P[y0, x0] = ci
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy
    return P


def to_rgba(P):
    lut = np.array([pal.rgb(n) for n in pal.NAMES], np.uint8)
    H, W = P.shape
    out = np.zeros((H, W, 4), np.uint8)
    m = P >= 0
    out[m, :3] = lut[P[m]]
    out[m, 3] = 255
    return out


def process(d, cfg):
    ramp_id, idx, tmap = shade(d, cfg)
    classes = cfg['classes']
    P = to_colors(ramp_id, idx, classes)
    keep = np.zeros(P.shape, bool)
    for c, spec in classes.items():
        if spec.get('keep'):
            keep |= ramp_id == c
    P = clean_alpha(P)
    P = clean_orphans(P, keep_mask=keep, passes=cfg.get('orphan_passes', 2))
    if cfg.get('outline', False):
        P = outline(P, ramp_id, idx, tmap, classes, rim_t=cfg.get('rim_t', 0.62),
                    inner_depth=cfg.get('inner_depth'), depth=d['depth'],
                    inner_steps=cfg.get('inner_steps', 2))
    return P, ramp_id, idx


def save_png(rgba, path):
    Image.fromarray(rgba, 'RGBA').save(path, optimize=True)


def upscale(path_in, path_out, k=3):
    im = Image.open(path_in)
    im.resize((im.width * k, im.height * k), Image.NEAREST).save(path_out)
