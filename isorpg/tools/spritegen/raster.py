"""Supersampled rasterizer: shapes -> 4x buffers -> cel shading -> majority vote -> pixels.

World space is the character's ground frame after it has been turned to face one of
the 8 directions: x to the right of the screen, d away from the camera, z up.
One world unit is one final pixel horizontally. The camera looks down at 30 degrees,
which is exactly what a 2:1 isometric tile grid implies (ground is squashed by sin 30).
"""
import numpy as np

S = 4  # supersample factor
E_SIN = 0.5
E_COS = float(np.sqrt(3) / 2)

# Light comes from the upper left of the screen (y grows downward).
LIGHT = np.array([-0.55, -1.0])
LIGHT = LIGHT / np.linalg.norm(LIGHT)

OUTLINE = (20, 12, 28)


def project(p):
    """World point(s) -> (screen x, screen y down, depth away from camera), in final pixels."""
    p = np.asarray(p, dtype=np.float64)
    x, d, z = p[..., 0], p[..., 1], p[..., 2]
    return x, -(d * E_SIN + z * E_COS), d * E_COS - z * E_SIN


def normal_to_cam(n):
    """World normal(s) -> camera space (x right, y up, z toward the viewer)."""
    n = np.asarray(n, dtype=np.float64)
    x, d, z = n[..., 0], n[..., 1], n[..., 2]
    return np.stack([x, d * E_SIN + z * E_COS, -d * E_COS + z * E_SIN], axis=-1)


class Material:
    def __init__(self, name, tones):
        assert len(tones) == 5, name
        self.name = name
        self.tones = [tuple(int(c) for c in t) for t in tones]


def hexpal(*hexes):
    return [tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) for h in hexes]


class Part:
    """One logical piece of the character. Seams are drawn between different groups."""

    def __init__(self, canvas, name, material, group=None, fx=False, shade=True,
                 bands=(1.25, 3.0), highlight=0.75, vote=1.0, base_tone=1, casts=True):
        self.canvas = canvas
        self.name = name
        self.material = material
        self.group = group or name
        self.fx = fx
        self.shade = shade
        self.bands = bands
        self.highlight = highlight
        self.vote = vote
        self.base_tone = base_tone
        self.casts = casts
        h, w = canvas.H * S, canvas.W * S
        self.depth = np.full((h, w), np.inf, dtype=np.float32)
        self.normal = np.zeros((h, w, 3), dtype=np.float16)
        self.used = False

    # --- primitives -------------------------------------------------------
    def _hi(self, p):
        x, y, d = project(p)
        return (x + self.canvas.ox) * S, (y + self.canvas.oy) * S, d

    def _bbox(self, xs, ys, pad):
        h, w = self.depth.shape
        x0 = max(int(np.floor(min(xs) - pad)), 0)
        x1 = min(int(np.ceil(max(xs) + pad)) + 1, w)
        y0 = max(int(np.floor(min(ys) - pad)), 0)
        y1 = min(int(np.ceil(max(ys) + pad)) + 1, h)
        if x0 >= x1 or y0 >= y1:
            return None
        gy, gx = np.mgrid[y0:y1, x0:x1].astype(np.float64)
        return x0, x1, y0, y1, gx + 0.5, gy + 0.5

    def _write(self, box, inside, depth, normal):
        x0, x1, y0, y1 = box[:4]
        cur = self.depth[y0:y1, x0:x1]
        win = inside & (depth < cur)
        if not win.any():
            return
        cur[win] = depth[win]
        self.normal[y0:y1, x0:x1][win] = normal[win].astype(np.float16)
        self.used = True

    def capsule(self, a, b, ra, rb=None):
        """Tapered capsule between two world points, with a rounded depth bulge."""
        rb = ra if rb is None else rb
        ax, ay, ad = self._hi(a)
        bx, by, bd = self._hi(b)
        box = self._bbox([ax, bx], [ay, by], max(ra, rb) * S + 2)
        if box is None:
            return
        gx, gy = box[4], box[5]
        vx, vy = bx - ax, by - ay
        l2 = vx * vx + vy * vy
        if l2 > 1e-9:
            t = np.clip(((gx - ax) * vx + (gy - ay) * vy) / l2, 0.0, 1.0)
        else:
            t = np.zeros_like(gx)
        cx, cy = ax + t * vx, ay + t * vy
        r = (ra + (rb - ra) * t) * S
        ox, oy = gx - cx, gy - cy
        d2 = ox * ox + oy * oy
        inside = d2 < r * r
        h = np.sqrt(np.maximum(r * r - d2, 0.0))
        depth = ad + t * (bd - ad) - h / S
        rr = np.maximum(r, 1e-6)
        normal = np.stack([ox / rr, -oy / rr, h / rr], axis=-1)
        self._write(box, inside, depth, normal)

    def sphere(self, c, r):
        self.capsule(c, c, r, r)

    def tri(self, p3, n3=None):
        p3 = np.asarray(p3, dtype=np.float64)
        xs, ys, ds = self._hi(p3)
        box = self._bbox(xs, ys, 1)
        if box is None:
            return
        gx, gy = box[4], box[5]
        area = (xs[1] - xs[0]) * (ys[2] - ys[0]) - (xs[2] - xs[0]) * (ys[1] - ys[0])
        if abs(area) < 1e-6:
            return
        w0 = ((xs[1] - gx) * (ys[2] - gy) - (xs[2] - gx) * (ys[1] - gy)) / area
        w1 = ((xs[2] - gx) * (ys[0] - gy) - (xs[0] - gx) * (ys[2] - gy)) / area
        w2 = 1.0 - w0 - w1
        inside = (w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6)
        depth = w0 * ds[0] + w1 * ds[1] + w2 * ds[2]
        if n3 is None:
            n = np.cross(p3[1] - p3[0], p3[2] - p3[0])
            n3 = np.stack([n, n, n])
        nc = normal_to_cam(n3)
        normal = (w0[..., None] * nc[0] + w1[..., None] * nc[1] + w2[..., None] * nc[2])
        normal /= np.maximum(np.linalg.norm(normal, axis=-1, keepdims=True), 1e-6)
        normal[..., 2] = np.abs(normal[..., 2])  # double sided
        self._write(box, inside, depth, normal)

    def quad(self, a, b, c, d, na=None, nb=None, nc=None, nd=None):
        if na is None:
            self.tri([a, b, c])
            self.tri([a, c, d])
        else:
            self.tri([a, b, c], [na, nb, nc])
            self.tri([a, c, d], [na, nc, nd])

    def loft(self, rings, normals=None, closed=True):
        """Surface through a list of rings (each an (N,3) array of points)."""
        for i in range(len(rings) - 1):
            r0, r1 = rings[i], rings[i + 1]
            n = len(r0)
            m = n if closed else n - 1
            for j in range(m):
                k = (j + 1) % n
                if normals is None:
                    self.quad(r0[j], r0[k], r1[k], r1[j])
                else:
                    n0, n1 = normals[i], normals[i + 1]
                    self.quad(r0[j], r0[k], r1[k], r1[j], n0[j], n0[k], n1[k], n1[j])


