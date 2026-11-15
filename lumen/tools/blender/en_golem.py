"""en_golem.py: esqueleto e clipes compartilhados pelos golens de pedra (Sentinela e Guardiao).

As medidas estao em "unidades de sentinela" (2,2 de altura); cada golem escala tudo por S e os
tempos por T. Bracos e pernas usam IK assado (alvos nos canais fist.*.ik / paw.*.ik)."""
import math

from mathutils import Vector

import lp
import en_base as eb
from en_base import B, clip, mg, sym, wave

J = {
    'pelvis': Vector((0, 0, 0.95)), 'torso': Vector((0, 0, 1.08)), 'neck': Vector((0, 0, 1.84)),
    'core': Vector((0, -0.31, 1.42)), 'eyes': Vector((0, -0.20, 2.03)),
    'sh': Vector((0.66, 0, 1.62)), 'el': Vector((0.84, 0.02, 1.18)), 'wr': Vector((0.86, -0.06, 0.52)),
    'hip': Vector((0.27, 0, 0.88)), 'kn': Vector((0.29, -0.04, 0.50)), 'an': Vector((0.29, 0, 0.14)),
}
# centro de cada bloco no repouso (para o desmoronamento)
CEN = {'body': (0, 0, 0.98), 'torso': (0, 0.02, 1.50), 'noggin': (0, -0.02, 2.02), 'armU': (0.74, 0, 1.66),
       'armF': (0.85, -0.02, 0.87), 'fist': (0.86, -0.06, 0.34), 'legU': (0.28, 0, 0.70), 'legF': (0.29, -0.01, 0.36),
       'paw': (0.30, -0.08, 0.12)}
PILE = {   # osso: (alvo do centro, rotacao absoluta)
    'body': ((0.0, 0.06, 0.17), (8, 6, 14)), 'torso': ((0.06, 0.46, 0.42), (-72, 8, 10)),
    'noggin': ((-0.30, -0.72, 0.19), (95, 0, 50)),
    'armU.L': ((0.95, 0.30, 0.25), (10, 65, 20)), 'armU.R': ((-0.88, 0.62, 0.25), (-20, -80, -40)),
    'armF.L': ((1.12, -0.32, 0.25), (88, 0, 30)), 'armF.R': ((-1.08, -0.08, 0.25), (-92, 0, -65)),
    'fist.L': ((0.80, -0.90, 0.22), (0, 10, 40)), 'fist.R': ((-0.62, -0.60, 0.22), (5, -12, -70)),
    'legU.L': ((0.47, 0.00, 0.18), (0, 35, 10)), 'legU.R': ((-0.44, 0.14, 0.18), (12, -50, -25)),
    'legF.L': ((0.54, -0.34, 0.15), (30, 70, 0)), 'legF.R': ((-0.52, -0.26, 0.15), (-20, -75, 15)),
    'paw.L': ((0.34, -0.12, 0.12), (0, 0, 14)), 'paw.R': ((-0.32, -0.06, 0.12), (0, 0, -20)),
}
ORDER = ['body', 'torso', 'noggin', 'armU.L', 'armF.L', 'fist.L', 'armU.R', 'armF.R', 'fist.R',
         'legU.L', 'legF.L', 'paw.L', 'legU.R', 'legF.R', 'paw.R']


def rig(S):
    def p(k, s=1):
        v = J[k]
        return (v.x * s * S, v.y * S, v.z * S)
    bones = [B('root', None, (0, 0, 0), 0.2 * S), B('body', 'root', p('pelvis'), 0.12 * S),
             B('torso', 'body', p('torso'), 0.3 * S), B('noggin', 'torso', p('neck'), 0.2 * S),
             B('core', 'torso', p('core'), 0.1 * S), B('eyes', 'noggin', p('eyes'), 0.06 * S)]
    for s in (1, -1):
        sf = '.L' if s > 0 else '.R'
        bones += [B('armU' + sf, 'torso', p('sh', s), 0.2 * S), B('armF' + sf, 'armU' + sf, p('el', s), 0.2 * S),
                  B('fist' + sf, 'armF' + sf, p('wr', s), 0.15 * S),
                  B('legU' + sf, 'body', p('hip', s), 0.15 * S), B('legF' + sf, 'legU' + sf, p('kn', s), 0.15 * S),
                  B('paw' + sf, 'legF' + sf, p('an', s), 0.1 * S)]
    return bones


