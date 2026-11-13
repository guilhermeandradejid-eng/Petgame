"""Curated twilight palette for "Jardim das Lanternas Suspensas".

All stage art is quantised to PALETTE (≈46 colours).  Ramps are listed dark ->
light and are hue shifted: shadows lean indigo/blue, highlights lean warm
peach/amber (the setting sun is the warm key, the sky the cool fill).

Each layer maps material classes to a sub-ramp: far layers use the hazy,
low-contrast purples close to the sky gradient, mid uses a softened ramp,
near/ground use the full-contrast ramps (atmospheric perspective).
"""

SKY = {
    'top': '#0b0a24', 'high': '#1d1748', 'mid': '#4a2a6e',
    'low': '#a2477a', 'horizon': '#f08a6a', 'glow': '#ffc98a',
}

PALETTE = {
    # indigo / violet stone (s0 = outline)
    's0': '#120e26', 's1': '#1e1838', 's2': '#2c2249', 's3': '#3d2e5c',
    's4': '#523d70', 's5': '#6c5084', 's6': '#8c6894', 's7': '#b48a9c',
    # haze purples (far)
    'h2': '#4e3674', 'h3': '#66447f', 'h4': '#7f5288', 'h5': '#9c5f8c',
    # clouds / peach
    'c0': '#b86c8a', 'c1': '#d98690', 'c2': '#f0a596', 'c3': '#ffc7a2',
    # teal foliage
    't0': '#172a3e', 't1': '#1d4450', 't2': '#27645f', 't3': '#3a8773',
    't4': '#6aae88',
    # moss / grass
    'm2': '#4f7a4f', 'm3': '#8aa75e', 'm4': '#c2c46e',
    # blossom pinks
    'p0': '#3e1a48', 'p1': '#66285e', 'p2': '#933a74', 'p3': '#c2557f',
    'p4': '#e67f93', 'p5': '#ffb0a8',
    # amber lantern light / gold
    'a0': '#4c1f30', 'a1': '#8e3236', 'a2': '#cf5b38', 'a3': '#f2923f',
    'a4': '#ffc46a', 'a5': '#ffe7a6', 'a6': '#fffbe8',
    # bark / wood
    'b0': '#3b2335', 'b1': '#5e3a48',
    # water / moon / cold light
    'w0': '#7fb0dc', 'w1': '#bfe8f0', 'w2': '#f1eaf6',
    'n1': '#d8cfea', 'n2': '#bdb2dc', 'n3': '#a397c9',
}

NAMES = list(PALETTE.keys())
INDEX = {n: i for i, n in enumerate(NAMES)}


def rgb(name):
    h = PALETTE[name].lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


# ---------------------------------------------------------------------------
# material classes (encoded in the id pass)
# ---------------------------------------------------------------------------
STONE, TRIM, MOSS, LEAF, BLOSSOM, BARK, LANTERN, GOLD, WATER, CLOUD, GRASS, \
    FLOWER_W, FLOWER_P, SHROOM, ROOT, MOON, ROPE, RUNE, FLAG, FAR_A, FAR_B, \
    FAR_C, PAPER, FOAM, LEAF_P, GLOWCAP, CLOUD_B, INLAY, UNDER = range(1, 30)