class Canvas:
    def __init__(self, w, h, ox, oy):
        self.W, self.H = w, h
        self.ox, self.oy = ox, oy  # where world (0,0,0) lands, in final pixels
        self.parts = []

    def part(self, *args, **kw):
        p = Part(self, *args, **kw)
        self.parts.append(p)
        return p

    def to_px(self, p):
        x, y, d = project(p)
        return x + self.ox, y + self.oy, d


def _shift(mask, dx, dy, fill=False):
    """Move mask contents by (dx, dy) whole pixels."""
    dx, dy = int(round(dx)), int(round(dy))
    out = np.full_like(mask, fill)
    h, w = mask.shape
    xs0, xs1 = max(0, -dx), min(w, w - dx)
    ys0, ys1 = max(0, -dy), min(h, h - dy)
    if xs0 < xs1 and ys0 < ys1:
        out[ys0 + dy:ys1 + dy, xs0 + dx:xs1 + dx] = mask[ys0:ys1, xs0:xs1]
    return out


def compose(canvas, cast_dist=1.5, seam_eps=1.0):
    """Cel shade, majority-vote downsample, seams and outline.

    Returns dict with rgba (H,W,4) uint8, normal (H,W,3) uint8, owner (H,W) int part index
    (-1 empty), depth (H,W) float, parts list.
    """
    parts = [p for p in canvas.parts if p.used]
    H, W = canvas.H, canvas.W
    hh, ww = H * S, W * S
    if not parts:
        return None
    depths = np.stack([p.depth for p in parts])
    owner = np.argmin(depths, axis=0)
    mind = np.min(depths, axis=0)
    covered = np.isfinite(mind)

    # --- cel shading by mask offsets (computed on each part's full, unoccluded mask)
    tone = np.ones((hh, ww), dtype=np.int16)
    lx, ly = LIGHT
    for i, p in enumerate(parts):
        vis = covered & (owner == i)
        if not vis.any():
            continue
        if not p.shade:
            tone[vis] = p.base_tone
            continue
        m = np.isfinite(p.depth)
        t = np.full((hh, ww), p.base_tone, dtype=np.int16)
        if p.highlight > 0:
            hl = m & ~_shift(m, -lx * p.highlight * S, -ly * p.highlight * S)
            t[hl] = 0
        b1 = m & ~_shift(m, lx * p.bands[0] * S, ly * p.bands[0] * S)
        t[b1] = np.maximum(t[b1], 2)
        b2 = m & ~_shift(m, lx * p.bands[1] * S, ly * p.bands[1] * S)
        t[b2] = 3
        tone[vis] = t[vis]

    # --- parts cast onto what sits behind them
    groups = {}
    for i, p in enumerate(parts):
        if p.fx or not p.casts:
            continue
        g = groups.setdefault(p.group, np.full((hh, ww), np.inf, dtype=np.float32))
        np.minimum(g, p.depth, out=g)
    group_of = np.array([hash(p.group) for p in parts])
    own_group = group_of[owner]
    cdx, cdy = -lx * cast_dist * S, -ly * cast_dist * S  # occluder sits toward the light
    for name, gd in groups.items():
        occ = _shift(gd, cdx, cdy, fill=np.inf)
        shadowed = covered & (own_group != hash(name)) & (occ < mind - 2.0)
        for i, p in enumerate(parts):
            if p.fx or not p.shade:
                shadowed &= owner != i
        tone[shadowed] = np.minimum(tone[shadowed] + 1, 3)

    # --- majority vote downsample
    keys = np.where(covered, owner * 8 + tone, -1).astype(np.int32)
    votes = np.where(covered, np.array([p.vote for p in parts])[owner], 1.0)
    kb = keys.reshape(H, S, W, S).transpose(0, 2, 1, 3).reshape(H, W, S * S)
    vb = votes.reshape(H, S, W, S).transpose(0, 2, 1, 3).reshape(H, W, S * S)
    eq = kb[..., :, None] == kb[..., None, :]
    score = (eq * vb[..., None, :]).sum(-1)
    idx = np.argmax(score, axis=-1)
    fk = np.take_along_axis(kb, idx[..., None], axis=-1)[..., 0]
    match = kb == fk[..., None]
    db = np.where(covered, mind, 0).reshape(H, S, W, S).transpose(0, 2, 1, 3).reshape(H, W, S * S)
    cnt = np.maximum(match.sum(-1), 1)
    fdepth = (db * match).sum(-1) / cnt
    nrm = np.zeros((hh, ww, 3), dtype=np.float32)
    for i, p in enumerate(parts):
        sel = covered & (owner == i)
        nrm[sel] = p.normal[sel]
    nb = nrm.reshape(H, S, W, S, 3).transpose(0, 2, 1, 3, 4).reshape(H, W, S * S, 3)
    fn = (nb * match[..., None]).sum(-2)
    fn /= np.maximum(np.linalg.norm(fn, axis=-1, keepdims=True), 1e-6)

    fowner = np.where(fk >= 0, fk // 8, -1)
    ftone = np.where(fk >= 0, fk % 8, 0)
    filled = fowner >= 0

    # --- colors
    rgba = np.zeros((H, W, 4), dtype=np.uint8)
    for i, p in enumerate(parts):
        for t in range(5):
            sel = (fowner == i) & (ftone == t)
            if sel.any():
                rgba[sel, :3] = p.material.tones[t]
                rgba[sel, 3] = 255

    # --- internal lines: on the part that sits behind, where a different group touches it
    is_fx = np.array([p.fx for p in parts])
    gid = {g: n for n, g in enumerate(sorted({p.group for p in parts}))}
    pgroup = np.array([gid[p.group] for p in parts])
    fgroup = np.where(filled, pgroup[np.maximum(fowner, 0)], -1)
    ffx = np.where(filled, is_fx[np.maximum(fowner, 0)], False)
    seam = np.zeros((H, W), dtype=bool)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        ng = _shift(fgroup, dx, dy, fill=-1)
        nd = _shift(fdepth, dx, dy, fill=np.inf)
        nfx = _shift(ffx, dx, dy, fill=True)
        seam |= filled & ~ffx & (ng >= 0) & ~nfx & (ng != fgroup) & (nd < fdepth - seam_eps)
    for i, p in enumerate(parts):
        sel = seam & (fowner == i)
        rgba[sel, :3] = p.material.tones[4]

    # --- one pixel of outline around the body (fx excluded)
    body = filled & ~ffx
    edge = np.zeros((H, W), dtype=bool)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        edge |= _shift(body, dx, dy)
    edge &= ~body
    rgba[edge, :3] = OUTLINE
    rgba[edge, 3] = 255

    normal = np.zeros((H, W, 3), dtype=np.uint8)
    normal[...] = (128, 128, 255)
    enc = np.clip((fn * 0.5 + 0.5) * 255, 0, 255).astype(np.uint8)
    normal[filled] = enc[filled]
    fowner[edge] = -2
    return dict(rgba=rgba, normal=normal, owner=fowner, depth=fdepth, parts=parts)
