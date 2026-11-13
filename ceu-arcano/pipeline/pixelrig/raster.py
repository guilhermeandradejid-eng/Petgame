"""Compositor de pixel art.

Desenha as partes em ordem de profundidade num buffer indexado (material, nível da rampa),
depois aplica: limpeza de pixels órfãos, sombra projetada, contorno interno seletivo e
contorno de silhueta colorido. Só no fim vira RGBA, com qualquer paleta.
"""
from __future__ import annotations

import numpy as np

from .shapes import Shape, Decal, matches

LIGHT = np.array([-0.5, -0.62, 0.6])
LIGHT = LIGHT / np.linalg.norm(LIGHT)
SHADOW_OFFSET = (1, 2)  # (dx, dy) da sombra projetada


class Material:
    def __init__(self, name, ramp, shadow=0.2, light=0.78, hi=0.93, emissive=False, outline=None):
        """ramp: 5 cores hex [contorno, sombra, base, luz, brilho]."""
        self.name = name
        self.ramp = [hex_rgba(c) for c in ramp]
        self.t = (shadow, light, hi)
        self.emissive = emissive
        if outline:
            self.ramp[0] = hex_rgba(outline)


def hex_rgba(c):
    c = c.lstrip("#")
    if len(c) == 6:
        c += "ff"
    return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4, 6))


class Part:
    def __init__(self, name, bone, z, shapes, bias=0.0, hurt=None, shadow=True, when=None):
        self.name = name
        self.bone = bone
        self.z = z
        self.shapes = shapes
        self.bias = bias
        self.hurt = hurt
        self.shadow = shadow
        self.when = when


