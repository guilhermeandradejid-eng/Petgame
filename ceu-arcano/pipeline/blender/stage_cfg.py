"""Per-layer post-processing configs (palette ramps per material class).

lum = (lo, hi) log2 luminance of the white-material light pass mapped onto
each ramp; per class: ramp (dark -> light), bias/gamma, outline colour for
shadow-side silhouette pixels, keep (exempt from orphan clean-up), dither
(ordered dither amount), off_mul (0 = ignore procedural offsets).
"""
import palette as P

def far_cfg():
    return dict(lum=(-4.3, -1.0), outline=False, classes={
        P.CLOUD: dict(ramp=['h4', 'h5', 'c0', 'c1', 'c2'], dither=0.3, gamma=0.8),
        P.CLOUD_B: dict(ramp=['c0', 'c1', 'c2', 'c3'], dither=0.3, gamma=0.85, bias=0.05),
        P.FAR_A: dict(ramp=['h2', 'h3', 'h4'], off_mul=0),
        P.FAR_B: dict(ramp=['h3', 'h4', 'h5'], off_mul=0),
        P.FAR_C: dict(ramp=['h4', 'h5', 'c0'], off_mul=0),
        P.WATER: dict(ramp=['h5', 'c0', 'c1'], keep=True, lum=(-2, 0)),
    })


def mid_cfg():
    """Softer, slightly hazier ramps than near (no near-black, lighter shadows)."""
    return dict(lum=(-4.3, -1.0), outline=True, inner_depth=8, inner_steps=1, rim_t=0.6, classes={
        P.STONE: dict(ramp=['s3', 's4', 's5', 's6', 's7'], outline='s3'),
        P.MOSS: dict(ramp=['t1', 't2', 't3', 't4'], outline='t1', bias=-0.05),
        P.TRIM: dict(ramp=['s3', 's4', 's5', 's6'], outline='s3'),
        P.LEAF: dict(ramp=['t1', 't2', 't3', 't4'], outline='t1', bias=0.05),
        P.BLOSSOM: dict(ramp=['p1', 'p2', 'p3', 'p4', 'p5'], outline='p1', bias=0.05),
        P.BARK: dict(ramp=['s2', 'b0', 'b1'], outline=None),
        P.ROOT: dict(ramp=['s3', 'b1'], outline=None, off_mul=0),
        P.WATER: dict(ramp=['w0', 'w1', 'w2'], keep=True, lum=(-1.5, 0.2), no_inner=True),
        P.LANTERN: dict(ramp=['a3', 'a4', 'a5'], keep=True, lum=(0.0, 2.5), no_inner=True),
        P.GOLD: dict(ramp=['a1', 'a2', 'a3'], keep=True),
    })


def near_cfg():
    return dict(lum=(-4.3, -1.0), outline=True, inner_depth=6, inner_steps=2, rim_t=0.62, classes={
        P.STONE: dict(ramp=['s1', 's2', 's3', 's4', 's5', 's6', 's7', 'c2'], outline='s0'),
        P.TRIM: dict(ramp=['s1', 's2', 's3', 's4', 's5', 's6', 's7'], outline='s0', bias=-0.08),
        P.MOSS: dict(ramp=['t0', 't1', 't2', 'm2', 'm3'], outline='s0', bias=-0.05),
        P.LEAF: dict(ramp=['t0', 't1', 't2', 't3', 't4'], outline='s0', bias=0.05),
        P.BLOSSOM: dict(ramp=['p0', 'p1', 'p2', 'p3', 'p4', 'p5'], outline='p0', bias=-0.04),
        P.BARK: dict(ramp=['s0', 'b0', 'b1', 's4'], outline='s0'),
        P.ROOT: dict(ramp=['s0', 'b0', 'b1'], outline=None, off_mul=0),
        P.LANTERN: dict(ramp=['a1', 'a2', 'a3', 'a4', 'a5', 'a6'], keep=True, lum=(0.0, 2.6),
                        no_inner=True),
        P.GOLD: dict(ramp=['a0', 'a1', 'a2', 'a3', 'a4'], keep=True, outline='a0'),
        P.RUNE: dict(ramp=['t3', 't4', 'w1'], keep=True, lum=(-0.5, 1.6), no_inner=True),
    })


def ground_cfg():
    return dict(lum=(-4.3, -1.0), outline=True, inner_depth=5, inner_steps=2, rim_t=0.62, classes={
        P.STONE: dict(ramp=['s1', 's2', 's3', 's4', 's5', 's6', 's7', 'c2'], outline='s0'),
        P.FLAG: dict(ramp=['s1', 's2', 's3', 's4', 's5', 's6'], outline='s0', bias=-0.12),
        P.INLAY: dict(ramp=['s4', 's5', 's6', 's7'], outline='s1', keep=True),
        P.UNDER: dict(ramp=['s0', 's1', 's2', 's3', 's4', 's5'], outline='s0', bias=-0.05),
        P.TRIM: dict(ramp=['s1', 's2', 's3', 's4', 's5', 's6', 's7'], outline='s0', bias=-0.05),
        P.MOSS: dict(ramp=['t0', 't1', 't2', 'm2'], outline='s0', bias=-0.15),
        P.GRASS: dict(ramp=['t0', 't1', 't2', 'm2', 'm3', 'm4'], outline=None, bias=0.08),
        P.LEAF: dict(ramp=['t0', 't1', 't2', 't3', 't4'], outline='s0'),
        P.BLOSSOM: dict(ramp=['p0', 'p1', 'p2', 'p3', 'p4', 'p5'], outline='p0'),
        P.ROOT: dict(ramp=['s0', 'b0', 'b1'], outline=None, off_mul=0),
        P.FLOWER_W: dict(ramp=['n3', 'n2', 'n1', 'w2'], keep=True, bias=0.2),
        P.FLOWER_P: dict(ramp=['p2', 'p3', 'p4', 'p5'], keep=True, bias=0.2),
        P.LANTERN: dict(ramp=['a1', 'a2', 'a3', 'a4', 'a5', 'a6'], keep=True, lum=(0.0, 2.6),
                        no_inner=True),
        P.GOLD: dict(ramp=['a0', 'a1', 'a2', 'a3', 'a4'], keep=True),
    })


def fg_cfg():
    return dict(lum=(-4.3, -1.0), outline=True, rim_t=0.7, classes={
        P.GRASS: dict(ramp=['s0', 't0', 't0', 't1'], outline=None),
        P.STONE: dict(ramp=['s0', 's0', 's1', 's1', 's2'], outline=None, off_mul=0),
        P.MOSS: dict(ramp=['s0', 't0', 't1'], outline=None, off_mul=0),
        P.FLOWER_P: dict(ramp=['p0', 'p1', 'p2'], keep=True),
        P.TRIM: dict(ramp=['s0', 's1', 's2'], outline=None),
        P.GLOWCAP: dict(ramp=['t2', 't3', 't4', 'w1'], keep=True, lum=(-0.5, 2.0)),
        P.LANTERN: dict(ramp=['a1', 'a2', 'a3', 'a4', 'a5'], keep=True, lum=(0.0, 2.6)),
        P.GOLD: dict(ramp=['s0', 'a0', 'a1'], keep=True),
    })


def moon_cfg():
    return dict(lum=(-3.2, -0.6), outline=False, classes={
        P.MOON: dict(ramp=['n3', 'n2', 'n1', 'w2'], gamma=0.8, bias=-0.08),
    })


CFG = dict(far=far_cfg(), mid=mid_cfg(), near=near_cfg(), ground=ground_cfg(), fg=fg_cfg(),
           moon=moon_cfg())
