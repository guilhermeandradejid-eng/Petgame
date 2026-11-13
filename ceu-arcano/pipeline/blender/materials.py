"""Material library: every material = (id encoding, light shader)."""
from bl_util import make_material, hex_lin
import palette as P


def _noise_off(nb, scale, amp=1.0, thresh=(0.42, 0.6), seed_w=0.0):
    """-1 / 0 / +1 offset from a noise field (soft blotches)."""
    n = nb.noise(scale, 2.0, 0.5, w=seed_w) if seed_w else nb.noise(scale, 2.0, 0.5)
    lo = nb.lt(n, thresh[0])
    hi = nb.gt(n, thresh[1])
    return nb.mul(nb.math('SUBTRACT', hi, lo), amp)


def stone(name, cls=P.STONE, moss=True, moss_thresh=0.62, crack_scale=0.06,
          bump=0.3, strata=0.0, moss_cls=P.MOSS, noise_scale=0.05, lip=0.0, lip_var=6.0):
    """lip > 0: grass/moss band hanging lip..lip+lip_var px below object-space
    z = 0 (island tops), with drips."""
    def cls_fn(nb):
        if not moss:
            return float(cls)
        nz = nb.normal_z()
        n = nb.noise(0.08, 3.0, 0.6)
        v = nb.math('MULTIPLY_ADD', n, 0.5, nz)            # nz + 0.5 n
        is_moss = nb.gt(v, moss_thresh + 0.25)
        if lip:
            co = nb.coord('Object')
            xs = nb.scale_vec(co, (0.22, 0.22, 0.0))
            drip = nb.noise(1.0, 2.0, 0.6, vec=xs)
            depth = nb.math('MULTIPLY_ADD', nb.math('POWER', drip, 3.0), lip_var * 3.0, lip)
            is_lip = nb.gt(nb.sep(co)[2], nb.math('MULTIPLY', depth, -1.0))
            is_moss = nb.math('MAXIMUM', is_moss, is_lip)
        return nb.lerp(float(cls), float(moss_cls), is_moss)

    def off_fn(nb):
        vor = nb.voronoi(crack_scale, feature='DISTANCE_TO_EDGE')
        crack = nb.mul(nb.lt(vor, 0.045), nb.gt(nb.noise(0.03, 1.0, 0.5), 0.52))
        o = nb.math('SUBTRACT', _noise_off(nb, noise_scale, 1.0, (0.34, 0.68)), crack)
        if strata:
            pos = nb.sep(nb.coord('Object'))[2]
            wob = nb.noise(0.05, 2.0, 0.5)
            s = nb.math('SINE', nb.math('MULTIPLY_ADD', wob, 6.0, nb.mul(pos, strata)))
            o = nb.math('SUBTRACT', o, nb.gt(s, 0.72))
        return o

    def light_fn(nb):
        h = nb.noise(0.09, 3.0, 0.55)
        return nb.diffuse(bump=h, bump_strength=bump, bump_dist=2.0)

    return make_material(name, cls_fn, off_fn, light_fn)


def flat(name, cls, off=0.0, bump=0.0, bump_scale=0.2, color=(0.8, 0.8, 0.8), var=None):
    """Simple class with optional noise offset blotches."""
    def off_fn(nb):
        if var is None:
            return float(off)
        return nb.add(_noise_off(nb, var, 1.0, (0.38, 0.64)), float(off))

    def light_fn(nb):
        if bump:
            return nb.diffuse(color, bump=nb.noise(bump_scale, 2.0, 0.5), bump_strength=bump,
                              bump_dist=2.0)
        return nb.diffuse(color)
    return make_material(name, cls, off_fn, light_fn)


def foliage(name, cls, var_scale=0.12, bump=0.22):
    """Canopies: clumpy noise offsets, strong bump for leaf clusters."""
    def off_fn(nb):
        v = nb.voronoi(var_scale, feature='F1')
        a = nb.lt(v, 0.18)                 # bright cluster centres
        n = nb.noise(var_scale * 1.6, 2.0, 0.5)
        b = nb.lt(n, 0.36)
        return nb.math('SUBTRACT', a, b)

    def light_fn(nb):
        h = nb.voronoi(var_scale * 0.8, feature='F1')
        return nb.diffuse(bump=h, bump_strength=bump, bump_dist=3.0)
    return make_material(name, cls, off_fn, light_fn)


def emissive(name, cls, color_hex='#ffb050', strength=6.0, core=1.0, off=0.0, base=0.0):
    """Glowing paper: emission brighter where facing the camera."""
    col = hex_lin(color_hex)

    def light_fn(nb):
        f = nb.facing(0.45)
        s = nb.math('MULTIPLY_ADD', nb.math('POWER', nb.math('SUBTRACT', 1.0, f), 1.5),
                    strength * core, strength * 0.25)
        e = nb.emission(col, s)
        if base:
            return nb.add_shader(e, nb.diffuse())
        return e
    return make_material(name, cls, off, light_fn)


def water(name, cls=P.WATER):
    def off_fn(nb):
        co = nb.coord('Object')
        v = nb.scale_vec(co, (0.5, 0.5, 0.05))
        n = nb.noise(1.0, 2.0, 0.5, vec=v)
        return nb.math('SUBTRACT', nb.gt(n, 0.6), nb.lt(n, 0.4))

    def light_fn(nb):
        return nb.emission((0.6, 0.6, 0.7), 1.0)
    return make_material(name, cls, off_fn, light_fn)


def flagstone(name, cls=P.FLAG, front_y=None, var=True):
    """Per-stone variation (Random Per Island), darker rows near the front
    edge, rare hairline cracks."""
    def off_fn(nb):
        g = nb.new('ShaderNodeNewGeometry')
        rnd = g.outputs['Random Per Island']
        o = nb.math('SUBTRACT', nb.gt(rnd, 0.82), nb.lt(rnd, 0.28)) if var else 0.0
        if front_y is not None:
            y = nb.sep(nb.coord('Object'))[1]
            o = nb.math('SUBTRACT', o, nb.lt(y, front_y))
        return o

    def light_fn(nb):
        return nb.diffuse(bump=nb.noise(0.12, 2.0, 0.5), bump_strength=0.18, bump_dist=2.0)
    return make_material(name, cls, off_fn, light_fn)


def moon(name):
    """Maria (dark seas) from large noise; craters come from geometry."""
    def off_fn(nb):
        n = nb.noise(0.03, 3.0, 0.55)
        return nb.mul(nb.add(nb.lt(n, 0.44), nb.lt(n, 0.36)), -1.0)
    return make_material(name, P.MOON, off_fn, None)