class Canvas:
    def __init__(self, w, h, ox, oy, materials):
        self.w, self.h, self.ox, self.oy = w, h, ox, oy
        self.mats = materials              # lista de Material
        self.mat_index = {m.name: i for i, m in enumerate(materials)}
        self.mat = np.full((h, w), -1, np.int16)
        self.lev = np.zeros((h, w), np.int8)
        self.order = np.full((h, w), -1, np.int32)
        self.group = np.full((h, w), -1, np.int32)
        self.part = np.full((h, w), -1, np.int16)
        self.flags = np.zeros((h, w), np.uint8)   # 1 = linha, 2 = sombreado (limpável), 4 = decal
        self.shadow = np.zeros((h, w), np.int8)
        self._order = 0
        self.part_names = []

    # ------------------------------------------------------------ desenho
    def _region(self, bbox, m, pad=2):
        x0, y0, x1, y1 = bbox
        corners = [(x0, y0), (x1, y0), (x0, y1), (x1, y1)]
        xs, ys = [], []
        for cx, cy in corners:
            xs.append(m[0][0] * cx + m[0][1] * cy + m[0][2])
            ys.append(m[1][0] * cx + m[1][1] * cy + m[1][2])
        j0 = int(np.floor(min(xs) + self.ox)) - pad
        j1 = int(np.ceil(max(xs) + self.ox)) + pad
        i0 = int(np.floor(min(ys) + self.oy)) - pad
        i1 = int(np.ceil(max(ys) + self.oy)) + pad
        j0, i0 = max(0, j0), max(0, i0)
        j1, i1 = min(self.w, j1), min(self.h, i1)
        if j1 <= j0 or i1 <= i0:
            return None
        return i0, i1, j0, j1

    def _local_grid(self, reg, inv):
        i0, i1, j0, j1 = reg
        jj, ii = np.meshgrid(np.arange(j0, j1, dtype=np.float64), np.arange(i0, i1, dtype=np.float64))
        wx = jj - self.ox + 0.5
        wy = ii - self.oy + 0.5
        lx = inv[0][0] * wx + inv[0][1] * wy + inv[0][2]
        ly = inv[1][0] * wx + inv[1][1] * wy + inv[1][2]
        return lx, ly

    def draw_part(self, part, xf, ctx, part_bias=0.0):
        if part.when is not None and not matches(part.when, ctx):
            return
        m = xf.matrix()
        inv = xf.inverse()
        pid = len(self.part_names)
        self.part_names.append(part.name)
        first_order = self._order
        mask_total = np.zeros((self.h, self.w), bool)
        for sh in part.shapes:
            if not matches(sh.when, ctx):
                continue
            if isinstance(sh, Decal):
                self._draw_decal(sh, m, inv, pid)
                continue
            reg = self._region(sh.bbox, m)
            if reg is None:
                continue
            lx, ly = self._local_grid(reg, inv)
            d = sh.fn(lx, ly) * xf.scale
            inside = d < 0.0
            if not inside.any():
                continue
            mi = self.mat_index[sh.mat]
            mat = self.mats[mi]
            if sh.level is not None or mat.emissive:
                lev = np.full(d.shape, sh.level if sh.level is not None else 2, np.int8)
                shaded = False
            else:
                gy, gx = np.gradient(d)
                gl = np.sqrt(gx * gx + gy * gy) + 1e-6
                gx, gy = gx / gl, gy / gl
                t = np.clip(-d / max(sh.bevel, 0.5), 0.0, 1.0)
                hgt = np.sqrt(np.maximum(1.0 - (1.0 - t) ** 2, 0.0025))
                k = (1.0 - t) / hgt
                nx, ny, nz = gx * k, gy * k, np.ones_like(k)
                nl = np.sqrt(nx * nx + ny * ny + nz * nz)
                v = (nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2]) / nl + sh.bias + part.bias + part_bias
                ts, tl, th = mat.t
                lev = np.where(v < ts, 1, np.where(v < tl, 2, np.where((v < th) | (not sh.hi), 3, 4))).astype(np.int8)
                shaded = True
            i0, i1, j0, j1 = reg
            self._order += 1
            sl = (slice(i0, i1), slice(j0, j1))
            self.mat[sl][inside] = mi
            self.lev[sl][inside] = lev[inside]
            self.order[sl][inside] = self._order
            self.group[sl][inside] = sh.group if sh.group is not None else 1000 + pid
            self.part[sl][inside] = pid
            fl = (1 if sh.line else 0) | (2 if shaded else 0)
            self.flags[sl][inside] = fl
            self.shadow[sl][inside] = 0
            if sh.shadow and part.shadow:
                mask_total[sl] |= inside
        if part.shadow and mask_total.any():
            dx, dy = SHADOW_OFFSET
            sh_mask = np.zeros_like(mask_total)
            sh_mask[dy:, dx:] = mask_total[:-dy, :-dx]
            tgt = sh_mask & ~mask_total & (self.order >= 0) & (self.order <= first_order)
            tgt &= (self.flags & 2) > 0
            self.shadow[tgt] = 1

    def _draw_decal(self, dc, m, inv, pid):
        reg = self._region(dc.bbox, m, pad=1)
        if reg is None:
            return
        lx, ly = self._local_grid(reg, inv)
        gx = np.floor(lx - dc.x).astype(int)
        gy = np.floor(ly - dc.y).astype(int)
        i0, i1, j0, j1 = reg
        self._order += 1
        for r, row in enumerate(dc.rows):
            for c, ch in enumerate(row):
                if ch == "." or ch == " ":
                    continue
                matname, lvl = dc.keys[ch]
                sel = (gx == c) & (gy == r)
                if not sel.any():
                    continue
                sub = (slice(i0, i1), slice(j0, j1))
                self.mat[sub][sel] = self.mat_index[matname]
                self.lev[sub][sel] = lvl
                self.order[sub][sel] = self._order
                self.group[sub][sel] = 1000 + pid
                self.part[sub][sel] = pid
                self.flags[sub][sel] = 4
                self.shadow[sub][sel] = 0

    def draw_world_shape(self, sh, pid_name, ctx):
        """Forma já em coordenadas do mundo (correntes, rastros)."""
        from .rig import Xform
        part = Part(pid_name, None, 0, [sh], shadow=sh.shadow)
        self.draw_part(part, Xform(0.0, 0.0, 0.0, 1.0), ctx)

    # ------------------------------------------------------------ pós
    def finish(self, outline=True, cleanup=True):
        mat, lev, order, group, flags = self.mat, self.lev, self.order, self.group, self.flags
        filled = mat >= 0
        H, W = mat.shape

        def nb(a, dy, dx, fill):
            out = np.full_like(a, fill)
            ys = slice(max(0, dy), H + min(0, dy))
            yd = slice(max(0, -dy), H + min(0, -dy))
            xs = slice(max(0, dx), W + min(0, dx))
            xd = slice(max(0, -dx), W + min(0, -dx))
            out[yd, xd] = a[ys, xs]
            return out

        dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)]
        # limpeza: pixel sombreado diferente de todos os vizinhos do mesmo material
        if cleanup:
            shaded = (flags & 2) > 0
            same_all_diff = shaded.copy()
            votes = np.zeros((5,) + mat.shape, np.int8)
            for dy, dx in dirs:
                m2 = nb(mat, dy, dx, -1)
                l2 = nb(lev, dy, dx, -1)
                o2 = nb(order, dy, dx, -1)
                same = (m2 == mat) & (o2 >= 0)
                same_all_diff &= ~(same & (l2 == lev))
                for k in range(1, 5):
                    votes[k] += (same & (l2 == k)).astype(np.int8)
            best = np.argmax(votes, axis=0).astype(np.int8)
            has = votes.max(axis=0) >= 2
            fix = same_all_diff & has
            lev[fix] = best[fix]
        # sombra projetada
        sh = (self.shadow > 0) & ((flags & 2) > 0) & (lev >= 2)
        lev[sh] -= 1
        # contorno interno seletivo
        line = np.zeros_like(filled)
        for dy, dx in dirs:
            m2 = nb(mat, dy, dx, -1)
            o2 = nb(order, dy, dx, -1)
            g2 = nb(group, dy, dx, -1)
            line |= filled & ((flags & 1) > 0) & (m2 >= 0) & (o2 < order) & (g2 != group)
        emis = np.array([m.emissive for m in self.mats])
        line &= ~emis[np.maximum(mat, 0)]
        lev[line] = 0
        # contorno da silhueta
        if outline:
            best_o = np.full(mat.shape, -1, np.int32)
            best_m = np.full(mat.shape, -1, np.int16)
            for dy, dx in dirs:
                m2 = nb(mat, dy, dx, -1)
                o2 = nb(order, dy, dx, -1)
                take = (~filled) & (m2 >= 0) & (o2 > best_o)
                best_o[take] = o2[take]
                best_m[take] = m2[take]
            add = best_m >= 0
            mat[add] = best_m[add]
            lev[add] = 0
            order[add] = 0
            self.part[add] = -2
        return self

    def rgba(self, materials=None):
        mats = materials or self.mats
        lut = np.zeros((len(mats), 5, 4), np.uint8)
        for i, m in enumerate(mats):
            for k in range(5):
                lut[i, k] = m.ramp[k]
        out = np.zeros((self.h, self.w, 4), np.uint8)
        f = self.mat >= 0
        out[f] = lut[self.mat[f], self.lev[f]]
        return out