class Golem:
    def __init__(self, S=1.0, T=1.0):
        self.S, self.T = S, T
        self.fist = self.v(*eb.lfu(J['wr']))
        self.paw = self.v(*eb.lfu(J['an']))
        r = sym({'fist.L.ik': self.fist, 'paw.L.ik': self.paw, 'paw.L.wrot': (0, 0, 0), 'fist.L': (0, 0, 0)})
        for b in ORDER:
            r[b] = (0, 0, 0)
            r[b + '.pos'] = (0, 0, 0)
        r.update({'body.scale': (1, 1, 1), 'core.scale': (1, 1, 1), 'eyes.scale': (1, 1, 1)})
        self.REST = r

    # ---- utilidades
    def v(self, x, y, z):
        return (x * self.S, y * self.S, z * self.S)

    def f(self, n):
        return max(1, int(round(n * self.T)))

    def hands(self, l, r=None):
        """Alvos das maos em unidades: l = (esq, frente, cima); r espelha l se faltar."""
        r = (-l[0], l[1], l[2]) if r is None else r
        return {'fist.L.ik': self.v(*l), 'fist.R.ik': self.v(*r)}

    def feet(self, l=(0, 0, 0), r=(0, 0, 0)):
        """Deslocamento dos pes (esq, frente, cima) a partir do repouso."""
        a = self.paw
        return {'paw.L.ik': (a[0] + l[0] * self.S, a[1] + l[1] * self.S, a[2] + l[2] * self.S),
                'paw.R.ik': (-a[0] + r[0] * self.S, a[1] + r[1] * self.S, a[2] + r[2] * self.S)}

    def bp(self, x, y, z):
        return {'body.pos': self.v(x, y, z)}

    def ck(self, name, n, keys, loop=False, scale=True, base=None):
        base = base or self.REST
        ks = [(0, base)]
        for k in keys:
            fr = self.f(k[0]) if scale else k[0]
            ks.append((fr, k[1]) + tuple(k[2:]))
        return clip(name, self.f(n) if scale else n, ks, loop=loop, base=base)

    def fin(self, c, sk, arms='parent', ik=True):
        if ik:
            for sf in ('.L', '.R'):
                eb.ik_bake(c, sk, 'legU' + sf, 'legF' + sf, 'paw' + sf, space='world', end_world=True)
                eb.ik_bake(c, sk, 'armU' + sf, 'armF' + sf, 'fist' + sf, space=arms)
        return c

    def pulse(self, c, amp=0.10, period=30):
        return eb.add_fn(c, 'core.scale', lambda f: (amp * math.sin(math.tau * f / period),) * 3)

    # ---- clipes comuns
    def idle(self, sk, n=60):
        S = self.S
        c = self.ck('idle', n, [], loop=True)
        L = c.length
        eb.add_fn(c, 'body.pos', lambda f: (0, 0, -0.022 * S * (0.5 - 0.5 * math.cos(math.tau * f / L))))
        eb.add_fn(c, 'torso', lambda f: (wave(f, L, 2.0, -0.1), 0, wave(f, L, 1.2, 0.3)))
        eb.add_fn(c, 'noggin.pos', lambda f: (0, 0, wave(f, L, 0.022 * S, 0.2)))
        eb.add_fn(c, 'noggin', lambda f: (wave(f, L, 2.5, 0.1), wave(f, L, 2.0, 0.4), wave(f, L, 4.0, 0.55)))
        eb.add_fn(c, 'armU.L.pos', lambda f: (0, 0, wave(f, L, 0.018 * S, 0.45)))
        eb.add_fn(c, 'armU.R.pos', lambda f: (0, 0, wave(f, L, 0.018 * S, 0.7)))
        eb.add_fn(c, 'fist.L.ik', lambda f: (0, wave(f, L, 0.03 * S, 0.3), wave(f, L, 0.03 * S, 0.5)))
        eb.add_fn(c, 'fist.R.ik', lambda f: (0, wave(f, L, 0.03 * S, 0.8), wave(f, L, 0.03 * S, 0.85)))
        self.pulse(c, 0.10, L / 2.0)
        return self.fin(c, sk)

    def move(self, sk, n=36, stride=0.56, lean=5.0, name='move', arm_r=None, base=None, drop=None, lift=0.20):
        """Andar pesado: passos longos, tronco contra-girando, bracos como pendulos."""
        S = self.S
        c = self.ck(name, n, [], loop=True, base=base)
        L = c.length
        eb.gait(c, 'paw.L.ik', self.feet()['paw.L.ik'], 0.0, stride=stride * S, lift=lift * S, duty=0.60)
        eb.gait(c, 'paw.R.ik', self.feet()['paw.R.ik'], 0.5, stride=stride * S, lift=lift * S, duty=0.60)
        drop = (0.07 + 0.25 * stride ** 2) if drop is None else drop
        eb.add_fn(c, 'body.pos', lambda f: (0.05 * S * math.sin(math.tau * (f / L - 0.05)), 0,
                                            -S * (drop + 0.04 * math.cos(2 * math.tau * (f / L - 0.04)))))
        eb.add_fn(c, 'body', lambda f: (lean, 3.5 * math.sin(math.tau * (f / L - 0.05)), -5 * math.sin(math.tau * f / L + 1.2)))
        eb.add_fn(c, 'torso', lambda f: (2 + 2 * math.cos(2 * math.tau * f / L), 0, 9 * math.sin(math.tau * f / L + 1.2)))
        eb.add_fn(c, 'noggin', lambda f: (-lean * 0.6 + 2 * math.cos(2 * math.tau * (f / L - 0.1)), 0,
                                          -5 * math.sin(math.tau * f / L + 1.2)))
        eb.add_fn(c, 'noggin.pos', lambda f: (0, 0, 0.02 * S * math.cos(2 * math.tau * (f / L - 0.12))))
        eb.add_fn(c, 'fist.L.ik', lambda f: (0, -0.24 * S * math.cos(math.tau * (f / L - 0.06)),
                                             S * (drop + 0.05 * (1 - math.cos(2 * math.tau * f / L)))))
        if arm_r is None:
            eb.add_fn(c, 'fist.R.ik', lambda f: (0, 0.24 * S * math.cos(math.tau * (f / L - 0.06)),
                                                 S * (drop + 0.05 * (1 - math.cos(2 * math.tau * f / L)))))
        else:
            eb.add_fn(c, 'fist.R.ik', lambda f: (0, 0.06 * S * math.cos(math.tau * (f / L - 0.06)),
                                                 S * (drop + 0.06 + arm_r * math.cos(2 * math.tau * (f / L - 0.1)))))
        self.pulse(c, 0.08, L / 2.0)
        return self.fin(c, sk)

    def slam(self, sk):
        """Ergue os dois punhos (telegrafo de ~0,7 s) e esmaga o chao. Acerto no quadro f(25)."""
        up = self.hands((0.30, -0.12, 2.55))
        c = self.ck('attack', 50, [
            (6, mg({'body': (6, 0, 0), 'torso': (8, 0, 0), 'noggin': (6, 0, 0)}, self.bp(0, 0.02, -0.10),
                   self.hands((0.80, 0.10, 0.50))), 'o'),
            (15, mg({'body': (-6, 0, 0), 'torso': (-16, 0, 0), 'noggin': (-12, 0, 0), 'core.scale': (1.4, 1.4, 1.4)},
                    self.bp(0, -0.08, 0.0), up), 'o'),
            (22, mg({'body': (-8, 0, 0), 'torso': (-20, 0, 0), 'noggin': (-14, 0, 0)}, self.bp(0, -0.10, 0.01),
                    self.hands((0.28, -0.20, 2.60)))),
            (25, mg({'body': (16, 0, 0), 'torso': (46, 0, 0), 'noggin': (-34, 0, 0), 'body.scale': (1.05, 1.05, 0.93),
                     'core.scale': (1.8, 1.8, 1.8)}, self.bp(0, 0.20, -0.24), self.hands((0.28, 0.98, 0.42))), 'i'),
            (27, mg({'torso': (50, 0, 0), 'core.scale': (1, 1, 1)}, self.bp(0, 0.22, -0.27),
                    self.hands((0.30, 1.0, 0.40))), 'o'),
            (34, mg({'body': (14, 0, 0), 'torso': (44, 0, 0), 'body.scale': (1, 1, 1)}, self.bp(0, 0.20, -0.22))),
            (50, self.REST),
        ])
        f0, f1 = self.f(14), self.f(23)
        eb.shake(c, 'torso', f0, f1, (0, 0, 2.2), freq=0.9)
        eb.shake(c, 'fist.L.ik', f0, f1, (0.02 * self.S, 0, 0.015 * self.S), freq=1.0, seed=2)
        eb.shake(c, 'fist.R.ik', f0, f1, (0.02 * self.S, 0, 0.015 * self.S), freq=1.0, seed=4)
        return self.fin(c, sk, arms='world'), self.f(25)

    def sweep(self, sk):
        """Gira o tronco e varre a frente com o braco direito. Acerto no quadro f(21)."""
        lh = (0.70, 0.30, 0.95)
        c = self.ck('attack2', 46, [
            (5, mg({'torso': (4, 0, 8)}, self.bp(0, 0, -0.05)), 'o'),
            (15, mg({'body': (0, 0, -16), 'torso': (-6, 0, -46), 'noggin': (0, 0, 40)}, self.bp(0.06, -0.06, -0.10),
                    self.hands(lh, (-1.30, -0.55, 1.30)), {'core.scale': (1.4, 1.4, 1.4)}), 'o'),
            (18, mg({'torso': (-8, 0, -52)}, self.hands(lh, (-1.28, -0.66, 1.36)))),
            (20, mg({'body': (6, 0, 4), 'torso': (10, 0, 4), 'noggin': (0, 0, 0)}, self.bp(-0.02, 0.10, -0.14),
                    self.hands((0.95, -0.20, 1.0), (-0.95, 0.95, 0.80))), 'i'),
            (22, mg({'body': (8, 0, 18), 'torso': (12, 0, 56), 'noggin': (0, 0, -30), 'core.scale': (1, 1, 1)},
                    self.bp(-0.06, 0.12, -0.14), self.hands((1.0, -0.55, 1.05), (0.45, 1.10, 0.80))), 'l'),
            (25, mg({'torso': (10, 0, 70)}, self.hands((0.95, -0.60, 1.0), (0.95, 0.55, 0.95))), 'o'),
            (32, mg({'body': (4, 0, 12), 'torso': (6, 0, 50)}, self.bp(-0.03, 0.06, -0.08))),
            (46, self.REST),
        ])
        eb.shake(c, 'torso', self.f(13), self.f(19), (0, 0, 2.0), freq=0.9)
        return self.fin(c, sk, arms='world'), self.f(21)

    def hit(self, sk, n=9):
        c = self.ck('hit', n, [
            (2, mg({'body': (-5, 0, 3), 'torso': (-13, 0, 7), 'noggin': (-14, 0, 9), 'noggin.pos': self.v(0, -0.03, 0.11),
                    'core.scale': (0.6, 0.6, 0.6)}, self.bp(0, -0.06, -0.02), self.hands((0.98, 0.0, 0.66), (-0.94, 0.10, 0.60)),
                   sym({'armU.L.pos': self.v(0.06, 0, 0.06)})), 'o'),
            (5, mg({'body': (2, 0, -1), 'torso': (5, 0, -2), 'noggin': (5, 0, -3), 'noggin.pos': self.v(0, 0, -0.02),
                    'core.scale': (1.3, 1.3, 1.3)}, self.bp(0, -0.02, -0.03), self.hands((0.86, 0.10, 0.50)),
                   sym({'armU.L.pos': (0, 0, 0)}))),
            (n, self.REST),
        ], scale=False)
        return self.fin(c, sk)

    # ---- desmoronar / montar
    def pile(self, sk, g=None):
        """Pose da pilha de blocos; com a malha `g`, assenta cada bloco exatamente no chao."""
        S = self.S
        if getattr(self, '_pile', None) is not None:
            return dict(self._pile)
        lift = {b: 0.0 for b in ORDER}
        pts = {b: [] for b in ORDER}
        if g is not None:
            for p, ws in zip(g.v, g.w):
                b = max(ws, key=ws.get)
                b = {'core': 'torso', 'eyes': 'noggin'}.get(b, b)
                if b in pts:
                    pts[b].append(p)
        for _ in range(3 if g is not None else 1):
            pose = {}
            for b in ORDER:
                base = b.split('.')[0]
                cen = Vector(CEN[base])
                if b.endswith('.R'):
                    cen.x = -cen.x
                tgt, rot = PILE[b]
                eb.place(sk, pose, b, cen * S, (tgt[0] * S, tgt[1] * S, tgt[2] * S + lift[b]), rot)
            if g is None:
                break
            mats = sk.fk({k: tuple(v) for k, v in pose.items()})
            for b in ORDER:
                if pts[b]:
                    lift[b] -= min((mats[b] @ p).z for p in pts[b]) - 0.004
        self._pile = dict(pose)
        return pose

    def exploded(self, k=1.0):
        S = self.S * k
        e = sym({'armU.L.pos': (0.26 * S, 0, 0.10 * S), 'armU.L': (0, -14 * k, 0), 'armF.L.pos': (0.08 * S, 0, -0.10 * S),
                 'armF.L': (10 * k, -8 * k, 0), 'fist.L.pos': (0, 0, -0.12 * S), 'fist.L': (0, 0, 20 * k),
                 'legU.L.pos': (0.08 * S, 0, 0.02 * S), 'legF.L.pos': (0.03 * S, 0, 0.0), 'legU.L': (0, -8 * k, 0)})
        e.update({'torso.pos': (0, 0, 0.20 * S), 'torso': (-6 * k, 0, 4 * k), 'noggin.pos': (0, 0, 0.26 * S),
                  'noggin': (-10 * k, 0, 14 * k), 'body.pos': (0, 0, 0.04 * S), 'body': (0, 0, -4 * k)})
        return e

    def die(self, sk, n=44, g=None):
        """A runa falha e apaga, as juntas soltam e os blocos desabam numa pilha."""
        pile = self.pile(sk, g)
        arms = {k: v for k, v in pile.items() if k.startswith(('armF', 'fist'))}
        head = {k: v for k, v in pile.items() if k.startswith('noggin')}
        rest = {k: v for k, v in pile.items() if k not in arms and k not in head}
        off = {'core.scale': (0.01, 0.01, 0.01), 'eyes.scale': (0.01, 0.01, 0.01)}
        c = self.ck('die', n, [
            (2, {'torso': (-12, 0, 6), 'noggin': (-14, 0, 9), 'noggin.pos': self.v(0, 0, 0.10), 'core.scale': (1.6, 1.6, 1.6)}, 'o'),
            (5, {'core.scale': (0.3, 0.3, 0.3), 'eyes.scale': (1, 1, 0.3)}), (8, {'core.scale': (1.2, 1.2, 1.2), 'eyes.scale': (1, 1, 1)}),
            (11, off, 'i'),
            (12, self.exploded(0.45)),
            (21, arms, 'i'), (25, rest, 'i'), (28, head, 'i'),
            (n, {'body': pile['body']}),
        ])
        f = self.f(25)
        eb.add_fn(c, 'body.pos', lambda fr: (0, 0, 0.05 * self.S * math.sin(math.pi * (fr - f) / (self.f(31) - f)))
                  if f < fr < self.f(31) else (0, 0, 0))
        return self.fin(c, sk, ik=False)

    def assemble(self, sk, n=50, g=None):
        """Os blocos tremem na pilha, sobem, flutuam soltos e se encaixam; a runa acende."""
        pile = self.pile(sk, g)
        off = {'core.scale': (0.01, 0.01, 0.01), 'eyes.scale': (0.01, 0.01, 0.01)}
        start = mg(self.REST, pile, off)
        c = self.ck('spawn', n, [
            (8, pile),
            (22, self.exploded(1.0), 'io'),
            (27, self.exploded(1.15)),
            (28, off),
            (31, mg({b: (0, 0, 0) for b in ORDER}, {b + '.pos': (0, 0, 0) for b in ORDER},
                    {'body.scale': (1.06, 1.06, 0.92), 'body.pos': self.v(0, 0, -0.08)}), 'i'),
            (34, {'core.scale': (1.9, 1.9, 1.9), 'eyes.scale': (1.3, 1.3, 1.6), 'body.scale': (0.98, 0.98, 1.03),
                  'body.pos': (0, 0, 0)}, 'o'),
            (40, {'core.scale': (1, 1, 1), 'eyes.scale': (1, 1, 1), 'torso': (-8, 0, 0), 'noggin': (-10, 0, 0),
                  'body.scale': (1, 1, 1)}),
            (n, self.REST),
        ], base=start)
        for b in ('torso', 'noggin', 'armF.L', 'armF.R', 'fist.L', 'fist.R'):
            eb.shake(c, b, 0, self.f(9), (3, 3, 3), freq=1.3, seed=len(b), grow=True)
        return self.fin(c, sk, ik=False)
